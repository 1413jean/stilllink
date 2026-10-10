import SwiftUI

/// 系統 Form 換成 App 的色系（跟「我的」一樣）：暖白底、淺灰卡片，深色模式也一致
struct ZForm<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        Form {
            Group { content }
                .listRowBackground(Color.zHover)
        }
        .scrollContentBackground(.hidden)
        .background(Color.zBg)
        .zEdgeFades(bottom: nil)   // 表單都在彈出視窗裡：底部不淡出
    }
}

extension View {
    /// 上下邊緣：跟 Mac 版一樣的 TopFade（同底色漸層＋背景模糊），取代系統的捲動邊緣效果
    /// （系統的在深色模式會整片變黑）。導覽列、分頁列都不要自己的底色
    /// bottom 傳 nil：底部不淡出（彈出視窗 sheet 底部就是螢幕邊，不需要）
    func zEdgeFades(top: CGFloat = 24, bottom: CGFloat? = 56) -> some View {
        modifier(EdgeFades(top: top, bottom: bottom))
    }

    /// 開關一律用主色（按鈕、選單是主文字色）
    func zSwitch() -> some View {
        tint(Color.zAccent)
    }
}

private struct EdgeFades: ViewModifier {
    let top: CGFloat
    let bottom: CGFloat?

    /// 狀態列高度：問狀態列管理器（這一頁量到的安全區會含導覽列；讀視窗的安全區會在排版中再觸發排版）
    @MainActor static var statusBar: CGFloat {
        let h = UIApplication.shared.connectedScenes.compactMap { ($0 as? UIWindowScene)?.statusBarManager?.statusBarFrame.height }.first ?? 0
        return h > 0 ? h : 54
    }

    func body(content: Content) -> some View {
        content
            .toolbarBackgroundVisibility(.hidden, for: .navigationBar)
            .toolbarBackgroundVisibility(.hidden, for: .tabBar)
            // 先量這一頁的安全區域（狀態列＋導覽列、分頁列），再從螢幕上下緣明確排：
            // 頂部蓋到導覽列下面再多 top，底部蓋到分頁列上面再多 bottom
            .overlay {
                GeometryReader { g in
                    VStack(spacing: 0) {
                        // 照 Claude App：只蓋狀態列（時間、電量那一條），導覽列按鈕底下完全透明
                        EdgeFade(edge: .top, height: Self.statusBar + top, solid: Self.statusBar)
                        Spacer(minLength: 0)
                        if let bottom {
                            EdgeFade(edge: .bottom, height: g.safeAreaInsets.bottom + bottom, solid: max(1, g.safeAreaInsets.bottom))
                        }
                    }
                    .ignoresSafeArea()
                }
                .allowsHitTesting(false)
            }
            .modifier(NativeScrollEdgeHidden())
            .onAppear(perform: SystemScrollEdge.hideAll)
    }
}

/// iOS 26.1 起用 SwiftUI 原生的關法：List 的「硬式」邊緣效果（導覽列下緣一層底色＋一條分隔線）
/// KVC 關不掉；26.0 這個 API 缺型別會閃退，所以只在 26.1 以上用
private struct NativeScrollEdgeHidden: ViewModifier {
    func body(content: Content) -> some View {
        if #available(iOS 26.1, *) {
            content.scrollEdgeEffectHidden(true, for: .all)
        } else {
            content
        }
    }
}

/// 狀態列＋導覽列（或底部安全區）後面，照 Figma Morning App「Navbar」：
/// 同底色漸層——邊緣 100% 線性淡到 0%（結束在導覽列下緣）
struct EdgeFade: View {
    let edge: VerticalEdge
    var height: CGFloat = 20
    var solid: CGFloat = 0     // 導覽列（或底部安全區）本身的高度：模糊只蓋這段

    var body: some View {
        let start: UnitPoint = edge == .top ? .top : .bottom, end: UnitPoint = edge == .top ? .bottom : .top
        // 照 Claude／Instagram：漸進模糊（邊緣最糊、往內平順到 0，沒有交界線）＋同底色漸層 100% → 0%
        ZStack {
            if solid > 0 { VariableBlur(radius: 12, fromTop: edge == .top) }
            LinearGradient(colors: [Color.zBg, Color.zBg.opacity(0)], startPoint: start, endPoint: end)
        }
        .frame(height: height)
        .allowsHitTesting(false)
    }
}

/// 漸進背景模糊：用系統導覽列邊緣效果同一個濾鏡（CAFilter variableBlur，未公開 API），
/// 由一張漸層圖決定每一處糊多少——邊緣 100%、往內平順到 0，所以沒有分割線。
/// 濾鏡名稱用拼字組出來、找不到就什麼都不做（只剩漸層），不會閃退
private struct VariableBlur: UIViewRepresentable {
    let radius: CGFloat
    let fromTop: Bool

    final class View: UIView {
        var radius: CGFloat = 12
        var fromTop = true
        private var applied: CGSize = .zero
        // 這個 view 本身的 layer 就是 backdrop layer（會取樣後面的畫面），濾鏡直接掛在它上面
        override class var layerClass: AnyClass { NSClassFromString(["CA", "Backdrop", "Layer"].joined()) ?? CALayer.self }

        override func layoutSubviews() {
            super.layoutSubviews()
            guard bounds.size != applied, bounds.height > 0 else { return }
            applied = bounds.size
            apply()
        }

        override func traitCollectionDidChange(_ previous: UITraitCollection?) {
            super.traitCollectionDidChange(previous)
            applied = .zero; setNeedsLayout()
        }

        private func apply() {
            let cls = ["CA", "Filter"].joined()
            let make = NSSelectorFromString(["filter", "With", "Type:"].joined())
            guard let filterClass = NSClassFromString(cls) as AnyObject as? NSObjectProtocol,
                  filterClass.responds(to: make),
                  let filter = filterClass.perform(make, with: ["variable", "Blur"].joined())?.takeUnretainedValue() as? NSObject
            else { return }
            filter.setValue(radius, forKey: "inputRadius")
            filter.setValue(mask(bounds.size), forKey: "inputMaskImage")
            filter.setValue(true, forKey: "inputNormalizeEdges")
            layer.filters = [filter]
            layer.setValue(UIScreen.main.scale, forKey: "scale")
        }

        /// 遮罩圖：邊緣不透明（全糊）→ 往內透明（不糊），用緩和曲線
        private func mask(_ size: CGSize) -> CGImage? {
            let h = max(1, Int(size.height))
            let r = UIGraphicsImageRenderer(size: CGSize(width: 1, height: h))
            return r.image { ctx in
                // 往內的那一半要很緩（0.25 → 0.08 → 0），不然模糊開始的地方看得出一條線
                let colors = [1, 0.55, 0.25, 0.08, 0].map { UIColor.black.withAlphaComponent($0).cgColor } as CFArray
                guard let g = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors, locations: [0, 0.3, 0.55, 0.8, 1]) else { return }
                let a = CGPoint(x: 0, y: fromTop ? 0 : CGFloat(h)), b = CGPoint(x: 0, y: fromTop ? CGFloat(h) : 0)
                ctx.cgContext.drawLinearGradient(g, start: a, end: b, options: [])
            }.cgImage
        }
    }

    func makeUIView(context: Context) -> View {
        let v = View()
        v.isUserInteractionEnabled = false
        v.backgroundColor = .clear
        v.radius = radius; v.fromTop = fromTop
        return v
    }
    func updateUIView(_ v: View, context: Context) { v.radius = radius; v.fromTop = fromTop }
}

/// 輕度、均勻的背景模糊：系統材質用暫停的動畫器停在 35% 強度（調模糊強度的公開做法），
/// 並清掉材質自帶的灰色染色；回到前景時動畫器會被系統跑完，所以重建
private struct LightBlur: UIViewRepresentable {
    static let intensity: CGFloat = 0.35

    final class View: UIVisualEffectView {
        private var animator: UIViewPropertyAnimator?
        private var observer: NSObjectProtocol?

        override func didMoveToWindow() {
            super.didMoveToWindow()
            guard window != nil else { return }
            rebuild()
            if observer == nil {
                observer = NotificationCenter.default.addObserver(forName: UIApplication.willEnterForegroundNotification, object: nil, queue: .main) { [weak self] _ in
                    MainActor.assumeIsolated { self?.rebuild() }
                }
            }
        }

        override func layoutSubviews() {
            super.layoutSubviews()
            for v in subviews where String(describing: type(of: v)).contains("VisualEffectSubview") { v.backgroundColor = .clear }
        }

        func rebuild() {
            animator?.stopAnimation(true)
            effect = nil
            let a = UIViewPropertyAnimator(duration: 1, curve: .linear) { [weak self] in
                self?.effect = UIBlurEffect(style: .systemUltraThinMaterial)
            }
            a.pausesOnCompletion = true
            a.fractionComplete = LightBlur.intensity
            animator = a
            setNeedsLayout()
        }

        deinit {
            animator?.stopAnimation(true)
            if let observer { NotificationCenter.default.removeObserver(observer) }
        }
    }

    func makeUIView(context: Context) -> View {
        let v = View(effect: nil)
        v.isUserInteractionEnabled = false
        return v
    }
    func updateUIView(_ v: View, context: Context) {}
}

/// iOS 26 的捲動邊緣效果（深色模式會整片變黑）全部關掉，改用上面的 EdgeFade。
/// SwiftUI 的 scrollEdgeEffectHidden 在 26.0 測試版缺型別會閃退，所以直接找 UIScrollView 關：
/// 用 KVC＋responds(to:) 檢查，沒有這個屬性的系統（iOS 18）什麼都不做
enum SystemScrollEdge {
    @MainActor static func hideAll() {
        // 畫面剛出來時 List／ScrollView 還沒掛上去，晚一點再掃一次
        for delay in [0.05, 0.4] {
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                for scene in UIApplication.shared.connectedScenes.compactMap({ $0 as? UIWindowScene }) {
                    for w in scene.windows { walk(w) }
                }
            }
        }
    }

    @MainActor private static func walk(_ v: UIView) {
        if let sv = v as? UIScrollView {
            for key in ["topEdgeEffect", "bottomEdgeEffect", "leftEdgeEffect", "rightEdgeEffect"]
            where sv.responds(to: NSSelectorFromString(key)) {
                (sv.value(forKey: key) as? NSObject)?.setValue(true, forKey: "hidden")
            }
        }
        v.subviews.forEach(walk)
    }
}
