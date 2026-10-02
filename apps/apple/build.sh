#!/bin/zsh
# 編譯並組成 StillLink（原生 SwiftUI，沒有 WebView）
#
#   ./build.sh                 測試版 → build/StillLink Beta.app
#   ./build.sh install         測試版，裝到「應用程式」
#   ./build.sh dmg             測試版 DMG（Apple 晶片＋Intel 通用版）
#   ./build.sh release ...     正式版（StillLink.app），其他用法同上
#
# 測試版和正式版是兩個獨立的 App：名稱、圖示、bundle id、資料資料夾都分開，可以同時裝。
# 版本號在 VERSION；build 號＝git commit 數。
set -e
cd "$(dirname "$0")"

CHANNEL=beta
ACTION=""
for a in "$@"; do
  case $a in
    beta|release) CHANNEL=$a ;;
    install|dmg) ACTION=$a ;;
    *) echo "用法：./build.sh [beta|release] [install|dmg]"; exit 1 ;;
  esac
done

VER=$(cat VERSION)
BUILD=$(git rev-list --count HEAD 2>/dev/null || echo 1)
if [ $CHANNEL = release ]; then
  NAME="StillLink"; BUNDLE_ID="app.stilllink.mac"; ICON=Resources/icon-1024.png
  DMG_NAME="StillLink-$VER.dmg"
else
  NAME="StillLink Beta"; BUNDLE_ID="app.stilllink.mac.beta"; ICON=Resources/icon-1024-beta.png
  DMG_NAME="StillLink-Beta-$VER-b$BUILD.dmg"
fi
APP="build/$NAME.app"

if [ "$ACTION" = "dmg" ]; then
  swift build -c release --arch arm64 --arch x86_64
  BIN=.build/apple/Products/Release/StillLink
else
  swift build -c release
  BIN=.build/release/StillLink
fi
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN" "$APP/Contents/MacOS/StillLink"
cp Resources/*.js Resources/zone.tab "$APP/Contents/Resources/"
cp -R Resources/sfx "$APP/Contents/Resources/sfx"
# App 圖示（改圖示：swift scripts/make-icon.swift Resources/icon-1024.png，測試版加參數 beta）
ICONSET=.build/AppIcon.iconset
rm -rf $ICONSET && mkdir -p $ICONSET
for s in 16 32 128 256 512; do
  sips -z $s $s $ICON --out $ICONSET/icon_${s}x${s}.png >/dev/null
  sips -z $((s*2)) $((s*2)) $ICON --out $ICONSET/icon_${s}x${s}@2x.png >/dev/null
done
iconutil -c icns $ICONSET -o "$APP/Contents/Resources/AppIcon.icns"
cat > "$APP/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleName</key><string>$NAME</string>
  <key>CFBundleDisplayName</key><string>$NAME</string>
  <key>CFBundleIdentifier</key><string>$BUNDLE_ID</string>
  <key>CFBundleExecutable</key><string>StillLink</string>
  <key>CFBundleIconFile</key><string>AppIcon</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleShortVersionString</key><string>$VER</string>
  <key>CFBundleVersion</key><string>$BUILD</string>
  <key>StillLinkChannel</key><string>$CHANNEL</string>
  <key>LSMinimumSystemVersion</key><string>14.0</string>
  <key>NSHighResolutionCapable</key><true/>
  <key>CFBundleDevelopmentRegion</key><string>zh_TW</string>
</dict>
</plist>
PLIST
codesign --force --sign - "$APP" >/dev/null 2>&1 || true
echo "built $APP（$CHANNEL $VER build $BUILD）"

# 裝到「應用程式」資料夾（測試版、正式版各裝各的）
if [ "$ACTION" = "install" ]; then
  osascript -e "quit app \"$NAME\"" 2>/dev/null || true
  sleep 1
  rm -rf "/Applications/$NAME.app"
  cp -R "$APP" "/Applications/$NAME.app"
  echo "installed /Applications/$NAME.app"
fi

# DMG：有背景、箭頭、App 圖示、安裝說明的安裝視窗
if [ "$ACTION" = "dmg" ]; then
  # dmgbuild 裝在 .build 裡的 venv（第一次會自動建）
  DMGENV=.build/dmgenv
  [ -x $DMGENV/bin/dmgbuild ] || { python3.11 -m venv $DMGENV && $DMGENV/bin/pip install -q dmgbuild; }
  BG=.build/dmg-bg && rm -rf $BG && mkdir -p $BG
  swift scripts/make-dmg-background.swift $BG "$NAME" >/dev/null
  # 安裝說明：測試版把 App 名稱和路徑換掉
  GUIDE=.build/guide && rm -rf $GUIDE && mkdir -p $GUIDE
  if [ $CHANNEL = release ]; then
    cp Resources/安裝說明.txt $GUIDE/安裝說明.txt
  else
    sed -e 's|/Applications/StillLink.app|@@PATH@@|g' -e 's|StillLink|StillLink Beta|g' \
        -e 's|@@PATH@@|"/Applications/StillLink Beta.app"|g' Resources/安裝說明.txt > $GUIDE/安裝說明.txt
  fi
  DMG="build/$DMG_NAME"
  rm -f "$DMG"
  $DMGENV/bin/dmgbuild -s scripts/dmg-settings.py \
    -D app="$APP" -D bg=$BG/background.png -D icon="$APP/Contents/Resources/AppIcon.icns" -D guide="$GUIDE/安裝說明.txt" \
    "$NAME" "$DMG" >/dev/null
  swift scripts/set-file-icon.swift "$APP/Contents/Resources/AppIcon.icns" "$DMG" >/dev/null
  echo "dmg $DMG"
fi
