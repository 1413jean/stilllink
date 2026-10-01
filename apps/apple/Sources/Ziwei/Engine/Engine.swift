import Foundation
import JavaScriptCore

// MARK: - 資料模型（iztro 算出來的結果）

struct Star: Codable, Hashable {
    let name: String
    let type: String
    let brightness: String
    let mutagen: String
}

struct Palace: Codable, Hashable {
    let name: String
    let stem: String
    let branch: String
    let isBody: Bool
    let major: [Star]
    let minor: [Star]
    let adj: [Star]
    let changsheng: String
    let boshi: String
    let jiangqian: String
    let suiqian: String
    let range: [Int]
    let ages: [Int]

    var stars: [Star] { major + minor }
}

struct Chart: Codable {
    let solarDate: String
    let lunarDate: String
    let chineseDate: String
    let time: String
    let timeRange: String
    let sign: String
    let zodiac: String
    let soul: String
    let body: String
    let fiveElementsClass: String
    let yearBranch: String
    let palaces: [Palace]

    var soulIndex: Int { palaces.firstIndex { $0.name == "命宮" } ?? 0 }
}

struct HoroScope: Codable {
    let index: Int
    let stem: String
    let branch: String
    let palaceNames: [String]
    let mutagen: [String]
}

struct Horoscope: Codable {
    let decadal: HoroScope
    let yearly: HoroScope
    let monthly: HoroScope
    let daily: HoroScope
    let hourly: HoroScope

    /// 依層級（1 大限 … 5 流時）取出運限
    func scope(_ level: Int) -> HoroScope {
        [decadal, yearly, monthly, daily, hourly][level - 1]
    }
}

struct LunarDate: Codable { let year: Int; let month: Int; let day: Int }

// MARK: - 排盤引擎：iztro 跑在 JavaScriptCore（純計算，沒有任何網頁畫面）

final class Engine {
    static let shared = Engine()
    private let ctx: JSContext
    private var chartCache: [String: Chart] = [:]

    private init() {
        ctx = JSContext()!
        ctx.exceptionHandler = { _, e in NSLog("[engine] JS error: \(e?.toString() ?? "?")") }
        ctx.evaluateScript("var window = this, self = this;")
        for name in ["iztro.min", "bridge"] {
            guard let url = Engine.resource(name, "js"), let src = try? String(contentsOf: url, encoding: .utf8) else {
                fatalError("找不到 \(name).js")
            }
            ctx.evaluateScript(src, withSourceURL: url)
        }
    }

    /// .app 內在 Contents/Resources；用 swift run 開發時往上找 Resources 資料夾
    static func resource(_ name: String, _ ext: String) -> URL? {
        if let u = Bundle.main.url(forResource: name, withExtension: ext) { return u }
        var dir = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
        for _ in 0..<5 {
            let u = dir.appendingPathComponent("Resources/\(name).\(ext)")
            if FileManager.default.fileExists(atPath: u.path) { return u }
            dir.deleteLastPathComponent()
        }
        return nil
    }

    private func call(_ fn: String, _ args: [Any]) -> String {
        ctx.objectForKeyedSubscript(fn).call(withArguments: args)?.toString() ?? ""
    }

    private func decode<T: Decodable>(_ s: String) -> T {
        try! JSONDecoder().decode(T.self, from: Data(s.utf8))
    }

    func chart(for p: Person) -> Chart {
        let key = "\(p.solar)|\(p.hour)|\(p.gender.rawValue)"
        if let c = chartCache[key] { return c }
        let c: Chart = decode(call("zwChart", [p.solar, p.hour, p.gender.rawValue]))
        chartCache[key] = c
        return c
    }

    func horoscope(for p: Person, date: String, hour: Int) -> Horoscope {
        decode(call("zwHoro", [p.solar, p.hour, p.gender.rawValue, date, hour]))
    }

    func lunarToSolar(_ y: Int, _ m: Int, _ d: Int) -> String {
        call("zwLunarToSolar", [y, m, d])
    }

    func solarToLunar(_ solar: String) -> LunarDate {
        decode(call("zwSolarToLunar", [solar]))
    }
}
