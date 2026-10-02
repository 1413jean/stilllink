import SwiftUI
import AppKit
import UniformTypeIdentifiers

/// 附件資料夾：~/Library/Application Support/StillLink/media
enum Media {
    static let dir: URL = {
        let d = Store.dataDir.appendingPathComponent("media", isDirectory: true)
        try? FileManager.default.createDirectory(at: d, withIntermediateDirectories: true)
        return d
    }()
    static func url(_ name: String) -> URL { dir.appendingPathComponent(name) }

    static func importFiles(_ urls: [URL]) -> [String] {
        urls.compactMap { src in
            let name = UUID().uuidString + "." + (src.pathExtension.isEmpty ? "jpg" : src.pathExtension)
            return (try? FileManager.default.copyItem(at: src, to: url(name))) != nil ? name : nil
        }
    }
}

/// 右側資訊欄（Codex 右邊那種浮動卡片）：命主資料、照片附件
struct InfoPanel: View {
    @EnvironmentObject var store: Store
    let person: Person
    let chart: Chart?
    @State private var preview: String?
    @State private var dropping = false
    @State private var draft = ""
    @State private var appeared = false
    @FocusState private var draftFocused: Bool

    @AppStorage("nowGender") private var nowGender: Gender = .male
    /// 隱藏生辰（幫客人看盤時不讓旁人看到出生日期時間）；全部命盤共用
    @AppStorage("hideBirth") private var hideBirth = false
    private func mask(_ s: String) -> String { hideBirth ? "••••••" : s }
    private var current: Person { store.people.first { $0.id == person.id } ?? person }
    private var isNow: Bool { person.id == NowChart.id }
    private var isTemp: Bool { !isNow && !store.people.contains { $0.id == person.id } }

    var body: some View {
        VStack(spacing: 12) {
                card("命主資料",
                     action: isNow ? nil : ("square.and.pencil", { NotificationCenter.default.post(name: .editChart, object: person.id) }),
                     actions: [(hideBirth ? "eye.slash" : "eye", hideBirth ? "顯示生辰" : "隱藏生辰",
                                { withAnimation(Motion.fast) { hideBirth.toggle() } })]) {
                    VStack(alignment: .leading, spacing: 7) {
                        HStack(spacing: 10) {
                            AvatarButton(name: Binding(
                                get: { current.avatar },
                                set: { v in
                                    var p = current; p.avatar = v; store.update(p)
                                    if p.id == store.selfID { store.userAvatarRaw = v ?? "" }
                                }), size: 34, enabled: !isNow && !isTemp)
                            VStack(alignment: .leading, spacing: 1) {
                                Text(current.name).font(Font.zHeadline)
                                Text("\(current.gender.rawValue) · \(current.group)\(chart.map { " · " + $0.fiveElementsClass } ?? "")")
                                    .font(Font.zCaption).foregroundStyle(Color.zText3)
                            }
                        }
                        .padding(.bottom, 4)
                        row("calendar", "國曆", mask(chart?.solarDate ?? current.solar))
                        row("moon", "農曆", mask(chart.map { "\($0.lunarDate) \($0.time)" } ?? ""))
                        if let ts = current.trueSolar {
                            row("sun.max", "真太陽時", mask(ts))
                            row("clock", "鐘錶時間", mask(current.clock ?? ""))
                        } else {
                            row("clock", "時辰", mask(ZW.hours[current.hour] + "時"))
                        }
                        if let pl = current.place {
                            row("mappin.and.ellipse", "出生地", pl.name)
                        } else {
                            row("mappin.slash", "出生地", "未填（無法換算真太陽時）")
                        }
                    }
                }

                if isTemp {
                    card("暫時命盤") {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("紫占或反查產生的命盤，不會自動存檔。").font(Font.zCallout).foregroundStyle(Color.zText3)
                            Button("存入命盤") { withAnimation(Motion.base) { store.add(person) } }
                                .buttonStyle(ZPrimaryButton(small: true))
                        }
                    }
                } else if isNow {
                    card("此刻盤") {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("以當下時間排盤，每分鐘自動更新，不會存檔。")
                                .font(Font.zCallout).foregroundStyle(Color.zText3)
                            Picker("", selection: $nowGender) { ForEach(Gender.allCases, id: \.self) { Text($0.rawValue).tag($0) } }
                                .pickerStyle(.segmented).labelsHidden().fixedSize()
                        }
                    }
                } else {
                card("備註") {
                    VStack(alignment: .leading, spacing: 10) {
                        TextField("記下客人的問題或你的觀察…", text: $draft, axis: .vertical)
                            .textFieldStyle(.plain)
                            .lineLimit(2...5)
                            .font(Font.zCallout)
                            .focused($draftFocused)
                            .padding(10)
                            .background(RoundedRectangle(cornerRadius: 9).fill(Color.zBg))
                            .overlay(RoundedRectangle(cornerRadius: 9).stroke(draftFocused ? Color.zGrid : Color.zLine))
                            .onSubmit(addNote)
                        HStack {
                            Spacer()
                            Button("新增備註", action: addNote)
                                .disabled(draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                                .buttonStyle(ZPrimaryButton(small: true))
                        }
                        VStack(alignment: .leading, spacing: 0) {
                            ForEach(current.notes.reversed()) { n in
                                NoteRow(note: n) { deleteNote(n.id) }
                                    .transition(.asymmetric(insertion: .opacity.combined(with: .offset(y: -6)),
                                                            removal: .opacity.combined(with: .scale(scale: 0.98, anchor: .top))))
                            }
                        }
                        .animation(Motion.base, value: current.notes.map(\.id))
                    }
                }

                card("照片與附件", action: ("plus", pickPhotos)) {
                    let photos = current.photos ?? []
                    if photos.isEmpty {
                        VStack(spacing: 6) {
                            Image(systemName: "photo.on.rectangle.angled").font(Font.zIconLarge)
                            Text("拖曳照片到這裡，或按＋加入").font(Font.zCaption)
                        }
                        .foregroundStyle(Color.zText3)
                        .frame(maxWidth: .infinity, minHeight: 86)
                        .background(RoundedRectangle(cornerRadius: 10).strokeBorder(dropping ? Color.zAccent : Color.zLine, style: StrokeStyle(lineWidth: 1, dash: [4, 3])))
                    } else {
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 76), spacing: 6)], spacing: 6) {
                            ForEach(photos, id: \.self) { name in
                                Thumb(name: name)
                                    .onTapGesture { preview = name }
                                    .contextMenu {
                                        Button("移除", role: .destructive) { removePhoto(name) }
                                    }
                            }
                        }
                    }
                }
                .onDrop(of: [.fileURL], isTargeted: $dropping) { providers in
                    for pr in providers {
                        _ = pr.loadObject(ofClass: URL.self) { url, _ in
                            guard let url else { return }
                            DispatchQueue.main.async { addPhotos([url]) }
                        }
                    }
                    return true
                }
                }
        }
        .frame(width: infoPanelWidth)
        .enterFromBelow(appeared, index: 4)
        .onAppear { appeared = true }
        .sheet(item: Binding(get: { preview.map { PreviewItem(name: $0) } }, set: { preview = $0?.name })) { item in
            VStack {
                if let img = NSImage(contentsOf: Media.url(item.name)) {
                    Image(nsImage: img).resizable().scaledToFit()
                }
                Button("關閉") { preview = nil }.keyboardShortcut(.cancelAction).padding(.bottom, 12)
            }
            .frame(minWidth: 520, minHeight: 420)
        }
    }

    private struct PreviewItem: Identifiable { let name: String; var id: String { name } }

    private func card<C: View>(_ title: String, action: (String, () -> Void)? = nil, actions: [(String, String, () -> Void)] = [],
                               @ViewBuilder _ content: () -> C) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 12) {
                Text(title).font(Font.zCalloutStrong).foregroundStyle(Color.zText2)
                Spacer()
                ForEach(Array(actions.enumerated()), id: \.offset) { _, a in
                    Button(action: a.2) { Image(systemName: a.0).font(Font.zCallout).foregroundStyle(Color.zText2) }
                        .buttonStyle(.plain)
                        .help(a.1)
                }
                if let action {
                    Button(action: action.1) { Image(systemName: action.0).font(Font.zCallout).foregroundStyle(Color.zText2) }
                        .buttonStyle(.plain)
                }
            }
            content()
        }
        .padding(14)
        // 陰影只加在卡片底板，不會染到文字；邊框讓層級清楚
        .background(
            RoundedRectangle(cornerRadius: 14).fill(Color.zCard)
                .shadow(color: Color.zShadow.opacity(0.6), radius: 10, y: 3)
        )
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.zLine))
    }

    private func row(_ icon: String, _ label: String, _ value: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Image(systemName: icon).font(Font.zCaption).foregroundStyle(Color.zText3).frame(width: 14)
            Text(label).font(Font.zCallout).foregroundStyle(Color.zText3).frame(width: 62, alignment: .leading)
            Text(value).font(Font.zCallout.monospacedDigit()).foregroundStyle(Color.zText).textSelection(.enabled)
            Spacer(minLength: 0)
        }
    }

    private func addNote() {
        let t = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !t.isEmpty else { return }
        var p = current
        p.notes.append(Note(text: t))
        store.update(p)
        draft = ""
    }

    private func deleteNote(_ id: UUID) {
        var p = current
        p.notes.removeAll { $0.id == id }
        store.update(p)
    }

    private func pickPhotos() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = true
        panel.allowedContentTypes = [.image]
        if panel.runModal() == .OK { addPhotos(panel.urls) }
    }

    private func addPhotos(_ urls: [URL]) {
        var p = current
        p.photos = (p.photos ?? []) + Media.importFiles(urls)
        store.update(p)
    }

    private func removePhoto(_ name: String) {
        var p = current
        p.photos?.removeAll { $0 == name }
        try? FileManager.default.removeItem(at: Media.url(name))
        store.update(p)
    }
}

/// 一則備註：滑過時右上角出現刪除鈕
private struct NoteRow: View {
    let note: Note
    let onDelete: () -> Void
    @State private var hover = false

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            VStack(alignment: .leading, spacing: 3) {
                Text(note.text).font(Font.zCallout).foregroundStyle(Color.zText).textSelection(.enabled)
                    .fixedSize(horizontal: false, vertical: true)
                Text(note.at.formatted(date: .abbreviated, time: .shortened))
                    .font(Font.zMicro).foregroundStyle(Color.zText3)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            Button(action: onDelete) {
                Image(systemName: "trash").font(Font.zCaption).foregroundStyle(Color.zText3)
                    .frame(width: 22, height: 22).contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .help("刪除這則備註")
            .opacity(hover ? 1 : 0)
        }
        .padding(.top, 8)
        .overlay(alignment: .top) { Rectangle().fill(Color.zLine).frame(height: 0.5) }
        .contentShape(Rectangle())
        .onHover { hover = $0 }
        .contextMenu { Button("刪除", role: .destructive, action: onDelete) }
    }
}

private struct Thumb: View {
    let name: String
    var body: some View {
        Group {
            if let img = NSImage(contentsOf: Media.url(name)) {
                Image(nsImage: img).resizable().scaledToFill()
            } else {
                Color.zHover
            }
        }
        .frame(width: 80, height: 80)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.zLine))
        .contentShape(Rectangle())
    }
}
