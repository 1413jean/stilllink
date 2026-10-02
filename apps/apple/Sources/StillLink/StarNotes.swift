import SwiftUI

/// 一顆星（或雙星組合、四化）的筆記：總論＋落在十二宮的意思
struct StarNote: Codable, Equatable {
    var summary = ""
    var palaces: [String: String] = [:]   // 命、兄、夫…疾 → 意思
    var isEmpty: Bool { summary.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && palaces.values.allSatisfy { $0.isEmpty } }
}

/// 星曜筆記：內建一份預設（朋友整理的星曜文件，scripts/import-star-notes.py 轉的），
/// 使用者改過的另外存在資料夾的 star-notes.json，只存改過的那幾條；沒改的永遠跟著預設
@MainActor
final class StarNotes: ObservableObject {
    static let shared = StarNotes()
    static let palaceKeys = ["命", "兄", "夫", "子", "財", "疾", "遷", "友", "官", "田", "福", "父"]

    /// 筆記頁的分組（依序）
    static let groups: [(String, [String])] = [
        ("十四主星", ["紫微", "天機", "太陽", "武曲", "天同", "廉貞", "天府", "太陰", "貪狼", "巨門", "天相", "天梁", "七殺", "破軍"]),
        ("雙星組合", ["紫微天府", "紫微貪狼", "紫微天相", "紫微七殺", "紫微破軍", "天機太陰", "天機巨門", "天機天梁",
                    "太陽太陰", "太陽巨門", "太陽天梁", "武曲天府", "武曲貪狼", "武曲天相", "武曲七殺", "武曲破軍",
                    "天同太陰", "天同巨門", "天同天梁", "廉貞天府", "廉貞貪狼", "廉貞天相", "廉貞七殺", "廉貞破軍"]),
        ("輔星", ["左輔", "右弼", "文昌", "文曲", "天魁", "天鉞"]),
        ("吉星", ["祿存", "天馬"]),
        ("凶星", ["擎羊", "陀羅", "火星", "鈴星", "地空", "地劫"]),
        ("雜曜", ["紅鸞", "天喜", "天姚", "天刑", "咸池"]),
        ("四化", ["化祿", "化權", "化科", "化忌"]),
    ]

    private(set) var defaults: [String: StarNote] = [:]
    @Published private(set) var custom: [String: StarNote] = [:]
    private let url = Store.dataDir.appendingPathComponent("star-notes.json")

    private init() {
        if let u = Bundle.main.url(forResource: "star-notes", withExtension: "json"),
           let d = try? Data(contentsOf: u), let v = try? JSONDecoder().decode([String: StarNote].self, from: d) { defaults = v }
        if let d = try? Data(contentsOf: url), let v = try? JSONDecoder().decode([String: StarNote].self, from: d) { custom = v }
    }

    func note(_ key: String) -> StarNote { custom[key] ?? defaults[key] ?? StarNote() }
    func isCustom(_ key: String) -> Bool { custom[key] != nil }
    func hasNote(_ key: String) -> Bool { !note(key).isEmpty }

    func set(_ key: String, _ n: StarNote) {
        if n == defaults[key] { custom[key] = nil } else { custom[key] = n }
        save()
    }

    func reset(_ key: String) { custom[key] = nil; save() }

    private func save() {
        let enc = JSONEncoder(); enc.outputFormatting = [.prettyPrinted, .sortedKeys]
        if let d = try? enc.encode(custom) { try? d.write(to: url, options: .atomic) }
    }

    /// 宮名 → 筆記用的一個字（命宮→命、交友→友、官祿→官…）
    static func palaceKey(_ name: String) -> String {
        if name.contains("友") || name.contains("僕") { return "友" }
        return String(name.prefix(1))
    }

    /// 這一宮要顯示哪些筆記：雙星組合、主星、其他有筆記的星、生年四化
    func keys(for p: Palace) -> [(key: String, type: String)] {
        var out: [(String, String)] = []
        let majors = p.stars.filter { $0.type == "major" }.map(\.name)
        if majors.count == 2 {
            let a = majors[0] + majors[1], b = majors[1] + majors[0]
            if hasNote(a) { out.append((a, "major")) } else if hasNote(b) { out.append((b, "major")) }
        }
        for s in p.stars where hasNote(s.name) { out.append((s.name, s.type)) }
        for s in p.adj where hasNote(s.name) { out.append((s.name, s.type)) }
        for m in Set(p.stars.map(\.mutagen)).sorted() where !m.isEmpty && hasNote("化" + m) { out.append(("化" + m, "mutagen")) }
        return out
    }
}

/// 右側面板：點選宮位的星曜筆記
struct StarNotesCard: View {
    @ObservedObject private var notes = StarNotes.shared
    @Environment(\.zSettings) private var settings
    let palace: Palace
    @State private var expanded: Set<String> = []

    var body: some View {
        let pk = StarNotes.palaceKey(palace.name)
        let list = notes.keys(for: palace)
        VStack(alignment: .leading, spacing: 10) {
            if list.isEmpty {
                Text("這一宮沒有星曜筆記。可以到「星曜筆記」頁自己寫。").font(Font.zCaption).foregroundStyle(Color.zText3)
            }
            ForEach(list, id: \.key) { item in
                let n = notes.note(item.key)
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Text(item.key).font(Font.zBodyStrong)
                            .foregroundStyle(item.type == "mutagen" ? Color.zText : settings.starTone(type: item.type).color)
                        if let first = n.summary.split(separator: "\n").first, first.count <= 12 {
                            Text(first).font(Font.zCaption).foregroundStyle(Color.zText3)
                        }
                        Spacer(minLength: 0)
                        Button { NotificationCenter.default.post(name: .openStarNotes, object: item.key) } label: {
                            Image(systemName: "square.and.pencil").font(Font.zCaption).foregroundStyle(Color.zText3)
                                .frame(width: 22, height: 22).contentShape(Rectangle())
                        }
                        .buttonStyle(PressStyle()).help("編輯「\(item.key)」的筆記")
                    }
                    if let t = n.palaces[pk], !t.isEmpty {
                        Text("落\(palace.name)：\(t)").font(Font.zCallout).foregroundStyle(Color.zText)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    let open = expanded.contains(item.key)
                    if !n.summary.isEmpty {
                        Text(n.summary).font(Font.zCaption).foregroundStyle(Color.zText2)
                            .lineLimit(open ? nil : 2)
                            .fixedSize(horizontal: false, vertical: true)
                        Button(open ? "收起" : "更多") {
                            withAnimation(Motion.fast) { if open { expanded.remove(item.key) } else { expanded.insert(item.key) } }
                        }
                        .buttonStyle(.plain).font(Font.zCaption).foregroundStyle(Color.zAccent)
                    }
                }
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(RoundedRectangle(cornerRadius: 9).fill(Color.zHover))
            }
        }
    }
}

/// 星曜筆記頁：左邊星曜列表，右邊編輯總論和十二宮
struct StarNotesPage: View {
    var initial: String? = nil
    var onClose: () -> Void
    @ObservedObject private var notes = StarNotes.shared
    @State private var key = "紫微"
    @State private var draft = StarNote()
    @State private var search = ""

    var body: some View {
        HStack(spacing: 0) {
            list.frame(width: 220)
            Rectangle().fill(Color.zLine).frame(width: 0.5)
            editor.frame(maxWidth: .infinity)
        }
        .background(Color.zBg)
        .navigationTitle("")
        .onAppear { if let initial { key = initial }; draft = notes.note(key) }
    }

    private var list: some View {
        VStack(spacing: 0) {
            HStack(spacing: 6) {
                Image(systemName: "magnifyingglass").font(Font.zCaption).foregroundStyle(Color.zText3)
                TextField("搜尋星曜", text: $search).textFieldStyle(.plain).font(Font.zCallout)
            }
            .padding(.horizontal, 10).frame(height: 32)
            .background(RoundedRectangle(cornerRadius: 8).fill(Color.zCard))
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.zLine))
            .padding(12)
            ScrollView {
                VStack(alignment: .leading, spacing: 1) {
                    ForEach(StarNotes.groups, id: \.0) { g in
                        let items = g.1.filter { search.isEmpty || $0.contains(search) }
                        if !items.isEmpty {
                            Text(g.0).font(Font.zCaptionStrong).foregroundStyle(Color.zText3)
                                .padding(.horizontal, 10).padding(.top, 10).padding(.bottom, 4)
                            ForEach(items, id: \.self) { k in
                                Button { pick(k) } label: {
                                    HStack {
                                        Text(k).font(Font.zCallout).foregroundStyle(Color.zText)
                                        Spacer()
                                        if notes.isCustom(k) { Circle().fill(Color.zAccent).frame(width: 6, height: 6).help("已自己改寫") }
                                    }
                                    .padding(.horizontal, 10).frame(height: 30)
                                    .background(RoundedRectangle(cornerRadius: 7).fill(k == key ? Color.zHover : .clear))
                                    .contentShape(Rectangle())
                                }
                                .buttonStyle(PressStyle())
                            }
                        }
                    }
                }
                .padding(.horizontal, 8).padding(.bottom, 16)
            }
        }
    }

    private var editor: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                HStack(alignment: .firstTextBaseline) {
                    Text(key).font(.zTitle).foregroundStyle(Color.zText)
                    Text(notes.isCustom(key) ? "已自己改寫" : "預設內容").font(Font.zCaption).foregroundStyle(Color.zText3)
                    Spacer()
                    if notes.isCustom(key) {
                        Button("還原成預設") { notes.reset(key); draft = notes.note(key); Toast.show("「\(key)」已還原成預設") }
                            .buttonStyle(.plain).font(Font.zCallout).foregroundStyle(Color.zAccent)
                    }
                }
                .padding(.bottom, 4)
                Text("點宮位時，右側會顯示這顆星的總論和「落在這一宮」的意思。改了會自動存。")
                    .font(Font.zCallout).foregroundStyle(Color.zText3).padding(.bottom, 16)

                label("總論")
                field(Binding(get: { draft.summary }, set: { draft.summary = $0; commit() }), minH: 110)
                    .padding(.bottom, 18)

                label("落在各宮")
                ForEach(StarNotes.palaceKeys, id: \.self) { pk in
                    HStack(alignment: .top, spacing: 10) {
                        Text(pk).font(Font.zBodyStrong).foregroundStyle(Color.wmRed).frame(width: 22).padding(.top, 8)
                        field(Binding(get: { draft.palaces[pk] ?? "" }, set: { draft.palaces[pk] = $0; commit() }), minH: 36)
                    }
                    .padding(.bottom, 8)
                }
            }
            .frame(maxWidth: 680, alignment: .leading)
            .padding(.horizontal, 32).padding(.vertical, 20)
            .frame(maxWidth: .infinity)
        }
    }

    private func label(_ t: String) -> some View {
        Text(t).font(Font.zCalloutStrong).foregroundStyle(Color.zText2).padding(.bottom, 6)
    }

    private func field(_ b: Binding<String>, minH: CGFloat) -> some View {
        TextEditor(text: b)
            .font(Font.zBody)
            .scrollContentBackground(.hidden)
            .frame(minHeight: minH)
            .fixedSize(horizontal: false, vertical: true)
            .padding(6)
            .background(RoundedRectangle(cornerRadius: 8).fill(Color.zCard))
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.zLine))
    }

    private func pick(_ k: String) {
        key = k
        draft = notes.note(k)
    }

    private func commit() {
        var n = draft
        n.palaces = n.palaces.filter { !$0.value.isEmpty }
        notes.set(key, n)
    }
}

extension Notification.Name {
    static let openStarNotes = Notification.Name("zw.openStarNotes")
}
