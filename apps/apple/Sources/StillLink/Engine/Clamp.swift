import Foundation

/// 夾宮：被選宮位的左右鄰宮（地支前後兩宮）各有一顆成對的星或四化，就是「被 OO 夾」
/// 鄰宮是空宮（沒有主星）時借對宮的星曜一起看（例：命宮空宮借遷移的地空，跟另一邊的地劫成空劫夾）
struct Clamp: Hashable {
    let name: String      // 左右夾、雙忌夾忌…
    let meaning: String
    let good: Bool        // 吉夾（綠）／凶夾（紅）
}

extension ZW {
    /// 對星夾：兩顆星分別在左右鄰宮
    private static let clampStarPairs: [(String, String, String, String, Bool)] = [
        ("紫微", "天府", "紫府夾", "尊貴", true),
        ("太陽", "太陰", "日月夾", "太陽太陰相夾，主名聲", true),
        ("文昌", "文曲", "昌曲夾", "文藝、藝術類", true),
        ("左輔", "右弼", "左右夾", "左輔右弼相夾，貴人幫襯", true),
        ("天魁", "天鉞", "魁鉞夾", "天魁天鉞相夾，長輩幫忙", true),
        ("火星", "鈴星", "火鈴夾", "爆發式憤怒、瞬間燒起來，突然很多人看見", false),
        ("地空", "地劫", "空劫夾", "虛無、反潮流、異於平常", false),
        ("擎羊", "陀羅", "羊陀夾", "被夾的宮位負面化（本宮有化忌）才會成立", false),
    ]

    /// 四化夾：兩邊各有一個四化（祿存也算祿）
    private static let clampMutagenPairs: [(String, String, String, String, Bool)] = [
        ("祿", "祿", "雙祿夾", "兩邊都是祿，資源、財源匯聚", true),
        ("權", "權", "雙權夾", "兩邊都是權，有實權、主導", true),
        ("科", "科", "雙科夾", "兩邊都是科，名聲、貴人", true),
        ("祿", "權", "祿權夾", "一邊祿一邊權，有資源也有掌控力", true),
        ("科", "權", "科權夾", "一邊科一邊權，有名望也有掌控力", true),
        ("忌", "忌", "雙忌夾", "被夾的宮位有雙化忌特質", false),
    ]

    /// 一組星有哪些四化：生年四化一定算；`level` ≥ 1 時再加上那一層運限的四化；祿存當成祿
    private static func clampMutagens(_ stars: [Star], horo: Horoscope, level: Int) -> Set<String> {
        var out = Set(stars.map(\.mutagen).filter { !$0.isEmpty })
        if level >= 1 {
            let list = horo.scope(level).mutagen
            for s in stars { if let m = mutagen(in: list, star: s.name) { out.insert(m.rawValue) } }
        }
        if stars.contains(where: { $0.name == "祿存" }) { out.insert("祿") }
        return out
    }

    /// 鄰宮拿來判斷夾的星：本宮的星；空宮（沒有主星）再加上對宮的星
    private static func clampStars(_ c: Chart, _ n: Int) -> (own: [Star], all: [Star], borrowedFrom: String?) {
        let p = c.palaces[n]
        guard p.major.isEmpty else { return (p.stars, p.stars, nil) }
        let opp = c.palaces[(n + 6) % 12]
        return (p.stars, p.stars + opp.stars, opp.name)
    }

    /// 被選宮位 `i` 被哪些組合夾（`level`：0＝只看生年四化，1–5＝再加上那一層的四化）
    static func clamps(_ c: Chart, horo: Horoscope, center i: Int, level: Int) -> [Clamp] {
        let na = (i + 11) % 12, nb = (i + 1) % 12
        let a = clampStars(c, na), b = clampStars(c, nb)
        let centerJi = clampMutagens(c.palaces[i].stars, horo: horo, level: level).contains("忌")
        // 只靠本宮的星就成立 → 不用註明；要借對宮才成立 → 說明裡寫是哪一宮借了哪一宮
        func note(_ needA: Bool, _ needB: Bool) -> String {
            var parts: [String] = []
            if needA, let f = a.borrowedFrom { parts.append("\(c.palaces[na].name)空宮，借對宮\(f)") }
            if needB, let f = b.borrowedFrom { parts.append("\(c.palaces[nb].name)空宮，借對宮\(f)") }
            return parts.isEmpty ? "" : "（" + parts.joined(separator: "；") + "）"
        }
        func check(_ x: String, _ y: String, sets: ([Star]) -> Set<String>) -> String? {
            let ao = sets(a.own), aa = sets(a.all), bo = sets(b.own), ba = sets(b.all)
            func hit(_ l: Set<String>, _ r: Set<String>) -> Bool { (l.contains(x) && r.contains(y)) || (l.contains(y) && r.contains(x)) }
            if hit(ao, bo) { return "" }
            if hit(aa, bo) { return note(true, false) }
            if hit(ao, ba) { return note(false, true) }
            if hit(aa, ba) { return note(true, true) }
            return nil
        }
        var out: [Clamp] = []
        for (x, y, name, meaning, good) in clampStarPairs {
            guard let n = check(x, y, sets: { Set($0.map(\.name)) }) else { continue }
            if name == "羊陀夾" && !centerJi { continue }
            out.append(Clamp(name: name, meaning: meaning + n, good: good))
        }
        for (x, y, name, meaning, good) in clampMutagenPairs {
            guard let n = check(x, y, sets: { clampMutagens($0, horo: horo, level: level) }) else { continue }
            if name == "雙忌夾" && centerJi {
                out.append(Clamp(name: "雙忌夾忌", meaning: "等同被夾的宮位有三個忌" + n, good: false))
            } else {
                out.append(Clamp(name: name, meaning: meaning + n, good: good))
            }
        }
        return out
    }
}
