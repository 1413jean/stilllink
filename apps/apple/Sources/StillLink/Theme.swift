import SwiftUI

/// 設計 token：Claude／Codex 式的暖白與暖黑，亮暗各一組
extension Color {
    static func dynamic(_ light: UInt32, _ dark: UInt32) -> Color {
        #if os(macOS)
        Color(nsColor: NSColor(name: nil) { ap in
            let hex = ap.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua ? dark : light
            return NSColor(srgbRed: CGFloat((hex >> 16) & 0xff) / 255, green: CGFloat((hex >> 8) & 0xff) / 255,
                           blue: CGFloat(hex & 0xff) / 255, alpha: 1)
        })
        #else
        Color(uiColor: UIColor { t in
            let hex = t.userInterfaceStyle == .dark ? dark : light
            return UIColor(red: CGFloat((hex >> 16) & 0xff) / 255, green: CGFloat((hex >> 8) & 0xff) / 255,
                           blue: CGFloat(hex & 0xff) / 255, alpha: 1)
        })
        #endif
    }

    // 外框色：從 App 圖示延伸（夜空深藍 night ＋ 四角星橘 star），對應 Figma Stillink DS 的 🎨/night、🎨/star
    static let zBg = dynamic(0xF7F9FC, 0x0B1220)        // night/100；深色是圖示的夜空底
    static let zCard = dynamic(0xFFFFFF, 0x152036)
    static let zSide = dynamic(0xF2F5FA, 0x080E1A)      // 側欄：比主區再淺／深一階
    static let zLine = dynamic(0xE2E7EF, 0x26324A)
    static let zRaised = dynamic(0xFFFFFF, 0x1F2B44)    // 浮在盤面上的卡片（備註）：深色模式比 zCard 亮一階才分得出來
    static let zRaisedLine = dynamic(0xDCE2EC, 0x34415C) // 浮起卡片的細框
    static let zGrid = dynamic(0xC9D1DE, 0x3A4762)
    static let zText = dynamic(0x1A2944, 0xE9EEF6)      // 主文字：night/900（圖示的深藍）
    static let zText2 = dynamic(0x4E5A72, 0xA2AEC3)     // night/700／500
    static let zText3 = dynamic(0x8B96AB, 0x6F7C95)
    static let zHover = dynamic(0xEEF2F8, 0x1C2740)
    static let zSel = dynamic(0xE8EDF5, 0x243049)       // 選取列：淺藍灰
    static let zAccent = dynamic(0xC95A2A, 0xF59457)   // 星橘：淺色用 star/600（淺底上 star/500 太亮看不清楚），深色用圖示的星色 star/400
    static let zToastAction = dynamic(0xFBBF97, 0xC95A2A)   // 提示條上的按鈕：提示條是反色（淺色模式深底、深色模式淺底），橘色要跟著反過來挑才看得清楚

    // 命盤（照文墨天機）
    static let wmRed = dynamic(0xD0102A, 0xFF6B76)
    static let wmBlue = dynamic(0x1F5FBF, 0x7AABF5)
    static let wmIron = dynamic(0x666666, 0x9E9E9E)   // 鐵灰（約 K60）：雜曜，跟藍綠色的流曜分開；深色模式提亮一點
    static let wmGreen = dynamic(0x1F8A3A, 0x5BCB8A)
    static let wmBlack = dynamic(0x1C1B19, 0xECEAE4)
    static let wmEarth = dynamic(0xB5701A, 0xE0A84A)
    static let wmSF = dynamic(0xEEF2F8, 0x222E47)       // 三方四正：淺藍灰（跟側欄同一家）
    static let wmSel = dynamic(0xFCEFE7, 0x2A2530)      // 選取宮：主色 10% 淡底

    static let mLu = dynamic(0x1F8A3A, 0x4FBF7E)
    static let mQuan = dynamic(0x7B48C8, 0xA987EC)
    static let mKe = dynamic(0x1F5FBF, 0x6AA2F5)
    static let mJi = dynamic(0xD0102A, 0xF06A6A)

    /// 小限：青綠
    static let minorColor = dynamic(0x0098B5, 0x2EC4DE)   // 小限：青色（深淺色都用青），跟大限的綠分開

    /// 運限四化色：大限綠、流年藍、流月琥珀、流日洋紅、流時灰
    static let scopeColors: [Color] = [
        dynamic(0x1F8A3A, 0x4FBF7E), dynamic(0x1F5FBF, 0x6AA2F5), dynamic(0xC27A12, 0xE8A84A),
        dynamic(0xB8357A, 0xE877B4), dynamic(0x5E6A82, 0xA2AEC3),
    ]
}

extension Mutagen {
    /// 文字、箭頭用（深色模式較亮）
    var color: Color { [.mLu, .mQuan, .mKe, .mJi][Mutagen.allCases.firstIndex(of: self)!] }
    /// 色塊底色用（上面放白字）：深色模式改用較沉、飽和度較低的色，白字才讀得清楚
    var fill: Color { [.fLu, .fQuan, .fKe, .fJi][Mutagen.allCases.firstIndex(of: self)!] }
}

extension Color {
    static let fLu = dynamic(0x1F8A3A, 0x2F6B45)
    static let fQuan = dynamic(0x7B48C8, 0x5F4796)
    static let fKe = dynamic(0x1F5FBF, 0x335B99)
    static let fJi = dynamic(0xD0102A, 0x9C3239)
    static let fBirth = dynamic(0xD0102A, 0x9C3239)       // 生年四化方塊
    static let fMinor = dynamic(0x0098B5, 0x0098B5)       // 小限四化方塊：深淺色都用同一個青色
    static let fHepan = dynamic(0xA0651E, 0x7A5A34)       // 合盤四化方塊：土色，深色模式偏棕調沉（白字才看得清，也跟流月的琥珀分開）
    /// 運限四化方塊底色：大限、流年、流月、流日、流時
    static let fScopes: [Color] = [
        dynamic(0x1F8A3A, 0x2F6B45), dynamic(0x1F5FBF, 0x335B99), dynamic(0xC27A12, 0x8E6224),
        dynamic(0xB8357A, 0x8A3C66), dynamic(0x5E6A82, 0x4E5A72),
    ]
}

extension ZW.Tone {
    var color: Color {
        switch self { case .red: .wmRed; case .blue: .wmBlue; case .black: .wmBlack; case .green: .wmGreen; case .earth: .wmEarth; case .purple: .mQuan; case .gray: .wmIron }
    }
}

extension ZW.Wuxing {
    var color: Color {
        switch self { case .wood: .wmGreen; case .fire: .wmRed; case .earth: .wmEarth; case .metal: .wmBlue; case .water: .wmBlack }
    }
}

extension Color {
    /// 色塊上的文字（四化方塊、強調色按鈕）
    static let zOnColor = Color.white
    /// 彈窗背景模糊上的暗化
    static let zScrim = Color.black.opacity(0.12)
    /// 浮層陰影
    static let zShadow = Color.black.opacity(0.12)
}

// MARK: - 字級（全部 SF Pro；中文由系統自動以蘋方補字）
// 設計系統：跟 Figma「Stillink Design System」的文字樣式同名（Typography 變數集合的 macOS 模式就是這裡的數值）。
// 改字級請先改 Figma，再同步這張表；畫面上一律用這些樣式，不要直接寫 .system(size:)。

/// 文字樣式：大小／行高／粗細／字距
enum ZType: String, CaseIterable {
    case titleLarge = "title/title.large", title1 = "title/title.1", title2 = "title/title.2", title3 = "title/title.3"
    case headline = "body/body.headline"
    case body = "body/body.large", bodyStrong = "body/body.large.strong"
    case callout = "body/body.callout", calloutStrong = "body/body.callout.strong"
    case subheadline = "body/body.subheadline", subheadlineStrong = "body/body.subheadline.strong"
    case footnote = "body/body.footnote", footnoteStrong = "body/body.footnote.strong"
    case caption1 = "body/body.caption.1", caption1Strong = "body/body.caption.1.strong"
    case caption2 = "body/body.caption.2"
    case eyebrow = "label/label.eyebrow"

    /// （字級, 行高, 粗體, 字距）— Mac 用 macOS 模式、iPhone／iPad 用 iOS 模式（Figma Typography 兩個 mode）
    var spec: (size: CGFloat, lineHeight: CGFloat, strong: Bool, tracking: CGFloat) {
        #if os(iOS)
        switch self {
        case .titleLarge: (34, 41, true, 0)
        case .title1: (28, 34, true, 0)
        case .title2: (22, 28, true, 0)
        case .title3: (20, 25, true, 0)
        case .headline: (17, 22, true, 0)
        case .body: (17, 22, false, 0)
        case .bodyStrong: (17, 22, true, 0)
        case .callout: (16, 21, false, 0)
        case .calloutStrong: (16, 21, true, 0)
        case .subheadline: (15, 20, false, 0)
        case .subheadlineStrong: (15, 20, true, 0)
        case .footnote: (13, 18, false, 0)
        case .footnoteStrong: (13, 18, true, 0)
        case .caption1: (12, 16, false, 0)
        case .caption1Strong: (12, 16, true, 0)
        case .caption2: (11, 13, false, 0)
        case .eyebrow: (11, 13, true, 1.4)
        }
        #else
        switch self {
        case .titleLarge: (32, 38, true, 0)
        case .title1: (22, 28, true, 0)
        case .title2: (20, 26, true, 0)
        case .title3: (16, 22, true, 0)
        case .headline: (14, 20, true, 0)
        case .body: (15, 24, false, 0)
        case .bodyStrong: (15, 24, true, 0)
        case .callout: (13, 20, false, 0)
        case .calloutStrong: (13, 20, true, 0)
        case .subheadline: (12, 18, false, 0)
        case .subheadlineStrong: (12, 18, true, 0)
        case .footnote: (11, 16, false, 0)
        case .footnoteStrong: (11, 16, true, 0)
        case .caption1: (10, 14, false, 0)
        case .caption1Strong: (10, 14, true, 0)
        case .caption2: (9, 12, false, 0)
        case .eyebrow: (10, 12, true, 1.4)
        }
        #endif
    }
    /// 「粗」在 macOS 是 Medium、iOS 是 Semibold（Figma 變數 font/weight/strong 依模式不同）
    #if os(iOS)
    var font: Font { Font.system(textStyle, weight: spec.strong ? .semibold : .regular) }
    /// 對應的 Dynamic Type 文字樣式（預設大小跟上面的 iOS 字級一樣）
    var textStyle: Font.TextStyle {
        switch self {
        case .titleLarge: .largeTitle
        case .title1: .title
        case .title2: .title2
        case .title3: .title3
        case .headline, .body, .bodyStrong: .body
        case .callout, .calloutStrong: .callout
        case .subheadline, .subheadlineStrong: .subheadline
        case .footnote, .footnoteStrong: .footnote
        case .caption1, .caption1Strong: .caption
        case .caption2, .eyebrow: .caption2
        }
    }
    #else
    var font: Font { .system(size: spec.size, weight: spec.strong ? .medium : .regular) }
    #endif
}

extension View {
    /// 套用文字樣式（字體＋行高＋字距）：多行文字一律用這個，行高才會照設計系統
    func zText(_ t: ZType) -> some View {
        font(t.font)
            .lineSpacing(max(0, t.spec.lineHeight - t.spec.size * 1.2))
            .tracking(t.spec.tracking)
    }
}

/// 舊名稱 → 設計系統樣式（之後新程式直接用 ZType）
extension Font {
    static let zDisplay = ZType.titleLarge.font          // 首頁大標
    static let zTitle = ZType.title2.font                // 頁面、彈窗標題
    static let zReadTitle = ZType.title3.font            // 閱讀內容的小標題（星曜筆記、參考文件）
    static let zHeadline = ZType.headline.font           // 卡片內人名
    static let zBrand = ZType.headline.font              // 側欄頂端產品名
    static let zRead = ZType.body.font                   // 閱讀內容（星曜筆記、參考文件）
    static let zReadStrong = ZType.bodyStrong.font
    static let zInput = ZType.body.font                  // 表單輸入框
    static let zBody = ZType.callout.font                // 介面內文、側欄列
    static let zBodyStrong = ZType.calloutStrong.font
    static let zCallout = ZType.subheadline.font         // 次要內文、資料列
    static let zCalloutStrong = ZType.subheadlineStrong.font   // 卡片標題、表頭
    static let zCaption = ZType.footnote.font            // 說明、標籤
    static let zCaptionStrong = ZType.footnoteStrong.font
    static let zMicro = ZType.caption1.font              // 時間戳、方位、計數
    static let zMicroStrong = ZType.caption1Strong.font
    static let zTiny = ZType.caption2.font               // 最小字

    static let zIcon = Font.system(size: 12)                            // 列表圖示
    static let zIconBold = Font.system(size: 12, weight: .bold)         // 送出箭頭
    static let zIconLarge = Font.system(size: 20, weight: .light)       // 空狀態圖示
    static let zIconHero = Font.system(size: 28, weight: .light)        // 首頁星形
}

/// 命盤字級：跟著盤面大小縮放，fs 是宮位基準字級（主星大小）
enum ChartType {
    #if os(iOS)
    /// iPhone 宮格窄（約 98pt），用寬度算會落到最小值；照文墨天機手機版約 11pt
    static func base(cellWidth cw: CGFloat) -> CGFloat { max(11, min(15.5, cw / 11.5)) }
    #else
    static func base(cellWidth cw: CGFloat) -> CGFloat { max(11, min(15.5, cw / 11.5)) }
    #endif

    static func star(_ fs: CGFloat) -> CGFloat { fs }                       // 主星、輔星
    static func adj(_ fs: CGFloat) -> CGFloat { max(10.5, fs * 0.94) }      // 雜曜：跟主星差一點點就好
    static func meta(_ fs: CGFloat) -> CGFloat { max(8, fs * 0.68) }        // 亮度、長生
    static func tag(_ fs: CGFloat) -> CGFloat { max(9, fs * 0.8) }         // 四化方塊、運限宮名、自化
    static func gods(_ fs: CGFloat) -> CGFloat { fs * 0.74 }                // 博士／將前／歲前
    static func ages(_ fs: CGFloat) -> CGFloat { max(8, fs * 0.58) }        // 流年／小限歲數
    static func range(_ fs: CGFloat) -> CGFloat { fs * 0.88 }               // 大限歲數
    static func palace(_ fs: CGFloat) -> CGFloat { fs }                     // 宮名
    #if os(iOS)
    static func ganzhi(_ fs: CGFloat) -> CGFloat { fs * 1.12 }              // 宮干支（iPhone 宮格窄，小一階才放得下身宮章）
    #else
    static func ganzhi(_ fs: CGFloat) -> CGFloat { fs * 1.3 }               // 宮干支
    #endif
    static func centerTitle(_ fs: CGFloat) -> CGFloat { fs * 1.15 }
    static func centerBody(_ fs: CGFloat) -> CGFloat { fs * 0.9 }
    static func centerSmall(_ fs: CGFloat) -> CGFloat { fs * 0.75 }
    static func pillar(_ fs: CGFloat) -> CGFloat { fs * 1.35 }
    static func pillarSmall(_ fs: CGFloat) -> CGFloat { fs * 1.1 }          // 中宮兩組四柱
    static func dayun(_ fs: CGFloat) -> CGFloat { fs * 0.95 }               // 大運干支
    static func godLabel(_ fs: CGFloat) -> CGFloat { max(7.5, fs * 0.55) }  // 十神小字、大運歲數

    /// 命盤字體一律比介面細一階（Jean：盤面字要細一點）：semibold→medium、medium→regular、regular→light
    static func font(_ size: CGFloat, _ weight: Font.Weight = .regular) -> Font { .system(size: size, weight: lighter(weight)) }

    static func lighter(_ w: Font.Weight) -> Font.Weight {
        switch w {
        case .heavy, .black: .bold
        case .bold: .semibold
        case .semibold: .medium
        case .medium: .regular
        case .regular: .light
        default: .light
        }
    }
}
