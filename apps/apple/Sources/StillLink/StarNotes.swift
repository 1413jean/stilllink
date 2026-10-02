import SwiftUI

/// 一顆星（或雙星組合、四化）的筆記：總論＋落在十二宮的意思
struct StarNote: Codable, Equatable {
    var tagline = ""                      // 一句話重點（紫微：皇帝、文昌：寫字、文采好…）
    var summary = ""
    var palaces: [String: String] = [:]   // 命、兄、夫…疾 → 意思
    var deep: [String: String] = [:]      // 延伸說明（附錄：命＝職業、官＝工作模式、財＝現金、田＝居家、遷＝打扮、疾＝疾病）
    var isEmpty: Bool {
        (tagline + summary).trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && palaces.values.allSatisfy(\.isEmpty) && deep.values.allSatisfy(\.isEmpty)
    }

    init() {}
    // 舊版存的筆記沒有 tagline、deep：缺的欄位用空值，不要整條讀不出來
    init(from d: Decoder) throws {
        let c = try d.container(keyedBy: CodingKeys.self)
        tagline = try c.decodeIfPresent(String.self, forKey: .tagline) ?? ""
        summary = try c.decodeIfPresent(String.self, forKey: .summary) ?? ""
        palaces = try c.decodeIfPresent([String: String].self, forKey: .palaces) ?? [:]
        deep = try c.decodeIfPresent([String: String].self, forKey: .deep) ?? [:]
    }
}

/// 星曜筆記：內建一份預設（朋友整理的星曜文件，scripts/import-star-notes.py 轉的），
/// 使用者改過的另外存在資料夾的 star-notes.json，只存改過的那幾條；沒改的永遠跟著預設
@MainActor
final class StarNotes: ObservableObject {
    static let shared = StarNotes()
    static let palaceKeys = ["命", "兄", "夫", "子", "財", "疾", "遷", "友", "官", "田", "福", "父"]

    static let majors = ["紫微", "天機", "太陽", "武曲", "天同", "廉貞", "天府", "太陰", "貪狼", "巨門", "天相", "天梁", "七殺", "破軍"]
    /// 筆記頁的分組（依序）
    static let groups: [(String, [String])] = [
        ("總覽", ["主星介紹", "六吉星總覽", "四煞星總覽", "雜曜總覽", "十干四化", "長生十二神", "紫占", "天生沒長好", "其他備註"]),
        ("十四主星", majors),
        ("雙星組合", ["紫微天府", "紫微貪狼", "紫微天相", "紫微七殺", "紫微破軍", "天機太陰", "天機巨門", "天機天梁",
                    "太陽太陰", "太陽巨門", "太陽天梁", "武曲天府", "武曲貪狼", "武曲天相", "武曲七殺", "武曲破軍",
                    "天同太陰", "天同巨門", "天同天梁", "廉貞天府", "廉貞貪狼", "廉貞天相", "廉貞七殺", "廉貞破軍"]),
        ("輔星", ["左輔", "右弼", "文昌", "文曲", "天魁", "天鉞"]),
        ("吉星", ["祿存", "天馬"]),
        ("凶星", ["擎羊", "陀羅", "火星", "鈴星", "地空", "地劫"]),
        ("雜曜", ["紅鸞", "天喜", "天姚", "天刑", "咸池"]),
        ("四化", ["化祿", "化權", "化科", "化忌"]),
        ("十干星化", starMutagenKeys),
        ("長生十二神", ["長生", "沐浴", "冠帶", "臨官", "帝旺", "衰", "病", "死", "墓", "絕", "胎", "養"]),
    ]
    /// 只有內文的總覽／星化／長生（沒有十二宮）
    static func isDoc(_ key: String) -> Bool {
        groups.contains { ["總覽", "十干星化", "長生十二神"].contains($0.0) && $0.1.contains(key) }
    }
    /// 十干四化各星（甲：廉貞化祿、破軍化權…），照天干順序；庚另有天相化忌一說
    private static var starMutagenKeys: [String] {
        var out: [String] = []
        for st in ZW.stems {
            for (k, star) in (ZW.defaultStemMutagen[st] ?? []).enumerated() where k < 4 {
                out.append(star + "化" + ["祿", "權", "科", "忌"][k])
            }
            if st == "庚" { out.append("天相化忌") }
        }
        return out
    }
    /// 延伸說明的標題
    static let deepLabel = ["命": "職業", "官": "工作模式", "財": "現金處理", "田": "居家風格", "遷": "打扮風格", "疾": "疾病參考"]

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
        for s in p.stars {
            if hasNote(s.name) { out.append((s.name, s.type)) }
            // 生年四化：這顆星在十干四化裡的意思（廉貞化祿…）
            if !s.mutagen.isEmpty, hasNote(s.name + "化" + s.mutagen) { out.append((s.name + "化" + s.mutagen, "mutagen")) }
        }
        for s in p.adj where hasNote(s.name) { out.append((s.name, s.type)) }
        for m in Set(p.stars.map(\.mutagen)).sorted() where !m.isEmpty && hasNote("化" + m) { out.append(("化" + m, "mutagen")) }
        if !p.changsheng.isEmpty, hasNote(p.changsheng) { out.append((p.changsheng, "changsheng")) }
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
                        if !n.tagline.isEmpty {
                            Text(n.tagline).font(Font.zCaption).foregroundStyle(Color.zText3).lineLimit(1)
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
                    let deep = n.deep[pk] ?? ""
                    // 延伸說明（附錄：職業、工作模式…）展開才顯示
                    if open && !deep.isEmpty {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(StarNotes.deepLabel[pk] ?? "延伸").font(Font.zCaptionStrong).foregroundStyle(Color.zText2)
                            Text(deep).font(Font.zCaption).foregroundStyle(Color.zText2).fixedSize(horizontal: false, vertical: true)
                        }
                        .padding(.vertical, 2)
                    }
                    if !n.summary.isEmpty || !deep.isEmpty {
                        if !n.summary.isEmpty {
                            Text(n.summary).font(Font.zCaption).foregroundStyle(Color.zText2)
                                .lineLimit(open ? nil : 2)
                                .fixedSize(horizontal: false, vertical: true)
                        }
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
            list.frame(width: 260)
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
                            // 小標籤排成多欄：主星兩個字一排 3 個，雙星四個字一排 2 個
                            LazyVGrid(columns: [GridItem(.adaptive(minimum: items.first.map { $0.count > 2 ? 96 : 60 } ?? 60), spacing: 6)],
                                      alignment: .leading, spacing: 6) {
                                ForEach(items, id: \.self) { k in
                                    Button { pick(k) } label: {
                                        Text(k).font(Font.zCallout).foregroundStyle(k == key ? Color.zBg : Color.zText)
                                            .lineLimit(1)
                                            .frame(maxWidth: .infinity, minHeight: 32)
                                            .background(RoundedRectangle(cornerRadius: 8).fill(k == key ? Color.zText : Color.zCard))
                                            .overlay(RoundedRectangle(cornerRadius: 8).stroke(k == key ? .clear : Color.zLine))
                                            .overlay(alignment: .topTrailing) {
                                                if notes.isCustom(k) { Circle().fill(Color.zAccent).frame(width: 6, height: 6).padding(4).help("已自己改寫") }
                                            }
                                            .contentShape(Rectangle())
                                    }
                                    .buttonStyle(PressStyle())
                                }
                            }
                            .padding(.horizontal, 4)
                        }
                    }
                }
                .padding(.horizontal, 12).padding(.bottom, 16)
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
                let doc = StarNotes.isDoc(key)
                Text(doc ? "參考內容，可以自己改寫。改了會自動存。" : "點宮位時，右側會顯示這顆星的重點、總論和「落在這一宮」的意思。改了會自動存。")
                    .font(Font.zCallout).foregroundStyle(Color.zText3).padding(.bottom, 16)

                if !doc || !draft.tagline.isEmpty {
                    label("一句話重點")
                    field(Binding(get: { draft.tagline }, set: { draft.tagline = $0; commit() }), lines: 1...2)
                        .padding(.bottom, 18)
                }
                label(doc ? "內容" : "總論")
                field(Binding(get: { draft.summary }, set: { draft.summary = $0; commit() }), lines: doc ? 8...40 : 3...14)
                    .padding(.bottom, 18)

                if !doc {
                    label("落在各宮")
                    // 寬的時候兩欄、窄的時候一欄（每格至少 300 寬）；主星多一格延伸說明（職業、工作模式…）
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 300), spacing: 12, alignment: .top)], alignment: .leading, spacing: 10) {
                        ForEach(StarNotes.palaceKeys, id: \.self) { pk in
                            HStack(alignment: .firstTextBaseline, spacing: 8) {
                                Text(pk).font(Font.zBodyStrong).foregroundStyle(Color.wmRed).frame(width: 18)
                                VStack(alignment: .leading, spacing: 4) {
                                    field(Binding(get: { draft.palaces[pk] ?? "" }, set: { draft.palaces[pk] = $0; commit() }), lines: 1...6)
                                    if let dl = StarNotes.deepLabel[pk], draft.deep[pk] != nil || StarNotes.majors.contains(key) {
                                        Text(dl).font(Font.zCaption).foregroundStyle(Color.zText3).padding(.top, 2)
                                        field(Binding(get: { draft.deep[pk] ?? "" }, set: { draft.deep[pk] = $0; commit() }), lines: 1...10)
                                    }
                                }
                            }
                        }
                    }
                }
            }
            .frame(maxWidth: 1100, alignment: .leading)
            .padding(.horizontal, 28).padding(.vertical, 20)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func label(_ t: String) -> some View {
        Text(t).font(Font.zCalloutStrong).foregroundStyle(Color.zText2).padding(.bottom, 6)
    }

    /// 輸入框：依內容長高（lines 是最少～最多行數）
    private func field(_ b: Binding<String>, lines: ClosedRange<Int>) -> some View {
        TextField("", text: b, axis: .vertical)
            .textFieldStyle(.plain)
            .font(Font.zCallout)
            .lineLimit(lines)
            .padding(.horizontal, 10).padding(.vertical, 8)
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
        n.deep = n.deep.filter { !$0.value.isEmpty }
        notes.set(key, n)
    }
}

extension Notification.Name {
    static let openStarNotes = Notification.Name("zw.openStarNotes")
}
