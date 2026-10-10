import SwiftUI

/// 星曜筆記（照 Mac 右側面板，iPhone 放底下）：命盤下方浮著一條「宮位摘要」，
/// 點了從底部拉出半頁筆記（三方四正的星曜、四化、夾宮）；半頁時還能點盤面換宮位，筆記跟著換；
/// 往上拉成整頁、點星曜看單獨介紹、可以編輯。內容元件（StarNotesCard、StarDetailView）跟 Mac 共用
struct NotesBar: View {
    let title: String
    let stars: String
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: "book.closed").font(.system(size: 14, weight: .medium)).foregroundStyle(Color.zText2)
                Text(title).zText(.subheadlineStrong).foregroundStyle(Color.zText)
                if !stars.isEmpty { Text(stars).zText(.subheadline).foregroundStyle(Color.zText2).lineLimit(1) }
                Image(systemName: "chevron.up").font(.system(size: 11, weight: .semibold)).foregroundStyle(Color.zText3)
            }
            .padding(.horizontal, 18).frame(height: 44)
            .zFloatingCapsule()
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(title)星曜筆記")
    }
}

struct NotesSheet: View {
    let chart: Chart
    let index: Int
    var includeBirth = true
    var scopes: [(String, [String])] = []
    var clamps: [Clamp] = []
    var names: [String]? = nil
    var prefix = ""
    @State private var path: [Detail] = []
    @State private var editing: String?
    @Environment(\.dismiss) private var dismiss

    struct Detail: Hashable { let key: String; let palace: String }

    private var title: String { (names.map { prefix + $0[index] } ?? chart.palaces[index].name) + " · 三方四正" }

    var body: some View {
        NavigationStack(path: $path) {
            ScrollView {
                StarNotesCard(chart: chart, index: index, includeBirth: includeBirth, scopes: scopes, clamps: clamps,
                              names: names, prefix: prefix, onOpen: { path.append(Detail(key: $0, palace: $1)) })
                    .padding(.horizontal, 20).padding(.top, 4).padding(.bottom, 32)
            }
            .background(Color.zBg)
            .zEdgeFades()
            .zSheetBar(title, done: { dismiss() })
            .navigationDestination(for: Detail.self) { d in
                ScrollView {
                    StarDetailView(key: d.key, palaceName: d.palace, onBack: { _ = path.popLast() }, showHeader: false)
                        .padding(.horizontal, 20).padding(.top, 4).padding(.bottom, 32)
                }
                .background(Color.zBg)
                .zEdgeFades()
                // 系統導覽列：返回、標題（星名）、右上編輯
                .navigationTitle(d.key)
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button { editing = d.key } label: { Image(systemName: "square.and.pencil") }
                            .accessibilityLabel("編輯筆記")
                    }
                }
            }
        }
        .tint(Color.zText)
        // StarDetailView 的「編輯筆記」按鈕（Mac 是開筆記頁）：這裡改開編輯表單
        .onReceive(NotificationCenter.default.publisher(for: .openStarNotes)) { n in editing = n.object as? String }
        .sheet(item: Binding(get: { editing.map(EditKey.init) }, set: { editing = $0?.key })) { NoteEditor(key: $0.key) }
    }

    private struct EditKey: Identifiable { let key: String; var id: String { key } }
}

/// 編輯一顆星的筆記：總論＋十二宮；存的是自己的版本，可以還原成預設
struct NoteEditor: View {
    let key: String
    @ObservedObject private var notes = StarNotes.shared
    @Environment(\.dismiss) private var dismiss
    @State private var draft = StarNote()
    @State private var loaded = false

    var body: some View {
        NavigationStack {
            ZForm {
                Section("總論") {
                    TextField("這顆星的重點、個性…", text: $draft.summary, axis: .vertical).lineLimit(3...12)
                }
                if !StarNotes.isDoc(key) {
                    Section("落在各宮") {
                        ForEach(StarNotes.palaceKeys, id: \.self) { k in
                            HStack(alignment: .firstTextBaseline, spacing: 12) {
                                Text(k).zText(.bodyStrong).foregroundStyle(Color.zText).frame(width: 20)
                                TextField("落\(k)宮的意思", text: Binding(get: { draft.palaces[k] ?? "" },
                                                                        set: { draft.palaces[k] = $0.isEmpty ? nil : $0 }),
                                          axis: .vertical).lineLimit(1...8)
                            }
                        }
                    }
                }
                if notes.isCustom(key) {
                    Section {
                        Button("還原成預設內容", role: .destructive) { notes.reset(key); dismiss() }
                    }
                }
            }
            .zSheetBar(key, done: { notes.set(key, draft); Platform.haptic(.success); dismiss() }, confirm: "儲存", cancel: { dismiss() })
            .onAppear { if !loaded { draft = notes.note(key); loaded = true } }
        }
        .tint(Color.zText)
    }
}
