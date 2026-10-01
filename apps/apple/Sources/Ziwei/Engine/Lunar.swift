import Foundation

/// 國曆↔農曆：用系統內建的農曆曆法（不經過 JS，主執行緒直接算，約 2µs）
enum Lunar {
    private static let tz = TimeZone(identifier: "Asia/Taipei")!
    private static let greg: Calendar = { var c = Calendar(identifier: .gregorian); c.timeZone = tz; return c }()
    private static let chinese: Calendar = { var c = Calendar(identifier: .chinese); c.timeZone = tz; return c }()

    /// 農曆年（西元）→ 系統農曆的 era／year（六十甲子循環）
    private static func eraYear(_ y: Int) -> (Int, Int) {
        let n = y + 2697
        let yr = n % 60
        return yr == 0 ? (n / 60 - 1, 60) : (n / 60, yr)
    }

    static func toLunar(_ y: Int, _ m: Int, _ d: Int) -> LunarDate {
        let date = greg.date(from: DateComponents(year: y, month: m, day: d, hour: 12))!
        let c = chinese.dateComponents([.era, .year, .month, .day], from: date)
        return LunarDate(year: c.era! * 60 + c.year! - 2697, month: c.month!, day: c.day!)
    }

    /// 農曆 → 國曆 (y, m, d)；這個月沒有那一天時回傳 nil
    static func toSolar(_ y: Int, _ m: Int, _ d: Int, leap: Bool = false) -> (Int, Int, Int)? {
        let (era, yr) = eraYear(y)
        var k = DateComponents(era: era, year: yr, month: m, day: d, hour: 12)
        k.isLeapMonth = leap
        guard let date = chinese.date(from: k) else { return nil }
        let back = chinese.dateComponents([.month, .day], from: date)
        guard back.month == m, back.day == d else { return nil }
        let g = greg.dateComponents([.year, .month, .day], from: date)
        return (g.year!, g.month!, g.day!)
    }

    /// 這個農曆月有幾天（29 或 30）
    static func monthLength(_ y: Int, _ m: Int) -> Int { toSolar(y, m, 30) == nil ? 29 : 30 }

    static func solarString(_ y: Int, _ m: Int, _ d: Int, leap: Bool = false) -> String? {
        toSolar(y, m, d, leap: leap).map { "\($0.0)-\($0.1)-\($0.2)" }
    }
}
