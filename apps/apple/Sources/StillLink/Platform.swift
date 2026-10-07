import SwiftUI
#if os(macOS)
import AppKit
typealias PlatformFont = NSFont
#else
import UIKit
typealias PlatformFont = UIFont
#endif

/// Mac／iOS 共用檔案裡不一樣的地方集中在這裡，其他檔案不用到處寫 #if
enum Platform {
    /// 系統「減少動態效果」
    static var reduceMotion: Bool {
        #if os(macOS)
        NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
        #else
        UIAccessibility.isReduceMotionEnabled
        #endif
    }

    /// 判斷「點兩下」的間隔（Mac 跟著系統設定；iPhone 沒有這個設定，用 UIKit 預設的 0.35 秒）
    static var doubleTapInterval: TimeInterval {
        #if os(macOS)
        NSEvent.doubleClickInterval
        #else
        0.35
        #endif
    }

    enum Haptic { case alignment, levelChange }
    /// 觸控板（Mac）／Taptic Engine（iPhone）回饋
    @MainActor static func haptic(_ h: Haptic) {
        #if os(macOS)
        NSHapticFeedbackManager.defaultPerformer.perform(h == .alignment ? .alignment : .levelChange, performanceTime: .now)
        #else
        switch h {
        case .alignment: UISelectionFeedbackGenerator().selectionChanged()
        case .levelChange: UIImpactFeedbackGenerator(style: .light).impactOccurred()
        }
        #endif
    }
}
