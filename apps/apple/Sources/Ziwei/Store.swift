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
    var avatar: String? = nil     // 頭貼檔名（裁切壓縮後的 256×256 JPEG）

    var birthYear: Int { Int(solar.split(separator: "-").first ?? "0") ?? 0 }
    var chartKey: String { "\(solar)|\(hour)|\(gender.rawValue)" }
}

enum Appearance: String, Codable, CaseIterable {
    case light, dark, system
    var label: String { ["light": "淺色", "dark": "深色", "system": "跟隨系統"][rawValue]! }
    var icon: String { ["light": "sun.max", "dark": "moon", "system": "circle.lefthalf.filled"][rawValue]! }
    var scheme: ColorScheme? { self == .light ? .light : self == .dark ? .dark : nil }
}

/// 命盤資料：先存在本機 JSON（~/Library/Application Support/Ziwei），之後換 SQLite＋雲端同步
@MainActor
final class Store: ObservableObject {
    @Published var people: [Person] = [] {
        didSet {
            save()
            // 只有影響排盤的資料（生辰、性別、人數）變了才重算側欄主星；改備註、照片不用
            if people.map(\.chartKey) != oldValue.map(\.chartKey) || people.map(\.id) != oldValue.map(\.id) { refreshSoulStars() }
        }
    }
    /// 側欄顯示的命宮主星，背景算好放這裡
    @Published var soulStars: [UUID: String] = [:]
    @AppStorage("appearance") var appearance: Appearance = .system
    /// 使用者（左下角帳號列）顯示的名字
    @AppStorage("userName") var userName: String = "我"
    /// 自己的命盤（個人檔案）
    @AppStorage("selfID") var selfIDString: String = ""
    /// 使用者自己的頭貼（沒有自己的命盤時也能設定）
    @AppStorage("userAvatar") var userAvatarRaw: String = ""
    var userAvatar: String? {
        get { me?.avatar ?? (userAvatarRaw.isEmpty ? nil : userAvatarRaw) }
        set {
            userAvatarRaw = newValue ?? ""
            if var p = me { p.avatar = newValue; update(p) }
            objectWillChange.send()
        }
    }
    /// 側欄是否顯示「我」
    @AppStorage("showSelfInSidebar") var showSelfInSidebar = true

    var selfID: UUID? { UUID(uuidString: selfIDString) }
    var me: Person? { selfID.flatMap { id in people.first { $0.id == id } } }

    /// 改使用者名稱時，自己的命盤也一起改名
    func renameUser(_ name: String) {
        userName = name
        if var p = me { p.name = name; update(p) }
    }
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

    private static func loadSettings() -> ZSettings { ZSettings.stored() }

    private let url: URL = {
        // ZIWEI_DATA_DIR：驗證／測試用的另一份資料夾，不會動到正式資料
        let dir = ProcessInfo.processInfo.environment["ZIWEI_DATA_DIR"].map { URL(fileURLWithPath: $0, isDirectory: true) }
            ?? FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
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
            people = []   // 第一次開啟：完全空白，不放範例
        }
        refreshSoulStars()
        // 舊資料：還沒設定自己的命盤，但有「自己」分組的命盤，就當成自己的
        if selfID == nil, let mine = people.first(where: { $0.group == "自己" }) {
            selfIDString = mine.id.uuidString
            userName = mine.name
        }
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

    private let saveQueue = DispatchQueue(label: "zw.save", qos: .utility)
    /// 存檔放到背景，不卡畫面
    private func save() {
        let snapshot = people, url = url
        saveQueue.async {
            guard let data = try? JSONEncoder().encode(snapshot) else { return }
            try? data.write(to: url, options: .atomic)
        }
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

    // MARK: 側欄排序（拖曳）

    /// 資料夾順序（存在偏好設定）
    @AppStorage("groupOrder") private var groupOrderRaw: String = ""
    var groupOrder: [String] {
        get { groupOrderRaw.isEmpty ? [] : groupOrderRaw.components(separatedBy: "\u{1F}") }
        set { groupOrderRaw = newValue.joined(separator: "\u{1F}"); objectWillChange.send() }
    }

    /// 側欄命盤排序
    enum SortMode: String, CaseIterable {
        case custom, newest, oldest, nameAZ, nameZA, elder, younger
        var label: String {
            switch self {
            case .custom: "自訂（拖曳）"
            case .newest: "新增時間：新到舊"
            case .oldest: "新增時間：舊到新"
            case .nameAZ: "名稱：A → Z"
            case .nameZA: "名稱：Z → A"
            case .elder: "出生日期：年長在前"
            case .younger: "出生日期：年輕在前"
            }
        }
        var icon: String {
            switch self {
            case .custom: "hand.draw"
            case .newest, .oldest: "clock"
            case .nameAZ, .nameZA: "textformat"
            case .elder, .younger: "calendar"
            }
        }
    }
    @AppStorage("sortMode") var sortMode: SortMode = .custom

    /// 依目前排序方式排好一組命盤
    func sorted(_ list: [Person]) -> [Person] {
        let zh = Locale(identifier: "zh_TW")
        func birth(_ p: Person) -> String {
            let n = (p.clock ?? p.solar).split(whereSeparator: { " -:".contains($0) }).compactMap { Int($0) }
            return n.map { String(format: "%04d", $0) }.joined()
        }
        switch sortMode {
        case .custom: return list
        case .newest: return list.sorted { $0.createdAt > $1.createdAt }
        case .oldest: return list.sorted { $0.createdAt < $1.createdAt }
        case .nameAZ: return list.sorted { $0.name.compare($1.name, locale: zh) == .orderedAscending }
        case .nameZA: return list.sorted { $0.name.compare($1.name, locale: zh) == .orderedDescending }
        case .elder: return list.sorted { birth($0) < birth($1) }
        case .younger: return list.sorted { birth($0) > birth($1) }
        }
    }

    /// 拖曳就是自訂順序：先把目前看到的排序寫回去，再改成自訂，順序才不會跳
    private func adoptCustomOrder() {
        guard sortMode != .custom else { return }
        people = sorted(people)
        sortMode = .custom
    }

    /// 把命盤拖到另一張命盤的前面或後面：分組／釘選也跟目標一樣
    func movePerson(_ id: UUID, near target: UUID, after: Bool) {
        adoptCustomOrder()
        guard id != target, let from = people.firstIndex(where: { $0.id == id }),
              let t = people.first(where: { $0.id == target }) else { return }
        var p = people.remove(at: from)
        p.group = t.group
        p.pinned = t.pinned
        let to = people.firstIndex(where: { $0.id == target }).map { after ? $0 + 1 : $0 } ?? people.count
        people.insert(p, at: to)
    }

    /// 把命盤拖到資料夾上：移進這個分組（放在最後）
    func movePerson(_ id: UUID, toGroup g: String) {
        guard let from = people.firstIndex(where: { $0.id == id }) else { return }
        var p = people.remove(at: from)
        p.group = g
        p.pinned = false
        people.append(p)
    }

    /// 資料夾拖到另一個資料夾的前面或後面
    func moveGroup(_ g: String, near target: String, after: Bool, current: [String]) {
        guard g != target else { return }
        var order = current
        order.removeAll { $0 == g }
        order.insert(g, at: order.firstIndex(of: target).map { after ? $0 + 1 : $0 } ?? order.count)
        groupOrder = order
    }

    static let samples: [Person] = [
        Person(name: "範例命盤", gender: .female, solar: "1990-6-15", hour: 6, group: "範例", pinned: true),
        Person(name: "林小姐", gender: .female, solar: "1988-11-2", hour: 3, group: "客人"),
        Person(name: "陳先生", gender: .male, solar: "1979-3-21", hour: 9, group: "客人"),
        Person(name: "王小美", gender: .female, solar: "1996-8-8", hour: 11, group: "客人"),
        Person(name: "張大哥", gender: .male, solar: "1984-1-30", hour: 1, group: "客人"),
        Person(name: "媽媽", gender: .female, solar: "1962-9-12", hour: 5, group: "家人"),
    ]
}
