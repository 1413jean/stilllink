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
    let color: Color   // 背景色：疊在模糊上面做漸層
    var edge: VerticalEdge = .top
    var height: CGFloat = 64
    var body: some View {
        // 背景模糊＋底色漸層：頂部由上往下 100%→0%，底部由上往下 0%→100%
        // 漸層要用模糊元件自己的 maskImage；用 SwiftUI 的 .mask 會讓背景模糊失效
        let start: UnitPoint = edge == .top ? .top : .bottom, end: UnitPoint = edge == .top ? .bottom : .top
        ZStack {
            BackdropBlur(fadeFromTop: edge == .top)
            // 照 Figma Navbar - Morning：上面 30% 實心底色，往下 70% 線性淡到 0
            LinearGradient(stops: [.init(color: color, location: 0), .init(color: color, location: 0.3),
                                   .init(color: color.opacity(0), location: 1)],
                           startPoint: start, endPoint: end)
        }
            .frame(height: height)
            .ignoresSafeArea(edges: edge == .top ? .top : .bottom)
            .allowsHitTesting(false)
    }
}

/// 背景模糊：把視窗裡在它後面的內容模糊化（NSVisualEffectView，within window）
/// fadeFromTop：true＝上面 100% 往下淡到 0；false＝上面 0 往下到 100%；nil＝整片
/// 漸層用圖層遮罩（CAGradientLayer）；maskImage 和 SwiftUI .mask 都會讓模糊整片消失
struct BackdropBlur: NSViewRepresentable {
    var fadeFromTop: Bool? = nil
    var material: NSVisualEffectView.Material = .headerView

    final class View: NSVisualEffectView {
        var fadeFromTop: Bool?
        private let gradient = CAGradientLayer()
        override func layout() {
            super.layout()
            guard let top = fadeFromTop else { layer?.mask = nil; return }
            wantsLayer = true
            gradient.frame = bounds
            // 圖層座標原點在左下：startPoint y=1 是上面
            // 緩和曲線（ease-out）：邊緣不會有一條明顯的界線
            gradient.colors = [1, 0.8, 0.45, 0.15, 0].map { NSColor.black.withAlphaComponent($0).cgColor }
            gradient.locations = [0, 0.25, 0.55, 0.8, 1]
            gradient.startPoint = CGPoint(x: 0.5, y: top ? 1 : 0)
            gradient.endPoint = CGPoint(x: 0.5, y: top ? 0 : 1)
            layer?.mask = gradient
        }
    }

    func makeNSView(context: Context) -> View {
        let v = View()
        v.blendingMode = .withinWindow
        v.state = .active
        v.material = material
        v.fadeFromTop = fadeFromTop
        return v
    }
    func updateNSView(_ v: View, context: Context) {
        v.material = material
        v.fadeFromTop = fadeFromTop
        v.needsLayout = true
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
