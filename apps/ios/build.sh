#!/bin/zsh
# iOS 版建置（模擬器）
#   ./build.sh          編譯＋組 .app
#   ./build.sh run      編譯後裝進模擬器並打開（預設 iPhone 17 Pro；SIM=名稱 可換，例：SIM="iPad Pro 13-inch (M5)"）
#   ./build.sh check    只做型別檢查（最快，列出錯誤）
#   ./build.sh xcode    產生 StillLink.xcodeproj（要用 Xcode 開、上實機時；需要 xcodegen＋Xcode 的 iOS 元件）
#
# 為什麼不用 xcodebuild：這台 Mac 的 Xcode 還沒裝 iOS 26.5 元件（要 8.5GB 空間），xcodebuild 會拒絕編譯；
# 直接用 swiftc＋iphonesimulator SDK 編，裝進現有的 iOS 26.0 模擬器就能跑。
# 共用檔案清單跟 project.yml 一樣，兩邊要一起改。
set -e
cd "${0:A:h}"
SIM=${SIM:-"iPhone 17 Pro"}
SHARED=../apple/Sources/StillLink
RES=../apple/Resources
OUT=build/StillLink.app
BUNDLE_ID=app.stilllink.ios.beta

if [[ "$1" == xcode ]]; then xcodegen generate; open StillLink.xcodeproj; exit 0; fi

FILES=(Sources/**/*.swift(N)
  $SHARED/Engine/*.swift
  $SHARED/{AppInfo,Platform,Settings,Store,Theme,Motion,Sound,StarNotes}.swift
  $SHARED/Views/{ChartBoard,ClampOverlay,Controls,ZInput,PeriodTable}.swift)

SDK=$(xcrun -sdk iphonesimulator --show-sdk-path)
ARCH=$(uname -m)
FLAGS=(-sdk $SDK -target $ARCH-apple-ios18.0-simulator -swift-version 5 -module-name StillLink -parse-as-library)

mkdir -p build
if [[ "$1" == check ]]; then
  xcrun swiftc -typecheck $FLAGS $FILES 2>&1 | grep -E "error:" | sed -E 's|^.*/(Sources/)|\1|' | sort -u | head -80
  [[ ${pipestatus[1]} == 0 ]] && echo "✓ 沒有錯誤"
  exit 0
fi

rm -rf $OUT && mkdir -p $OUT
if ! xcrun swiftc $FLAGS -Onone -g $FILES -o $OUT/StillLink > build/swiftc.log 2>&1; then
  grep -E "error:" build/swiftc.log | sed -E 's|^.*/(Sources/)|\1|' | sort -u | head -80
  echo "✗ 編譯失敗（完整紀錄 build/swiftc.log）"; exit 1
fi

# 資源：排盤 JS、時區表、星曜筆記、音效、圖示
cp $RES/{iztro.min.js,bridge.js,zone.tab,star-notes.json} $OUT/
cp -R $RES/sfx $OUT/sfx
[[ -d Resources ]] && cp -R Resources/. $OUT/ 2>/dev/null || true

VERSION=$(cat ../apple/VERSION 2>/dev/null || echo 0.1.0)
cat > $OUT/Info.plist <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
  <key>CFBundleIdentifier</key><string>$BUNDLE_ID</string>
  <key>CFBundleName</key><string>StillLink</string>
  <key>CFBundleDisplayName</key><string>StillLink</string>
  <key>CFBundleExecutable</key><string>StillLink</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleShortVersionString</key><string>$VERSION</string>
  <key>CFBundleVersion</key><string>$(git rev-list --count HEAD)</string>
  <key>CFBundleDevelopmentRegion</key><string>zh_TW</string>
  <key>CFBundleIcons</key><dict><key>CFBundlePrimaryIcon</key><dict>
    <key>CFBundleIconFiles</key><array><string>AppIcon60x60</string></array></dict></dict>
  <key>LSRequiresIPhoneOS</key><true/>
  <key>MinimumOSVersion</key><string>18.0</string>
  <key>UIDeviceFamily</key><array><integer>1</integer><integer>2</integer></array>
  <key>UILaunchScreen</key><dict/>
  <key>UIApplicationSceneManifest</key><dict><key>UIApplicationSupportsMultipleScenes</key><true/></dict>
  <key>UISupportedInterfaceOrientations</key><array><string>UIInterfaceOrientationPortrait</string></array>
  <key>UISupportedInterfaceOrientations~ipad</key><array>
    <string>UIInterfaceOrientationPortrait</string><string>UIInterfaceOrientationPortraitUpsideDown</string>
    <string>UIInterfaceOrientationLandscapeLeft</string><string>UIInterfaceOrientationLandscapeRight</string></array>
  <key>StillLinkChannel</key><string>beta</string>
  <key>DTPlatformName</key><string>iphonesimulator</string>
</dict></plist>
PLIST
codesign --force --sign - $OUT >/dev/null 2>&1
echo "✓ $OUT"

if [[ "$1" == run ]]; then
  xcrun simctl boot "$SIM" 2>/dev/null || true
  open -g -a Simulator
  xcrun simctl install "$SIM" $OUT
  xcrun simctl launch "$SIM" $BUNDLE_ID ${=LAUNCH_ARGS:-}
fi
