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
        Task.detached {
            var lines: [String] = []
            func ms(_ t0: Date) -> String { String(format: "%.1fms", Date().timeIntervalSince(t0) * 1000) }
            let p = Person(name: "測", gender: .female, solar: "1990-6-15", hour: 6, group: "x")
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
