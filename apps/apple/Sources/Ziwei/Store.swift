import Foundation
import SwiftUI

enum Gender: String, Codable, CaseIterable { case female = "女", male = "男" }

struct Note: Codable, Identifiable, Hashable {
    var id = UUID()
    var text: String
    var at = Date()
}

struct BirthPlace: Codable, Hashable {
    var name: String
    var latitude: Double
    var longitude: Double
    var timeZoneID: String
}

struct Person: Codable, Identifiable, Hashable {
    var id = UUID()
    var name: String
    var gender: Gender
    var solar: String // 排盤用的國曆日期 yyyy-M-d（有出生地時是真太陽時的日期）
    var hour: Int     // 排盤用的時辰：0 早子 … 12 晚子
    var group: String
    var pinned = false
    var notes: [Note] = []
    var createdAt = Date()
    // 新增命盤時填的原始資料（舊資料沒有，所以是選填）
    var clock: String? = nil      // 鐘錶時間 yyyy-M-d HH:mm
    var trueSolar: String? = nil  // 真太陽時 yyyy-M-d HH:mm
    var place: BirthPlace? = nil
    var photos: [String]? = nil   // 附件照片檔名（存在 Application Support/Ziwei/media）

    var birthYear: Int { Int(solar.split(separator: "-").first ?? "0") ?? 0 }
    var chartKey: String { "\(solar)|\(hour)|\(gender.rawValue)" }
}

enum Appearance: String, Codable, CaseIterable {
    case light, dark, system
    var label: String { ["light": "淺色", "dark": "深色", "system": "跟隨系統"][rawValue]! }
    var scheme: ColorScheme? { self == .light ? .light : self == .dark ? .dark : nil }
}

/// 命盤資料：先存在本機 JSON（~/Library/Application Support/Ziwei），之後換 SQLite＋雲端同步
@MainActor
final class Store: ObservableObject {
    @Published var people: [Person] = [] { didSet { save(); refreshSoulStars() } }
    /// 側欄顯示的命宮主星，背景算好放這裡
    @Published var soulStars: [UUID: String] = [:]
    @AppStorage("appearance") var appearance: Appearance = .system
    /// 命盤設定：變了就重新設定引擎、重算側欄
    @Published var settings: ZSettings = Store.loadSettings() {
        didSet {
            guard settings != oldValue else { return }
            if let d = try? JSONEncoder().encode(settings) { UserDefaults.standard.set(d, forKey: "settings") }
            Motion.userEnabled = settings.motion
            if settings.calcKey != oldValue.calcKey {
                Engine.shared.configure(settings)
                refreshSoulStars()
            }
        }
    }

    private static func loadSettings() -> ZSettings {
        guard let d = UserDefaults.standard.data(forKey: "settings"), let s = try? JSONDecoder().decode(ZSettings.self, from: d) else { return ZSettings() }
        return s
    }

    private let url: URL = {
        let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Ziwei", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("people.json")
    }()

    init() {
        Engine.shared.configure(settings)
        Motion.userEnabled = settings.motion
        if let data = try? Data(contentsOf: url), let list = try? JSONDecoder().decode([Person].self, from: data) {
            people = list
        } else {
            people = Store.samples
        }
        refreshSoulStars()
    }

    private func refreshSoulStars() {
        let list = people
        Task {
            await Engine.shared.warm(list, pick: Pick.today())
            var out: [UUID: String] = [:]
            for p in list {
                let c = await Engine.shared.chart(for: p)
                out[p.id] = c.palaces.first { $0.name == "命宮" }?.major.map(\.name).joined() ?? ""
            }
            soulStars = out
        }
    }

    private func save() {
        guard let data = try? JSONEncoder().encode(people) else { return }
        try? data.write(to: url, options: .atomic)
    }

    var groups: [(String, [Person])] {
        var out: [(String, [Person])] = []
        let pinned = people.filter(\.pinned)
        if !pinned.isEmpty { out.append(("釘選", pinned)) }
        var order: [String] = []
        for p in people where !p.pinned && !order.contains(p.group) { order.append(p.group) }
        for g in order { out.append((g, people.filter { !$0.pinned && $0.group == g })) }
        return out
    }

    func add(_ p: Person) { people.insert(p, at: 0) }
    func update(_ p: Person) { if let i = people.firstIndex(where: { $0.id == p.id }) { people[i] = p } }
    func delete(_ id: UUID) { people.removeAll { $0.id == id } }

    static let samples: [Person] = [
        Person(name: "Jean", gender: .female, solar: "1990-6-15", hour: 6, group: "自己", pinned: true),
        Person(name: "林小姐", gender: .female, solar: "1988-11-2", hour: 3, group: "客人"),
        Person(name: "陳先生", gender: .male, solar: "1979-3-21", hour: 9, group: "客人"),
        Person(name: "王小美", gender: .female, solar: "1996-8-8", hour: 11, group: "客人"),
        Person(name: "張大哥", gender: .male, solar: "1984-1-30", hour: 1, group: "客人"),
        Person(name: "媽媽", gender: .female, solar: "1962-9-12", hour: 5, group: "家人"),
    ]
}
