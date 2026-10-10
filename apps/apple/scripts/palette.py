#!/usr/bin/env python3
"""調整外框中性色的冷調程度：python3 scripts/palette.py 0.3
0 = 純灰黑（沒有色偏），1 = 原始的 night 色（iOS 第一版，偏冷）。只改明度不變的「色偏」，主色星橘不動。
改的是 Theme.swift（Mac、iOS 共用），兩個 App 一起變。"""
import re, sys, pathlib
K = float(sys.argv[1]) if len(sys.argv) > 1 else 0.3
# 基準值（night，冷調 1.0）：名稱 → (淺色, 深色)
BASE = {
    "zBg": (0xF8F8FA, 0x18191D), "zCard": (0xFFFFFF, 0x222328), "zSide": (0xF3F3F6, 0x131417),
    "zLine": (0xE6E6EA, 0x2E2F35), "zRaised": (0xFFFFFF, 0x2A2B31), "zRaisedLine": (0xDEDEE3, 0x3A3B42),
    "zGrid": (0xCBCCD2, 0x404148), "zText": (0x1D1E22, 0xECECEF), "zText2": (0x55575F, 0xA9AAB2),
    "zText3": (0x8E9098, 0x74767E), "zHover": (0xF0F0F3, 0x26272C), "zSel": (0xEAEAEE, 0x2D2E34),
    "wmSF": (0xEFEFF2, 0x25262B),
}
# 流時的灰（scopeColors、fScopes 最後一個）
SCOPE = [((0x66686F, 0xA9AAB2)), ((0x66686F, 0x55575F))]

def tint(h):
    r, g, b = (h >> 16) & 255, (h >> 8) & 255, h & 255
    m = (r + g + b) / 3
    f = lambda c: max(0, min(255, round(m + (c - m) * K)))
    return (f(r) << 16) | (f(g) << 8) | f(b)

p = pathlib.Path(__file__).parent.parent / "Sources/StillLink/Theme.swift"
s = p.read_text(encoding="utf-8")
for name, (l, d) in BASE.items():
    s, n = re.subn(rf"(static let {name} = dynamic\()0x[0-9A-F]{{6}}, 0x[0-9A-F]{{6}}\)",
                   lambda m: f"{m.group(1)}0x{tint(l):06X}, 0x{tint(d):06X})", s)
    assert n == 1, name
# 流時灰：每一組都在同一行的第二個 dynamic（B8357A 那行）
lines = s.split("\n"); k = 0
for i, line in enumerate(lines):
    m = re.search(r"dynamic\(0xB8357A, 0x[0-9A-F]{6}\), dynamic\(0x[0-9A-F]{6}, 0x[0-9A-F]{6}\)", line)
    if m and k < len(SCOPE):
        l, d = SCOPE[k]; k += 1
        lines[i] = re.sub(r"(dynamic\(0xB8357A, 0x[0-9A-F]{6}\), dynamic\()0x[0-9A-F]{6}, 0x[0-9A-F]{6}\)",
                          lambda mm: f"{mm.group(1)}0x{tint(l):06X}, 0x{tint(d):06X})", lines[i])
assert k == 2
p.write_text("\n".join(lines), encoding="utf-8")
print(f"冷調 {K}：zBg 深色 #{tint(0x18191D):06X}、zCard 深色 #{tint(0x222328):06X}、zBg 淺色 #{tint(0xF8F8FA):06X}")
