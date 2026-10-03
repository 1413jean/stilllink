# StillLink 製作規範（給 AI 協作者：Codex、Claude 等）

StillLink 是原生 SwiftUI 的紫微斗數 Mac app（macOS 14+，另有 macOS 13 分支）。盤面照「文墨天機」，外框照 Claude／Codex 桌面版。
專案負責人是 Jean（UX/UI 設計師）。回覆和程式註解一律用**繁體中文**，講結果、別太長。

相關文件：
- `README.md`：功能、建置指令、分支對照
- `DESIGN.md`：設計系統（字級、顏色、命盤用色、控制項、動態、提示條）。**改 UI 前先讀**

---

## 1. 絕對不能做的事

1. **不碰正式資料。** 使用者資料在 `~/Library/Application Support/StillLink`（測試版是 `StillLink Beta`）。測試一律設 `ZIWEI_DATA_DIR=<暫存資料夾>`，把 `people.json` 複製過去再用。
2. **Sparkle 私鑰不進 repo。** 私鑰在鑰匙圈（account `stilllink`），`build.sh` 只放公鑰。
3. **不要自己發佈。** 只有 Jean 說「發佈／上版」才出正式版。平常改完只裝測試版給 Jean 看。
4. **不要用 WebView 做介面。** iztro 只在 JavaScriptCore 裡算資料，畫面全部是 SwiftUI。
5. **星曜筆記只開在測試版。** `StarNotes.enabled`（＝`AppInfo.isBeta`）擋住的功能，正式版要保持隱藏。這包含星曜 hover 卡。
6. **不 force push、不改 main/release 的歷史。**

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
      SettingsPage.swift   設定頁
    Theme.swift            顏色 token（Color.z*、wm*、m*、f*）、字級（ZType、ChartType）
    Motion.swift           動畫 token、TopFade（漸進模糊）、Toast 提示條
    Settings.swift         ZSettings（新增欄位要給預設值，舊資料會自動補）
    Store.swift            資料、資料夾位置
    BugReport.swift        「回報問題…」
DESIGN.md                  設計規範
```

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
| `ZIWEI_PICK=宮位編號` | 當成使用者點了那一宮 |
| `ZIWEI_NEW=1`、`ZIWEI_EDIT` | 直接開新增／編輯命盤 |
| `ZIWEI_SETTINGS=區段` | 直接開到設定某一節 |
| `ZIWEI_TOAST=文字` | 3 秒後跳一個提示條 |
| `ZIWEI_OPEN_COMMENT=1`、`ZIWEI_DRAFT=文字` | 打開第一則備註／備註輸入框 |
| `ZIWEI_PAN_HOVER=1` | 運限表左右箭頭不用 hover 也顯示 |
| `ZIWEI_REPORT=檔案路徑` | 把「回報問題」內容寫到檔案 |
| `ZIWEI_CURSOR_DUMP=資料夾` | 把各工具游標存成 PNG |
| `ZIWEI_NOTES`、`ZIWEI_STAR_DETAIL` | 開星曜筆記頁 |

要測新畫面就照這個模式自己加一個 `ZIWEI_*`，並補進這張表。

## 6. 設計規範（摘要，細節看 DESIGN.md）

- **Figma 是設計系統的來源。** 檔案「Stillink Design System」（Colors：Light／Dark 兩個 mode；Typography：iOS／macOS 兩個 mode）。改 token 時 Figma、`Theme.swift`、`DESIGN.md` 三處要一致。
- **不寫死數字和系統色。** 文字用 `.zText(.樣式)` 或 `Font.z*`；命盤文字用 `ChartType.*(fs)`（跟著盤面縮放）；顏色用 `Color.z*`／`wm*`／`m*`／`f*`。
- **淺色、深色都要做。** 浮在盤面上的卡片用 `zRaised`＋`zRaisedLine`＋`raisedShadow()`，深色模式才分得出層次。
- **RWD**：視窗從最小寬度到很寬都要能用；窄的時候側欄先自動收起。可點的東西至少 28pt 高，觸控情境 ≥ 44pt。
- **滑鼠和觸控板都要能操作。** 不是每個人都會左右滑：可以橫向捲動的東西，要同時支援點按鈕、按住拖、滑鼠滾輪／Shift＋滾輪（參考 `GroupDial`、`PanRow`）。
- **header／footer 淡出**＝同底色漸層（30% 實心＋70% 淡出）疊在漸進背景模糊上（`TopFade`）。SwiftUI 的 `.mask` 會讓模糊失效，要用 `CAGradientLayer` 當 mask。
- **動畫**用 `Motion.*` token，只動 offset／scale／opacity。
- **宮名用「交友宮」**（不用僕役）。

## 7. 寫程式的習慣

- 照周圍程式碼的風格寫：註解密度、命名、繁中註解寫「為什麼」。
- SwiftUI 的 `.position()` 會讓 view 撐滿父層：`onHover`、手勢、`contextMenu` 要掛在 `.position()` **前面**，不然會攔到整片範圍。
- 要攔滾動事件時用 `NSEvent.addLocalMonitorForEvents(.scrollWheel)`，比對視窗座標，`onDisappear` 記得移除。
- `ZSettings` 新增欄位：給預設值即可，`ZSettings.stored()` 會把舊資料疊在預設值上。
- 不要大改不相關的檔案；一次 commit 做一件事。

## 8. 發佈（只有 Jean 說要發才做）

以下以 `X.Y.Z` 代表新版本號，在 `apps/apple` 底下執行：

1. `echo X.Y.Z > VERSION`，commit「版本 X.Y.Z」，push `beta`，再 `git push origin beta:release`
2. `./build.sh release dmg` → 產出 `build/StillLink-X.Y.Z.dmg` 和 `build/appcast.xml`（用鑰匙圈私鑰簽）。把這兩個檔**另外存一份**（下一步會被覆蓋）
3. `git checkout macos13 && git merge --no-edit origin/release`，修相容問題（第 3 節），`./build.sh beta` 編過，commit＋push `macos13`
4. 在 `macos13` 上 `./build.sh release dmg` → `build/StillLink-X.Y.Z-macOS13.dmg`、`build/appcast-macOS13.xml`
5. 寫更新說明（繁中，分「盤面／工具／介面」這類小標，講使用者看得到的改變）
6. `gh release create vX.Y.Z --repo 1413jean/stilllink --target release --title "StillLink X.Y.Z" --notes-file notes.md` 附上四個檔：兩個 DMG、`appcast.xml`、`appcast-macOS13.xml`
7. `git checkout beta`，`./build.sh release install` 換掉 Jean 的正式版
8. 確認 App 內更新抓得到：
   `curl -sL https://github.com/1413jean/stilllink/releases/latest/download/appcast.xml | grep shortVersionString`（macOS 13 那份同理），兩份都要是新版本

App 內更新（Sparkle）讀的是「最新 Release」裡的 `appcast.xml`／`appcast-macOS13.xml`，少附一個檔就會有一群人收不到更新。
