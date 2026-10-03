# 設計系統

這是原生 SwiftUI app，沒有 WebView。所有顏色和字級都定義在 `apps/apple/Sources/StillLink/Theme.swift`。畫面上不直接寫數字或系統色，一律引用 token。

## 字型
- 全部用 SF Pro（`.system`），中文由系統自動用蘋方補字。不用宋體或其他字型。

### 介面字級（設計系統 `ZType`）
跟 Figma「Stillink Design System」的文字樣式同名：Typography 變數集合有 **iOS** 和 **macOS** 兩個模式，Mac app 用 macOS 模式的數值。改字級先改 Figma，再同步 `Theme.swift` 的 `ZType`。
多行文字用 `.zText(.樣式)`（字體＋行高＋字距一起套）；單行可用 `Font.z*` 舊名稱（都對應到下表）。

| Figma 樣式 | `ZType` | macOS 字級／行高 | iOS 字級／行高 | 舊名稱 | 用途 |
|---|---|---|---|---|---|
| title/title.large | `.titleLarge` | 32 / 38 粗 | 34 / 41 | `zDisplay` | 首頁大標 |
| title/title.1 | `.title1` | 22 / 28 粗 | 28 / 34 | — | 大標 |
| title/title.2 | `.title2` | 20 / 26 粗 | 22 / 28 | `zTitle` | 頁面、彈窗標題 |
| title/title.3 | `.title3` | 16 / 22 粗 | 20 / 25 | `zReadTitle` | 閱讀內容的小標題 |
| body/body.headline | `.headline` | 14 / 20 粗 | 17 / 22 | `zHeadline`、`zBrand` | 卡片內人名、產品名 |
| body/body.large | `.body` | 15 / 24 | 17 / 22 | `zRead`、`zInput` | 閱讀內容（星曜筆記、參考文件）、輸入框 |
| body/body.large.strong | `.bodyStrong` | 15 / 24 粗 | 17 / 22 | `zReadStrong` | 閱讀內容強調 |
| body/body.callout | `.callout` | 13 / 20 | 16 / 21 | `zBody` | 介面內文、側欄列 |
| body/body.callout.strong | `.calloutStrong` | 13 / 20 粗 | 16 / 21 | `zBodyStrong` | 按鈕、列表標題 |
| body/body.subheadline | `.subheadline` | 12 / 18 | 15 / 20 | `zCallout` | 次要內文、資料列 |
| body/body.subheadline.strong | `.subheadlineStrong` | 12 / 18 粗 | 15 / 20 | `zCalloutStrong` | 卡片標題、表頭 |
| body/body.footnote | `.footnote` | 11 / 16 | 13 / 18 | `zCaption` | 說明、標籤 |
| body/body.footnote.strong | `.footnoteStrong` | 11 / 16 粗 | 13 / 18 | `zCaptionStrong` | 小標籤 |
| body/body.caption.1 | `.caption1` | 10 / 14 | 12 / 16 | `zMicro` | 時間戳、方位、計數 |
| body/body.caption.1.strong | `.caption1Strong` | 10 / 14 粗 | 12 / 16 | `zMicroStrong` | 小徽章 |
| body/body.caption.2 | `.caption2` | 9 / 12 | 11 / 13 | `zTiny` | 最小字 |
| label/label.eyebrow | `.eyebrow` | 10 / 12 粗、字距 +1.4 | 11 / 13 | — | 品牌小標 |

「粗」在 macOS 是 Medium、iOS 是 Semibold（Figma 變數 `font/weight/strong` 依模式不同）。圖示大小（`zIcon*`）不在文字系統內。

### 命盤字級（`ChartType`）
命盤字級會跟著盤面大小縮放。基準字級 `fs` 由宮位寬度算出（`ChartType.base`，介於 10 到 14），其他字級都是 `fs` 的比例：
- 主星、宮名：`star`／`palace`
- 雜曜：`adj`
- 亮度、長生：`meta`
- 四化方塊、運限宮名：`tag`
- 博士、將前、歲前：`gods`
- 流年、小限：`ages`
- 大限歲數：`range`
- 宮干支：`ganzhi`
- 中宮：`centerTitle`、`centerBody`、`centerSmall`、`pillar`

## 顏色（`Color.z*`，每個都有淺色和深色兩組值）
- 底色：`zBg` 主區、`zSide` 側欄、`zCard` 卡片。
- 線條：`zLine` 一般邊線、`zGrid` 盤面格線。
- 文字：`zText` 主要、`zText2` 次要、`zText3` 輔助。
- 狀態：`zHover` 滑過、`zSel` 選取。
- 強調：`zAccent`，赭紅色。整個 app 的 tint 也是它，送出鈕和星形圖示都用它。
- `zOnColor` 是色塊上的文字顏色，`zShadow` 是浮層陰影。

### 命盤用色
- 星曜（設定裡可以改，下面是預設）：
  | 類別 | 色票 | 淺色／深色 |
  |---|---|---|
  | 主星（十四主星） | `wmRed` | 朱紅 |
  | 輔星（含祿存、天馬） | `wmGreen` | 綠 |
  | 凶星（擎羊陀羅火鈴空劫） | `wmBlack` | 墨黑 |
  | 雜曜 | `wmIron` 鐵灰 | `#666666`／`#9E9E9E` |
- 字級：主星和重要雜曜（紅鸞、天喜、咸池、天姚、天刑，`ZW.keyAdjective`）都用 `ChartType.star`，排在雜曜最前面；一般雜曜用 `ChartType.adj`；流曜再小一階。
- 主星和雜曜優先排同一排，放不下先縮雜曜、再一起縮，縮到底才換第二排。
- 四化：祿 `mLu` 綠、權 `mQuan` 紫、科 `mKe` 藍、忌 `mJi` 紅。
  - 點選宮位時，那一宮宮干化出的四化會墊在被化到的星曜底色上。
  - 盤上不用框線。
- 生年四化是 `wmRed` 實心方塊；運限四化用 `scopeColors` 實心方塊：大限綠、流年藍、流月琥珀、流日洋紅、流時灰。
- 中宮的層級開關「本・限・年・月・日・時」（最多同時三層）＋「小限」：每一層在星曜下方有固定位置，沒有四化的層留空白；方塊 3 個以內是 1.22 倍字級，超過 3 個縮成 1.06 倍。
- 宮名用「交友宮」（不用僕役），在 `bridge.js` 統一轉換。
- 四柱依五行上色（`ZW.Wuxing.color`）。

## 控制項（`Controls.swift`）
- 輸入框 `inputBox()`、分段 `ZSegmented`、選單 `ZMenuField` 的高度一律 38。
- 按鈕有兩種，都是 40 高、圓角 10、字級 `zBodyStrong`：
  - `ZPrimaryButton`：強調色實心，用在主要動作。
  - `ZSecondaryButton`：卡片底色加細框，用在取消、完成這類次要動作。
  - 兩種都有 `small: true` 版本，32 高，放在卡片裡用。
- 不使用系統的 `.borderedProminent`。

## 版面（照 Claude／Codex）
- 左邊是自訂側欄，依序是新增命盤、搜尋、釘選，下面的分組做成可收合的資料夾；左下角是帳號列。
- 中間是命盤，大小接近文墨天機的比例，上限 700，下面接運限表。捲動區佔滿整個寬度，捲軸貼在視窗最右邊。
- 底部浮著 AI 解盤輸入框，目前停用。
- 右上角固定浮著資訊卡：命主資料、備註、照片附件。

## 提示條（Snackbar，`ToastHost`）
- 用 `Toast.show("…")` 跳出，2 秒後自動消失。
- 位置：在命盤頁對齊底部工具列的中心（`ToastAnchor`），浮在工具列上方；其他頁置中。
- 外觀：膠囊形，背景模糊（`.hudWindow`）疊 64% 的 `zText`，0.5pt 白色細邊，兩層陰影；寬度跟著文字走，不固定。
- 內距：左 18、右 22、上下 12；icon 和文字間距 10；文字 `zCalloutStrong`、`zBg` 色，最多兩行。
- Icon 依訊息自動判斷：成功（「已…」）`checkmark.circle.fill`、提示說明 `info.circle.fill`、失敗／錯誤 `exclamationmark.triangle.fill`；顏色一律灰白（`zBg` 75%），不用彩色。

## 動態（`Motion.swift`，參考 GSAP 的原則）
- **Easing**：一律用 out 系曲線，開頭快、收尾慢。只動 offset、scale、opacity，不去動版面尺寸。
- **Token**：
  - `fast` 0.15s：hover、按壓
  - `base` 0.25s：選取、展開、資料更新
  - `enter` 0.4s：進場
  - `exit` 0.18s：退場，比進場快
  - `snap`：跟手的彈簧，用在滑動的選取底色和膠囊
- **錯開（stagger）**：`enterFromBelow(_, index:)` 讓元件往上 8pt 並淡入，每一項延遲 0.025s，等同 GSAP 的 `from({ y: 8, autoAlpha: 0, stagger })`。
- **用在哪裡**：
  - 命盤十二宮依序進場。
  - 點宮位時，三方四正的連線會滑到新的位置。
  - 運限表、側欄、分段控制的選取底色會滑過去（matchedGeometryEffect，類似 GSAP Flip）。
  - 彈窗進場是縮放加位移加淡入，退場較快。
  - 備註新增和刪除有過場動畫。
  - 按鈕按下會縮到 0.97。
- 系統開啟「減少動態效果」時，所有動畫改成瞬間切換。
