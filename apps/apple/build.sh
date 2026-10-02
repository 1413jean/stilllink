#!/bin/zsh
# 編譯並組成 StillLink.app（原生 SwiftUI，沒有 WebView）
set -e
cd "$(dirname "$0")"
APP=build/StillLink.app
# ./build.sh dmg → Apple 晶片＋Intel 通用版，給別人下載用
if [ "$1" = "dmg" ]; then
  swift build -c release --arch arm64 --arch x86_64
  BIN=.build/apple/Products/Release/Ziwei
else
  swift build -c release
  BIN=.build/release/Ziwei
fi
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN" "$APP/Contents/MacOS/Ziwei"
cp Resources/*.js Resources/zone.tab "$APP/Contents/Resources/"
cp -R Resources/sfx "$APP/Contents/Resources/sfx"
# App 圖示：icon-1024.png → AppIcon.icns（改圖示：swift scripts/make-icon.swift Resources/icon-1024.png）
ICONSET=.build/AppIcon.iconset
rm -rf $ICONSET && mkdir -p $ICONSET
for s in 16 32 128 256 512; do
  sips -z $s $s Resources/icon-1024.png --out $ICONSET/icon_${s}x${s}.png >/dev/null
  sips -z $((s*2)) $((s*2)) Resources/icon-1024.png --out $ICONSET/icon_${s}x${s}@2x.png >/dev/null
done
iconutil -c icns $ICONSET -o "$APP/Contents/Resources/AppIcon.icns"
cat > "$APP/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleName</key><string>StillLink</string>
  <key>CFBundleDisplayName</key><string>StillLink</string>
  <key>CFBundleIdentifier</key><string>com.jeanui.ziwei</string>
  <key>CFBundleExecutable</key><string>Ziwei</string>
  <key>CFBundleIconFile</key><string>AppIcon</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleShortVersionString</key><string>0.1.0</string>
  <key>CFBundleVersion</key><string>1</string>
  <key>LSMinimumSystemVersion</key><string>14.0</string>
  <key>NSHighResolutionCapable</key><true/>
  <key>CFBundleDevelopmentRegion</key><string>zh_TW</string>
</dict>
</plist>
PLIST
codesign --force --sign - "$APP" >/dev/null 2>&1 || true
echo "built $APP"

# ./build.sh install → 裝到「應用程式」資料夾
if [ "$1" = "install" ]; then
  osascript -e 'quit app "StillLink"' 2>/dev/null || true
  osascript -e 'quit app "紫微"' 2>/dev/null || true
  sleep 1
  rm -rf "/Applications/紫微.app"          # 舊名稱
  rm -rf "/Applications/StillLink.app"
  cp -R "$APP" "/Applications/StillLink.app"
  echo "installed /Applications/StillLink.app"
fi

# ./build.sh dmg → build/StillLink-<版本>.dmg（拖進「應用程式」的安裝畫面）
if [ "$1" = "dmg" ]; then
  VER=$(/usr/libexec/PlistBuddy -c "Print CFBundleShortVersionString" "$APP/Contents/Info.plist")
  STAGE=.build/dmg
  rm -rf $STAGE && mkdir -p $STAGE
  cp -R "$APP" $STAGE/
  ln -s /Applications $STAGE/Applications
  DMG=build/StillLink-$VER.dmg
  rm -f "$DMG"
  hdiutil create -volname "StillLink $VER" -srcfolder $STAGE -fs HFS+ -format UDZO -ov "$DMG" >/dev/null
  echo "dmg $DMG"
fi
