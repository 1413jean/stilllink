import AppKit

/// 回報問題：把版本、系統、螢幕、設定整理成一段文字複製到剪貼簿，讓使用者貼到 LINE 傳給 Jean
/// 不上傳任何東西，也不含命盤內容（只有張數）
@MainActor
enum BugReport {
    static func run(store: Store) {
        let text = report(store: store)
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)

        let alert = NSAlert()
        alert.messageText = "已複製問題回報資訊"
        alert.informativeText = """
        請貼到 LINE 傳給 Jean，並附上一張截圖：
        按 ⌘⇧4，再按空白鍵，點一下 StillLink 視窗就會存到桌面。

        回報內容只有版本、系統、螢幕和顯示設定，不含任何命盤資料。
        """
        alert.addButton(withTitle: "好")
        alert.runModal()
    }

    static func report(store: Store) -> String {
        let os = ProcessInfo.processInfo.operatingSystemVersion
        let win = NSApp.keyWindow ?? NSApp.windows.first { $0.isVisible }
        var lines = [
            "【StillLink 問題回報】",
            "App：\(AppInfo.name) \(AppInfo.version)（build \(AppInfo.build)）",
            "macOS：\(os.majorVersion).\(os.minorVersion).\(os.patchVersion)",
            "機型：\(sysctl("hw.model"))　晶片：\(sysctl("machdep.cpu.brand_string"))",
            "外觀：設定＝\(store.appearance.label)，目前＝\(win?.effectiveAppearance.name.rawValue ?? "?")",
        ]
        if let win {
            lines.append("視窗：\(Int(win.frame.width))×\(Int(win.frame.height))，倍率 \(win.backingScaleFactor)x")
        }
        // 每台螢幕的解析度與倍率（1x 螢幕最常出現細線、殘點這類顯示問題）
        for (i, s) in NSScreen.screens.enumerated() {
            let here = win?.screen == s ? "（StillLink 在這台）" : ""
            lines.append("螢幕 \(i + 1)：\(s.localizedName) \(Int(s.frame.width))×\(Int(s.frame.height))，倍率 \(s.backingScaleFactor)x\(here)")
        }
        lines.append("命盤：\(store.people.count) 張")
        if let data = try? JSONEncoder().encode(store.settings), let json = String(data: data, encoding: .utf8) {
            lines.append("設定：\(json)")
        }
        return lines.joined(separator: "\n")
    }

    private static func sysctl(_ name: String) -> String {
        var size = 0
        guard sysctlbyname(name, nil, &size, nil, 0) == 0, size > 0 else { return "?" }
        var buf = [CChar](repeating: 0, count: size)
        guard sysctlbyname(name, &buf, &size, nil, 0) == 0 else { return "?" }
        return String(cString: buf)
    }
}
