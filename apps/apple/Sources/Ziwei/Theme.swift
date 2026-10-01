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
    static let wmSF = dynamic(0xF6F3EC, 0x2D2C2A)
    static let wmSel = dynamic(0xFBEDEA, 0x3A2E2C)

    static let mLu = dynamic(0x1F8A3A, 0x4FBF7E)
    static let mQuan = dynamic(0x7B48C8, 0xA987EC)
    static let mKe = dynamic(0x1F5FBF, 0x6AA2F5)
    static let mJi = dynamic(0xD0102A, 0xF06A6A)

    static let scopeColors: [Color] = [
        dynamic(0xB5701A, 0xE0A84A), dynamic(0x1F5FBF, 0x6AA2F5), dynamic(0x7B48C8, 0xA987EC),
        dynamic(0x1F8A8A, 0x4FC9C9), dynamic(0x6B6963, 0xA6A39C),
    ]
}

extension Mutagen {
    var color: Color { [.mLu, .mQuan, .mKe, .mJi][Mutagen.allCases.firstIndex(of: self)!] }
}

extension ZW.Tone {
    var color: Color { self == .red ? .wmRed : self == .blue ? .wmBlue : .wmBlack }
}

extension ZW.Wuxing {
    var color: Color {
        switch self { case .wood: .wmGreen; case .fire: .wmRed; case .earth: .wmEarth; case .metal: .wmBlue; case .water: .wmBlack }
    }
}

extension Font {
    static func serif(_ size: CGFloat, _ weight: Font.Weight = .regular) -> Font {
        .custom("Songti TC", size: size).weight(weight)
    }
}
