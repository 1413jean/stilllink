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
    /// 星曜筆記先只在測試版開放，正式版隱藏（Jean：正式先不要上）
    nonisolated static var enabled: Bool { AppInfo.isBeta }
    static let palaceKeys = ["命", "兄", "夫", "子", "財", "疾", "遷", "友", "官", "田", "福", "父"]

    /// 筆記頁的分組（依序）
    static let groups: [(String, [String])] = [
        ("十四主星", ["紫微", "天機", "太陽", "武曲", "天同", "廉貞", "天府", "太陰", "貪狼", "巨門", "天相", "天梁", "七殺", "破軍"]),
        ("雙星組合", ["紫微天府", "紫微貪狼", "紫微天相", "紫微七殺", "紫微破軍", "天機太陰", "天機巨門", "天機天梁",
                    "太陽太陰", "太陽巨門", "太陽天梁", "武曲天府", "武曲貪狼", "武曲天相", "武曲七殺", "武曲破軍",
                    "天同太陰", "天同巨門", "天同天梁", "廉貞天府", "廉貞貪狼", "廉貞天相", "廉貞七殺", "廉貞破軍"]),
        ("輔星", ["左輔", "右弼", "文昌", "文曲", "天魁", "天鉞", "祿存", "天馬"]),
        ("凶星", ["擎羊", "陀羅", "火星", "鈴星", "地空", "地劫"]),
        ("雜曜", ["紅鸞", "天喜", "天姚", "天刑", "咸池"]),
        ("四化", ["化祿", "化權", "化科", "化忌"]),
        ("十年天干四化", ["十干四化表"] + ZW.stems.map { $0 + "干四化" } + ["化忌解方"]),
        ("實戰小應用", ["紫占"]),
        ("長生十二宮", ["長生十二宮", "長生", "沐浴", "冠帶", "臨官", "帝旺", "衰", "病", "死", "墓", "絕", "胎", "養"]),
        ("附錄", ["附錄一 命宮主星職業", "附錄二 官祿宮工作模式", "附錄三 財帛宮現金處理", "附錄四 田宅宮居家風格",
                "附錄五 遷移宮打扮風格", "附錄六 疾厄宮疾病參考", "附錄七 化忌可拜神明", "附錄八 天生沒長好", "其他備註"]),
    ]
    /// 目錄上的短名稱
    static let groupShort = ["十四主星": "主星", "雙星組合": "雙星", "十年天干四化": "十干四化", "實戰小應用": "紫占", "長生十二宮": "長生"]
    /// 參考文件（十干四化、紫占、長生、附錄）：只有內文，沒有十二宮
    static func isDoc(_ key: String) -> Bool {
        groups.contains { ["十年天干四化", "實戰小應用", "長生十二宮", "附錄"].contains($0.0) && $0.1.contains(key) }
    }

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

    /// 一句話重點：總論第一行夠短就當重點（紫微 → 皇帝）
    static func tagline(_ n: StarNote) -> String {
        guard let f = n.summary.split(separator: "\n").first, f.count <= 12 else { return "" }
        return String(f)
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

/// 右側面板：點選宮位的星曜筆記，連三方四正一起整理（本宮、對宮、兩個三合宮）
struct StarNotesCard: View {
    let chart: Chart
    let index: Int
    var includeBirth = true                    // 生年四化有沒有在顯示範圍（跟盤面一樣最多三層）
    var scopes: [(String, [String])] = []      // 目前顯示的運限四化：（大限、流年…, 祿權科忌四顆星）

    /// 對宮、三合：輔星（含祿存天馬）、凶星一律看，其他星有四化才看（星名 → 四化標籤「生年祿・流年忌」，沒四化就是空字串）
    private func mutagenTags(_ p: Palace) -> [String: String] {
        var out: [String: String] = [:]
        for s in p.stars {
            var t: [String] = []
            if includeBirth, !s.mutagen.isEmpty { t.append("生年" + s.mutagen) }
            for (label, list) in scopes { if let k = list.firstIndex(of: s.name), k < 4 { t.append(label + ["祿", "權", "科", "忌"][k]) } }
            if !t.isEmpty || ["soft", "lucun", "tianma", "tough"].contains(s.type) { out[s.name] = t.joined(separator: "・") }
        }
        return out
    }

    var onOpen: (String, String) -> Void = { _, _ in }   // 點一顆星：（筆記 key、宮名）打開單獨介紹

    var body: some View {
        let sf = ZW.sanFang(index)   // [本宮, 三合, 三合, 對宮]
        let parts: [(String, Int)] = [("本宮", sf[0]), ("對宮", sf[3]), ("三合", sf[1]), ("三合", sf[2])]
        let shown = parts.filter { label, i in
            label == "本宮" || StarNotes.shared.keys(for: chart.palaces[i]).contains { mutagenTags(chart.palaces[i])[$0.key] != nil }
        }
        VStack(alignment: .leading, spacing: 20) {
            ForEach(shown, id: \.1) { label, i in
                VStack(alignment: .leading, spacing: 6) {
                    Text("\(label)・\(chart.palaces[i].name)").font(Font.zCalloutStrong).foregroundStyle(Color.zText3)
                    PalaceNotes(palace: chart.palaces[i], only: label == "本宮" ? nil : mutagenTags(chart.palaces[i]), onOpen: onOpen)
                }
            }
        }
    }
}

/// 一個宮位裡每顆星的重點（黑灰色、只留重點；點了打開單獨介紹）
private struct PalaceNotes: View {
    @ObservedObject private var notes = StarNotes.shared
    let palace: Palace
    var only: [String: String]? = nil   // 只列這些星（對宮、三合：輔星＋有四化的星 → 四化標籤）
    var onOpen: (String, String) -> Void

    var body: some View {
        let pk = StarNotes.palaceKey(palace.name)
        let list = notes.keys(for: palace).filter { only == nil || only![$0.key] != nil }
        VStack(alignment: .leading, spacing: 0) {
            if list.isEmpty {
                Text(only != nil ? "沒有輔星或四化星" : palace.stars.isEmpty ? "空宮" : "沒有星曜筆記")
                    .font(Font.zCallout).foregroundStyle(Color.zText3).padding(.vertical, 4)
            }
            ForEach(list, id: \.key) { item in
                let n = notes.note(item.key)
                Button { onOpen(item.key, palace.name) } label: {
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        VStack(alignment: .leading, spacing: 5) {
                            HStack(spacing: 6) {
                                Text(item.key).font(Font.zBodyStrong).foregroundStyle(Color.zText)
                                Text(only?[item.key].flatMap { $0.isEmpty ? nil : $0 } ?? StarNotes.tagline(n))
                                    .font(Font.zCallout).foregroundStyle(Color.zText3).lineLimit(1)
                            }
                            if let t = n.palaces[pk], !t.isEmpty {
                                Text(t).font(Font.zCallout).foregroundStyle(Color.zText2).lineLimit(2)
                                    .lineSpacing(3).fixedSize(horizontal: false, vertical: true)
                            }
                        }
                        Spacer(minLength: 0)
                        Image(systemName: "chevron.right").font(.system(size: 10, weight: .semibold)).foregroundStyle(Color.zText3)
                    }
                    .padding(.vertical, 11)
                    .contentShape(Rectangle())
                }
                .buttonStyle(PressStyle())
                if item.key != list.last?.key { Rectangle().fill(Color.zLine).frame(height: 0.5) }
            }
        }
    }
}

/// 右側單獨介紹一顆星：重點、落在這一宮、總論、十二宮
struct StarDetailView: View {
    @ObservedObject private var notes = StarNotes.shared
    let key: String
    let palaceName: String
    var onBack: () -> Void

    var body: some View {
        let n = notes.note(key)
        let pk = StarNotes.palaceKey(palaceName)
        VStack(alignment: .leading, spacing: 20) {
            HStack(spacing: 8) {
                Button(action: onBack) {
                    Image(systemName: "chevron.left").font(.system(size: 12, weight: .semibold)).foregroundStyle(Color.zText2)
                        .frame(width: 26, height: 26).background(Circle().fill(Color.zHover))
                }
                .buttonStyle(PressStyle()).help("返回")
                .keyboardShortcut(.cancelAction)
                VStack(alignment: .leading, spacing: 1) {
                    Text(key).font(Font.zHeadline).foregroundStyle(Color.zText)
                    let tl = StarNotes.tagline(n)
                    if !tl.isEmpty { Text(tl).font(Font.zCallout).foregroundStyle(Color.zText3) }
                }
                Spacer()
                Button { NotificationCenter.default.post(name: .openStarNotes, object: key) } label: {
                    Image(systemName: "square.and.pencil").font(Font.zBody).foregroundStyle(Color.zText2)
                }
                .buttonStyle(.plain).help("編輯筆記")
            }
            if let t = n.palaces[pk], !t.isEmpty {
                VStack(alignment: .leading, spacing: 7) {
                    Text("落\(palaceName)").font(Font.zCalloutStrong).foregroundStyle(Color.zText3)
                    Text(t).font(Font.zBody).foregroundStyle(Color.zText).lineSpacing(4).fixedSize(horizontal: false, vertical: true)
                }
                .padding(.leading, 10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .overlay(alignment: .leading) { Rectangle().fill(Color.zText).frame(width: 2) }
            }
            // 總論：第一行已經當重點放在標題下，就不重複
            let body = StarNotes.tagline(n).isEmpty ? n.summary : n.summary.split(separator: "\n").dropFirst().joined(separator: "\n")
            if !body.isEmpty {
                VStack(alignment: .leading, spacing: 7) {
                    Text("總論").font(Font.zCalloutStrong).foregroundStyle(Color.zText3)
                    Text(body).font(Font.zBody).foregroundStyle(Color.zText2).lineSpacing(4).fixedSize(horizontal: false, vertical: true)
                }
            }
            if !n.palaces.isEmpty {
                VStack(alignment: .leading, spacing: 11) {
                    Text("落在各宮").font(Font.zCalloutStrong).foregroundStyle(Color.zText3)
                    ForEach(StarNotes.palaceKeys.filter { n.palaces[$0] != nil && $0 != pk }, id: \.self) { k in
                        HStack(alignment: .firstTextBaseline, spacing: 8) {
                            Text(k).font(Font.zBodyStrong).foregroundStyle(Color.zText).frame(width: 16)
                            Text(n.palaces[k] ?? "").font(Font.zCallout).foregroundStyle(Color.zText2).lineSpacing(4).fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
            }
        }
        .textSelection(.enabled)
    }
}

/// 盤面上滑鼠移到星曜：深色小卡顯示重點（像留言框）
struct StarHoverCard: View {
    let key: String
    let palaceName: String

    var body: some View {
        let n = StarNotes.shared.note(key)
        let t = n.palaces[StarNotes.palaceKey(palaceName)] ?? ""
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                Text(key).font(Font.zBodyStrong).foregroundStyle(Color.white)
                let tl = StarNotes.tagline(n)
                if !tl.isEmpty { Text(tl).font(Font.zCallout).foregroundStyle(Color.white.opacity(0.6)) }
            }
            if !t.isEmpty {
                Text("落\(palaceName)：\(t)").font(Font.zCallout).foregroundStyle(Color.white.opacity(0.85))
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.horizontal, 12).padding(.vertical, 9)
        .frame(width: 240, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 12).fill(Color(white: 0.16)))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.white.opacity(0.08)))
        .shadow(color: Color.black.opacity(0.25), radius: 12, y: 5)
        .allowsHitTesting(false)
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
    @State private var editingDoc = false   // 參考文件：false＝看排好版的內容，true＝改文字

    /// 每顆星一個小圖示（照星的意思：紫微皇帝＝皇冠、太陽＝太陽…）；雙星組合統一用 sparkles
    static let starIcon: [String: String] = [
        "紫微": "crown", "天機": "lightbulb", "太陽": "sun.max", "武曲": "dollarsign.circle", "天同": "cup.and.saucer",
        "廉貞": "checklist", "天府": "building.columns", "太陰": "moon", "貪狼": "heart", "巨門": "bubble.left",
        "天相": "checkmark.seal", "天梁": "book", "七殺": "bolt", "破軍": "hammer",
        "左輔": "figure.stand", "右弼": "figure.stand.dress", "文昌": "pencil", "文曲": "music.note",
        "天魁": "shield", "天鉞": "shield.lefthalf.filled", "祿存": "plus.circle", "天馬": "figure.run",
        "擎羊": "scissors", "陀羅": "tortoise", "火星": "flame", "鈴星": "bell", "地空": "circle.dashed", "地劫": "minus.circle",
        "紅鸞": "heart.circle", "天喜": "gift", "天姚": "wineglass", "天刑": "exclamationmark.shield", "咸池": "drop",
        "化祿": "leaf", "化權": "bolt.circle", "化科": "star", "化忌": "exclamationmark.triangle",
    ]
    static func icons(_ key: String) -> [String] {
        if let i = starIcon[key] { return [i] }
        if key.hasSuffix("干四化") { return ["calendar"] }
        switch key {
        case "十干四化表": return ["tablecells"]
        case "化忌解方": return ["cross.case"]
        case "紫占": return ["dice"]
        case "長生十二宮": return ["sunrise"]
        case "其他備註": return ["note.text"]
        default: break
        }
        if key.hasPrefix("附錄") { return ["doc.text"] }
        if key.count == 4 { return ["sparkles"] }   // 雙星組合：一個圖示就好
        if StarNotes.isDoc(key) { return ["circle.dotted"] }  // 長生十二神
        return []
    }

    var body: some View {
        HStack(spacing: 0) {
            list.frame(width: 280)
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
                Image(systemName: "magnifyingglass").font(Font.zCallout).foregroundStyle(Color.zText3)
                TextField("搜尋星曜", text: $search).textFieldStyle(.plain).font(Font.zBody)
            }
            .padding(.horizontal, 12).frame(height: 40)
            .background(RoundedRectangle(cornerRadius: 8).fill(Color.zCard))
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.zLine))
            .padding(.horizontal, 12).padding(.top, 12).padding(.bottom, 8)
            ScrollViewReader { proxy in
            // 目錄：點了跳到那一類
            FlowLayout(spacing: 4, lineSpacing: 4) {
                ForEach(StarNotes.groups, id: \.0) { g in
                    Button { withAnimation(Motion.base) { proxy.scrollTo(g.0, anchor: .top) } } label: {
                        Text(StarNotes.groupShort[g.0] ?? g.0).font(Font.zCaption).foregroundStyle(Color.zText2)
                            .padding(.horizontal, 8).frame(height: 24)
                            .background(Capsule().fill(Color.zHover))
                            .contentShape(Capsule())
                    }
                    .buttonStyle(PressStyle())
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 12).padding(.bottom, 8)
            Rectangle().fill(Color.zLine).frame(height: 0.5)
            ScrollView {
                VStack(alignment: .leading, spacing: 1) {
                    ForEach(StarNotes.groups, id: \.0) { g in
                        let items = g.1.filter { search.isEmpty || $0.contains(search) }
                        if !items.isEmpty {
                            Text(g.0).font(Font.zCaptionStrong).foregroundStyle(Color.zText3)
                                .padding(.horizontal, 10).padding(.top, 10).padding(.bottom, 4)
                                .id(g.0)
                            ForEach(items, id: \.self) { k in
                                Button { pick(k) } label: {
                                    HStack {
                                        Image(systemName: Self.icons(k).first ?? "circle")
                                            .font(Font.zCaption).foregroundStyle(Color.zText).frame(width: 18)
                                        Text(k).font(Font.zInput).foregroundStyle(Color.zText)
                                        Spacer()
                                        if notes.isCustom(k) { Circle().fill(Color.zAccent).frame(width: 6, height: 6).help("已自己改寫") }
                                    }
                                    .padding(.horizontal, 12).frame(height: 38)
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
    }

    private var editor: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                HStack(alignment: .firstTextBaseline) {
                    Text(key).font(.zTitle).foregroundStyle(Color.zText)
                    Text(notes.isCustom(key) ? "已自己改寫" : "預設內容").font(Font.zCaption).foregroundStyle(Color.zText3)
                    Spacer()
                    if StarNotes.isDoc(key) {
                        Button(editingDoc ? "完成" : "編輯") { withAnimation(Motion.fast) { editingDoc.toggle() } }
                            .buttonStyle(.plain).font(Font.zCallout).foregroundStyle(Color.zAccent)
                            .padding(.trailing, 8)
                    }
                    if notes.isCustom(key) {
                        Button("還原成預設") { notes.reset(key); draft = notes.note(key); Toast.show("「\(key)」已還原成預設") }
                            .buttonStyle(.plain).font(Font.zCallout).foregroundStyle(Color.zAccent)
                    }
                }
                .padding(.bottom, 4)
                let doc = StarNotes.isDoc(key)
                Text(doc ? "參考內容，可以自己改寫。改了會自動存。" : "點宮位時，右側會顯示這顆星的總論和「落在這一宮」的意思。改了會自動存。")
                    .font(Font.zCallout).foregroundStyle(Color.zText3).padding(.bottom, 16)

                if doc && !editingDoc {
                    DocView(text: draft.summary)
                        .padding(.bottom, 18)
                } else {
                    label(doc ? "內容" : "總論")
                    if doc { Text("格式：「## 」開頭是小標題、「・」開頭是條列、用「｜」隔開是表格（第一列是表頭）。").font(Font.zCaption).foregroundStyle(Color.zText3).padding(.bottom, 6) }
                    field(Binding(get: { draft.summary }, set: { draft.summary = $0; commit() }), minH: doc ? 320 : 110)
                        .padding(.bottom, 18)
                }

                if !doc {
                    label("落在各宮")
                    ForEach(StarNotes.palaceKeys, id: \.self) { pk in
                        HStack(alignment: .top, spacing: 10) {
                            Text(pk).font(Font.zReadStrong).foregroundStyle(Color.wmRed).frame(width: 22).padding(.top, 9)
                            field(Binding(get: { draft.palaces[pk] ?? "" }, set: { draft.palaces[pk] = $0; commit() }), minH: 36)
                        }
                        .padding(.bottom, 8)
                    }
                }
            }
            .frame(maxWidth: 760, alignment: .leading)
            .padding(.horizontal, 28).padding(.vertical, 20)
            .frame(maxWidth: .infinity, alignment: .leading)   // 貼著左邊列表，不置中
        }
    }

    private func label(_ t: String) -> some View {
        Text(t).font(Font.zBodyStrong).foregroundStyle(Color.zText2).padding(.bottom, 6)
    }

    private func field(_ b: Binding<String>, minH: CGFloat) -> some View {
        TextEditor(text: b)
            .font(Font.zRead)
            .scrollContentBackground(.hidden)
            .frame(minHeight: minH)
            .fixedSize(horizontal: false, vertical: true)
            .padding(6)
            .background(RoundedRectangle(cornerRadius: 8).fill(Color.zCard))
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.zLine))
    }

    private func pick(_ k: String) {
        key = k
        editingDoc = false
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

/// 參考文件的排版：「## 」小標題一段一張卡片（寬的時候兩欄）、「・鍵：值」左標籤右內文、「A｜B」表格、數字步驟
struct DocView: View {
    let text: String

    private enum Block { case bullet(String), step(String), table([[String]]), para(String) }
    private struct Section: Identifiable { let id: Int; let title: String?; var blocks: [Block] }

    private var sections: [Section] {
        var out: [Section] = []
        var cur = Section(id: 0, title: nil, blocks: [])
        var rows: [[String]] = []
        func flush() { if !rows.isEmpty { cur.blocks.append(.table(rows)); rows = [] } }
        for raw in text.components(separatedBy: "\n") {
            let l = raw.trimmingCharacters(in: .whitespaces)
            if l.contains("｜") { rows.append(l.components(separatedBy: "｜")); continue }
            flush()
            if l.isEmpty { continue }
            if l.hasPrefix("## ") {
                if cur.title != nil || !cur.blocks.isEmpty { out.append(cur) }
                cur = Section(id: out.count, title: String(l.dropFirst(3)), blocks: [])
            } else if l.hasPrefix("・") { cur.blocks.append(.bullet(String(l.dropFirst()))) }
            else if l.first?.isNumber == true, l.contains(".") { cur.blocks.append(.step(l)) }
            else { cur.blocks.append(.para(l)) }
        }
        flush()
        if cur.title != nil || !cur.blocks.isEmpty { out.append(cur) }
        return out
    }

    var body: some View {
        let secs = sections
        let intro = secs.first?.title == nil ? secs.first : nil
        let rest = secs.filter { $0.title != nil }
        // 有表格的段落獨佔一整行；其他小卡寬的時候排兩欄
        let wide = rest.filter { $0.blocks.contains { if case .table = $0 { true } else { false } } }.map(\.id)
        VStack(alignment: .leading, spacing: 16) {
            if let intro { blocks(intro.blocks) }
            ForEach(rest.filter { wide.contains($0.id) }) { card($0) }
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 340), spacing: 16, alignment: .top)], alignment: .leading, spacing: 16) {
                ForEach(rest.filter { !wide.contains($0.id) }) { card($0) }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .textSelection(.enabled)
    }

    private func card(_ s: Section) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            if let t = s.title {
                HStack(spacing: 8) {
                    // 「XX化祿」這類標題：前面加上跟盤面一樣的四化方塊
                    if let m = Mutagen.allCases.first(where: { t.hasSuffix("化" + $0.rawValue) }) {
                        Text(m.rawValue).font(Font.zCalloutStrong).foregroundStyle(Color.zOnColor)
                            .frame(width: 22, height: 22).background(RoundedRectangle(cornerRadius: 5).fill(m.fill))
                    }
                    Text(t).font(Font.zReadTitle).foregroundStyle(Color.zText)
                }
            }
            blocks(s.blocks)
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .background(RoundedRectangle(cornerRadius: 14).fill(Color.zCard))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.zLine))
    }

    @ViewBuilder
    private func blocks(_ bs: [Block]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            ForEach(Array(bs.enumerated()), id: \.offset) { _, b in
                switch b {
                case .bullet(let t): bullet(t)
                case .step(let t):
                    let parts = t.split(separator: ".", maxSplits: 1).map(String.init)
                    HStack(alignment: .firstTextBaseline, spacing: 10) {
                        Text(parts[0]).font(Font.zCalloutStrong.monospacedDigit()).foregroundStyle(Color.zOnColor)
                            .frame(width: 20, height: 20).background(Circle().fill(Color.zText))
                        Text(parts.count > 1 ? parts[1].trimmingCharacters(in: .whitespaces) : "").font(Font.zRead).foregroundStyle(Color.zText)
                    }
                case .table(let rows): table(rows)
                case .para(let t):
                    Text(t).font(Font.zRead).foregroundStyle(Color.zText2).lineSpacing(4).fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }

    /// 「鍵：值」：左邊灰色小標籤、右邊內文；沒有鍵就是一般條列
    @ViewBuilder
    private func bullet(_ t: String) -> some View {
        let parts = t.split(separator: "：", maxSplits: 1).map(String.init)
        if parts.count == 2 && parts[0].count <= 8 {
            VStack(alignment: .leading, spacing: 3) {
                Text(parts[0]).font(Font.zCalloutStrong).foregroundStyle(Color.zText3)
                Text(parts[1]).font(Font.zRead).foregroundStyle(Color.zText).lineSpacing(4).fixedSize(horizontal: false, vertical: true)
            }
        } else {
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Circle().fill(Color.zText3).frame(width: 5, height: 5).alignmentGuide(.firstTextBaseline) { $0[.bottom] + 5 }
                Text(t).font(Font.zRead).foregroundStyle(Color.zText).lineSpacing(4).fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private func table(_ rows: [[String]]) -> some View {
        let cols = rows.map(\.count).max() ?? 1
        return Grid(alignment: .leading, horizontalSpacing: 18, verticalSpacing: 0) {
            ForEach(Array(rows.enumerated()), id: \.offset) { r, row in
                GridRow {
                    ForEach(0..<cols, id: \.self) { c in
                        Text(c < row.count ? row[c] : "")
                            .font(r == 0 ? Font.zCalloutStrong : (c == 0 ? Font.zReadStrong : Font.zRead))
                            .foregroundStyle(r == 0 ? Color.zText3 : (c == 0 ? Color.zText : Color.zText2))
                            .fixedSize(horizontal: c == 0, vertical: true)
                            .padding(.vertical, 9)
                    }
                }
                if r < rows.count - 1 {
                    Rectangle().fill(Color.zLine).frame(height: 0.5).gridCellColumns(cols)
                }
            }
        }
    }
}
