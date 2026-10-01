import SwiftUI
import AppKit

/// 設計 token：Claude／Codex 式的暖白與暖黑，亮暗各一組
extension Color {
    static func dynamic(_ light: UInt32, _ dark: UInt32) -> Color {
        Color(nsColor: NSColor(name: nil) { ap in
            let hex = ap.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua ? dark : light
            return NSColor(srgbRed: CGFloat((hex >> 16) & 0xff) / 255, green: CGFloat((hex >> 8) & 0xff) / 255,
                           blue: CGFloat(hex & 0xff) / 255, alpha: 1)
        })
    }

    static let zBg = dynamic(0xFAF9F6, 0x262624)
    static let zCard = dynamic(0xFFFFFF, 0x30302E)
    static let zSide = dynamic(0xF3F2EE, 0x1F1F1D)
    static let zLine = dynamic(0xE7E5DF, 0x3D3C39)
    static let zGrid = dynamic(0xCFCCC4, 0x4A4946)
    static let zText = dynamic(0x1F1E1C, 0xECEAE4)
    static let zText2 = dynamic(0x6B6963, 0xA6A39C)
    static let zText3 = dynamic(0x9C9A93, 0x7A7872)
    static let zHover = dynamic(0xF0EEE8, 0x34332F)
    static let zSel = dynamic(0xEDEAE2, 0x3A3935)
    static let zAccent = dynamic(0xC2603F, 0xE08A68)

    // 命盤（照文墨天機）
    static let wmRed = dynamic(0xD0102A, 0xFF6B76)
    static let wmBlue = dynamic(0x1F5FBF, 0x7AABF5)
    static let wmGreen = dynamic(0x1F8A3A, 0x5BCB8A)
    static let wmBlack = dynamic(0x1F1E1C, 0xECEAE4)
    static let wmEarth = dynamic(0xB5701A, 0xE0A84A)
    static let wmSF = dynamic(0xF4F0E6, 0x3E3C37)
    static let wmSel = dynamic(0xFBEDEA, 0x3A2E2C)

    static let mLu = dynamic(0x1F8A3A, 0x4FBF7E)
    static let mQuan = dynamic(0x7B48C8, 0xA987EC)
    static let mKe = dynamic(0x1F5FBF, 0x6AA2F5)
    static let mJi = dynamic(0xD0102A, 0xF06A6A)

    /// 小限：青綠
    static let minorColor = dynamic(0x1F8A8A, 0x4FC9C9)

    /// 運限四化色：大限綠、流年藍、流月琥珀、流日洋紅、流時灰
    static let scopeColors: [Color] = [
        dynamic(0x1F8A3A, 0x4FBF7E), dynamic(0x1F5FBF, 0x6AA2F5), dynamic(0xC27A12, 0xE8A84A),
        dynamic(0xB8357A, 0xE877B4), dynamic(0x6B6963, 0xA6A39C),
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
    static let fMinor = dynamic(0x1F8A8A, 0x2C6E6E)       // 小限四化方塊
    /// 運限四化方塊底色：大限、流年、流月、流日、流時
    static let fScopes: [Color] = [
        dynamic(0x1F8A3A, 0x2F6B45), dynamic(0x1F5FBF, 0x335B99), dynamic(0xC27A12, 0x8E6224),
        dynamic(0xB8357A, 0x8A3C66), dynamic(0x6B6963, 0x5A5955),
    ]
}

extension ZW.Tone {
    var color: Color { self == .red ? .wmRed : self == .blue ? .wmBlue : .wmBlack }
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

extension Font {
    static let zDisplay = Font.system(size: 32, weight: .medium)        // 首頁大標
    static let zTitle = Font.system(size: 20, weight: .semibold)        // 彈窗標題
    static let zHeadline = Font.system(size: 14, weight: .medium)       // 卡片內人名
    static let zInput = Font.system(size: 14)                           // 表單輸入框
    static let zBody = Font.system(size: 13)                            // 內文、側欄列
    static let zBodyStrong = Font.system(size: 13, weight: .medium)
    static let zCallout = Font.system(size: 12)                         // 次要內文、資料列
    static let zCalloutStrong = Font.system(size: 12, weight: .medium)  // 卡片標題、表頭
    static let zCaption = Font.system(size: 11)                         // 說明、標籤
    static let zCaptionStrong = Font.system(size: 11, weight: .medium)
    static let zMicro = Font.system(size: 10)                           // 時間戳、方位、計數
    static let zMicroStrong = Font.system(size: 10, weight: .semibold)

    static let zIcon = Font.system(size: 12)                            // 列表圖示
    static let zIconBold = Font.system(size: 12, weight: .bold)         // 送出箭頭
    static let zIconLarge = Font.system(size: 20, weight: .light)       // 空狀態圖示
    static let zIconHero = Font.system(size: 28, weight: .light)        // 首頁星形
}

/// 命盤字級：跟著盤面大小縮放，fs 是宮位基準字級（主星大小）
enum ChartType {
    static func base(cellWidth cw: CGFloat) -> CGFloat { max(11, min(15.5, cw / 11.5)) }

    static func star(_ fs: CGFloat) -> CGFloat { fs }                       // 主星、輔星
    static func adj(_ fs: CGFloat) -> CGFloat { max(9, fs - 2) }            // 雜曜
    static func meta(_ fs: CGFloat) -> CGFloat { max(8, fs * 0.68) }        // 亮度、長生
    static func tag(_ fs: CGFloat) -> CGFloat { max(9, fs * 0.8) }         // 四化方塊、運限宮名、自化
    static func gods(_ fs: CGFloat) -> CGFloat { fs * 0.74 }                // 博士／將前／歲前
    static func ages(_ fs: CGFloat) -> CGFloat { max(8, fs * 0.58) }        // 流年／小限歲數
    static func range(_ fs: CGFloat) -> CGFloat { fs * 0.88 }               // 大限歲數
    static func palace(_ fs: CGFloat) -> CGFloat { fs }                     // 宮名
    static func ganzhi(_ fs: CGFloat) -> CGFloat { fs * 1.3 }               // 宮干支
    static func centerTitle(_ fs: CGFloat) -> CGFloat { fs * 1.15 }
    static func centerBody(_ fs: CGFloat) -> CGFloat { fs * 0.9 }
    static func centerSmall(_ fs: CGFloat) -> CGFloat { fs * 0.75 }
    static func pillar(_ fs: CGFloat) -> CGFloat { fs * 1.35 }
    static func pillarSmall(_ fs: CGFloat) -> CGFloat { fs * 1.1 }          // 中宮兩組四柱
    static func dayun(_ fs: CGFloat) -> CGFloat { fs * 0.95 }               // 大運干支
    static func godLabel(_ fs: CGFloat) -> CGFloat { max(7.5, fs * 0.55) }  // 十神小字、大運歲數

    static func font(_ size: CGFloat, _ weight: Font.Weight = .regular) -> Font { .system(size: size, weight: weight) }
}
