import SwiftUI

// MARK: - iOS 共用元件（新畫面一律用這些，不要在各頁自己畫膠囊、陰影）
// 清單與用途寫在 DESIGN.md「iOS 元件」

/// 膠囊按鈕：主要（黑底白字）、次要（淺灰底）、外框（卡片底＋細框）。高度統一 48，按下縮 0.97，停用 40% 透明
struct CapsuleButtonStyle: ButtonStyle {
    enum Kind { case primary, secondary, outline }
    var kind: Kind = .primary
    var fill = false        // true：撐滿寬度（表單、卡片裡的按鈕）
    var floating = false    // true：浮在內容上（右下角新增、側欄底部）加陰影
    @Environment(\.isEnabled) private var enabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .zText(.bodyStrong)
            .foregroundStyle(kind == .primary ? Color.zBg : Color.zText)
            .padding(.horizontal, 22)
            .frame(maxWidth: fill ? .infinity : nil)
            .frame(height: 48)
            .background(Capsule().fill(kind == .primary ? Color.zText : kind == .secondary ? Color.zHover : Color.zCard))
            .overlay { if kind == .outline { Capsule().stroke(Color.zLine) } }
            .shadow(color: floating ? Color.zShadow : .clear, radius: 10, y: 3)
            .contentShape(Capsule())
            .scaleEffect(configuration.isPressed && !Motion.reduce ? 0.97 : 1)
            .opacity(enabled ? 1 : 0.4)
            .animation(Motion.fast, value: configuration.isPressed)
    }
}

extension ButtonStyle where Self == CapsuleButtonStyle {
    static func capsule(_ kind: CapsuleButtonStyle.Kind = .primary, fill: Bool = false, floating: Bool = false) -> CapsuleButtonStyle {
        CapsuleButtonStyle(kind: kind, fill: fill, floating: floating)
    }
}

extension View {
    /// 浮在盤面上的膠囊（底部筆記入口這類）：浮起卡片色＋細框＋陰影，深色模式也分得出層次
    func zFloatingCapsule() -> some View {
        background(Capsule().fill(Color.zRaised))
            .overlay(Capsule().stroke(Color.zRaisedLine, lineWidth: 0.5))
            .shadow(color: Color.zShadow, radius: 12, y: 4)
    }
}
