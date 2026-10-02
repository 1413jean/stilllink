# 設計系統

這是原生 SwiftUI app，沒有 WebView。所有顏色和字級都定義在 `apps/apple/Sources/StillLink/Theme.swift`。畫面上不直接寫數字或系統色，一律引用 token。

## 字型
- 全部用 SF Pro（`.system`），中文由系統自動用蘋方補字。不用宋體或其他字型。

### 介面字級（`Font.z*`）
| token | 大小／字重 | 用途 |
|---|---|---|
| `zDisplay` | 32 medium | 首頁大標 |
| `zTitle` | 20 semibold | 彈窗標題 |
| `zHeadline` | 14 medium | 卡片內的人名 |
| `zBody` / `zBodyStrong` | 13 | 內文、輸入框、側欄列表 |
| `zCallout` / `zCalloutStrong` | 12 | 次要內文、資料列；Strong 用在卡片標題、表頭 |
| `zCaption` / `zCaptionStrong` | 11 | 說明、標籤 |
| `zMicro` / `zMicroStrong` | 10 | 時間戳、方位、計數 |
| `zIcon`、`zIconBold`、`zIconLarge`、`zIconHero` | 12／12 bold／20 light／28 light | 圖示 |

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
- 星曜：主星和吉星用 `wmRed`，煞星用 `wmBlack`，雜曜用 `wmBlue`；博士用 `wmGreen`。
- 四化：祿 `mLu` 綠、權 `mQuan` 紫、科 `mKe` 藍、忌 `mJi` 紅。
  - 點選宮位時，那一宮宮干化出的四化會墊在被化到的星曜底色上。
  - 盤上不用框線。
- 生年四化是 `wmRed` 實心方塊；運限四化用 `scopeColors` 實心方塊：大限綠、流年藍、流月琥珀、流日洋紅、流時灰。
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
