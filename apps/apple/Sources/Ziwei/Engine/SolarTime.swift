import Foundation

/// 真太陽時：鐘錶時間 → UTC → 加上經度時差（每度 4 分鐘）→ 加上均時差
enum SolarTime {
    struct Result {
        let date: Date          // 真太陽時（以 UTC 曆法欄位表示）
        let ymd: (Int, Int, Int)
        let hm: (Int, Int)
        let shichen: Int        // 0 早子 … 12 晚子
    }

    /// clock：出生地的鐘錶時間欄位；tz：出生地時區（自動處理當年的夏令時間）
    static func compute(year: Int, month: Int, day: Int, hour: Int, minute: Int, longitude: Double, tz: TimeZone) -> Result {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = tz
        let local = cal.date(from: DateComponents(year: year, month: month, day: day, hour: hour, minute: minute))!
        // local 已是絕對時間；真太陽時 = UTC + 經度/15 小時 + 均時差
        let n = Double(cal.ordinality(of: .day, in: .year, for: local) ?? 1)
        let b = 2 * Double.pi * (n - 81) / 364
        let eot = 9.87 * sin(2 * b) - 7.53 * cos(b) - 1.5 * sin(b) // 分鐘
        let solar = local.addingTimeInterval((longitude * 4 + eot) * 60)
        var utc = Calendar(identifier: .gregorian)
        utc.timeZone = TimeZone(identifier: "UTC")!
        let c = utc.dateComponents([.year, .month, .day, .hour, .minute], from: solar)
        return Result(date: solar, ymd: (c.year!, c.month!, c.day!), hm: (c.hour!, c.minute!), shichen: shichen(c.hour!))
    }

    /// iztro 的時辰序號：0 早子(00–01)、1 丑(01–03)… 11 亥(21–23)、12 晚子(23–24)
    static func shichen(_ h: Int) -> Int { h == 23 ? 12 : (h + 1) / 2 }
}
