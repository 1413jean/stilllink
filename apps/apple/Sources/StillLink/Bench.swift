import Foundation
import SwiftUI

/// 效能量測（驗證用）：ZIWEI_BENCH=/path.txt 時量排盤各步驟耗時，寫入檔案後結束
enum Bench {
    static func runIfRequested() {
        // 頭貼裁切自測：ZIWEI_AVATAR_TEST=<圖片>，以縮放 1.5、偏移 (40, -20) 裁切後回報結果
        if let img = ProcessInfo.processInfo.environment["ZIWEI_AVATAR_TEST"], let out = ProcessInfo.processInfo.environment["ZIWEI_BENCH"],
           let image = NSImage(contentsOfFile: img) {
            let name = AvatarStore.save(image, crop: CropState(scale: 1.5, offset: CGSize(width: 40, height: -20)), viewport: 280)
            let url = name.map(Media.url)
            let attrs = url.flatMap { try? FileManager.default.attributesOfItem(atPath: $0.path) }
            let rep = url.flatMap { NSImage(contentsOf: $0) }?.representations.first
            let line = "avatar \(name ?? "nil") \(rep?.pixelsWide ?? 0)x\(rep?.pixelsHigh ?? 0) \((attrs?[.size] as? Int) ?? 0) bytes\n\(url?.path ?? "")"
            try? line.write(toFile: out, atomically: true, encoding: .utf8)
            exit(0)
        }
        guard let path = ProcessInfo.processInfo.environment["ZIWEI_BENCH"] else { return }
        // 盤面重畫自測：ZIWEI_REDRAW_BENCH=1 → 反覆切換「三方四正連線」，量整張盤重新排版＋繪製花多久
        if ProcessInfo.processInfo.environment["ZIWEI_REDRAW_BENCH"] != nil {
            DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
                MainActor.assumeIsolated {
                    guard let store = Store.current, let win = NSApp.windows.first(where: { $0.isVisible }), let view = win.contentView else { return }
                    var times: [Double] = []
                    for _ in 0..<10 {
                        let t = Date()
                        store.settings.showSanfang.toggle()
                        RunLoop.main.run(until: Date().addingTimeInterval(0.001))
                        view.layoutSubtreeIfNeeded(); view.displayIfNeeded()
                        times.append(Date().timeIntervalSince(t) * 1000)
                    }
                    let sorted = times.sorted()
                    let line = String(format: "redraw x10  median %.0fms  min %.0fms  max %.0fms", sorted[5], sorted[0], sorted[9])
                    try? line.write(toFile: path, atomically: true, encoding: .utf8)
                    exit(0)
                }
            }
            return
        }
        // 切換外觀自測：ZIWEI_THEME_BENCH=1 → 量快照與換色重畫各花多久
        if ProcessInfo.processInfo.environment["ZIWEI_THEME_BENCH"] != nil {
            DispatchQueue.main.asyncAfter(deadline: .now() + 4) {
                MainActor.assumeIsolated {
                    guard let store = Store.current, let win = NSApp.windows.first(where: { $0.isVisible }), let view = win.contentView else { return }
                    var lines: [String] = []
                    func ms(_ t: Date) -> String { String(format: "%.0fms", Date().timeIntervalSince(t) * 1000) }
                    for next in [Appearance.dark, .light, .dark, .light] {
                        var t = Date()
                        _ = view
                        var applied = false
                        ThemeTransition.change { store.appearance = next; applied = true }
                        let snap = ms(t) + (applied ? "" : "?")
                        t = Date()
                        RunLoop.main.run(until: Date().addingTimeInterval(0.001))
                        view.layoutSubtreeIfNeeded(); view.displayIfNeeded()
                        lines.append("→\(next.rawValue)  轉場準備 \(snap)  換色重畫 \(ms(t))")
                    }
                    try? lines.joined(separator: "\n").write(toFile: path, atomically: true, encoding: .utf8)
                    exit(0)
                }
            }
            return
        }
        // 備份自測：ZIWEI_BACKUP_TEST=1（務必搭配 ZIWEI_DATA_DIR）→ 備份、清空、還原，回報前後是否一致
        if ProcessInfo.processInfo.environment["ZIWEI_BACKUP_TEST"] != nil, ProcessInfo.processInfo.environment["ZIWEI_DATA_DIR"] != nil {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                MainActor.assumeIsolated {
                    guard let store = Store.current else { return }
                    let before = store.people.map(\.name), name = store.userName
                    let data = (try? store.makeBackup()) ?? Data()
                    store.eraseAll()
                    let erased = store.people.count
                    try? store.restore(data)
                    let after = store.people.map(\.name)
                    let line = "before \(before) name \(name)\nerased \(erased)\nafter \(after) name \(store.userName)\nmatch \(before == after && name == store.userName) bytes \(data.count)"
                    try? line.write(toFile: path, atomically: true, encoding: .utf8)
                    exit(0)
                }
            }
            return
        }
        // 亂數起盤年份自測：ZIWEI_YEARS_TEST=1 時，排西元 1～9999 年的極端年份並回報命宮主星與四柱
        if ProcessInfo.processInfo.environment["ZIWEI_YEARS_TEST"] != nil {
            Task.detached {
                var lines: [String] = []
                for (y, m, d, h) in [(1, 1, 1, 0), (1, 6, 15, 13), (100, 3, 3, 7), (1582, 10, 10, 9), (1899, 12, 31, 23),
                                     (2026, 10, 2, 10), (5000, 7, 7, 5), (9999, 12, 28, 22)] {
                    let p = TempChart.make(y, m, d, h, 0, .male, name: "匿名")
                    let c = await Engine.shared.chart(for: p)
                    let mdl = await Engine.shared.model(for: p, pick: Pick.today())
                    let bazi = BaziInfo(person: p, chart: c)
                    lines.append("\(p.solar) → \(c.solarDate) | \(c.lunarDate) \(c.time) | 四柱 \(bazi.pillars.joined(separator: " ")) | model \(mdl == nil ? "nil" : "ok")")
                }
                try? lines.joined(separator: "\n").write(toFile: path, atomically: true, encoding: .utf8)
                exit(0)
            }
            return
        }
        Task.detached {
            var lines: [String] = []
            func ms(_ t0: Date) -> String { String(format: "%.1fms", Date().timeIntervalSince(t0) * 1000) }
            let p = Person(name: "測", gender: .female, solar: "2000-1-1", hour: 0, group: "x")
            var t = Date(); _ = await Engine.shared.chart(for: p); lines.append("首次排盤 \(ms(t))")
            t = Date(); _ = await Engine.shared.model(for: p, pick: Pick.today()); lines.append("首次 model（含運限）\(ms(t))")
            t = Date()
            for y in 2020..<2030 { for m in [1, 5, 9] {
                _ = await Engine.shared.model(for: p, pick: Pick(level: 3, year: y, lm: m, ld: 1, hour: 0))
            } }
            lines.append("30 次不同運限 model 平均 \(String(format: "%.2fms", Date().timeIntervalSince(t) * 1000 / 30))")
            t = Date(); for _ in 0..<1000 { _ = Lunar.toLunar(2026, 10, 1) }; lines.append("Lunar 1000 次 \(ms(t))")
            let c = await Engine.shared.chart(for: p)
            t = Date(); for _ in 0..<100 { _ = BaziInfo(person: p, chart: c) }; lines.append("BaziInfo 100 次 \(ms(t))")
            // 盤面繪製（ImageRenderer 離屏畫一張完整盤面，含排版）
            var models: [ChartModel] = []
            for (lv, y) in [(1, 2026), (2, 2026), (2, 2027), (3, 2027), (5, 2028)] {
                if let m = await Engine.shared.model(for: p, pick: Pick(level: lv, year: y, lm: 3, ld: 5, hour: 4)) { models.append(m) }
            }
            let built = models
            let renderLines: [String] = await MainActor.run {
                var out: [String] = []
                for (k, m) in built.enumerated() {
                    let view = ChartBoard(person: p, model: m, level: [1, 2, 2, 3, 5][k])
                        .frame(width: 760, height: 806)
                        .environment(\.zSettings, ZSettings())
                    let r = ImageRenderer(content: view)
                    let t0 = Date()
                    _ = r.nsImage
                    out.append("繪製盤面 level \([1, 2, 2, 3, 5][k]) \(String(format: "%.1fms", Date().timeIntervalSince(t0) * 1000))")
                }
                return out
            }
            lines += renderLines
            try? lines.joined(separator: "\n").write(toFile: path, atomically: true, encoding: .utf8)
            exit(0)
        }
    }
}
