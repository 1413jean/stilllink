import SwiftUI

// MARK: - iOS 共用元件（新畫面一律用這些，不要在各頁自己畫膠囊、陰影）
// 清單與用途寫在 DESIGN.md「iOS 元件」

/// 膠囊按鈕：主要（黑底白字）、次要（淺灰底）、外框（卡片底＋細框）。高度統一 48，按下縮 0.97，停用 40% 透明
struct CapsuleButtonStyle: ButtonStyle {
    enum Kind { case primary, secondary, outline }
    var kind: Kind = .primary
    var fill = false        // true：撐滿寬度（表單、卡片裡的按鈕）
    var floating = false    // true：浮在內容上（右下角新增、側欄底部）加陰影
    @Environment(\.isEnabled) private var enabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .zText(.bodyStrong)
            .foregroundStyle(kind == .primary ? Color.zBg : Color.zText)
            .padding(.horizontal, 22)
            .frame(maxWidth: fill ? .infinity : nil)
            .frame(height: 48)
            .background(Capsule().fill(kind == .primary ? Color.zText : kind == .secondary ? Color.zHover : Color.zCard))
            .overlay { if kind == .outline { Capsule().stroke(Color.zLine) } }
            .shadow(color: floating ? Color.zShadow : .clear, radius: 10, y: 3)
            .contentShape(Capsule())
            .scaleEffect(configuration.isPressed && !Motion.reduce ? 0.97 : 1)
            .opacity(enabled ? 1 : 0.4)
            .animation(Motion.fast, value: configuration.isPressed)
    }
}

extension ButtonStyle where Self == CapsuleButtonStyle {
    static func capsule(_ kind: CapsuleButtonStyle.Kind = .primary, fill: Bool = false, floating: Bool = false) -> CapsuleButtonStyle {
        CapsuleButtonStyle(kind: kind, fill: fill, floating: floating)
    }
}

/// 篩選膠囊（分類、標籤）：選到是主文字色底＋反白字，沒選是淺灰底。字後面可帶一個數量
struct FilterChip: View {
    let title: String
    var count: Int? = nil
    let selected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Text(title).zText(.subheadlineStrong)
                if let count { Text("\(count)").zText(.subheadline).opacity(0.6) }
            }
            .foregroundStyle(selected ? Color.zBg : Color.zText)
            .padding(.horizontal, 14)
            .frame(height: 34)
            .background(Capsule().fill(selected ? Color.zText : Color.zHover))
            .padding(.vertical, 5)            // 觸控範圍補到 44
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .animation(Motion.fast, value: selected)
        .sensoryFeedback(.selection, trigger: selected)
    }
}

extension View {
    /// 浮在盤面上的膠囊（底部筆記入口這類）：浮起卡片色＋細框＋陰影，深色模式也分得出層次
    func zFloatingCapsule() -> some View {
        background(Capsule().fill(Color.zRaised))
            .overlay(Capsule().stroke(Color.zRaisedLine, lineWidth: 0.5))
            .shadow(color: Color.zShadow, radius: 12, y: 4)
    }
}

// MARK: - 彈出視窗（sheet）

extension View {
    /// 彈出視窗的導覽列，所有 sheet 一律用這個（不要各自寫 toolbar）：
    /// - 只看內容（筆記、條款、設定、我的）：只給 done → 右上「完成」
    /// - 要填寫（新增／編輯命盤、編輯筆記、反查、合盤）：cancel → 左上「取消」；done＋confirm 文字 → 右上主要動作
    /// - confirmEnabled = false 時字變淡但按得到（按了由呼叫端給錯誤震動，停用的按鈕按了沒反應不知道哪裡錯）
    /// - busy：主要動作進行中，換成轉圈
    /// 標題置中小字；底色與上下淡出由內容負責（ScrollView 用 zEdgeFades、表單用 ZForm）
    func zSheetBar(_ title: String? = nil, done: (() -> Void)? = nil, confirm: String = "完成", confirmEnabled: Bool = true,
                   busy: Bool = false, cancel: (() -> Void)? = nil) -> some View {
        modifier(SheetBar(title: title, done: done, confirm: confirm, confirmEnabled: confirmEnabled, busy: busy, cancel: cancel))
    }
}

private struct SheetBar: ViewModifier {
    let title: String?
    let done: (() -> Void)?
    let confirm: String
    let confirmEnabled: Bool
    let busy: Bool
    let cancel: (() -> Void)?

    func body(content: Content) -> some View {
        content
            .navigationTitle(title ?? "")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if let cancel {
                    ToolbarItem(placement: .cancellationAction) { Button("取消", action: cancel) }
                }
                if let done {
                    ToolbarItem(placement: .confirmationAction) {
                        if busy { ProgressView() }
                        else { Button(confirm, action: done).foregroundStyle(confirmEnabled ? Color.zText : Color.zText3) }
                    }
                }
            }
    }
}

