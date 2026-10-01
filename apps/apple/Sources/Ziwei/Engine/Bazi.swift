import Foundation

/// 八字：非節氣四柱、子斗、起運、大運與十神（中宮顯示用）
enum Bazi {
    // MARK: 太陽黃經（Meeus 低精度公式，誤差約數分鐘，足夠算起運）

    static func julianDay(_ d: Date) -> Double { d.timeIntervalSince1970 / 86400 + 2440587.5 }

    static func sunLongitude(_ d: Date) -> Double {
        let t = (julianDay(d) - 2451545) / 36525
        let l0 = 280.46646 + 36000.76983 * t + 0.0003032 * t * t
        let m = (357.52911 + 35999.05029 * t - 0.0001537 * t * t) * .pi / 180
        let c = (1.914602 - 0.004817 * t - 0.000014 * t * t) * sin(m) + (0.019993 - 0.000101 * t) * sin(2 * m) + 0.000289 * sin(3 * m)
        let omega = (125.04 - 1934.136 * t) * .pi / 180
        let lambda = l0 + c - 0.00569 - 0.00478 * sin(omega)
        return (lambda.truncatingRemainder(dividingBy: 360) + 360).truncatingRemainder(dividingBy: 360)
    }

    /// 十二「節」的太陽黃經：小寒 285、立春 315、驚蟄 345、清明 15 …（每 30°）
    private static func isJieBoundary(_ a: Double, _ b: Double) -> Bool {
        // a→b 期間跨過 (15 + 30k) 度
        let ka = floor((a - 15 + 360).truncatingRemainder(dividingBy: 360) / 30)
        let kb = floor((b - 15 + 360).truncatingRemainder(dividingBy: 360) / 30)
        return ka != kb
    }

    /// 從 birth 往前或往後找最近的「節」交節時刻
    static func nearestJie(from birth: Date, forward: Bool) -> Date {
        let step: Double = forward ? 3600 * 6 : -3600 * 6
        var a = birth, la = sunLongitude(a)
        for _ in 0..<(4 * 40) {
            let b = a.addingTimeInterval(step), lb = sunLongitude(b)
            if isJieBoundary(forward ? la : lb, forward ? lb : la) {
                // 二分逼近到一分鐘內
                var lo = forward ? a : b, hi = forward ? b : a
                for _ in 0..<20 {
                    let mid = Date(timeIntervalSince1970: (lo.timeIntervalSince1970 + hi.timeIntervalSince1970) / 2)
                    if isJieBoundary(sunLongitude(lo), sunLongitude(mid)) { hi = mid } else { lo = mid }
                }
                return hi
            }
            a = b; la = lb
        }
        return birth
    }

    // MARK: 起運與大運

    struct Qiyun { let years: Int; let months: Int; let days: Int; let forward: Bool }

    /// 陽男陰女順行、陰男陽女逆行；三天折一年、一天折四個月、一個時辰折十天
    static func qiyun(birth: Date, yearStem: String, male: Bool) -> Qiyun {
        let yang = ["甲", "丙", "戊", "庚", "壬"].contains(yearStem)
        let forward = yang == male
        let jie = nearestJie(from: birth, forward: forward)
        let minutes = abs(jie.timeIntervalSince(birth)) / 60
        let years = Int(minutes / 4320)
        let r1 = minutes - Double(years) * 4320
        let months = Int(r1 / 360)
        let days = Int((r1 - Double(months) * 360) / 12)
        return Qiyun(years: years, months: months, days: days, forward: forward)
    }

    /// 由月柱往前或往後推八步大運
    static func dayun(monthPillar: String, forward: Bool, count: Int = 8) -> [String] {
        let s = ZW.stems.firstIndex(of: String(monthPillar.prefix(1))) ?? 0
        let b = ZW.branches.firstIndex(of: String(monthPillar.suffix(1))) ?? 0
        return (1...count).map { k in
            let d = forward ? k : -k
            return ZW.stems[((s + d) % 10 + 10) % 10] + ZW.branches[((b + d) % 12 + 12) % 12]
        }
    }

    // MARK: 十神

    private static let element: [String: Int] = [
        "甲": 0, "乙": 0, "丙": 1, "丁": 1, "戊": 2, "己": 2, "庚": 3, "辛": 3, "壬": 4, "癸": 4,
    ]

    /// 以日干為我，看另一個天干是哪個十神
    static func tenGod(day: String, other: String) -> String {
        guard let d = element[day], let o = element[other],
              let di = ZW.stems.firstIndex(of: day), let oi = ZW.stems.firstIndex(of: other) else { return "" }
        let same = di % 2 == oi % 2
        switch (o - d + 5) % 5 {
        case 0: return same ? "比肩" : "劫財"
        case 1: return same ? "食神" : "傷官"   // 我生
        case 2: return same ? "偏財" : "正財"   // 我剋
        case 3: return same ? "七殺" : "正官"   // 剋我
        default: return same ? "偏印" : "正印"  // 生我
        }
    }

    // MARK: 非節氣四柱、子斗

    /// 非節氣四柱：年柱用農曆年、月柱用農曆月（五虎遁），日時同節氣四柱
    static func lunarPillars(lunarYear: Int, lunarMonth: Int, jieqi: [String]) -> [String] {
        guard jieqi.count == 4 else { return jieqi }
        return [ZW.yearGanzhi(lunarYear), ZW.monthGanzhi(lunarYear: lunarYear, month: lunarMonth), jieqi[2], jieqi[3]]
    }

    /// 子斗（子年斗君）：從子宮起正月逆數到生月，再順數到生時
    static func ziDou(lunarMonth: Int, hourBranch: Int) -> String {
        ZW.branches[((0 - (lunarMonth - 1) + hourBranch) % 12 + 12) % 12]
    }
}

// MARK: 四柱反查
extension Bazi {
    struct Match: Identifiable, Hashable { let id = UUID(); let date: Date; let y: Int; let m: Int; let d: Int; let hour: Int }

    /// 某一刻的節氣四柱（年以立春、月以節為界；子時起換日不處理，視晚子為次日）
    static func pillars(at date: Date, tz: TimeZone) -> [String] {
        var cal = Calendar(identifier: .gregorian); cal.timeZone = tz
        let c = cal.dateComponents([.year, .month, .day, .hour], from: date)
        let lon = sunLongitude(date)
        // 月支：寅月從立春 315° 起，每 30° 一支
        let mi = Int(((lon - 315 + 360).truncatingRemainder(dividingBy: 360)) / 30)   // 0＝寅
        // 年：立春（315°）前算前一年；1–2 月且還沒到立春
        var y = c.year!
        if c.month! <= 2 && lon > 250 && lon < 315 { y -= 1 }
        let yIdx = ((y - 4) % 60 + 60) % 60
        let yearGZ = ZW.ganzhi(yIdx)
        let firstMonthStem = ((yIdx % 10) % 5) * 2 + 2
        let monthGZ = ZW.stems[(firstMonthStem + mi) % 10] + ZW.branches[(mi + 2) % 12]
        var dayJ = jdn(c.year!, c.month!, c.day!)
        if c.hour! == 23 { dayJ += 1 }
        let dIdx = ZW.dayIndex(jdn: dayJ)
        let hb = ((c.hour! + 1) / 2) % 12
        let hourGZ = ZW.hourGanzhi(dayStem: dIdx % 10, hour: hb)
        return [yearGZ, monthGZ, ZW.ganzhi(dIdx), hourGZ]
    }

    private static func jdn(_ y: Int, _ m: Int, _ d: Int) -> Int { ZW.jdn(y, m, d) }

    /// 找出 1900–2100 年內符合四柱的時刻（取該時辰的中間點）
    static func search(_ target: [String], tz: TimeZone = TimeZone(identifier: "Asia/Taipei")!) -> [Match] {
        guard target.count == 4, let dTarget = (0..<60).first(where: { ZW.ganzhi($0) == target[2] }),
              let hb = ZW.branches.firstIndex(of: String(target[3].suffix(1))) else { return [] }
        var cal = Calendar(identifier: .gregorian); cal.timeZone = tz
        var out: [Match] = []
        var j = ZW.jdn(1900, 1, 1)
        while ZW.dayIndex(jdn: j) != dTarget { j += 1 }
        let end = ZW.jdn(2100, 12, 31)
        while j <= end {
            // 儒略日 → 國曆
            let a = j + 32044, b = (4 * a + 3) / 146097, c = a - 146097 * b / 4
            let d = (4 * c + 3) / 1461, e = c - 1461 * d / 4, m = (5 * e + 2) / 153
            let day = e - (153 * m + 2) / 5 + 1, month = m + 3 - 12 * (m / 10), year = 100 * b + d - 4800 + m / 10
            let hour = hb == 0 ? 0 : hb * 2
            if let date = cal.date(from: DateComponents(year: year, month: month, day: day, hour: hour, minute: hb == 0 ? 30 : 0)),
               pillars(at: date, tz: tz) == target {
                out.append(Match(date: date, y: year, m: month, d: day, hour: hour))
            }
            j += 60
        }
        return out
    }
}

/// 中宮要顯示的八字資訊：背景算好一次，畫面直接取用
struct BaziInfo {
    let pillars: [String]
    let lunarPillars: [String]
    let dayStem: String
    let ziDou: String
    let qiyun: Bazi.Qiyun
    let dayun: [String]
    let birthYear: Int

    init(person p: Person, chart: Chart) {
        pillars = chart.chineseDate.split(separator: " ").map(String.init)
        lunarPillars = Bazi.lunarPillars(lunarYear: chart.lunarYear, lunarMonth: chart.lunarMonth, jieqi: pillars)
        dayStem = String(pillars.count > 2 ? pillars[2].prefix(1) : "")
        ziDou = Bazi.ziDou(lunarMonth: chart.lunarMonth, hourBranch: p.hour == 12 ? 0 : p.hour)
        // 出生的絕對時間：有鐘錶時間＋出生地就照用，否則以時辰起點、台北時區估算
        let tz = TimeZone(identifier: p.place?.timeZoneID ?? "Asia/Taipei") ?? .current
        var cal = Calendar(identifier: .gregorian); cal.timeZone = tz
        let src = p.clock ?? "\(p.solar) \(p.hour == 12 ? 23 : p.hour * 2):00"
        let n = src.split(whereSeparator: { " -:".contains($0) }).compactMap { Int($0) }
        let birth = n.count >= 5 ? cal.date(from: DateComponents(year: n[0], month: n[1], day: n[2], hour: n[3], minute: n[4])) ?? Date() : Date()
        birthYear = n.first ?? p.birthYear
        qiyun = Bazi.qiyun(birth: birth, yearStem: String(pillars.first?.prefix(1) ?? ""), male: p.gender == .male)
        dayun = Bazi.dayun(monthPillar: pillars.count > 1 ? pillars[1] : "", forward: qiyun.forward)
    }
}
