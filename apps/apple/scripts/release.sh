#!/bin/zsh
# 一鍵發版：改 Changelog＋版本號 → 推 beta/release → 打包正式版 → 合併 macos13（修 onChange）→ 打包 macOS 13 版
#          → 建 GitHub Release（兩個 DMG＋兩份 appcast）→ 換掉本機正式版 → 確認 App 內更新抓得到
#
# 用法（在 apps/apple 底下）：
#   scripts/release.sh 2.2.2 notes.md            一般更新
#   scripts/release.sh 2.3.0 notes.md --major    重大更新（使用者右上角出現「新功能」）
#   scripts/release.sh 2.2.2 notes.md --check    只印出會寫進 Changelog 的內容，不做任何事
#
# notes.md 格式（只寫有的段落，每段用「- 」開頭列點，講使用者看得到的改變）：
#   ## 新功能
#   - …
#   ## 改進
#   - …
#   ## 修正
#   - …
#
# 過程只印每一步的結果；詳細輸出存在 build/release-<版本>/*.log。任何一步失敗就停下來、印出原因。
set -e
cd "$(dirname "$0")/.."
VER="$1"; NOTES="$2"; shift 2 2>/dev/null || true
MAJOR=""; CHECK=""
for a in "$@"; do [ "$a" = "--major" ] && MAJOR="--major"; [ "$a" = "--check" ] && CHECK=1; done
[ -n "$VER" ] && [ -f "$NOTES" ] || { echo "用法：scripts/release.sh X.Y.Z notes.md [--major|--check]"; exit 1; }
OUT="build/release-$VER"; mkdir -p "$OUT"
REPO=1413jean/stilllink

# Changelog：把 notes.md 轉成一筆 ReleaseNote，插在最上面
SWIFT=$(python3 - "$VER" "$NOTES" "$MAJOR" <<'EOF'
import sys, datetime
ver, path, mode = sys.argv[1], sys.argv[2], sys.argv[3] if len(sys.argv) > 3 else ""
keys = {"新功能": "new", "改進": "improved", "修正": "fixed"}
sec, items = None, {"new": [], "improved": [], "fixed": []}
for line in open(path, encoding="utf-8"):
    t = line.strip()
    if t.startswith("## "): sec = keys.get(t[3:].strip())
    elif t.startswith("- ") and sec: items[sec].append(t[2:].strip().replace('"', '\\"'))
d = datetime.date.today()
head = f'        ReleaseNote(version: "{ver}", date: "{d.year} 年 {d.month} 月 {d.day} 日"' + (", major: true" if mode == "--major" else "")
parts = []
for k in ("new", "improved", "fixed"):
    if items[k]:
        parts.append(f"            {k}: [\n" + "".join(f'                "{x}",\n' for x in items[k]) + "            ]")
print(head + ",\n" + ",\n".join(parts) + "),")
EOF
)
if [ -n "$CHECK" ]; then echo "$SWIFT"; rmdir "$OUT" 2>/dev/null; exit 0; fi

step() { echo "▸ $1"; }
fail() { echo "✗ $1（看 $OUT/$2.log）"; exit 1; }

# 0. 檢查：在 beta、沒有沒 commit 的改動、這個版本還沒發過
[ "$(git branch --show-current)" = "beta" ] || { echo "✗ 要在 beta 分支"; exit 1; }
[ -z "$(git status --porcelain -- . ../../AGENTS.md ../../DESIGN.md)" ] || { echo "✗ 還有沒 commit 的改動"; exit 1; }
gh release view "v$VER" --repo $REPO >/dev/null 2>&1 && { echo "✗ v$VER 已經發過"; exit 1; }

# 1. Changelog＋版本號，推 beta 和 release
step "Changelog＋版本號 $VER"
python3 - "$SWIFT" <<'EOF'
import sys, re
p = "Sources/StillLink/Changelog.swift"; s = open(p, encoding="utf-8").read()
i = s.index("        ReleaseNote(version:")
open(p, "w", encoding="utf-8").write(s[:i] + sys.argv[1] + "\n" + s[i:])
EOF
echo "$VER" > VERSION
git add Sources/StillLink/Changelog.swift VERSION
git commit -qm "版本 $VER

Co-Authored-By: Claude Opus 5.5 (1M context) <noreply@anthropic.com>"
git push -q origin beta && git push -q origin beta:release

# 2. 正式版 DMG（appcast 會被下一步覆蓋，先另存）
step "打包正式版"
./build.sh release dmg > "$OUT/release.log" 2>&1 || fail "正式版打包失敗" release
grep -q "error:" "$OUT/release.log" && fail "正式版編譯錯誤" release
cp "build/StillLink-$VER.dmg" build/appcast.xml "$OUT/"

# 3. macOS 13：合併 release，onChange 改單參數，編譯、推上去、打包
step "合併 macos13"
git checkout -q macos13
git merge --no-edit -q origin/release > "$OUT/merge.log" 2>&1 || { echo "✗ macos13 合併衝突（停在 macos13，解完衝突再手動繼續）"; git diff --name-only --diff-filter=U; exit 1; }
python3 - <<'EOF'
import re, glob
for f in glob.glob("Sources/StillLink/**/*.swift", recursive=True):
    s = open(f, encoding="utf-8").read()
    t = re.sub(r"(\.onChange\(of: [^{]*?\{\s*)_, (\w+) in", r"\1\2 in", s)
    t = re.sub(r"(\.onChange\(of: [^{]*?\{\s*)_, _ in", r"\1_ in", t)
    if t != s: open(f, "w", encoding="utf-8").write(t)
EOF
./build.sh beta > "$OUT/macos13-check.log" 2>&1
if grep -q "error:" "$OUT/macos13-check.log"; then
  echo "✗ macOS 13 編譯錯誤（停在 macos13，多半是 macOS 14 才有的 API，要用 #available 擋）："
  grep -o "StillLink/[^ ]*: error: .*" "$OUT/macos13-check.log" | sort -u | head -10
  exit 1
fi
[ -n "$(git status --porcelain -- Sources)" ] && git commit -qam "macos13：onChange 改單參數

Co-Authored-By: Claude Opus 5.5 (1M context) <noreply@anthropic.com>"
git push -q origin macos13
step "打包 macOS 13 版"
./build.sh release dmg > "$OUT/macos13.log" 2>&1 || fail "macOS 13 打包失敗" macos13
cp "build/StillLink-$VER-macOS13.dmg" build/appcast-macOS13.xml "$OUT/"

# 4. GitHub Release
step "建 GitHub Release"
{ cat "$NOTES"; echo; echo "macOS 14 以上下載 \`StillLink-$VER.dmg\`；macOS 13 下載 \`StillLink-$VER-macOS13.dmg\`。"; } > "$OUT/notes.md"
URL=$(gh release create "v$VER" --repo $REPO --target release --title "StillLink $VER" --notes-file "$OUT/notes.md" \
  "$OUT/StillLink-$VER.dmg" "$OUT/appcast.xml" "$OUT/StillLink-$VER-macOS13.dmg" "$OUT/appcast-macOS13.xml" 2>&1 | tail -1)

# 5. 回 beta，換掉本機正式版
step "換掉本機正式版"
git checkout -q beta
./build.sh release install > "$OUT/install.log" 2>&1 || fail "本機安裝失敗" install

# 6. 確認 App 內更新抓得到（兩份 appcast 都要是新版本）
A=$(curl -sL "https://github.com/$REPO/releases/latest/download/appcast.xml" | grep -o "<sparkle:shortVersionString>[^<]*" | sed 's/.*>//')
B=$(curl -sL "https://github.com/$REPO/releases/latest/download/appcast-macOS13.xml" | grep -o "<sparkle:shortVersionString>[^<]*" | sed 's/.*>//')
if [ "$A" = "$VER" ] && [ "$B" = "$VER" ]; then
  echo "✓ 發佈完成 $VER：$URL（兩份 App 內更新都是 $VER）"
else
  echo "✗ Release 建好了但 appcast 不對：一般版 $A／macOS 13 版 $B（$URL）"; exit 1
fi
