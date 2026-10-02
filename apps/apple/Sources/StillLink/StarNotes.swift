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

    var body: some View {
        let sf = ZW.sanFang(index)   // [本宮, 三合, 三合, 對宮]
        let parts: [(String, Int)] = [("本宮", sf[0]), ("對宮", sf[3]), ("三合", sf[1]), ("三合", sf[2])]
        VStack(alignment: .leading, spacing: 14) {
            ForEach(parts, id: \.1) { label, i in
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 6) {
                        Text(label).font(Font.zCaptionStrong).foregroundStyle(Color.zOnColor)
                            .padding(.horizontal, 6).frame(height: 18)
                            .background(Capsule().fill(label == "本宮" ? Color.zAccent : Color.zText3))
                        Text(chart.palaces[i].name).font(Font.zCalloutStrong).foregroundStyle(Color.wmRed)
                    }
                    PalaceNotes(palace: chart.palaces[i])
                }
            }
        }
    }
}

/// 一個宮位裡每顆星的筆記
private struct PalaceNotes: View {
    @ObservedObject private var notes = StarNotes.shared
    @Environment(\.zSettings) private var settings
    let palace: Palace
    @State private var expanded: Set<String> = []

    var body: some View {
        let pk = StarNotes.palaceKey(palace.name)
        let list = notes.keys(for: palace)
        VStack(alignment: .leading, spacing: 8) {
            if list.isEmpty {
                Text(palace.stars.isEmpty ? "空宮" : "沒有星曜筆記").font(Font.zCaption).foregroundStyle(Color.zText3)
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
                                        Text(k).font(Font.zBody).foregroundStyle(Color.zText)
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
                            Text(pk).font(Font.zBodyStrong).foregroundStyle(Color.wmRed).frame(width: 22).padding(.top, 8)
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

/// 參考文件的排版：「## 」小標題、「・」條列（「鍵：值」的鍵加粗）、「A｜B」表格、數字開頭的步驟、空行分段
struct DocView: View {
    let text: String

    private enum Block { case heading(String), bullet(String), step(String), table([[String]]), para(String), gap }

    private var blocks: [Block] {
        var out: [Block] = []
        var rows: [[String]] = []
        func flush() { if !rows.isEmpty { out.append(.table(rows)); rows = [] } }
        for raw in text.components(separatedBy: "\n") {
            let l = raw.trimmingCharacters(in: .whitespaces)
            if l.contains("｜") { rows.append(l.components(separatedBy: "｜")); continue }
            flush()
            if l.isEmpty { out.append(.gap) }
            else if l.hasPrefix("## ") { out.append(.heading(String(l.dropFirst(3)))) }
            else if l.hasPrefix("・") { out.append(.bullet(String(l.dropFirst()))) }
            else if l.first?.isNumber == true, l.contains(".") { out.append(.step(l)) }
            else { out.append(.para(l)) }
        }
        flush()
        return out
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            ForEach(Array(blocks.enumerated()), id: \.offset) { i, b in
                switch b {
                case .heading(let t):
                    Text(t).font(Font.zBodyStrong).foregroundStyle(Color.zText).padding(.top, i == 0 ? 0 : 10)
                case .bullet(let t):
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Circle().fill(Color.zText3).frame(width: 4, height: 4).alignmentGuide(.firstTextBaseline) { $0[.bottom] + 4 }
                        keyed(t)
                    }
                case .step(let t):
                    let parts = t.split(separator: ".", maxSplits: 1).map(String.init)
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Text(parts[0]).font(Font.zCalloutStrong.monospacedDigit()).foregroundStyle(Color.zAccent).frame(width: 16, alignment: .trailing)
                        Text(parts.count > 1 ? parts[1].trimmingCharacters(in: .whitespaces) : "").font(Font.zCallout).foregroundStyle(Color.zText)
                    }
                case .table(let rows):
                    table(rows)
                case .para(let t):
                    Text(t).font(Font.zCallout).foregroundStyle(Color.zText2).fixedSize(horizontal: false, vertical: true)
                case .gap:
                    Color.clear.frame(height: 2)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .textSelection(.enabled)
    }

    /// 「鍵：值」：鍵加粗
    private func keyed(_ t: String) -> some View {
        let parts = t.split(separator: "：", maxSplits: 1).map(String.init)
        let text: Text = parts.count == 2 && parts[0].count <= 12
            ? Text(parts[0] + "：").font(Font.zCalloutStrong).foregroundColor(Color.zText) + Text(parts[1]).font(Font.zCallout).foregroundColor(Color.zText)
            : Text(t).font(Font.zCallout).foregroundColor(Color.zText)
        return text.fixedSize(horizontal: false, vertical: true)
    }

    private func table(_ rows: [[String]]) -> some View {
        let cols = rows.map(\.count).max() ?? 1
        return Grid(alignment: .leading, horizontalSpacing: 14, verticalSpacing: 0) {
            ForEach(Array(rows.enumerated()), id: \.offset) { r, row in
                GridRow {
                    ForEach(0..<cols, id: \.self) { c in
                        Text(c < row.count ? row[c] : "")
                            .font(r == 0 ? Font.zCaptionStrong : Font.zCallout)
                            .foregroundStyle(r == 0 ? Color.zText3 : (c == 0 ? Color.zText : Color.zText2))
                            .fixedSize(horizontal: c == 0, vertical: true)
                            .padding(.vertical, 7)
                    }
                }
                // 整列一條分隔線（最後一列不畫）
                if r < rows.count - 1 {
                    Rectangle().fill(Color.zLine).frame(height: 0.5).gridCellColumns(cols)
                }
            }
        }
        .padding(.horizontal, 12).padding(.vertical, 4)
        .background(RoundedRectangle(cornerRadius: 10).fill(Color.zCard))
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.zLine))
        .padding(.vertical, 4)
    }
}
