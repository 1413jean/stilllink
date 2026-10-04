import SwiftUI

// 輸入框（設計系統元件，Figma「❖ 輸入框 Input」記錄同一份規格）
// 全 App 的單行、搜尋、多行輸入框都套 .zInput(...)：各處只決定尺寸、外觀、要不要圖示，
// 框的高度、字級、圓角、focus 光圈、停用都在這裡統一。
// 聊天式輸入列（評論、AI 解盤）框裡還有工具列，是另一種元件，不套這個。

/// 尺寸：框的高度和裡面的字一起決定，跟旁邊的文字搭得起來
enum InputSize {
    case small    // 32 高、callout 13：窄的地方（側欄、設定搜尋、數字卦）
    case medium   // 38 高、callout 13：卡片裡、旁邊都是小字時（合盤、備註、星曜搜尋）
    case large    // 38 高、body 15：表單（預設）
    case xLarge   // 44 高、body 15：主要的大輸入

    var height: CGFloat { switch self { case .small: 32; case .medium, .large: 38; case .xLarge: 44 } }
    var type: ZType { switch self { case .small, .medium: .callout; case .large, .xLarge: .body } }
    var padding: CGFloat { self == .small ? 10 : 12 }
    var radius: CGFloat { self == .small ? 8 : 9 }
    /// 多行時上下留白：第一行落在跟單行一樣的位置（(高度 − 行高) ÷ 2）
    var vPadding: CGFloat { switch self { case .small: 6; case .medium: 9; case .large: 7; case .xLarge: 10 } }
}

/// 外觀
enum InputStyle {
    case outline   // 卡片底＋細框：表單、卡片裡（預設）
    case filled    // 淺灰底、沒有框：側欄、清單上方的搜尋，逐項編輯
}

extension View {
    /// 套上設計系統輸入框。`focused` 傳進來才會有 focus 光圈；多行（axis: .vertical、TextEditor）要設 `multiline`
    func zInput(_ size: InputSize = .large, style: InputStyle = .outline, icon: String? = nil,
                focused: Bool = false, multiline: Bool = false) -> some View {
        modifier(ZInputBox(size: size, style: style, icon: icon, focused: focused, multiline: multiline))
    }
}

private struct ZInputBox: ViewModifier {
    let size: InputSize
    let style: InputStyle
    let icon: String?
    let focused: Bool
    let multiline: Bool
    @Environment(\.isEnabled) private var enabled

    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: size.radius)
        HStack(alignment: multiline ? .firstTextBaseline : .center, spacing: 6) {
            if let icon {
                Image(systemName: icon).font(Font.zIcon).foregroundStyle(Color.zText3)
            }
            content
                .textFieldStyle(.plain)
                .zText(size.type)
                .foregroundStyle(Color.zText)
        }
        .padding(.horizontal, size.padding)
        .padding(.vertical, multiline ? size.vPadding : 0)
        .frame(maxWidth: .infinity, minHeight: size.height, alignment: .leading)
        .frame(height: multiline ? nil : size.height)
        .background(shape.fill(style == .outline ? Color.zCard : Color.zHover))
        .overlay(shape.stroke(border, lineWidth: 1))
        .opacity(enabled ? 1 : 0.5)
        .animation(Motion.fast, value: focused)
    }

    private var border: Color {
        if focused { return Color.zAccent.opacity(0.55) }
        return style == .outline ? Color.zLine : .clear
    }
}

/// 輸入框尾端的清除鈕：有字才出現（`always` 讓它一直在，例如側欄搜尋拿來關掉搜尋）
struct ZClearButton: View {
    @Binding var text: String
    var always = false
    var action: (() -> Void)? = nil

    var body: some View {
        if always || !text.isEmpty {
            Button { text = ""; action?() } label: {
                Image(systemName: "xmark.circle.fill").foregroundStyle(Color.zText3)
            }
            .buttonStyle(.plain)
            .help("清除")
        }
    }
}
