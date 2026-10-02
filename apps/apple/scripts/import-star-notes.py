#!/usr/bin/env python3
"""把朋友整理的星曜文件（Google Docs 匯出成 txt）轉成 app 內建的預設星曜筆記。

用法：python3 scripts/import-star-notes.py notes.txt > Resources/star-notes.json
文件匯出：https://docs.google.com/document/d/<id>/export?format=txt

輸出：{ 名稱: {tagline, summary, palaces, deep} }
- 星曜（主星、雙星、六吉、六煞、雜曜、四化）：一句話重點、總論、落在十二宮
- deep：附錄 1～6 的延伸（命＝職業、官＝工作模式、財＝現金處理、田＝居家、遷＝打扮、疾＝疾病）
- 星化（廉貞化祿…）：十干四化各星的人物／事件形象，化忌另附解方
- 長生十二神、以及總覽文件（主星介紹、十干四化表、紫占…）：只有 summary
"""
import json
import re
import sys

MAJOR = "紫微 天機 太陽 武曲 天同 廉貞 天府 太陰 貪狼 巨門 天相 天梁 七殺 破軍".split()
MINOR = "文昌 文曲 左輔 右弼 天魁 天鉞 擎羊 陀羅 火星 鈴星 地空 地劫 祿存 天馬 紅鸞 天喜 天姚 天刑 咸池".split()
MUT = "化祿 化權 化科 化忌".split()
SINGLE = MAJOR + MINOR + MUT
PALACES = "命 兄 夫 子 財 父 福 田 官 友 遷 疾".split()
CHANGSHENG = "長生 沐浴 冠帶 臨官 帝旺 衰 病 死 墓 絕 胎 養".split()
STEMS = "甲 乙 丙 丁 戊 己 庚 辛 壬 癸".split()
STARS_ALL = MAJOR + MINOR


def norm(s):
    return s.replace("天粱", "天梁").replace("紫薇", "紫微")


def clean(s):
    return norm(s.strip().lstrip("*•").strip())


def is_double(n):
    return len(n) == 4 and n[:2] in MAJOR and n[2:] in MAJOR


def find(lines, pred, start=0):
    for i in range(start, len(lines)):
        if pred(lines[i]):
            return i
    return len(lines)


def at(lines, text, start=0):
    return find(lines, lambda l: norm(l.strip()).startswith(text), start)


def text_block(lines):
    return "\n".join(c for c in (clean(l) for l in lines) if c)


def main(path):
    L = [norm(l.rstrip("\n")) for l in open(path, encoding="utf-8-sig")]
    out = {}

    def note(k):
        return out.setdefault(k, {"tagline": "", "summary": "", "palaces": {}, "deep": {}})

    i_double = at(L, "雙星結構")
    i_six = at(L, "六吉星")
    i_four = at(L, "四煞星")
    i_kong = at(L, "空星")
    i_misc = at(L, "雜曜(")
    i_mut = find(L, lambda l: l.strip() == "四化")
    i_ten = at(L, "十年天干四化介紹")
    i_jia = at(L, "甲天干四化")
    i_order = at(L, "生年四化→")
    i_cure = at(L, "十年天干化忌解方")
    i_zz = at(L, "實戰小應用")
    i_cs = at(L, "長生十二宮")
    i_app = find(L, lambda l: l.strip() == "附錄")
    i_a8 = at(L, "附錄8")
    i_other = at(L, "其他備註")

    # ── 星曜區塊（主星、雙星、六吉、六煞、雜曜、四化）
    cur, in_pal = None, False
    for raw in L[:i_ten]:
        s = raw.strip()
        if not s:
            continue
        head = None
        if raw[:1] not in " \t*":
            m = re.match(r"^([一-鿿]{2,4})(?:[：:（(](.*?)[）)]?)?$", s)
            if m and (m.group(1) in SINGLE or is_double(m.group(1))):
                head = m.group(1), (m.group(2) or "").strip()
        if head:
            n = note(head[0])
            n["summary"], n["palaces"] = "", {}
            if head[1]:
                n["tagline"] = head[1]
            cur, in_pal = n, False
            continue
        if cur is None or s in ("雙星結構", "六吉星", "四煞星", "空星", "四化") or s.startswith("雜曜("):
            cur = None
            continue
        b = clean(s)
        if b.startswith("落在各宮狀態") or b.startswith("落在命盤四個角落狀態"):
            in_pal = True
            continue
        pm = re.match(r"^(命|兄|夫|子|財|父|福|田|官|友|遷|疾)[：:](.*)$", b)
        if in_pal and pm:
            cur["palaces"][pm.group(1)] = pm.group(2).strip()
        elif not s.startswith("*") and cur["summary"]:
            cur["summary"] += " " + b      # 沒有項目符號的行接在上一行後面
        else:
            cur["summary"] = (cur["summary"] + "\n" + b).strip()

    # ── 各分類開頭的一句話重點（文昌：寫字、文采好…）→ tagline
    for a, b in ((i_six, at(L, "文昌", i_six + 1)), (i_four, at(L, "擎羊", i_four + 1)),
                 (i_kong, i_kong + 3), (i_misc, at(L, "祿存", i_misc + 1))):
        for l in L[a + 1:b]:
            m = re.match(r"^([一-鿿]{2})[：:](.+)$", clean(l))
            if m and m.group(1) in STARS_ALL:
                note(m.group(1))["tagline"] = m.group(2).strip()

    # ── 總覽文件
    docs = {
        "主星介紹": text_block(L[1:at(L, "紫微")]),
        "六吉星總覽": text_block(L[i_six + 1:at(L, "文昌", i_six + 1)]),
        "四煞星總覽": text_block(L[i_four + 1:at(L, "擎羊", i_four + 1)] + ["空星："] + L[i_kong + 1:i_kong + 3]),
        "雜曜總覽": "不影響核心結果，補充細節、氛圍\n" + text_block(L[i_misc + 1:at(L, "祿存", i_misc + 1)]),
    }
    # 十干四化表：每 5 格一列（年尾、天干、祿權科忌、代表數、色彩）
    cells = [c for c in (l.strip() for l in L[i_ten + 1:i_jia]) if c]
    k = cells.index("代表色彩/元素") + 1 if "代表色彩/元素" in cells else 0
    rows = []
    for j in range(k, len(cells) - 4, 5):
        y, stem, sihua, num, color = cells[j:j + 5]
        if stem in STEMS:
            rows.append(f"{stem}（西元年尾 {y}）：{sihua}｜代表數 {num}｜{color}")
    order = L[i_order].strip() if i_order < len(L) else ""
    docs["十干四化"] = "\n".join(rows + ([f"\n看盤順序：{order}"] if order else []))
    docs["紫占"] = text_block(L[i_zz + 1:i_cs])
    docs["長生十二神"] = text_block(L[i_cs + 1:i_cs + 2])
    docs["天生沒長好"] = "宮位地支對應的身體部位\n" + text_block(L[i_a8 + 1:i_other])
    docs["其他備註"] = text_block(L[i_other + 1:])
    for name, t in docs.items():
        if t.strip():
            note(name)["summary"] = t.strip()

    # ── 星化：甲天干四化 → 廉貞化祿…
    cur = None
    for raw in L[i_jia:i_order]:
        s = clean(raw)
        m = re.match(r"^([一-鿿]{2})(化[祿權科忌])$", s)
        if m and m.group(1) in STARS_ALL:
            cur = note(m.group(1) + m.group(2))
            cur["summary"] = ""
        elif cur is not None and s and not s.endswith("天干四化"):
            cur["summary"] = (cur["summary"] + "\n" + s).strip()
    # 化忌解方：甲太陽化忌 → 太陽化忌
    cur = None
    for raw in L[i_cure + 1:i_zz]:
        s = clean(raw)
        m = re.match(r"^[甲乙丙丁戊己庚辛壬癸]([一-鿿]{2}化忌)$", s)
        if m:
            cur = note(m.group(1))
        elif cur is not None and s:
            cur["summary"] = (cur["summary"] + "\n" + s).strip()

    # ── 長生十二神：「1.長生（起點）意義：…」開頭，後面的行接上去
    cur = None
    for raw in L[i_cs + 2:i_app]:
        s = clean(raw)
        m = re.match(r"^\d+\.(\S+?)（(.+?)）(.*)$", s)
        if m and m.group(1) in CHANGSHENG:
            cur = note(m.group(1))
            cur["tagline"], cur["summary"] = m.group(2), m.group(3).strip()
        elif cur is not None and s:
            cur["summary"] = (cur["summary"] + "\n" + s).strip()

    # ── 附錄 1～5：主星在某宮的延伸表格；附錄 6：疾厄；附錄 7：化忌可拜神明
    app_palace = {"附錄1": "命", "附錄2": "官", "附錄3": "財", "附錄4": "田", "附錄5": "遷"}
    for tag, pk in app_palace.items():
        a = find(L, lambda l: l.strip().startswith(tag), i_app)
        b = find(L, lambda l: l.strip().startswith("附錄") and not l.strip().startswith(tag), a + 1)
        cells = [c for c in (l.strip() for l in L[a + 1:b]) if c]
        cells = cells[1:] if cells and cells[0] == "代表星曜" else cells
        first = next((j for j, c in enumerate(cells) if c[:2] in MAJOR), None)
        if first is None:
            continue
        heads = cells[:first]
        j = first
        while j < len(cells):
            star = cells[j][:2]
            vals = cells[j + 1:j + 1 + len(heads)]
            if star in MAJOR:
                note(star)["deep"][pk] = "\n".join(f"{h}：{v}" for h, v in zip(heads, vals))
            j += 1 + len(heads)
    a6 = find(L, lambda l: l.strip().startswith("附錄6"), i_app)
    b6 = at(L, "疾厄宮吉凶星", a6)
    cur = None
    for raw in L[a6 + 1:b6]:
        s = clean(raw)
        n = s[:-1] if s.endswith("星") and s[:-1] in MAJOR else s
        if n in MAJOR:
            cur = note(n)
            cur["deep"]["疾"] = ""
        elif cur is not None and s:
            cur["deep"]["疾"] = (cur["deep"]["疾"] + "\n" + s).strip()
    a7 = find(L, lambda l: l.strip().startswith("附錄7"), i_app)
    cells = [c for c in (l.strip() for l in L[a7 + 1:i_a8]) if c]
    for j, c in enumerate(cells):
        n = c[:-1] if c.endswith("星") else c
        nxt = cells[j + 1] if j + 1 < len(cells) else ""
        nxt_head = (nxt[:-1] if nxt.endswith("星") else nxt) in STARS_ALL
        if n in STARS_ALL and nxt and not nxt_head:
            nt = note(n)
            nt["summary"] = (nt["summary"] + "\n化忌可拜：" + nxt).strip()

    res = {}
    for k2, v in out.items():
        v["palaces"] = {p: v["palaces"][p] for p in PALACES if v["palaces"].get(p)}
        v["deep"] = {p: v["deep"][p] for p in PALACES if v["deep"].get(p)}
        if v["summary"] or v["palaces"] or v["tagline"]:
            res[k2] = v
    json.dump(res, sys.stdout, ensure_ascii=False, indent=1, sort_keys=True)


if __name__ == "__main__":
    main(sys.argv[1])
