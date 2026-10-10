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

    /// success／error：儲存完成、出錯（iPhone 是系統的成功、錯誤震動）
    enum Haptic { case alignment, levelChange, success, error }
    /// 觸控板（Mac）／Taptic Engine（iPhone）回饋；設定裡關掉「震動」就不震
    @MainActor static func haptic(_ h: Haptic) {
        if Store.current?.settings.haptics == false { return }
        #if os(macOS)
        NSHapticFeedbackManager.defaultPerformer.perform(h == .alignment ? .alignment : .levelChange, performanceTime: .now)
        #else
        // 產生器重複用、震完就 prepare 下一次（每次 new 一個，Taptic Engine 要暖機，會慢半拍）
        switch h {
        case .alignment: Feedback.select.selectionChanged(); Feedback.select.prepare()
        case .levelChange: Feedback.impact.impactOccurred(); Feedback.impact.prepare()
        case .success: Feedback.notify.notificationOccurred(.success)
        case .error: Feedback.notify.notificationOccurred(.error)
        }
        #endif
    }

    #if os(iOS)
    @MainActor private enum Feedback {
        static let select = UISelectionFeedbackGenerator()
        static let impact = UIImpactFeedbackGenerator(style: .light)
        static let notify = UINotificationFeedbackGenerator()
    }
    #endif
}
