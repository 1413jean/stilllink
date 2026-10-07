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
        .zNavBar()
    }
}

extension View {
    /// 導覽列捲動後的底色跟頁面一樣（系統預設在深色模式會變成一條黑）
    func zNavBar() -> some View {
        toolbarBackground(Color.zBg, for: .navigationBar)
    }

    /// 開關一律用主色（按鈕、選單是主文字色）
    func zSwitch() -> some View {
        tint(Color.zAccent)
    }
}
