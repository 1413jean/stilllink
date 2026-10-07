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
    func zEdgeFades(top: CGFloat = 20, bottom: CGFloat = 20) -> some View {
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
            .modifier(HideSystemScrollEdge())
            .toolbarBackgroundVisibility(.hidden, for: .navigationBar)
            .toolbarBackgroundVisibility(.hidden, for: .tabBar)
            // 頂部從導覽列（或狀態列）往下多淡 top；底部從分頁列往上多淡 bottom
            .overlay(alignment: .top) { TopFade(color: .zBg, height: top) }
            .overlay(alignment: .bottom) { TopFade(color: .zBg, edge: .bottom, height: bottom) }
    }
}

/// iOS 26 的捲動邊緣效果關掉，改用上面的 TopFade
private struct HideSystemScrollEdge: ViewModifier {
    func body(content: Content) -> some View {
        // 26.0 測試版（模擬器）缺 scrollEdgeEffectHidden 的型別會閃退：先退回柔和效果
        if #available(iOS 26.1, *) {
            content.scrollEdgeEffectHidden(true, for: .all)
        } else if #available(iOS 26.0, *) {
            content.scrollEdgeEffectStyle(.soft, for: .all)
        } else {
            content
        }
    }
}
