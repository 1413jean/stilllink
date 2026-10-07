import Foundation
#if os(macOS)
import AppKit
typealias PlatformSound = NSSound
#else
import AVFoundation
typealias PlatformSound = AVAudioPlayer
#endif

/// 介面回饋：音效（uisfx.com，CC0）＋觸控板震動。每種操作可以各自選音效。
enum Sound {
    static let styles: [(id: String, name: String)] = [
        ("minimal", "極簡"), ("soft", "柔和"), ("glass", "玻璃"), ("organic", "木質"),
        ("zen", "禪"), ("studio", "錄音室"), ("mechanical", "機械"),
    ]
    static let cues: [(id: String, name: String)] = [
        ("select", "選取"), ("press", "按壓"), ("snap", "扣合"), ("check", "勾選"),
        ("progress-step", "前進"), ("focus", "聚焦"), ("expand", "展開"), ("swipe", "滑動"), ("none", "無聲"),
    ]

    /// 會發出聲音的操作
    enum Event: String, CaseIterable, Codable {
        case palace, decade, year, month, day, hour
        var label: String {
            switch self {
            case .palace: "點宮位"; case .decade: "大限"; case .year: "流年"
            case .month: "流月"; case .day: "流日"; case .hour: "流時"
            }
        }
        var defaultCue: String {
            switch self {
            case .palace: "select"; case .decade: "snap"; case .year: "press"
            case .month: "progress-step"; case .day: "check"; case .hour: "focus"
            }
        }
        /// 運限層級（1 大限 … 5 流時）
        static func level(_ lv: Int) -> Event { [.decade, .decade, .year, .month, .day, .hour][max(0, min(5, lv))] }
    }

    private static var cache: [String: PlatformSound] = [:]

    static func url(_ style: String, _ cue: String) -> URL? {
        if let u = Bundle.main.url(forResource: cue, withExtension: "mp3", subdirectory: "sfx/\(style)") { return u }
        return Engine.resource("sfx/\(style)/\(cue)", "mp3")
    }

    /// 播放某個操作的音效＋觸控板回饋
    @MainActor static func tap(_ s: ZSettings, _ e: Event = .palace) {
        if s.haptics { Platform.haptic(e == .palace ? .alignment : .levelChange) }
        guard s.sound else { return }
        play(s.soundStyle, s.cues[e.rawValue] ?? e.defaultCue, volume: s.volume)
    }

    static func play(_ style: String, _ cue: String, volume: Double) {
        guard cue != "none", let u = url(style, cue) else { return }
        let key = style + "/" + cue
        #if os(macOS)
        let snd = cache[key] ?? NSSound(contentsOf: u, byReference: true)
        guard let snd else { return }
        cache[key] = snd
        snd.stop()
        #else
        // 跟靜音開關走（.ambient），不會打斷使用者正在聽的音樂
        try? AVAudioSession.sharedInstance().setCategory(.ambient, options: .mixWithOthers)
        let snd = cache[key] ?? (try? AVAudioPlayer(contentsOf: u))
        guard let snd else { return }
        cache[key] = snd
        snd.stop()
        snd.currentTime = 0
        #endif
        snd.volume = Float(volume)
        snd.play()
    }
}
