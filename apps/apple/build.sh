#!/bin/zsh
# 編譯並組成 紫微.app（原生 SwiftUI，沒有 WebView）
set -e
cd "$(dirname "$0")"
swift build -c release
APP=build/紫微.app
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp .build/release/Ziwei "$APP/Contents/MacOS/Ziwei"
cp Resources/*.js Resources/zone.tab "$APP/Contents/Resources/"
cat > "$APP/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleName</key><string>紫微</string>
  <key>CFBundleDisplayName</key><string>紫微</string>
  <key>CFBundleIdentifier</key><string>com.jeanui.ziwei</string>
  <key>CFBundleExecutable</key><string>Ziwei</string>
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
