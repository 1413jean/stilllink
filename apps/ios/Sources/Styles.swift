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
    func zEdgeFades(top: CGFloat = 0, bottom: CGFloat = 20) -> some View {
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

    var body: some View {
        let start: UnitPoint = edge == .top ? .top : .bottom, end: UnitPoint = edge == .top ? .bottom : .top
        // 目前只有同底色漸層：系統的模糊加漸層遮罩會失效、疊層模糊會出現階梯和灰帶（2026-10 試過），先不加
        LinearGradient(colors: [Color.zBg, Color.zBg.opacity(0)], startPoint: start, endPoint: end)
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
