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
APPENDIX = {"附錄1": "附錄一 命宮主星職業", "附錄2": "附錄二 官祿宮工作模式", "附錄3": "附錄三 財帛宮現金處理",
            "附錄4": "附錄四 田宅宮居家風格", "附錄5": "附錄五 遷移宮打扮風格", "附錄6": "附錄六 疾厄宮疾病參考",
            "附錄7": "附錄七 化忌可拜神明", "附錄8": "附錄八 天生沒長好"}


def clean(s):
    return norm(s.strip().lstrip("*•#-").strip())


def block(ls):
    return "\n".join(c for c in (clean(l) for l in ls) if c)


def docs(lines):
    L = [norm(l) for l in lines]
    def at(text, start=0):
        return next((i for i in range(start, len(L)) if L[i].strip().startswith(text)), len(L))
    out = {}
    i_ten, i_jia, i_order = at("十年天干四化介紹"), at("甲天干四化"), at("生年四化→")
    i_cure, i_zz, i_cs = at("十年天干化忌解方"), at("實戰小應用"), at("長生十二宮")
    i_app = next((i for i in range(i_cs, len(L)) if L[i].strip() == "附錄"), len(L))
    i_other = at("其他備註", i_app)

    # 十干四化表：每 5 格一列（年尾、天干、祿權科忌、代表數、色彩）
    cells = [c for c in (l.strip() for l in L[i_ten + 1:i_jia]) if c]
    k = cells.index("代表色彩/元素") + 1 if "代表色彩/元素" in cells else 0
    rows = [f"{st}（西元年尾 {y}）：{sh}｜代表數 {n}｜{c}"
            for y, st, sh, n, c in (cells[j:j + 5] for j in range(k, len(cells) - 4, 5)) if st in STEMS]
    out["十干四化表"] = "\n".join(rows + [f"\n看盤順序：{L[i_order].strip()}"])
    # 甲干四化…癸干四化：四顆星化的人物、事件形象
    for st in STEMS:
        a = at(st + "天干四化", i_jia)
        b = next((i for i in range(a + 1, i_order + 1) if L[i].strip().endswith("天干四化") or i == i_order), i_order)
        out[st + "干四化"] = block(L[a + 1:b])
    out["化忌解方"] = block(L[i_cure + 1:i_zz])
    out["紫占"] = block(L[i_zz + 1:i_cs])
    # 長生十二宮：開頭一段說明＋12 個長生神
    intro = block(L[i_cs + 1:i_cs + 2])
    cur = None
    for l in L[i_cs + 2:i_app]:
        c = clean(l)
        m = re.match(r"^\d+\.(\S+?)（(.+?)）(.*)$", c)
        if m and m.group(1) in CHANGSHENG:
            cur = m.group(1)
            out[cur] = f"{m.group(2)}\n{m.group(3).strip()}"
        elif cur and c:
            out[cur] += "\n" + c
    out["長生十二宮"] = intro + "\n" + "、".join(CHANGSHENG)
    # 附錄：表格整理成「星名\n欄位：內容」一段一段
    tags = list(APPENDIX)
    for n, tag in enumerate(tags):
        a = next((i for i in range(i_app, len(L)) if L[i].strip().startswith(tag)), None)
        if a is None:
            continue
        b = next((i for i in range(a + 1, len(L)) if any(L[i].strip().startswith(t) for t in tags[n + 1:]) or L[i].strip().startswith("其他備註")), len(L))
        cells = [c for c in (clean(l) for l in L[a + 1:b]) if c]
        if tag in ("附錄6", "附錄8"):
            out[APPENDIX[tag]] = "\n".join(cells)
            continue
        cells = cells[1:] if cells and cells[0] == "代表星曜" else cells
        first = next((j for j, c in enumerate(cells) if c[:2] in MAJORS), None)
        if first is None:
            continue
        heads, parts, j = cells[:first], [], first
        while j < len(cells):
            vals = cells[j + 1:j + 1 + len(heads)]
            parts.append(cells[j] + "\n" + "\n".join(f"{h}：{v}" for h, v in zip(heads, vals)))
            j += 1 + len(heads)
        out[APPENDIX[tag]] = "\n\n".join(parts)
    out["其他備註"] = block(L[i_other + 1:])
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
