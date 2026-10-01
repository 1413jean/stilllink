import Foundation

/// 效能量測（驗證用）：ZIWEI_BENCH=/path.txt 時量排盤各步驟耗時，寫入檔案後結束
enum Bench {
    static func runIfRequested() {
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
            try? lines.joined(separator: "\n").write(toFile: path, atomically: true, encoding: .utf8)
            exit(0)
        }
    }
}
