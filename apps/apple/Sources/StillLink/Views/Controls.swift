import SwiftUI

// 設計系統控制項：高度一律 38，與輸入框 zInput 一致

/// 分段選擇：淺底軌道，選中的是白色膠囊
struct ZSegmented<T: Hashable>: View {
    let options: [(T, String)]
    @Binding var selection: T
    @Namespace private var ns

    var body: some View {
        HStack(spacing: 2) {
            ForEach(options, id: \.0) { value, label in
                let on = value == selection
                Button { withAnimation(Motion.snap) { selection = value } } label: {
                    Text(label)
                        .font(on ? Font.zBodyStrong : Font.zBody)
                        .foregroundStyle(on ? Color.zText : Color.zText2)
                        .frame(maxWidth: .infinity)
                        .frame(height: 32)
                        .background {
                            if on {
                                RoundedRectangle(cornerRadius: 7).fill(Color.zCard)
                                    .shadow(color: Color.zShadow, radius: 2, y: 1)
                                    .matchedGeometryEffect(id: "pill", in: ns)
                            }
                        }
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(3)
        .frame(height: 38)
        .background(RoundedRectangle(cornerRadius: 9).fill(Color.zHover))
    }
}

/// 下拉選單：外觀跟輸入框一樣
struct ZMenuField: View {
    let options: [String]
    @Binding var selection: String

    var body: some View {
        Menu {
            ForEach(options, id: \.self) { o in Button(o) { selection = o } }
        } label: {
            HStack {
                Text(selection).font(Font.zInput).foregroundStyle(Color.zText)
                Spacer()
                Image(systemName: "chevron.up.chevron.down").font(Font.zCaption).foregroundStyle(Color.zText3)
            }
            .zInput()
            .contentShape(Rectangle())
        }
        .menuStyle(.button)
        .buttonStyle(.plain)
        .menuIndicator(.hidden)
    }
}

/// 滾軸式選擇：一欄可捲動的清單，選中的列反白。
/// 用 scrollPosition 只捲自己這一欄——不用 ScrollViewReader.scrollTo，它會連外層的彈窗一起捲，造成畫面跳動。
struct ZColumnList<Item: Hashable, ID: Hashable>: View {
    let items: [Item]
    let id: KeyPath<Item, ID>
    let label: (Item) -> String
    let selected: ID?
    let onSelect: (Item) -> Void
    @State private var position: ID?

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 1) {
                ForEach(items, id: id) { item in
                    let on = item[keyPath: id] == selected
                    Button { withAnimation(Motion.base) { onSelect(item) } } label: {
                        HStack {
                            Text(label(item)).font(Font.zBody).foregroundStyle(on ? Color.zText : Color.zText2)
                            Spacer()
                            if on { Image(systemName: "checkmark").font(Font.zCaptionStrong).foregroundStyle(Color.zText) }
                        }
                        .padding(.horizontal, 10)
                        .frame(height: 30)
                        .background(RoundedRectangle(cornerRadius: 7).fill(on ? Color.zSel : Color.clear))
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }
            .scrollTargetLayout()
            .padding(4)
        }
        .scrollPosition(id: $position, anchor: .center)
        .onAppear { position = selected }
        .onChange(of: items.map { $0[keyPath: id] }) { _, _ in position = selected }
        .background(RoundedRectangle(cornerRadius: 9).fill(Color.zCard))
        .overlay(RoundedRectangle(cornerRadius: 9).stroke(Color.zLine))
    }
}

// MARK: 按鈕（設計系統）：高度 40、圓角 10、字 13 medium；small 為 32 高

/// 主要按鈕：強調色實心
struct ZPrimaryButton: ButtonStyle {
    var small = false
    @Environment(\.isEnabled) private var enabled
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(small ? Font.zCalloutStrong : Font.zBodyStrong)
            .foregroundStyle(enabled ? Color.zOnColor : Color.zText3)
            .padding(.horizontal, small ? 14 : 22)
            .frame(minWidth: small ? 0 : 88, minHeight: small ? 32 : 40)
            .background(RoundedRectangle(cornerRadius: small ? 8 : 10).fill(enabled ? Color.zAccent : Color.zHover))
            .opacity(configuration.isPressed ? 0.85 : 1)
            .scaleEffect(configuration.isPressed && !Motion.reduce ? 0.97 : 1)
            .animation(Motion.fast, value: configuration.isPressed)
    }
}

/// 次要按鈕：淺底細框
struct ZSecondaryButton: ButtonStyle {
    var small = false
    @State private var hover = false
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(small ? Font.zCalloutStrong : Font.zBodyStrong)
            .foregroundStyle(Color.zText)
            .padding(.horizontal, small ? 14 : 22)
            .frame(minWidth: small ? 0 : 88, minHeight: small ? 32 : 40)
            .background(RoundedRectangle(cornerRadius: small ? 8 : 10).fill(hover ? Color.zHover : Color.zCard))
            .overlay(RoundedRectangle(cornerRadius: small ? 8 : 10).stroke(Color.zLine))
            .scaleEffect(configuration.isPressed && !Motion.reduce ? 0.97 : 1)
            .animation(Motion.fast, value: configuration.isPressed)
            .animation(Motion.fast, value: hover)
            .onHover { hover = $0 }
    }
}
