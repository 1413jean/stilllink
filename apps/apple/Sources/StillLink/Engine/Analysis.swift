import Foundation

enum Mutagen: String, CaseIterable { case lu = "祿", quan = "權", ke = "科", ji = "忌" }

enum ZW {
    static let hours = ["早子", "丑", "寅", "卯", "辰", "巳", "午", "未", "申", "酉", "戌", "亥", "晚子"]
    static let branches = Array("子丑寅卯辰巳午未申酉戌亥").map(String.init)
    static let stems = Array("甲乙丙丁戊己庚辛壬癸").map(String.init)
    static let lunarMonths = ["正月", "二月", "三月", "四月", "五月", "六月", "七月", "八月", "九月", "十月", "冬月", "臘月"]
    static let lunarDays: [String] = (1...30).map { d in
        let n = ["", "一", "二", "三", "四", "五", "六", "七", "八", "九", "十"]
        if d <= 10 { return "初" + n[d] }
        if d < 20 { return "十" + n[d - 10] }
        if d == 20 { return "二十" }
        if d < 30 { return "廿" + n[d - 20] }
        return "三十"
    }
    static let levels = ["本命", "大限", "流年", "流月", "流日", "流時"]
    static let scopeTags = ["大", "年", "月", "日", "時"]

    /// 目前使用的十干四化表（依設定，見 ZSettings.stemMutagen）
    static var stemMutagen: [String: [String]] = defaultStemMutagen

    /// 預設十干四化（祿權科忌），庚干採「陽武陰同」
    static let defaultStemMutagen: [String: [String]] = [
        "甲": ["廉貞", "破軍", "武曲", "太陽"], "乙": ["天機", "天梁", "紫微", "太陰"],
        "丙": ["天同", "天機", "文昌", "廉貞"], "丁": ["太陰", "天同", "天機", "巨門"],
        "戊": ["貪狼", "太陰", "右弼", "天機"], "己": ["武曲", "貪狼", "天梁", "文曲"],
        "庚": ["太陽", "武曲", "太陰", "天同"], "辛": ["巨門", "太陽", "文曲", "文昌"],
        "壬": ["天梁", "紫微", "左輔", "武曲"], "癸": ["破軍", "巨門", "太陰", "貪狼"],
    ]

    /// palaces[i]：0 寅、1 卯 … 11 丑 → 盤面 (row, col)
    static let grid: [(Int, Int)] = [(3, 0), (2, 0), (1, 0), (0, 0), (0, 1), (0, 2), (0, 3), (1, 3), (2, 3), (3, 3), (3, 2), (3, 1)]
    static let compass = ["東偏北", "正東方", "東偏南", "南偏東", "正南方", "南偏西", "西偏南", "正西方", "西偏北", "北偏西", "正北方", "北偏東"]
    /// 中宮四邊錨點（0–1），畫三方四正連線
    static let anchor: [(Double, Double)] = [(0, 1), (0, 0.75), (0, 0.25), (0, 0), (0.25, 0), (0.75, 0), (1, 0), (1, 0.25), (1, 0.75), (1, 1), (0.75, 1), (0.25, 1)]

    /// 十二宮簡稱（命宮起逆時針）
    static let palaceShort = ["命", "兄", "夫", "子", "財", "疾", "遷", "友", "官", "田", "福", "父"]
    static let palaceShortOf: [String: String] = [
        "命宮": "命", "兄弟": "兄", "夫妻": "夫", "子女": "子", "財帛": "財", "疾厄": "疾",
        "遷移": "遷", "交友": "友", "官祿": "官", "田宅": "田", "福德": "福", "父母": "父",
    ]

    /// 轉宮：以 taiji 宮為命，index 宮叫「X之Y」（例：夫之兄）
    static func transferredName(taiji t: Int, index i: Int, chart: Chart) -> String {
        let head = palaceShortOf[chart.palaces[t].name] ?? String(chart.palaces[t].name.prefix(1))
        return head + "之" + palaceShort[(t - i + 12) % 12]
    }

    static func sanFang(_ i: Int) -> [Int] { [i, (i + 4) % 12, (i + 8) % 12, (i + 6) % 12] }

    static func mutagen(in list: [String], star: String) -> Mutagen? {
        guard let k = list.firstIndex(of: star) else { return nil }
        return Mutagen.allCases[k]
    }

    /// 自化：本宮宮干化出本宮星（離心）、對宮宮干化入本宮星（向心）
    static func selfTransforms(_ c: Chart, _ i: Int) -> (out: [String: Mutagen], into: [String: Mutagen]) {
        let names = Set(c.palaces[i].stars.map(\.name))
        var out: [String: Mutagen] = [:], into: [String: Mutagen] = [:]
        for (k, s) in (stemMutagen[c.palaces[i].stem] ?? []).enumerated() where names.contains(s) { out[s] = Mutagen.allCases[k] }
        for (k, s) in (stemMutagen[c.palaces[(i + 6) % 12].stem] ?? []).enumerated() where names.contains(s) { into[s] = Mutagen.allCases[k] }
        return (out, into)
    }

    /// 宮干飛化：本宮宮干四化飛入哪一宮
    static func flying(_ c: Chart, _ i: Int) -> [(star: String, m: Mutagen, to: Int?)] {
        (stemMutagen[c.palaces[i].stem] ?? []).enumerated().map { k, star in
            (star, Mutagen.allCases[k], c.palaces.firstIndex { $0.stars.contains { $0.name == star } })
        }
    }

    /// 流年落在這一宮的虛歲（前 5 次）
    static func yearlyAges(_ c: Chart, _ i: Int) -> [Int] {
        let birth = branches.firstIndex(of: c.yearBranch) ?? 0
        let first = (((i + 2) % 12) - birth + 12) % 12 + 1
        return (0..<5).map { first + $0 * 12 }
    }

    static func yearGanzhi(_ y: Int) -> String { stems[((y - 4) % 10 + 10) % 10] + branches[((y - 4) % 12 + 12) % 12] }   // 西元 1～3 年也要正確

    /// 流月干支（五虎遁）：正月建寅，月干由年干起
    static func monthGanzhi(lunarYear y: Int, month m: Int) -> String {
        let first = ((((y - 4) % 10 + 10) % 10) % 5) * 2 + 2
        return stems[(first + m - 1) % 10] + branches[(m + 1) % 12]
    }

    /// 儒略日數（國曆）
    static func jdn(_ y: Int, _ m: Int, _ d: Int) -> Int {
        let a = (14 - m) / 12, yy = y + 4800 - a, mm = m + 12 * a - 3
        return d + (153 * mm + 2) / 5 + 365 * yy + yy / 4 - yy / 100 + yy / 400 - 32045
    }

    /// 日干支序號（0＝甲子）；2000-1-1 為戊午
    static func dayIndex(jdn: Int) -> Int { ((jdn - 11) % 60 + 60) % 60 }
    static func ganzhi(_ idx: Int) -> String { stems[idx % 10] + branches[idx % 12] }

    /// 流時干支（五鼠遁）：時干由日干起
    static func hourGanzhi(dayStem: Int, hour h: Int) -> String {
        stems[((dayStem % 5) * 2 + h) % 10] + branches[h]
    }

    enum Wuxing { case wood, fire, earth, metal, water }
    static func wuxing(_ ch: String) -> Wuxing {
        switch ch {
        case "甲", "乙", "寅", "卯": return .wood
        case "丙", "丁", "巳", "午": return .fire
        case "戊", "己", "辰", "戌", "丑", "未": return .earth
        case "庚", "辛", "申", "酉": return .metal
        default: return .water
        }
    }

    enum Tone: String, CaseIterable, Codable {
        case red, green, blue, black, earth, purple, gray
        var label: String { ["red": "紅", "green": "綠", "blue": "藍", "black": "黑", "earth": "褐", "purple": "紫", "gray": "灰"][rawValue] ?? "" }
    }

    /// 星曜分五類，各自一種顏色（設定裡可改）
    enum StarClass: String, CaseIterable {
        case major, aux, lucky, tough, misc
        var label: String { ["major": "十四主星", "aux": "輔星", "lucky": "吉星", "tough": "凶星", "misc": "雜曜"][rawValue] ?? "" }
        var members: String {
            switch self {
            case .major: "紫微、天機、太陽、武曲、天同、廉貞、天府、太陰、貪狼、巨門、天相、天梁、七殺、破軍"
            case .aux: "六吉：左輔、右弼、文昌、文曲、天魁、天鉞"
            case .lucky: "祿存、天馬"
            case .tough: "六煞：擎羊、陀羅、火星、鈴星、地空、地劫"
            case .misc: "紅鸞、天喜、天姚、天刑、三台、八座…其他小星"
            }
        }
        var defaultTone: Tone {
            switch self { case .major: .red; case .aux: .green; case .lucky: .purple; case .tough: .black; case .misc: .blue }
        }
        /// iztro 的星曜 type → 類別
        init(type: String) {
            switch type {
            case "major": self = .major
            case "soft": self = .aux
            case "lucun", "tianma": self = .lucky
            case "tough": self = .tough
            default: self = .misc
            }
        }
    }
}
