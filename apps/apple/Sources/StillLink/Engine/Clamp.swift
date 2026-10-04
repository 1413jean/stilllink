import Foundation

/// 夾宮：被選宮位的左右鄰宮（地支前後兩宮）各有一顆成對的星或四化，就是「被 OO 夾」
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

    /// 某一宮有哪些四化：生年四化一定算；`level` ≥ 1 時再加上那一層運限的四化；祿存當成祿
    private static func clampMutagens(_ p: Palace, horo: Horoscope, level: Int) -> Set<String> {
        var out = Set(p.stars.map(\.mutagen).filter { !$0.isEmpty })
        if level >= 1 {
            let list = horo.scope(level).mutagen
            for s in p.stars { if let m = mutagen(in: list, star: s.name) { out.insert(m.rawValue) } }
        }
        if p.stars.contains(where: { $0.name == "祿存" }) { out.insert("祿") }
        return out
    }

    /// 被選宮位 `i` 被哪些組合夾（`level`：0＝只看生年四化，1–5＝再加上那一層的四化）
    static func clamps(_ c: Chart, horo: Horoscope, center i: Int, level: Int) -> [Clamp] {
        let a = c.palaces[(i + 11) % 12], b = c.palaces[(i + 1) % 12], me = c.palaces[i]
        let sa = Set(a.stars.map(\.name)), sb = Set(b.stars.map(\.name))
        let ma = clampMutagens(a, horo: horo, level: level), mb = clampMutagens(b, horo: horo, level: level)
        let centerJi = clampMutagens(me, horo: horo, level: level).contains("忌")
        var out: [Clamp] = []
        for (x, y, name, meaning, good) in clampStarPairs where (sa.contains(x) && sb.contains(y)) || (sa.contains(y) && sb.contains(x)) {
            if name == "羊陀夾" && !centerJi { continue }
            out.append(Clamp(name: name, meaning: meaning, good: good))
        }
        for (x, y, name, meaning, good) in clampMutagenPairs where (ma.contains(x) && mb.contains(y)) || (ma.contains(y) && mb.contains(x)) {
            if name == "雙忌夾" && centerJi {
                out.append(Clamp(name: "雙忌夾忌", meaning: "等同被夾的宮位有三個忌", good: false))
            } else {
                out.append(Clamp(name: name, meaning: meaning, good: good))
            }
        }
        return out
    }
}
