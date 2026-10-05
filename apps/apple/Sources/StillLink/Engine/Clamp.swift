import Foundation

/// 夾宮：被選宮位的左右鄰宮（地支前後兩宮）各有一顆成對的星或四化，就是「被 OO 夾」
/// 鄰宮是空宮（沒有主星）時借對宮的星曜一起看（例：命宮空宮借遷移的地空，跟另一邊的地劫成空劫夾）
struct Clamp: Hashable {
    let name: String      // 左右夾、雙忌夾忌…
    let meaning: String   // 內建說明（星曜筆記沒寫時用）
    let good: Bool        // 吉夾（綠）／凶夾（紅）
    var borrow = ""       // 空宮借對宮才成立時的註記：（命宮空宮，借對宮遷移）
}

extension ZW {
    /// 對星夾：兩顆星分別在左右鄰宮
    private static let clampStarPairs: [(String, String, String, String, Bool)] = [
        ("紫微", "天府", "紫府夾", "紫微、天府一左一右護著，像身邊有靠山，這一宮的事容易被看重、受人尊敬。", true),
        ("太陽", "太陰", "日月夾", "太陽、太陰左右照著，這一宮容易被看見，帶來名聲。", true),
        ("文昌", "文曲", "昌曲夾", "文昌、文曲相夾，有文氣與才華，適合文字、藝術、學習相關的事。", true),
        ("左輔", "右弼", "左右夾", "左輔、右弼相夾，身邊總有人幫一把，貴人運好。", true),
        ("天魁", "天鉞", "魁鉞夾", "天魁、天鉞相夾，容易遇到長輩、上司提攜。", true),
        ("火星", "鈴星", "火鈴夾", "火星、鈴星相夾，情緒來得快、一點就燃；事情也可能突然爆開，一下子被很多人看見。", false),
        ("地空", "地劫", "空劫夾", "地空、地劫相夾，想法跳脫、不走尋常路，但也容易落空、白忙一場。", false),
        ("擎羊", "陀羅", "羊陀夾", "擎羊、陀羅相夾，像被壓住、拖住；這一宮本身有凶星或化忌時才算數（有祿存的宮位不算：祿存是加強主星，羊陀本來就排在它兩旁）。", false),
    ]

    /// 四化夾：兩邊各有一個四化（祿存也算祿）
    private static let clampMutagenPairs: [(String, String, String, String, Bool)] = [
        ("祿", "祿", "雙祿夾", "兩邊都是祿，資源和機會往這一宮聚。", true),
        ("權", "權", "雙權夾", "兩邊都是權，有主導權，也容易被交付責任。", true),
        ("科", "科", "雙科夾", "兩邊都是科，名聲好、形象佳，常有貴人。", true),
        ("祿", "權", "祿權夾", "一邊祿一邊權，資源和掌控力都有。", true),
        ("祿", "科", "祿科夾", "一邊祿一邊科，有資源也有名聲，容易遇到貴人。", true),
        ("科", "權", "科權夾", "一邊科一邊權，有名望也有話語權。", true),
        ("忌", "忌", "雙忌夾", "兩邊都是忌，這一宮像被兩股壓力夾住，容易糾結、卡關。", false),
    ]

    /// 判斷夾宮用的一組星：星本身＋這些星所在宮位的地支（合盤的合祿看地支）
    struct ClampSide { var stars: [Star]; var branches: [String] }

    /// 一組星有哪些四化：生年四化一定算；`level` ≥ 1 時再加上那一層運限的四化；合盤時加上對方年干的四化；祿存、合祿當成祿
    private static func clampMutagens(_ side: ClampSide, horo: Horoscope, level: Int, hepan: Hepan?) -> Set<String> {
        let stars = side.stars
        var out = Set(stars.map(\.mutagen).filter { !$0.isEmpty })
        if level >= 1 {
            let list = horo.scope(level).mutagen
            for s in stars { if let m = mutagen(in: list, star: s.name) { out.insert(m.rawValue) } }
        }
        if let h = hepan {
            for s in stars { if let m = h.mutagen(star: s.name) { out.insert(m.rawValue) } }
            if side.branches.contains(where: { h.stars(at: $0).contains("合祿") }) { out.insert("祿") }
        }
        if stars.contains(where: { $0.name == "祿存" }) { out.insert("祿") }
        return out
    }

    /// 鄰宮拿來判斷夾的星：本宮的星；空宮（沒有主星）再加上對宮的星
    private static func clampStars(_ c: Chart, _ n: Int) -> (own: ClampSide, all: ClampSide, borrowedFrom: String?) {
        let p = c.palaces[n]
        let own = ClampSide(stars: p.stars, branches: [p.branch])
        guard p.major.isEmpty else { return (own, own, nil) }
        let opp = c.palaces[(n + 6) % 12]
        return (own, ClampSide(stars: p.stars + opp.stars, branches: [p.branch, opp.branch]), opp.name)
    }

    /// 被選宮位 `i` 被哪些組合夾（`level`：0＝只看生年四化，1–5＝再加上那一層的四化；`hepan`：合盤時加上對方年干的四化）
    static func clamps(_ c: Chart, horo: Horoscope, center i: Int, level: Int, hepan: Hepan? = nil) -> [Clamp] {
        let na = (i + 11) % 12, nb = (i + 1) % 12
        let a = clampStars(c, na), b = clampStars(c, nb)
        // 被夾的宮位本身（空宮一樣借對宮）：雙忌夾忌看有沒有忌；羊陀夾看有沒有凶星或忌
        let me = clampStars(c, i).all
        let centerJi = clampMutagens(me, horo: horo, level: level, hepan: hepan).contains("忌")
        let centerBad = centerJi || me.stars.contains { ["擎羊", "陀羅", "火星", "鈴星", "地空", "地劫"].contains($0.name) }
        // 只靠本宮的星就成立 → 不用註明；要借對宮才成立 → 說明裡寫是哪一宮借了哪一宮
        func note(_ needA: Bool, _ needB: Bool) -> String {
            var parts: [String] = []
            if needA, let f = a.borrowedFrom { parts.append("\(c.palaces[na].name)空宮，借對宮\(f)") }
            if needB, let f = b.borrowedFrom { parts.append("\(c.palaces[nb].name)空宮，借對宮\(f)") }
            return parts.isEmpty ? "" : "（" + parts.joined(separator: "；") + "）"
        }
        func check(_ x: String, _ y: String, sets: (ClampSide) -> Set<String>) -> String? {
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
            guard let n = check(x, y, sets: { Set($0.stars.map(\.name)) }) else { continue }
            // 羊陀永遠排在祿存兩旁：有祿存的宮位不算被夾（祿存是加強主星）；其他宮位要有凶星或化忌才算
            if name == "羊陀夾" && (!centerBad || me.stars.contains { $0.name == "祿存" }) { continue }
            out.append(Clamp(name: name, meaning: meaning, good: good, borrow: n))
        }
        for (x, y, name, meaning, good) in clampMutagenPairs {
            guard let n = check(x, y, sets: { clampMutagens($0, horo: horo, level: level, hepan: hepan) }) else { continue }
            if name == "雙忌夾" && centerJi {
                out.append(Clamp(name: "雙忌夾忌", meaning: "兩邊是忌、本宮也有忌，等於三個忌疊在一起，壓力加倍，要特別留意。", good: false, borrow: n))
            } else {
                out.append(Clamp(name: name, meaning: meaning, good: good, borrow: n))
            }
        }
        return out
    }
}
