// StillLink 問題回報：App 把回報 POST 到這裡，這裡透過 Resend 寄信到 support@jeanui.com
// 使用者不用開自己的郵件 App。金鑰 RESEND_API_KEY 只存在 Cloudflare（wrangler secret），不進 repo。

const TO = "support@jeanui.com";
const FROM = "StillLink 回報 <report@send.jeanui.com>";
// App 帶的辨識碼：擋掉隨便掃網址的機器人（App 是公開下載的，擋不住會拆程式的人，搭配下面的頻率限制）
const APP_KEY = "stilllink-report-v1";

const json = (body, status = 200) =>
  new Response(JSON.stringify(body), { status, headers: { "content-type": "application/json; charset=utf-8" } });

const isEmail = (s) => /^[^\s@]{1,64}@[^\s@]{1,190}\.[^\s@]{2,}$/.test(s);

export default {
  async fetch(req, env) {
    if (req.method !== "POST") return new Response("StillLink report endpoint");
    if (req.headers.get("x-stilllink") !== APP_KEY) return json({ ok: false, error: "forbidden" }, 403);

    // 同一個 IP 每分鐘最多 3 封（wrangler.toml 的 ratelimits）
    const ip = req.headers.get("cf-connecting-ip") || "unknown";
    const { success } = await env.LIMITER.limit({ key: ip });
    if (!success) return json({ ok: false, error: "rate_limited" }, 429);

    let data;
    try { data = await req.json(); } catch { return json({ ok: false, error: "bad_json" }, 400); }
    const message = String(data.message || "").trim();
    const contact = String(data.contact || "").trim();
    const diagnostics = String(data.diagnostics || "").trim();
    const version = String(data.version || "").slice(0, 40);
    if (!message || message.length > 5000) return json({ ok: false, error: "bad_message" }, 400);
    if (contact && (contact.length > 254 || !isEmail(contact))) return json({ ok: false, error: "bad_contact" }, 400);
    if (diagnostics.length > 10000) return json({ ok: false, error: "bad_diagnostics" }, 400);

    const firstLine = message.split("\n")[0].slice(0, 40);
    const text = [
      message,
      "",
      "——",
      contact ? `回覆給：${contact}（直接按回覆即可）` : "對方沒有留 email，這封無法回覆",
      "",
      diagnostics,
    ].join("\n");

    const res = await fetch("https://api.resend.com/emails", {
      method: "POST",
      headers: { Authorization: `Bearer ${env.RESEND_API_KEY}`, "Content-Type": "application/json" },
      body: JSON.stringify({
        from: FROM,
        to: [TO],
        subject: `[StillLink ${version}] ${firstLine}`,
        text,
        ...(contact ? { reply_to: contact } : {}),
      }),
    });
    if (!res.ok) return json({ ok: false, error: "send_failed", status: res.status }, 502);
    return json({ ok: true });
  },
};
