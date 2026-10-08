import SwiftUI
#if os(macOS)
import AppKit
#else
import UIKit
#endif

/// 動態設計 token（參考 GSAP 的原則：out 系 easing、短時長、清單錯開、只動 transform／opacity）
/// 系統「減少動態效果」打開時，全部改成瞬間切換。
enum Motion {
    /// 設定裡的「介面動畫」開關
    static var userEnabled = true
    static var reduce: Bool { !userEnabled || Platform.reduceMotion }

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
#if os(macOS)
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
#else
/// iOS：UIVisualEffectView，漸層一樣用圖層遮罩（UIKit 圖層原點在左上，方向跟 Mac 相反）
struct BackdropBlur: UIViewRepresentable {
    var fadeFromTop: Bool? = nil
    var material: UIBlurEffect.Style = .headerView
    /// 漸進模糊的起點半徑（邊緣最模糊、往內到 0）；系統材質的半徑大約 24，所以這裡只用來決定遮罩是線性的
    var radius: CGFloat = 0

    final class View: UIVisualEffectView {
        var fadeFromTop: Bool?
        // UIVisualEffectView 不能直接用 layer.mask（模糊會整塊照畫、邊緣變成一條硬線）；要用 mask view
        private let maskHost = GradientMask()
        override func layoutSubviews() {
            super.layoutSubviews()
            guard let top = fadeFromTop else { mask = nil; return }
            maskHost.frame = bounds
            maskHost.set(top: top)
            if mask !== maskHost { mask = maskHost }
        }
    }

    /// 漸層遮罩：邊緣 100% → 往內 0%（緩和曲線，看不出分界）
    final class GradientMask: UIView {
        override class var layerClass: AnyClass { CAGradientLayer.self }
        func set(top: Bool) {
            let g = layer as! CAGradientLayer
            g.colors = [1, 0.85, 0.55, 0.25, 0].map { UIColor.black.withAlphaComponent($0).cgColor }
            g.locations = [0, 0.3, 0.6, 0.85, 1]
            g.startPoint = CGPoint(x: 0.5, y: top ? 0 : 1)
            g.endPoint = CGPoint(x: 0.5, y: top ? 1 : 0)
        }
    }

    func makeUIView(context: Context) -> View {
        let v = View(effect: UIBlurEffect(style: material))
        v.fadeFromTop = fadeFromTop
        return v
    }
    func updateUIView(_ v: View, context: Context) {
        v.effect = UIBlurEffect(style: material)
        v.fadeFromTop = fadeFromTop
        v.setNeedsLayout()
    }
}

/// 跟 Mac 版同名的材質，共用程式不用改
extension UIBlurEffect.Style {
    static var headerView: Self { .systemUltraThinMaterial }   // 最淡的模糊：顏色交給上面的同底色漸層，不要材質自己的深色
    static var hudWindow: Self { .systemMaterial }
}
#endif

// MARK: Snackbar 提示

extension Notification.Name { static let toast = Notification.Name("zw.toast") }

enum Toast {
    static func show(_ text: String) { NotificationCenter.default.post(name: .toast, object: ToastItem(text: text)) }
    /// 帶一個動作（例：「復原」）：多一個 ×，停留比較久
    static func show(_ text: String, action: String, perform: @escaping () -> Void) {
        NotificationCenter.default.post(name: .toast, object: ToastItem(text: text, action: action, perform: perform))
    }
}

/// 提示條要對齊的水平中心（視窗座標）：命盤頁會回報底部工具列的中心，其他頁用整個畫面的中間
@MainActor
final class ToastAnchor: ObservableObject {
    static let shared = ToastAnchor()
    @Published var centerX: CGFloat?
    @Published var top: CGFloat?      // 工具列上緣（視窗座標）：提示條停在它上面一點
    var owner: UUID?                  // 是哪一個命盤頁回報的（切換命盤時，舊頁關掉只清自己的，不會清掉新頁剛報的位置）
}

/// 一則提示：文字＋（可選）動作按鈕
final class ToastItem {
    let text: String
    let action: String?
    let perform: (() -> Void)?
    init(text: String, action: String? = nil, perform: (() -> Void)? = nil) {
        self.text = text; self.action = action; self.perform = perform
    }
}

/// 畫面底部的提示條（全 App 共用同一個）：2 秒後自動消失；帶動作按鈕的停 5 秒
struct ToastHost: View {
    @State private var item: ToastItem?
    @State private var token = 0
    @ObservedObject private var anchor = ToastAnchor.shared
    var body: some View {
        GeometryReader { g in
            let frame = g.frame(in: .global)
            // 工具列位置不在視窗裡（例如畫面外的那一頁回報的）就不用
            let x = anchor.centerX.flatMap { frame.minX...frame.maxX ~= $0 ? $0 : nil }
            let top = anchor.top.flatMap { (frame.minY + 40)...frame.maxY ~= $0 ? $0 : nil }
            let dx = x.map { $0 - frame.midX } ?? 0
            // 命盤頁：停在底部工具列上面一點（工具列被 AI 對話框推高時也跟著上去）；其他頁離底部 28
            let gap = top.map { max(12, frame.maxY - $0 + 10) } ?? 28
            ZStack(alignment: .bottom) { bar.offset(x: dx) }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
                .padding(.bottom, gap)
        }
    }

    /// 依訊息內容配 icon：失敗／錯誤用驚嘆號，提示說明用 i，其他（已複製、已儲存…）用打勾
    private static func kind(_ t: String) -> Int {
        if t.contains("失敗") || t.contains("不是") || t.contains("錯誤") { return 2 }
        if t.hasPrefix("已") && !t.contains("鎖定「") { return 0 }
        return 1
    }
    static func icon(for t: String) -> String {
        ["checkmark.circle.fill", "info.circle.fill", "exclamationmark.triangle.fill"][kind(t)]
    }

    private var bar: some View {
        ZStack {
            if let item {
                let text = item.text
                HStack(spacing: 10) {
                    Image(systemName: Self.icon(for: text))
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(Color.zBg.opacity(0.75))   // icon 一律灰白，不用彩色
                    Text(text)
                        .font(Font.zCalloutStrong)
                        .foregroundStyle(Color.zBg)
                        .lineLimit(2)
                    if let action = item.action {
                        Button(action) { item.perform?(); dismiss() }
                            .buttonStyle(.plain).font(Font.zCalloutStrong).foregroundStyle(Color.zToastAction)
                            .padding(.leading, 4)
                        Button(action: dismiss) {
                            Image(systemName: "xmark").font(.system(size: 10, weight: .bold)).foregroundStyle(Color.zBg.opacity(0.6))
                                .frame(width: 20, height: 20).contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.leading, 18).padding(.trailing, item.action == nil ? 22 : 14).padding(.vertical, 12)
                // 背景模糊＋半透明深色，後面的盤面隱約透出來
                .background(
                    ZStack {
                        BackdropBlur(material: .hudWindow)
                        Color.zText.opacity(0.64)
                    }
                    .clipShape(Capsule())
                )
                .overlay(Capsule().stroke(Color.white.opacity(0.12), lineWidth: 0.5))
                    // 兩層陰影：一層大而柔、一層貼近輪廓，浮起來比較明顯
                    .shadow(color: .black.opacity(0.18), radius: 14, y: 6)
                    .shadow(color: .black.opacity(0.10), radius: 2, y: 1)
                    .transition(.opacity.combined(with: .offset(y: 12)))
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .toast)) { n in
            guard let t = n.object as? ToastItem else { return }
            token += 1
            let mine = token
            withAnimation(Motion.enter) { item = t }
            DispatchQueue.main.asyncAfter(deadline: .now() + (t.action == nil ? 2 : 5)) {
                if mine == token { withAnimation(Motion.exit) { item = nil } }
            }
        }
    }

    private func dismiss() { token += 1; withAnimation(Motion.exit) { item = nil } }
}
