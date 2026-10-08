#!/bin/zsh
# 一行裝新版（只印一行結果，詳細紀錄在 build/deploy.log）
#   ./deploy.sh          裝到 Jean 的 iPhone
#   ./deploy.sh sim      裝到電腦上的模擬器（iPhone 17 Pro）
#   ./deploy.sh both     兩個都裝
cd "${0:A:h}"
LOG=build/deploy.log; mkdir -p build; : > $LOG
PHONE=00008150-001971140A80401C
TARGET=${1:-phone}

if [[ $TARGET == phone || $TARGET == both ]]; then
  xcodegen generate -q >>$LOG 2>&1
  if xcodebuild -project StillLink.xcodeproj -scheme StillLink -destination "id=$PHONE" -derivedDataPath build/dd \
       -allowProvisioningUpdates build >>$LOG 2>&1 &&
     xcrun devicectl device install app --device $PHONE build/dd/Build/Products/Debug-iphoneos/StillLink.app >>$LOG 2>&1; then
    echo "✓ iPhone"
  else
    echo "✗ iPhone（看 build/deploy.log）"; grep -m3 "error" $LOG
  fi
fi

if [[ $TARGET == sim || $TARGET == both ]]; then
  if ./build.sh >>$LOG 2>&1; then
    xcrun simctl boot "iPhone 17 Pro" >>$LOG 2>&1
    xcrun simctl install "iPhone 17 Pro" build/StillLink.app >>$LOG 2>&1
    xcrun simctl terminate "iPhone 17 Pro" app.stilllink.ios.beta >>$LOG 2>&1
    xcrun simctl launch "iPhone 17 Pro" app.stilllink.ios.beta >>$LOG 2>&1 && echo "✓ 模擬器"
  else
    echo "✗ 模擬器（看 build/deploy.log）"; grep -m3 "error" $LOG
  fi
fi
