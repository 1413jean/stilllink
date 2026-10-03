import SwiftUI
import AppKit

/// 動態設計 token（參考 GSAP 的原則：out 系 easing、短時長、清單錯開、只動 transform／opacity）
/// 系統「減少動態效果」打開時，全部改成瞬間切換。
enum Motion {
    /// 設定裡的「介面動畫」開關
    static var userEnabled = true
    static var reduce: Bool { !userEnabled || NSWorkspace.shared.accessibilityDisplayShouldReduceMotion }

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

/// 列表的按壓回饋：不縮放，按下時變淡（側欄用）
struct RowPressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label.opacity(configuration.isPressed ? 0.7 : 1)
    }
}

/// 按壓回饋：按下縮 0.97（hover 底色由各列自己處理）
struct PressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed && !Motion.reduce ? 0.97 : 1)
            .animation(Motion.fast, value: configuration.isPressed)
    }
}

/// 視窗頂端（工具列）漸層：底色 100% → 0%，整條寬度
struct TopFade: View {
    let color: Color
    var body: some View {
        // 背景模糊＋底色，都由上（100%）往下漸變到 0；整排頂部一樣
        ZStack {
            Rectangle().fill(.regularMaterial)
                .mask(LinearGradient(colors: [.black, .black.opacity(0)], startPoint: .top, endPoint: .bottom))
            LinearGradient(colors: [color, color.opacity(0)], startPoint: .top, endPoint: .bottom)
        }
            .frame(height: 64)
            .ignoresSafeArea(edges: .top)
            .allowsHitTesting(false)
    }
}

// MARK: Snackbar 提示

extension Notification.Name { static let toast = Notification.Name("zw.toast") }

enum Toast {
    static func show(_ text: String) { NotificationCenter.default.post(name: .toast, object: text) }
}

/// 畫面底部的提示條，2 秒後自動消失
struct ToastHost: View {
    @State private var text: String?
    @State private var token = 0
    var body: some View {
        ZStack {
            if let text {
                Text(text)
                    .font(Font.zCalloutStrong)
                    .foregroundStyle(Color.zBg)
                    .padding(.horizontal, 16).frame(height: 36)
                    .background(Capsule().fill(Color.zText))
                    // 兩層陰影：一層大而柔、一層貼近輪廓，浮起來比較明顯
                    .shadow(color: .black.opacity(0.18), radius: 14, y: 6)
                    .shadow(color: .black.opacity(0.10), radius: 2, y: 1)
                    .transition(.opacity.combined(with: .offset(y: 12)))
            }
        }
        .padding(.bottom, 124)   // 剛好在下方 AI 輸入框上面一點
        .allowsHitTesting(false)
        .onReceive(NotificationCenter.default.publisher(for: .toast)) { n in
            guard let t = n.object as? String else { return }
            token += 1
            let mine = token
            withAnimation(Motion.enter) { text = t }
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                if mine == token { withAnimation(Motion.exit) { text = nil } }
            }
        }
    }
}
