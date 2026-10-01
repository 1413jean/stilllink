import Foundation
import SwiftUI

enum Gender: String, Codable, CaseIterable { case female = "女", male = "男" }

struct Note: Codable, Identifiable, Hashable {
    var id = UUID()
    var text: String
    var at = Date()
}

struct Person: Codable, Identifiable, Hashable {
    var id = UUID()
    var name: String
    var gender: Gender
    var solar: String // yyyy-M-d
    var hour: Int     // 0 早子 … 12 晚子
    var group: String
    var pinned = false
    var notes: [Note] = []
    var createdAt = Date()

    var birthYear: Int { Int(solar.split(separator: "-").first ?? "0") ?? 0 }
}

enum Appearance: String, Codable, CaseIterable {
    case light, dark, system
    var label: String { ["light": "淺色", "dark": "深色", "system": "跟隨系統"][rawValue]! }
    var scheme: ColorScheme? { self == .light ? .light : self == .dark ? .dark : nil }
}

/// 命盤資料：先存在本機 JSON（~/Library/Application Support/Ziwei），之後換 SQLite＋雲端同步
@MainActor
final class Store: ObservableObject {
    @Published var people: [Person] = [] { didSet { save() } }
    @AppStorage("appearance") var appearance: Appearance = .system

    private let url: URL = {
        let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Ziwei", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("people.json")
    }()

    init() {
        if let data = try? Data(contentsOf: url), let list = try? JSONDecoder().decode([Person].self, from: data) {
            people = list
        } else {
            people = Store.samples
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
