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
    let lunarYear: Int
    let lunarMonth: Int
    let palaces: [Palace]

    var soulIndex: Int { palaces.firstIndex { $0.name == "命宮" } ?? 0 }
}

struct HoroScope: Codable {
    let index: Int
    let stem: String
    let branch: String
    let palaceNames: [String]
    let mutagen: [String]
    /// 流曜（大祿、年鸞…）：依宮位索引；大限、流年才有
    var stars: [[String]]? = nil
}

struct Horoscope: Codable {
    let decadal: HoroScope
    let age: HoroScope      // 小限
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
// JSContext 不能跨執行緒同時用，所有呼叫都排進同一條背景 queue，主執行緒不會被卡住。

final class Engine: @unchecked Sendable {
    static let shared = Engine()
    private let queue = DispatchQueue(label: "zw.engine", qos: .userInitiated)
    private var ctx: JSContext!
    private var chartCache: [String: Chart] = [:]
    private var horoCache: [String: Horoscope] = [:]

    private init() {
        queue.sync {
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
    }

    /// .app 內的 Contents/Resources（用 ./build.sh 組 app）
    static func resource(_ name: String, _ ext: String) -> URL? {
        Bundle.main.url(forResource: name, withExtension: ext)
    }

    // 以下 _ 開頭的只能在 queue 上呼叫
    private func _call(_ fn: String, _ args: [Any]) -> String {
        ctx.objectForKeyedSubscript(fn).call(withArguments: args)?.toString() ?? ""
    }

    private func _chart(_ p: Person) -> Chart {
        let key = p.chartKey
        if let c = chartCache[key] { return c }
        let c = try! JSONDecoder().decode(Chart.self, from: Data(_call("zwChart", [p.solar, p.hour, p.gender.rawValue]).utf8))
        chartCache[key] = c
        return c
    }

    private func _horo(_ p: Person, _ pick: Pick) -> Horoscope? {
        let key = "\(p.chartKey)|\(pick.year)-\(pick.lm)-\(pick.ld)|\(pick.hour)"
        if let h = horoCache[key] { return h }
        // 小月沒有三十就退一天
        let solar = Lunar.solarString(pick.year, pick.lm, pick.ld) ?? Lunar.solarString(pick.year, pick.lm, min(pick.ld, 29)) ?? "\(pick.year)-1-1"
        guard let h = try? JSONDecoder().decode(Horoscope.self, from: Data(_call("zwHoro", [p.solar, p.hour, p.gender.rawValue, solar, pick.hour]).utf8)) else { return nil }
        horoCache[key] = h
        return h
    }

    private func run<T>(_ work: @escaping () -> T) async -> T {
        await withCheckedContinuation { cont in queue.async { cont.resume(returning: work()) } }
    }

    // MARK: 對外 API

    func model(for p: Person, pick: Pick) async -> ChartModel? {
        await run {
            let c = self._chart(p)
            guard let h = self._horo(p, pick) else { return nil }
            return ChartModel(person: p, chart: c, horo: h, pick: pick)
        }
    }

    func chart(for p: Person) async -> Chart { await run { self._chart(p) } }

    /// 預先算好前後幾年（同月日時）的運限，切換流年時直接取快取
    func prefetch(_ p: Person, around pick: Pick) {
        queue.async(qos: .utility) {
            for d in [1, -1, 2, -2, 3, -3] {
                var q = pick; q.year += d
                _ = self._horo(p, q)
            }
        }
    }

    /// 套用命盤設定：同步到 iztro、本地四化表，並清掉快取
    func configure(_ s: ZSettings) {
        var cfg = s.iztroConfig
        cfg["fixLeap"] = s.leapSplit
        let json = String(data: try! JSONSerialization.data(withJSONObject: cfg), encoding: .utf8)!
        queue.sync {
            ZW.stemMutagen = s.stemMutagen
            _ = _call("zwConfig", [json])
            chartCache = [:]
            horoCache = [:]
        }
    }

    /// 開 app 時把所有人的命盤先算好
    func warm(_ people: [Person], pick: Pick) async {
        await run { for p in people { _ = self._chart(p); _ = self._horo(p, pick) } }
    }

    // 國曆↔農曆一律走 Lunar（系統曆法），不在主執行緒同步等 JS

}

/// 一張盤畫面需要的所有資料，背景算好再交給畫面
struct ChartModel {
    let id = UUID()
    let chart: Chart
    let horo: Horoscope
    let selfs: [(out: [String: Mutagen], into: [String: Mutagen])]
    let flying: [[(star: String, m: Mutagen, to: Int?)]]
    let yearlyAges: [[Int]]
    let bazi: BaziInfo

    init(person: Person, chart: Chart, horo: Horoscope, pick: Pick? = nil) {
        self.chart = chart
        self.horo = horo
        bazi = BaziInfo(person: person, chart: chart)
        selfs = (0..<12).map { ZW.selfTransforms(chart, $0) }
        flying = (0..<12).map { ZW.flying(chart, $0) }
        yearlyAges = (0..<12).map { ZW.yearlyAges(chart, $0) }
    }
}
