#!/bin/zsh
# 發佈到 GitHub Releases（App 的「檢查更新」就是讀這裡）
#   scripts/publish.sh          測試版 → tag v<版本>-b<build>，標成 Pre-release
#   scripts/publish.sh release  正式版 → tag v<版本>（要在 release 分支上）
set -e
cd "$(dirname "$0")/.."
CHANNEL=${1:-beta}
REPO=$(grep 'static let repo' Sources/StillLink/Updater.swift | sed 's/.*"\(.*\)".*/\1/')
VER=$(cat VERSION)
BUILD=$(git rev-list --count HEAD)
BRANCH=$(git branch --show-current)

if [ $CHANNEL = release ]; then
  [ $BRANCH = release ] || { echo "正式版要在 release 分支發佈（現在在 $BRANCH）"; exit 1; }
  TAG="v$VER"; TITLE="StillLink $VER"; FLAGS=()
  DMG="build/StillLink-$VER.dmg"
else
  TAG="v$VER-b$BUILD"; TITLE="StillLink Beta $VER（build $BUILD）"; FLAGS=(--prerelease)
  DMG="build/StillLink-Beta-$VER-b$BUILD.dmg"
fi

./build.sh $CHANNEL dmg
git push -q
gh release create "$TAG" "$DMG" --repo "$REPO" --target "$BRANCH" --title "$TITLE" \
  --notes "${NOTES:-$TITLE}" $FLAGS
echo "published $TAG"
