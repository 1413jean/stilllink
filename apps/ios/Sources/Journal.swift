import SwiftUI
import PhotosUI

// MARK: - 資料

/// 一則日記：時間、內文、心情、照片（存在資料夾 media/ 底下的檔名）
struct JournalEntry: Codable, Identifiable, Hashable {
    var id = UUID()
    var at = Date()
    var text: String
    var mood: String?
    var star: String?      // 寫的時候的提問主星（標籤顯示「紫微 · 平靜」）
    var photo: String?
}

/// 日記存在 Store 同一個資料夾的 journal.json；照片放 media/
@MainActor
final class JournalStore: ObservableObject {
    @Published var entries: [JournalEntry] = [] { didSet { save() } }
    private let url = Store.dataDir.appendingPathComponent("journal.json")
    static let mediaDir: URL = {
        let d = Store.dataDir.appendingPathComponent("media", isDirectory: true)
        try? FileManager.default.createDirectory(at: d, withIntermediateDirectories: true)
        return d
    }()

    init() {
        if let d = try? Data(contentsOf: url), let list = try? JSONDecoder().decode([JournalEntry].self, from: d) { entries = list }
    }

    func add(_ e: JournalEntry) { entries.insert(e, at: 0) }
    func delete(_ e: JournalEntry) {
        if let p = e.photo { try? FileManager.default.removeItem(at: Self.mediaDir.appendingPathComponent(p)) }
        entries.removeAll { $0.id == e.id }
    }

    private func save() {
        let snapshot = entries, url = url
        DispatchQueue.global(qos: .utility).async {
            if let d = try? JSONEncoder().encode(snapshot) { try? d.write(to: url, options: .atomic) }
        }
    }

    /// 照片縮到長邊 1600、存成 JPEG，回傳檔名
    static func savePhoto(_ data: Data) -> String? {
        guard let img = UIImage(data: data) else { return nil }
        let scale = min(1, 1600 / max(img.size.width, img.size.height))
        let size = CGSize(width: img.size.width * scale, height: img.size.height * scale)
        let out = UIGraphicsImageRenderer(size: size).image { _ in img.draw(in: CGRect(origin: .zero, size: size)) }
        guard let jpg = out.jpegData(compressionQuality: 0.82) else { return nil }
        let name = UUID().uuidString + ".jpg"
        try? jpg.write(to: mediaDir.appendingPathComponent(name))
        return name
    }
}

/// 今日提問：依自己命宮的主星（沒有就用紫微），每天換一題
enum JournalPrompt {
    static let prompts: [String: [String]] = [
        "紫微": ["今天哪一刻讓你覺得平靜？", "今天你替誰撐住了什麼？", "如果今天是你自己的主人，你會怎麼安排？"],
        "天機": ["今天腦袋裡轉最多的念頭是什麼？", "有什麼事你想了很久，今天終於想通？", "今天的計畫有哪裡臨時改變了？"],
        "太陽": ["今天你照亮了誰？", "今天有沒有一件事讓你覺得被看見？", "今天你給出去的，有收回來嗎？"],
        "武曲": ["今天你為了什麼咬牙撐住？", "今天花錢花得開心嗎？", "今天有什麼事是你一個人扛下來的？"],
        "天同": ["今天有什麼小事讓你笑出來？", "今天你有好好休息嗎？", "今天想對自己說一句什麼？"],
        "廉貞": ["今天有什麼情緒很強烈？", "今天你在哪裡堅持了原則？", "今天被什麼吸引了？"],
        "天府": ["今天你守住了什麼？", "今天哪一件事讓你覺得很踏實？", "今天你照顧了誰？"],
        "太陰": ["今天心裡最柔軟的時刻是什麼？", "今天有沒有想起家裡的誰？", "今晚睡前想放下什麼？"],
        "貪狼": ["今天你最想要的是什麼？", "今天有什麼新鮮事讓你心動？", "今天跟誰聊得最開心？"],
        "巨門": ["今天有什麼話想說卻沒說？", "今天你聽到了什麼值得記下的話？", "今天有什麼事讓你起了疑問？"],
        "天相": ["今天你幫誰協調了什麼？", "今天穿得、吃得，讓你舒服嗎？", "今天你為了公平做了什麼？"],
        "天梁": ["今天你給了誰建議？", "今天有誰照顧了你？", "今天有什麼事讓你覺得被保護？"],
        "七殺": ["今天你衝破了什麼？", "今天有什麼事讓你下定決心？", "今天你對什麼說了不？"],
        "破軍": ["今天你丟掉了什麼？", "今天有什麼事想重新來過？", "今天你嘗試了什麼新做法？"],
    ]
    static let moods = ["平靜", "開心", "感恩", "疲累", "焦慮", "低落"]

    @MainActor static func star(for store: Store) -> String {
        let soul = store.me.flatMap { store.soulStars[$0.id] } ?? ""
        return prompts.keys.first { soul.hasPrefix($0) } ?? "紫微"
    }
    static func today(star: String, date: Date = Date()) -> String {
        let list = prompts[star] ?? prompts["紫微"]!
        let day = Calendar.current.ordinality(of: .day, in: .era, for: date) ?? 0
        return list[day % list.count]
    }
}

// MARK: - 畫面

/// 日記分頁（照 Figma Stillink-UI「Journal」71:44）：一週日期條、今日提問卡、時間軸
struct JournalView: View {
    @EnvironmentObject private var store: Store
    @EnvironmentObject private var journal: JournalStore
    @State private var day = Calendar.current.startOfDay(for: Date())
    @State private var writing = false
    @State private var deleting: JournalEntry?

    private let cal = Calendar.current

    var body: some View {
        let star = JournalPrompt.star(for: store)
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("JOURNAL · 日記").zText(.eyebrow).foregroundStyle(Color.zAccent)
                    Text("日記").zText(.titleLarge).foregroundStyle(Color.zText)
                }
                .padding(.bottom, 18)

                weekStrip.padding(.bottom, 20)
                promptCard(star).padding(.bottom, 28)

                Text(dayTitle).zText(.title3).foregroundStyle(Color.zText).padding(.bottom, 14)
                let list = entries(on: day)
                if list.isEmpty {
                    Text(cal.isDateInToday(day) ? "今天還沒有紀錄。寫下一件小事就好。" : "這天沒有紀錄。")
                        .zText(.callout).foregroundStyle(Color.zText3)
                        .padding(.vertical, 8)
                } else {
                    ForEach(Array(list.enumerated()), id: \.element.id) { i, e in
                        EntryRow(entry: e, last: i == list.count - 1)
                            .contextMenu {
                                Button("刪除", systemImage: "trash", role: .destructive) { deleting = e }
                            }
                    }
                }
            }
            .padding(.horizontal, 24)
            .padding(.top, 20)
            .padding(.bottom, 24)
        }
        .background(Color.zBg)
        .zEdgeFades()
        .toolbar(.hidden, for: .navigationBar)
        .sheet(isPresented: $writing) { NewEntrySheet(star: star, prompt: JournalPrompt.today(star: star)) }
        .confirmationDialog("刪除這則日記？", isPresented: Binding(get: { deleting != nil }, set: { if !$0 { deleting = nil } }),
                            titleVisibility: .visible) {
            Button("刪除", role: .destructive) { if let e = deleting { withAnimation { journal.delete(e) } }; deleting = nil }
        }
    }

    private var dayTitle: String {
        if cal.isDateInToday(day) { return "今天" }
        if cal.isDateInYesterday(day) { return "昨天" }
        let c = cal.dateComponents([.month, .day], from: day)
        return "\(c.month!) 月 \(c.day!) 日"
    }

    private func entries(on d: Date) -> [JournalEntry] {
        journal.entries.filter { cal.isDate($0.at, inSameDayAs: d) }.sorted { $0.at > $1.at }
    }

    /// 這一週（週一到週日）：選到的那天黑底，有紀錄的日子下面一個紅點，未來的日子淡色不能點
    private var weekStrip: some View {
        let today = cal.startOfDay(for: Date())
        let weekday = (cal.component(.weekday, from: today) + 5) % 7   // 週一＝0
        let monday = cal.date(byAdding: .day, value: -weekday, to: today)!
        let names = ["一", "二", "三", "四", "五", "六", "日"]
        return HStack(spacing: 0) {
            ForEach(0..<7, id: \.self) { i in
                let d = cal.date(byAdding: .day, value: i, to: monday)!
                let on = cal.isDate(d, inSameDayAs: day)
                let future = d > today
                let has = !entries(on: d).isEmpty
                Button {
                    Platform.haptic(.alignment)
                    withAnimation(Motion.base) { day = d }
                } label: {
                    VStack(spacing: 6) {
                        Text(names[i]).zText(.caption1)
                            .foregroundStyle(on ? Color.zBg.opacity(0.7) : Color.zText3)
                        Text("\(cal.component(.day, from: d))").zText(.title3)
                            .foregroundStyle(on ? Color.zBg : future ? Color.zText3 : Color.zText)
                        Circle().fill(has ? Color.wmRed : .clear).frame(width: 5, height: 5)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(on ? Color.zText : .clear))
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .disabled(future)
            }
        }
    }

    private func promptCard(_ star: String) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("今日提問 · \(star)").zText(.eyebrow).foregroundStyle(Color.zBg.opacity(0.6)).padding(.bottom, 8)
            Text(JournalPrompt.today(star: star)).zText(.title2).fontWeight(.regular)
                .foregroundStyle(Color.zBg).padding(.bottom, 18)
            Button { writing = true } label: {
                Label("寫一則", systemImage: "plus")
                    .zText(.bodyStrong)
                    .foregroundStyle(Color.zText)
                    .padding(.horizontal, 20)
                    .frame(height: 44)
                    .background(Capsule().fill(Color.zBg))
            }
            .buttonStyle(.plain)
        }
        .padding(22)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 26, style: .continuous).fill(Color.zText))
    }
}

/// 時間軸的一則：左邊紅點＋直線，右邊時間、照片、內文、標籤
private struct EntryRow: View {
    let entry: JournalEntry
    let last: Bool

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            VStack(spacing: 0) {
                Circle().fill(Color.wmRed).frame(width: 9, height: 9).padding(.top, 5)
                if !last { Rectangle().fill(Color.zLine).frame(width: 1).frame(maxHeight: .infinity) }
            }
            .frame(width: 9)
            VStack(alignment: .leading, spacing: 10) {
                Text(entry.at, format: .dateTime.hour().minute()).zText(.footnote).foregroundStyle(Color.zText3)
                if let p = entry.photo, let img = UIImage(contentsOfFile: JournalStore.mediaDir.appendingPathComponent(p).path) {
                    Image(uiImage: img).resizable().scaledToFill()
                        .frame(maxWidth: .infinity).frame(height: 160)
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
                Text(entry.text).zText(.body).foregroundStyle(Color.zText)
                    .frame(maxWidth: .infinity, alignment: .leading)
                if let tag = [entry.star, entry.mood].compactMap({ $0 }).joined(separator: " · ").nilIfEmpty {
                    Text(tag).zText(.footnote).foregroundStyle(Color.zText2)
                        .padding(.horizontal, 10).padding(.vertical, 4)
                        .background(Capsule().fill(Color.zHover))
                }
            }
            .padding(.bottom, last ? 0 : 26)
        }
    }
}

private extension String {
    var nilIfEmpty: String? { isEmpty ? nil : self }
}

/// 寫一則日記：提問、內文、心情、照片
private struct NewEntrySheet: View {
    let star: String
    let prompt: String
    @EnvironmentObject private var journal: JournalStore
    @Environment(\.dismiss) private var dismiss
    @State private var text = ""
    @State private var mood: String?
    @State private var item: PhotosPickerItem?
    @State private var photoData: Data?
    @FocusState private var focused: Bool

    var body: some View {
        NavigationStack {
            ZForm {
                Section {
                    TextField("請輸入", text: $text, axis: .vertical)
                        .lineLimit(5...12)
                        .focused($focused)
                }
                Section("心情") {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(JournalPrompt.moods, id: \.self) { m in
                                Button { mood = mood == m ? nil : m } label: {
                                    Text(m).zText(.callout)
                                        .foregroundStyle(mood == m ? Color.zBg : Color.zText)
                                        .padding(.horizontal, 14).frame(height: 34)
                                        .background(Capsule().fill(mood == m ? Color.zText : Color.zHover))
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
                Section("照片") {
                    PhotosPicker(selection: $item, matching: .images) {
                        Label(photoData == nil ? "從相簿選一張" : "換一張", systemImage: "photo")
                    }
                    if let d = photoData, let img = UIImage(data: d) {
                        Image(uiImage: img).resizable().scaledToFill()
                            .frame(height: 180).frame(maxWidth: .infinity)
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                            .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                    }
                }
            }
            .navigationTitle("日記")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("取消") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("儲存", action: save)
                        .disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && photoData == nil)
                }
            }
            .onChange(of: item) { _, it in
                Task { photoData = try? await it?.loadTransferable(type: Data.self) }
            }
            .onAppear { focused = true }
        }
    }

    private func save() {
        let e = JournalEntry(text: text.trimmingCharacters(in: .whitespacesAndNewlines), mood: mood, star: star,
                             photo: photoData.flatMap(JournalStore.savePhoto))
        withAnimation { journal.add(e) }
        dismiss()
    }
}
