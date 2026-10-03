#!/usr/bin/env python3
"""把朋友整理的星曜文件（Google Docs 匯出成 txt）轉成 app 內建的預設星曜筆記。

用法：python3 scripts/import-star-notes.py notes.txt > Resources/star-notes.json
文件匯出：https://docs.google.com/document/d/<id>/export?format=txt

格式：每顆星一個區塊，開頭一行是星名（後面可接「：說明」或「（…）」），
底下是條列；「落在各宮狀態」之後的「命：…」「兄：…」那些行是落在十二宮的意思。
"""
import json
import re
import sys

MAJOR = "紫微 天機 太陽 武曲 天同 廉貞 天府 太陰 貪狼 巨門 天相 天梁 七殺 破軍".split()
SINGLE = MAJOR + "文昌 文曲 左輔 右弼 天魁 天鉞 擎羊 陀羅 火星 鈴星 地空 地劫 祿存 天馬 紅鸞 天喜 天姚 天刑 咸池 化祿 化權 化科 化忌".split()
PALACES = "命 兄 夫 子 財 父 福 田 官 友 遷 疾".split()
STOP = {"雙星結構", "六吉星", "四煞星", "空星", "四化", "十年天干四化介紹"}


def norm(name):
    return name.replace("天粱", "天梁").replace("紫薇", "紫微")


def header(line):
    """這行是不是一個星曜區塊的開頭；是的話回傳星名"""
    s = norm(line.strip())
    if not s or line[:1] in " \t*":
        return None
    m = re.match(r"^([一-鿿]{2,4})(?:[：:（(].*)?$", s)
    if not m:
        return None
    n = m.group(1)
    if n in SINGLE:
        return n
    # 雙星：兩顆主星連寫
    if len(n) == 4 and n[:2] in MAJOR and n[2:] in MAJOR:
        return n
    return None


# ── 參考文件（十年天干四化、紫占、長生十二宮、附錄）：只有內文，筆記頁的「目錄」會列出來

MAJORS = "紫微 天機 太陽 武曲 天同 廉貞 天府 太陰 貪狼 巨門 天相 天梁 七殺 破軍".split()
STEMS = "甲 乙 丙 丁 戊 己 庚 辛 壬 癸".split()
CHANGSHENG = "長生 沐浴 冠帶 臨官 帝旺 衰 病 死 墓 絕 胎 養".split()
# 十四主星分三組（附錄照這個順序分組排）
STAR_GROUPS = [("北斗星系", "紫微 貪狼 巨門 廉貞 武曲 破軍".split()),
               ("南斗星系", "天府 天梁 天機 天同 天相 七殺".split()),
               ("中天主星", "太陽 太陰".split())]
APPENDIX = {"附錄1": "附錄一 命宮主星職業", "附錄2": "附錄二 官祿宮工作模式", "附錄3": "附錄三 財帛宮現金處理",
            "附錄4": "附錄四 田宅宮居家風格", "附錄5": "附錄五 遷移宮打扮風格", "附錄6": "附錄六 疾厄宮疾病參考",
            "附錄7": "附錄七 化忌可拜神明", "附錄8": "附錄八 天生沒長好"}


def clean(s):
    return norm(s.strip().lstrip("*•#-").strip())


def block(ls):
    return "\n".join(c for c in (clean(l) for l in ls) if c)


def bullets(ls):
    """一行一點；行內的「•」也拆開"""
    out = []
    for l in ls:
        for part in norm(l).replace("•", "\n").split("\n"):
            c = clean(part)
            if c:
                out.append("・" + c)
    return out


def docs(lines):
    """參考文件排版：「## 小標題」、「・條列」、「A｜B｜C」表格（第一列是表頭）、空行分段"""
    L = [norm(l) for l in lines]
    def at(text, start=0):
        return next((i for i in range(start, len(L)) if L[i].strip().startswith(text)), len(L))
    out = {}
    i_ten, i_jia, i_order = at("十年天干四化介紹"), at("甲天干四化"), at("生年四化→")
    i_cure, i_zz, i_cs = at("十年天干化忌解方"), at("實戰小應用"), at("長生十二宮")
    i_app = next((i for i in range(i_cs, len(L)) if L[i].strip() == "附錄"), len(L))
    i_other = at("其他備註", i_app)

    # 十干四化表
    cells = [c for c in (l.strip() for l in L[i_ten + 1:i_jia]) if c]
    k = cells.index("代表色彩/元素") + 1 if "代表色彩/元素" in cells else 0
    rows = ["天干｜西元年尾｜祿權科忌｜代表數｜代表色彩、元素"]
    rows += [f"{st}｜{y}｜{sh}｜{n}｜{c.replace('/', '、')}"
             for y, st, sh, n, c in (cells[j:j + 5] for j in range(k, len(cells) - 4, 5)) if st in STEMS]
    order = L[i_order].strip()
    out["十干四化表"] = "\n".join(rows) + f"\n\n## 看盤順序\n{order.replace('→', ' → ')}"

    # 甲干四化…癸干四化：每顆星化一個小標題
    for st in STEMS:
        a = at(st + "天干四化", i_jia)
        b = next((i for i in range(a + 1, i_order + 1) if L[i].strip().endswith("天干四化") or i == i_order), i_order)
        parts = []
        for l in L[a + 1:b]:
            c = clean(l)
            if not c:
                continue
            if re.match(r"^[\u4e00-\u9fff]{2}化[祿權科忌]$", c):
                parts.append(("\n" if parts else "") + "## " + c)
            else:
                parts.append("・" + c)
        out[st + "干四化"] = "\n".join(parts)

    # 化忌解方：甲太陽化忌 → 「## 甲干 太陽化忌」
    parts = []
    for l in L[i_cure + 1:i_zz]:
        c = clean(l)
        m = re.match(r"^([甲乙丙丁戊己庚辛壬癸])([\u4e00-\u9fff]{2}化忌)$", c)
        if m:
            parts.append(("\n" if parts else "") + f"## {m.group(1)}干・{m.group(2)}")
        elif c:
            parts.append("・" + c)
    out["化忌解方"] = "\n".join(parts)

    # 紫占
    zz = [clean(l) for l in L[i_zz + 1:i_cs] if clean(l)]
    steps = [c for c in zz if re.match(r"^\d+\.", c)]
    demo = [c for c in zz if c.startswith("步驟")]
    notes = [c for c in zz if "須知" in c or c.startswith("空宮")]
    out["紫占"] = "\n".join(["## 操作步驟"] + steps + ["", "## 怎麼解盤"]
                            + ["・" + re.sub(r"^步驟(\d)：", r"第\1步：", c) for c in demo]
                            + ["", "## 須知"] + ["・" + c.replace("紫占須知：", "") for c in notes])

    # 長生十二宮：說明＋一覽表；每個長生神：意義、特點、落宮
    intro = clean(L[i_cs + 1])
    table = ["順序｜長生神｜階段"]
    cur = None
    for l in L[i_cs + 2:i_app]:
        c = clean(l)
        m = re.match(r"^(\d+)\.(\S+?)（(.+?)）(.*)$", c)
        if m and m.group(2) in CHANGSHENG:
            cur = m.group(2)
            table.append(f"{m.group(1)}｜{cur}｜{m.group(3)}")
            out[cur] = f"## {m.group(3)}\n" + "・" + m.group(4).strip()
        elif cur and c:
            out[cur] += "\n・" + c
    out["長生十二宮"] = intro + "\n\n" + "\n".join(table)

    # 附錄
    tags = list(APPENDIX)
    for n, tag in enumerate(tags):
        a = next((i for i in range(i_app, len(L)) if L[i].strip().startswith(tag)), None)
        if a is None:
            continue
        b = next((i for i in range(a + 1, len(L)) if any(L[i].strip().startswith(t) for t in tags[n + 1:]) or L[i].strip().startswith("其他備註")), len(L))
        raw = L[a + 1:b]
        cells = [c for c in (clean(l) for l in raw) if c]
        if tag == "附錄6":       # 疾厄：每顆主星一張卡片（條列），照北斗／南斗／中天分區
            per, cur = {}, None
            for l in raw:
                c = clean(l)
                name = c[:-1] if c.endswith("星") else c
                if name in MAJORS:
                    cur = name; per[cur] = []
                elif c and cur:
                    per[cur] += bullets([l])
            parts = []
            for g, stars in STAR_GROUPS:
                parts.append(("\n" if parts else "") + "# " + g)
                for st in stars:
                    if st in per:
                        parts += ["", "## " + st] + per[st]
            out[APPENDIX[tag]] = "\n".join(parts)
            continue
        if tag == "附錄8":       # 地支 → 部位，照子丑寅卯排成表
            pairs = dict(re.findall(r"([子丑寅卯辰巳午未申酉戌亥])：(\S+)", "\n".join(cells)))
            order = "子 丑 寅 卯 辰 巳 午 未 申 酉 戌 亥".split()
            out[APPENDIX[tag]] = "命盤上每個地支宮位對應的身體部位。\n\n地支｜部位\n" + "\n".join(f"{z}｜{pairs[z]}" for z in order if z in pairs)
            continue
        cells = cells[1:] if cells and cells[0] == "代表星曜" else cells
        first = next((j for j, c in enumerate(cells) if c[:2] in MAJORS), None)
        if first is None:
            continue
        heads, j = cells[:first], first
        if tag == "附錄7":       # 神明：照北斗／南斗／中天／輔星分組，各一張表
            gods = {}
            while j < len(cells):
                nm = cells[j][:-1] if cells[j].endswith("星") else cells[j]
                gods[nm] = cells[j + 1] if j + 1 < len(cells) else ""
                j += 2
            groups = STAR_GROUPS + [("輔星", [k for k in gods if k not in MAJORS])]
            parts = []
            for g, stars in groups:
                rows = [f"{st}｜{gods[st]}" for st in stars if st in gods]
                if rows:
                    parts.append(f"## {g}\n星曜｜代表神明\n" + "\n".join(rows))
            out[APPENDIX[tag]] = "\n\n".join(parts)
            continue
        # 附錄一～五：照北斗／南斗／中天分組，每組一張表（星曜｜各欄位）
        per = {}
        while j < len(cells):
            vals = cells[j + 1:j + 1 + len(heads)]
            nm = cells[j]
            short = nm.split("（")[0].rstrip("星")
            per[short] = (nm.replace("星（", "（"), vals)
            j += 1 + len(heads)
        parts = []
        for g, stars in STAR_GROUPS:
            rows = [per[st][0] + "｜" + "｜".join(v.replace("｜", "／") for v in per[st][1]) for st in stars if st in per]
            if rows:
                parts.append(f"## {g}\n星曜｜" + "｜".join(heads) + "\n" + "\n".join(rows))
        out[APPENDIX[tag]] = "\n\n".join(parts)

    # 其他備註：分成小技巧、靈力值、猜餐點
    oc = [clean(l) for l in L[i_other + 1:] if clean(l)]
    def idx(t):
        return next((i for i, c in enumerate(oc) if c.startswith(t)), len(oc))
    a_ling, a_meal, a_food = idx("靈力值"), idx("紫占猜餐點"), idx("猜食物")
    food = [c.split("：", 1) for c in oc[a_food + 1:] if "：" in c]
    out["其他備註"] = "\n".join(
        ["## 小技巧"] + ["・" + c for c in oc[:a_ling]]
        + ["", "## 靈力值紫占"] + ["・" + c for c in oc[a_ling + 1:a_meal]]
        + ["", "## 紫占猜餐點"] + ["・" + c for c in oc[a_meal + 1:a_food]]
        + ["", "## 星曜對應的食物", "星曜｜食物"] + [f"{a}｜{b}" for a, b in food])
    return {k: v.strip() for k, v in out.items() if v.strip()}


def main(path):
    lines = open(path, encoding="utf-8-sig").read().splitlines()
    notes = {}
    cur = None
    in_palace = False
    title = ""
    for raw in lines:
        s = raw.strip()
        if norm(s) in STOP or s.startswith("十年天干四化"):
            cur = None
            if s.startswith("十年天干四化"):
                break
            continue
        h = header(raw)
        if h:
            # 雙星目錄那一段只有名字沒有內容，遇到同名正文時重新開始
            cur = notes.setdefault(h, {"summary": [], "palaces": {}})
            cur["summary"], cur["palaces"] = [], {}
            sub = norm(s)[len(h):].lstrip("：:")
            title = sub
            if sub:
                cur["summary"].append(sub)
            in_palace = False
            continue
        if cur is None or not s:
            continue
        b = s.lstrip("*").strip()
        if b.startswith("落在各宮狀態") or b.startswith("落在命盤四個角落狀態"):
            in_palace = True
            continue
        pm = re.match(r"^(命|兄|夫|子|財|父|福|田|官|友|遷|疾)[：:](.*)$", b)
        if in_palace and pm:
            cur["palaces"][pm.group(1)] = pm.group(2).strip()
            continue
        if not s.startswith("*") and cur["summary"]:
            # 沒有項目符號的行接在上一行後面（例：男命特性；女命特性 被換行切開）
            cur["summary"][-1] += " " + b
        else:
            cur["summary"].append(b)
    out = {}
    for k, v in notes.items():
        summary = "\n".join(x for x in v["summary"] if x.strip(" ：;；"))
        if summary or v["palaces"]:
            out[k] = {"summary": summary, "palaces": {p: v["palaces"][p] for p in PALACES if v["palaces"].get(p)}}
    for k, t in docs(lines).items():
        out[k] = {"summary": t, "palaces": {}}
    json.dump(out, sys.stdout, ensure_ascii=False, indent=1, sort_keys=True)


if __name__ == "__main__":
    main(sys.argv[1])
