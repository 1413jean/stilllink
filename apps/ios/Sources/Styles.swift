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
        .zEdgeFades()
    }
}

extension View {
    /// 上下邊緣：跟 Mac 版一樣的 TopFade（同底色漸層＋背景模糊），取代系統的捲動邊緣效果
    /// （系統的在深色模式會整片變黑）。導覽列、分頁列都不要自己的底色
    func zEdgeFades(top: CGFloat = 36, bottom: CGFloat = 20) -> some View {
        modifier(EdgeFades(top: top, bottom: bottom))
    }

    /// 開關一律用主色（按鈕、選單是主文字色）
    func zSwitch() -> some View {
        tint(Color.zAccent)
    }
}

private struct EdgeFades: ViewModifier {
    let top: CGFloat
    let bottom: CGFloat

    func body(content: Content) -> some View {
        content
            .toolbarBackgroundVisibility(.hidden, for: .navigationBar)
            .toolbarBackgroundVisibility(.hidden, for: .tabBar)
            // 先量這一頁的安全區域（狀態列＋導覽列、分頁列），再從螢幕上下緣明確排：
            // 頂部蓋到導覽列下面再多 top，底部蓋到分頁列上面再多 bottom
            .overlay {
                GeometryReader { g in
                    VStack(spacing: 0) {
                        EdgeFade(edge: .top, height: g.safeAreaInsets.top + top)
                        Spacer(minLength: 0)
                        EdgeFade(edge: .bottom, height: g.safeAreaInsets.bottom + bottom)
                    }
                    .ignoresSafeArea()
                }
                .allowsHitTesting(false)
            }
            .onAppear(perform: SystemScrollEdge.hideAll)
    }
}

/// 狀態列、導覽列、分頁列後面：背景色（backgroundPrimary）漸層 100%→0%；頂部再疊漸進背景模糊（邊緣 24 → 0），底部只有漸層
struct EdgeFade: View {
    let edge: VerticalEdge
    var height: CGFloat = 20

    var body: some View {
        let start: UnitPoint = edge == .top ? .top : .bottom, end: UnitPoint = edge == .top ? .bottom : .top
        ZStack {
            // 底部只用背景色漸層（Jean：底部模糊看起來不自然），頂部才疊模糊
            if edge == .top { BackdropBlur(fadeFromTop: true, radius: 24) }
            // 底色漸層用緩和曲線（線性的在 0% 那一端看得出一條界線）
            LinearGradient(stops: [.init(color: Color.zBg, location: 0), .init(color: Color.zBg.opacity(0.85), location: 0.3),
                                   .init(color: Color.zBg.opacity(0.45), location: 0.6), .init(color: Color.zBg.opacity(0.12), location: 0.85),
                                   .init(color: Color.zBg.opacity(0), location: 1)], startPoint: start, endPoint: end)
        }
        .frame(height: height)
        .allowsHitTesting(false)
    }
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
