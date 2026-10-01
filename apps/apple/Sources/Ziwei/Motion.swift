import SwiftUI
import AppKit

/// 動態設計 token（參考 GSAP 的原則：out 系 easing、短時長、清單錯開、只動 transform／opacity）
/// 系統「減少動態效果」打開時，全部改成瞬間切換。
enum Motion {
    static var reduce: Bool { NSWorkspace.shared.accessibilityDisplayShouldReduceMotion }

    /// hover、按壓等即時回饋（≈ power1.out 0.15s）
    static var fast: Animation? { reduce ? nil : .timingCurve(0.25, 0.46, 0.45, 0.94, duration: 0.15) }
    /// 一般狀態切換：選取、展開、資料更新（≈ power2.out 0.25s）
    static var base: Animation? { reduce ? nil : .timingCurve(0.215, 0.61, 0.355, 1, duration: 0.25) }
    /// 進場：畫面、卡片、彈窗（≈ power3.out 0.4s）
    static var enter: Animation? { reduce ? nil : .timingCurve(0.22, 1, 0.36, 1, duration: 0.4) }
    /// 退場要比進場快（≈ power2.in 0.18s）
    static var exit: Animation? { reduce ? nil : .timingCurve(0.55, 0.055, 0.675, 0.19, duration: 0.18) }
    /// 跟手的選取指示（滑動的底色、膠囊）
    static var snap: Animation? { reduce ? nil : .spring(response: 0.32, dampingFraction: 0.86) }

    /// 清單錯開（stagger）每一項的延遲
    static func stagger(_ i: Int, each: Double = 0.025) -> Animation? {
        enter?.delay(Double(i) * each)
    }
}

extension View {
    /// 進場：由下往上 8pt＋淡入，可帶錯開序號（等同 gsap.from({ y: 8, autoAlpha: 0, stagger })）
    func enterFromBelow(_ shown: Bool, index: Int = 0, distance: CGFloat = 8) -> some View {
        self.opacity(shown ? 1 : 0)
            .offset(y: shown || Motion.reduce ? 0 : distance)
            .animation(Motion.stagger(index), value: shown)
    }
}

/// 彈窗開著時背景要模糊。模糊加在各欄的內容層（已在 safe area 內），
/// 不能加在 NavigationSplitView 外層——那樣會吃掉工具列的 safe area，整個畫面往上跳。
private struct DimmedKey: EnvironmentKey { static let defaultValue = false }
extension EnvironmentValues {
    var zDimmed: Bool {
        get { self[DimmedKey.self] }
        set { self[DimmedKey.self] = newValue }
    }
}

struct DimmedBlur: ViewModifier {
    @Environment(\.zDimmed) private var dimmed
    func body(content: Content) -> some View { content.blur(radius: dimmed ? 6 : 0) }
}

extension View {
    func dimmedBlur() -> some View { modifier(DimmedBlur()) }
}

/// 按壓回饋：按下縮 0.97（hover 底色由各列自己處理）
struct PressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed && !Motion.reduce ? 0.97 : 1)
            .animation(Motion.fast, value: configuration.isPressed)
    }
}
