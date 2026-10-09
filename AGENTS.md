# StillLink 製作規範（給 AI 協作者：Codex、Claude 等）

StillLink 是原生 SwiftUI 的紫微斗數 Mac app（macOS 14+，另有 macOS 13 分支）。盤面照「文墨天機」，外框照 Claude／Codex 桌面版。
專案負責人是 Jean（UX/UI 設計師）。回覆和程式註解一律用**繁體中文**；回覆先講結果，長度照問題需要就好。

相關文件：
- `README.md`：功能、建置指令、分支對照
- `DESIGN.md`：設計系統（字級、顏色、命盤用色、控制項、動態、提示條）。**改 UI 前先讀**

---

## 1. 絕對不能做的事

1. **不碰正式資料。** 使用者資料在 `~/Library/Application Support/StillLink`（測試版是 `StillLink Beta`）。測試一律設 `ZIWEI_DATA_DIR=<暫存資料夾>`，把 `people.json` 複製過去再用。
2. **Sparkle 私鑰不進 repo。** 私鑰在鑰匙圈（account `stilllink`），`build.sh` 只放公鑰。
3. **不要自己發佈。** 只有 Jean 說「發佈／上版」才出正式版。平常改完只裝測試版給 Jean 看。
4. **不要用 WebView 做介面。** Jean 試過兩次 WebView 版本，都「不是我要的結果」，所以整個改成原生 SwiftUI。iztro 只在 JavaScriptCore 裡算資料（沒有畫面，不算 WebView），畫面全部是 SwiftUI。
5. **命盤反推只開在測試版。** 反推別人的生辰牽涉個資：快捷選單的入口、星曜筆記「實戰小應用」裡的「命盤反推」那篇，正式版都不放（用 `AppInfo.isBeta` 擋）。星曜筆記本身（筆記頁、右側筆記卡、夾宮說明）2.2 起正式版也開放。
6. **不 force push、不改 release／macos13 的歷史。**

## 2. 專案結構

```
apps/apple/
  build.sh                 建置、安裝、出 DMG＋appcast（看檔頭說明）
  VERSION                  版本號；build 號＝git commit 數
  Sources/StillLink/
    Engine/                排盤引擎（iztro＋Swift：農曆、八字、真太陽時、飛化／自化分析）
    Views/                 SwiftUI 畫面
      ChartBoard.swift     十二宮盤面、中宮、層級開關
      ChartScreen.swift    命盤頁（盤面＋運限表＋底部工具列＋提示條錨點）
      PeriodTable.swift    運限表（PanRow：左右箭頭、拖曳、觸控板）
      Comments.swift       備註圖釘（像 Figma 留言）
      Annotations.swift    畫筆／螢光筆／箭頭／框線標註，各工具游標
      GroupDial.swift      刻度尺選擇器
      SettingsPage.swift   設定窗（浮窗＋搜尋；新設定用 row()／toggle() 加，才搜得到）
    Theme.swift            顏色 token（Color.z*、wm*、m*、f*）、字級（ZType、ChartType）
    Motion.swift           動畫 token、TopFade（漸進模糊）、Toast 提示條
    Settings.swift         ZSettings（新增欄位要給預設值，舊資料會自動補）
    Store.swift            資料、資料夾位置
    BugReport.swift        「回報問題…」
DESIGN.md                  設計規範
```

### iOS 版（`apps/ios`，分支 `ios`）

- 外框用系統元件（TabView 此刻／命盤／設定、List、Form、searchable、swipeActions），**盤面 `ChartBoard`、運限表 `PeriodTable`、引擎、`Store`、`Theme` 直接引用 `apps/apple` 同一份檔案**。共用清單在 `apps/ios/build.sh` 和 `project.yml`，兩邊要一起改。
- 共用檔案不能直接用 AppKit：Mac／iOS 不同的地方收在 `Platform.swift`，或用 `#if os(macOS)`。改完共用檔案，Mac（`./build.sh beta`）和 iOS（`apps/ios/build.sh check`）都要編過。
- `ZType` 在 iOS 用 Figma Typography 的 iOS 模式字級（粗＝Semibold）。
- 建置：`apps/ios/build.sh`（`check` 只型別檢查、`run` 裝進模擬器）。用 swiftc 直接編，不需要 Xcode 的 iOS 元件；要上實機才需要 `build.sh xcode`（要先在 Xcode 裝 iOS 平台元件、登入開發者帳號）。
- **裝新版一律用 `apps/ios/deploy.sh`**（預設裝 iPhone；`sim` 模擬器、`both` 兩個都裝），只印一行結果。小改動不用每次截圖驗證，Jean 會在手機上看。
- 裝到 Jean 的 iPhone：`cd apps/ios && xcodegen generate && xcodebuild -project StillLink.xcodeproj -scheme StillLink -destination 'id=00008150-001971140A80401C' -derivedDataPath build/dd -allowProvisioningUpdates build`，再 `xcrun devicectl device install app --device 00008150-001971140A80401C build/dd/Build/Products/Debug-iphoneos/StillLink.app`。Team 是 Jean 的 Personal Team（`project.yml` 的 `DEVELOPMENT_TEAM`），免費帳號 **7 天後失效要重裝**。Xcode 27 的模擬器 App 叫 DeviceHub（`Xcode.app/Contents/Applications/DeviceHub.app`）。
- 驗證：`SIMCTL_CHILD_ZIWEI_DATA_DIR=<暫存> xcrun simctl launch "iPhone 17 Pro" app.stilllink.ios.beta`，再 `xcrun simctl io … screenshot`。`ZIWEI_TAB=people|settings`、`ZIWEI_ROUTE=姓名`、`ZIWEI_NEW=1`、`ZIWEI_LEVEL` 可用。App 啟動約 5–10 秒（載入排盤引擎），截圖要等。

## 3. 分支與版本

| 分支 | 用途 |
|---|---|
| `beta` | 日常開發。所有修改先進這裡 |
| `release` | 正式版。發佈時把 `beta` 推過去（`git push origin beta:release`） |
| `macos13` | macOS 13 版。發佈時 merge `origin/release` 進來 |

**macOS 13 相容**（merge 進 `macos13` 時最常出錯的地方）：
- `onChange(of:) { _, new in }`（兩個參數）是 macOS 14 才有，`macos13` 要改成 `{ new in }`
- 其他 14+ API 參考 `macos13` 分支既有的 Compat 寫法
- merge 完一定要 `./build.sh beta` 編過再 commit

## 4. 開發流程

1. 在 `beta` 改。
2. 編譯：`cd apps/apple && ./build.sh beta`，有 `error:` 就修到乾淨。
3. **自己看畫面驗證**（見第 5 節），淺色和深色、寬和窄都要看。
4. 裝給 Jean 看：`./build.sh beta install`，會換掉 `/Applications/StillLink Beta.app`。
5. commit＋push 到 `beta`。訊息用繁中寫「改了什麼、為什麼」，結尾加 AI 協作者署名。
6. 回報 Jean：做了什麼、哪裡驗證過、哪裡沒驗證到（例如 hover、拖曳這種要真的滑鼠操作的）。

## 5. 驗證畫面（不打擾 Jean 正在用的 App）

複製一份改名的 App 來截圖，不要直接開 Jean 的 StillLink Beta。做法：
- 把 `build/StillLink Beta.app` 複製成另一個名字，用 `plutil` 改 `CFBundleName`／`CFBundleIdentifier`（例如 `com.jeanui.ziwei.verify`），再 `codesign --force --sign -`
- 用 `open -n --env ZIWEI_DATA_DIR=<暫存> --env ...` 開，等 6–9 秒
- 用 `CGWindowListCopyWindowInfo` 找視窗 ID，`screencapture -x -o -l <ID>` 截圖，`sips -Z 1500` 縮小再看
- 截完只關掉這份驗證 App（別用寬鬆的 `pkill -f`，會殺到別的程式）
- **不要移動 Jean 的滑鼠**做 hover 測試；做不到的互動就老實說「沒實測」

**驗證用環境變數**（App 啟動時讀，正式使用不會設）：

| 變數 | 作用 |
|---|---|
| `ZIWEI_DATA_DIR=路徑` | 用另一份資料夾（測試必設） |
| `ZIWEI_THEME=light/dark` | 強制淺色／深色 |
| `ZIWEI_LEVEL=0–5` | 開在本命／大限／流年／流月／流日／流時 |
| `ZIWEI_PICK=宮位編號`（＋`ZIWEI_PICK_DELAY=秒`） | 當成使用者點了那一宮（延後點：錄動畫時先開始錄） |
| `ZIWEI_PALACE_DUMP="年,月,日,時,分,f"`＋`ZIWEI_BENCH=檔案` | 列出每一宮所有星曜（主／輔／雜／長生），查「空宮是不是真的空」 |
| `ZIWEI_CLAMP_T=秒` | 夾宮框線樣式的能量流定格在第幾秒（截圖看動畫中間的樣子） |
| `ZIWEI_NEW=1`、`ZIWEI_EDIT` | 直接開新增／編輯命盤 |
| `ZIWEI_SETTINGS=區段` | 直接開到設定某一節 |
| `ZIWEI_SETTINGS_QUERY=文字` | 設定窗打開時直接搜尋 |
| `ZIWEI_TOAST=文字` | 3 秒後跳一個提示條 |
| `ZIWEI_OPEN_COMMENT=1`、`ZIWEI_DRAFT=文字` | 打開第一則備註／備註輸入框 |
| `ZIWEI_REPORT_SHEET=1` | 一開就打開回報問題彈窗 |
| `ZIWEI_CLAMP_TEST=1` 或 `"年,月,日,時,分,m"`＋`ZIWEI_BENCH=檔案` | 印出此刻盤（或指定生辰）12 宮各被什麼夾 |
| `ZIWEI_AUTO_UPDATE=check／download／install`＋`ZIWEI_UPDATE_LOG=檔案` | 自動檢查更新；download＝自動按更新、下載好照常跳「要不要重新開啟」彈窗；install＝全自動重開。測試時用改小版本號、改 bundle id 的副本 |
| `ZIWEI_BAZI_TEST="1984,10,3,13,30,f"`＋`ZIWEI_BENCH=檔案` | 印出節氣／非節氣四柱、起運、大運（對照文墨天機用；起運照文墨數時辰差） |
| `ZIWEI_PAN_HOVER=1` | 運限表左右箭頭不用 hover 也顯示 |
| `ZIWEI_REPORT=檔案路徑` | 把「回報問題」內容寫到檔案 |
| `ZIWEI_WHATSNEW=1` | 打開「新功能」視窗 |
| `ZIWEI_ACCOUNT_MENU=1` | 打開左下角帳號選單 |
| `ZIWEI_REVERSE=甲,巳,酉,未,寅,亥` | 打開命盤反推，自動填（年干,紅鸞,左輔,三台,紫微,命宮）並反推 |
| `ZIWEI_DOC_EDIT=段落編號` | 星曜筆記參考文件直接打開某一段的編輯 |
| `ZIWEI_CURSOR_DUMP=資料夾` | 把各工具游標存成 PNG |
| `ZIWEI_BENCH=檔案` ＋ `ZIWEI_REDRAW_BENCH=1` | 量整張盤重畫 10 次的時間寫到檔案（改盤面後確認沒變慢；目前約 80ms） |
| `ZIWEI_NOTES`、`ZIWEI_STAR_DETAIL` | 開星曜筆記頁 |
| `ZIWEI_SCROLL=1` | iOS：命盤頁、所有命盤一打開就捲到底（所有命盤會順便收起分類列），看捲動後頂端的樣子 |
| `ZIWEI_LEGAL=privacy／terms／delete／license` | iOS：「我的」頁打開時直接開那份條款 |
| `ZIWEI_PICK_BENCH=1` ＋ `ZIWEI_BENCH=檔案` | iOS：輪流點 12 宮 24 次，量每次選宮到排版完的時間（改盤面後確認點宮位沒變慢；2026-10 約 13ms，模擬器） |

要測新畫面就照這個模式自己加一個 `ZIWEI_*`，並補進這張表。

## 6. 設計規範（摘要，細節看 DESIGN.md）

- **Figma 是設計系統的來源。** 檔案「Stillink-MacOS Design System」（fileKey `dbUmstG3eIGY2ipJPFwLEY`；元件如輸入框 `Input` 也在這裡；元件以 App 程式碼為準，Figma 是紀錄）（Colors：Light／Dark 兩個 mode；Typography：iOS／macOS 兩個 mode）。改 token 時 Figma、`Theme.swift`、`DESIGN.md` 三處要一致。
- **不寫死數字和系統色。** 文字用 `.zText(.樣式)` 或 `Font.z*`；命盤文字用 `ChartType.*(fs)`（跟著盤面縮放）；顏色用 `Color.z*`／`wm*`／`m*`／`f*`。
- **淺色、深色都要做。** 浮在盤面上的卡片用 `zRaised`＋`zRaisedLine`＋`raisedShadow()`，深色模式才分得出層次。
- **RWD**：視窗從最小寬度到很寬都要能用；窄的時候側欄先自動收起。可點的東西至少 28pt 高，觸控情境 ≥ 44pt。
- **滑鼠和觸控板都要能操作。** 不是每個人都會左右滑：可以橫向捲動的東西，要同時支援點按鈕、按住拖、滑鼠滾輪／Shift＋滾輪（參考 `GroupDial`、`PanRow`）。
- **header／footer 淡出**＝同底色漸層（30% 實心＋70% 淡出）疊在漸進背景模糊上（`TopFade`）。SwiftUI 的 `.mask` 會讓模糊失效，要用 `CAGradientLayer` 當 mask。
- **動畫**用 `Motion.*` token，只動 offset／scale／opacity。
- **宮名用「交友宮」**（不用僕役）。

## 7. 寫程式的習慣

- 程式註解用繁中，寫「為什麼」而不是「做了什麼」。
- SwiftUI 的 `.position()` 會讓 view 撐滿父層：`onHover`、手勢、`contextMenu` 要掛在 `.position()` **前面**，不然會攔到整片範圍。
- 要攔滾動事件時用 `NSEvent.addLocalMonitorForEvents(.scrollWheel)`，比對視窗座標，`onDisappear` 記得移除。
- `ZSettings` 新增欄位：給預設值即可，`ZSettings.stored()` 會把舊資料疊在預設值上。
- 盤面每宮會重畫很多次：不要在每顆星上掛 `GeometryReader`，也不要用 `ViewThatFits` 試排多種版本（曾讓重畫慢到 230ms）；要量尺寸用 `TextMeasure` 算。
- 不要大改不相關的檔案；一次 commit 做一件事。

## 8. 發佈（只有 Jean 說要發才做）

**一行指令發版**（在 `apps/apple` 底下，要在 `beta` 分支、改動都 commit 了）：

1. 寫一份更新說明 `notes.md`（繁中，講使用者看得到的改變；只寫有的段落）：
   ```
   ## 新功能
   - …
   ## 改進
   - …
   ## 修正
   - …
   ```
2. `scripts/release.sh X.Y.Z notes.md`（重大更新加 `--major`，使用者右上角會出現「新功能」；加 `--check` 只印出會寫進 Changelog 的內容）

腳本會依序做完：Changelog＋`VERSION` → push `beta`、`beta:release` → 正式版 DMG → 合併 `macos13`（自動把 `onChange` 改單參數）→ macOS 13 版 DMG → `gh release create`（兩個 DMG＋`appcast.xml`＋`appcast-macOS13.xml`）→ `./build.sh release install` 換掉 Jean 的正式版 → curl 確認兩份 appcast 都是新版本。
過程只印每一步的結果，詳細輸出在 `build/release-X.Y.Z/*.log`；最後一行 `✓ 發佈完成` 才算成功。

**卡住時**：
- macos13 合併衝突，或出現 macOS 14 才有的 API（例如 `transaction(value:)`）→ 腳本會停在 `macos13` 並印出錯誤。修好、commit、push `macos13` 後，照腳本第 3 步之後的指令手動做完（`./build.sh release dmg` → `gh release create` → 回 `beta` → `./build.sh release install` → curl 確認）。
- 版本號：小修正加第三位（2.2.0 → 2.2.1），有新功能加第二位（2.2.x → 2.3.0）。

App 內更新（Sparkle）讀的是「最新 Release」裡的 `appcast.xml`／`appcast-macOS13.xml`，少附一個檔就會有一群人收不到更新。
