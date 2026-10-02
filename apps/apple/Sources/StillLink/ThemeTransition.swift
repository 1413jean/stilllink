import AppKit
import QuartzCore
import SwiftUI

/// 切換淺色／深色的過場：用 Core Animation 的淡化轉場（由顯示卡處理，不用另外拍快照，切換不會多卡一下）
@MainActor
enum ThemeTransition {
    static func change(_ apply: () -> Void) {
        guard !Motion.reduce,
              let win = NSApp.keyWindow ?? NSApp.windows.first(where: { $0.isVisible }),
              let layer = win.contentView?.superview?.layer ?? win.contentView?.layer else { apply(); return }
        let fade = CATransition()
        fade.type = .fade
        fade.duration = 0.35
        fade.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        layer.add(fade, forKey: "themeFade")
        apply()
    }
}

extension Store {
    /// 給外觀選單用的 binding：切換時帶過場動畫
    var appearanceWithTransition: Binding<Appearance> {
        Binding(get: { self.appearance }, set: { new in
            guard new != self.appearance else { return }
            ThemeTransition.change { self.appearance = new }
        })
    }
}
