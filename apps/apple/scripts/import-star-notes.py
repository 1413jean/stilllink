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
    json.dump(out, sys.stdout, ensure_ascii=False, indent=1, sort_keys=True)


if __name__ == "__main__":
    main(sys.argv[1])
