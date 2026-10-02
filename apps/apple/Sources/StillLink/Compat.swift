import SwiftUI

/// 支援 macOS 13：macOS 14 才有的寫法包一層，13 上退回舊做法（功能一樣，只是少一點細節）
extension View {
    /// 捲動區一開始停在最上面（13 本來就從上面開始，不用特別設）
    @ViewBuilder func defaultScrollAnchorTop() -> some View {
        if #available(macOS 14, *) { defaultScrollAnchor(.top) } else { self }
    }

    /// 捲動內容超出邊界時不裁切（卡片陰影）；13 會被裁一點點
    @ViewBuilder func scrollClipDisabledCompat() -> some View {
        if #available(macOS 14, *) { scrollClipDisabled() } else { self }
    }
}
