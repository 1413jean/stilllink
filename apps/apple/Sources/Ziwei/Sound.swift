import AppKit

/// 介面音效（uisfx.com，CC0）：點宮位、點運限時播放；設定裡可關、可選風格與音量
enum Sound {
    static let styles: [(id: String, name: String)] = [
        ("minimal", "極簡"), ("soft", "柔和"), ("glass", "玻璃"), ("organic", "木質"),
        ("zen", "禪"), ("studio", "錄音室"), ("mechanical", "機械"),
    ]

    private static var cache: [String: NSSound] = [:]

    static func url(_ style: String) -> URL? {
        if let u = Bundle.main.url(forResource: style, withExtension: "mp3", subdirectory: "sfx") { return u }
        return Engine.resource("sfx/\(style)", "mp3")
    }

    /// 播放目前設定的點擊音
    static func tap(_ s: ZSettings) {
        guard s.sound else { return }
        play(s.soundStyle, volume: s.volume)
    }

    static func play(_ style: String, volume: Double) {
        guard let u = url(style) else { return }
        let snd = cache[style] ?? NSSound(contentsOf: u, byReference: true)
        guard let snd else { return }
        cache[style] = snd
        snd.stop()
        snd.volume = Float(volume)
        snd.play()
    }
}
