import AppKit
import SwiftUI

/// 切換淺色／深色的過場：先把視窗拍成快照蓋在最上層，換好顏色後讓快照淡出（交叉淡化）
@MainActor
enum ThemeTransition {
    static func change(_ apply: () -> Void) {
        guard !Motion.reduce,
              let win = NSApp.keyWindow ?? NSApp.windows.first(where: { $0.isVisible }),
              let view = win.contentView,
              let rep = view.bitmapImageRepForCachingDisplay(in: view.bounds) else { apply(); return }
        view.cacheDisplay(in: view.bounds, to: rep)
        let image = NSImage(size: view.bounds.size)
        image.addRepresentation(rep)
        let cover = NSImageView(frame: view.bounds)
        cover.image = image
        cover.imageScaling = .scaleAxesIndependently
        cover.autoresizingMask = [.width, .height]
        cover.wantsLayer = true
        view.addSubview(cover, positioned: .above, relativeTo: nil)
        apply()
        // 等新顏色畫好再開始淡出
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.03) {
            NSAnimationContext.runAnimationGroup({ ctx in
                ctx.duration = 0.35
                ctx.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
                cover.animator().alphaValue = 0
            }, completionHandler: { cover.removeFromSuperview() })
        }
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
