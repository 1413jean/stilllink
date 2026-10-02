import Foundation

/// 合盤：只用對方的出生年（天干地支）疊到自己的盤上
/// - 合宮名：對方年支所在的宮＝合命，往回數合兄、合夫…（同一般宮位方向）
/// - 合祿／合羊／合陀：依對方年干的祿存，羊在祿存前一宮、陀在後一宮
/// - 合四化：對方年干的四化（照設定的四化表）
struct Hepan: Equatable {
    let year: Int
    let stem: String
    let branch: String

    init(year: Int) {
        self.year = year
        let gz = ZW.yearGanzhi(year)
        stem = String(gz.prefix(1))
        branch = String(gz.suffix(1))
    }

    private static let names = ["命", "兄", "夫", "子", "財", "疾", "遷", "友", "官", "田", "福", "父"]
    /// 年干 → 祿存所在地支
    private static let lucun: [String: String] = ["甲": "寅", "乙": "卯", "丙": "巳", "丁": "午", "戊": "巳",
                                                  "己": "午", "庚": "申", "辛": "酉", "壬": "亥", "癸": "子"]

    /// 這個地支的宮位是對方的哪一宮（合命、合兄…）
    func palaceName(at palaceBranch: String) -> String? {
        let b = ZW.branches
        guard let me = b.firstIndex(of: branch), let p = b.firstIndex(of: palaceBranch) else { return nil }
        return "合" + Self.names[(me - p + 12) % 12]
    }

    /// 這個地支的宮位上有哪些合祿／合羊／合陀
    func stars(at palaceBranch: String) -> [String] {
        let b = ZW.branches
        guard let l = Self.lucun[stem].flatMap({ b.firstIndex(of: $0) }), let p = b.firstIndex(of: palaceBranch) else { return [] }
        var out: [String] = []
        if p == l { out.append("合祿") }
        if p == (l + 1) % 12 { out.append("合羊") }
        if p == (l + 11) % 12 { out.append("合陀") }
        return out
    }

    /// 這顆星有沒有被對方年干化祿權科忌
    func mutagen(star: String) -> Mutagen? {
        guard let list = ZW.stemMutagen[stem], let i = list.firstIndex(of: star), i < Mutagen.allCases.count else { return nil }
        return Mutagen.allCases[i]
    }

    var label: String { "\(year) \(stem)\(branch)年" }
}
