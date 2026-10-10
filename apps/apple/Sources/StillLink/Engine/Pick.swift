import Foundation

/// 運限選擇（預設大限）：level 0 本命、1 大限、2 流年、3 流月、4 流日、5 流時；年月日都是農曆
struct Pick: Equatable, Hashable {
    var level = 1
    var year: Int
    var lm: Int
    var ld: Int
    var hour: Int

    static func today() -> Pick {
        let c = Calendar.current.dateComponents([.year, .month, .day, .hour], from: Date())
        let l = Lunar.toLunar(c.year!, c.month!, c.day!)
        return Pick(year: l.year, lm: l.month, ld: l.day, hour: SolarTime.shichen(c.hour!) % 12)
    }
}
