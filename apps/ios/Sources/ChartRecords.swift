import SwiftUI
import PhotosUI

/// 命盤頁最下面（運限表底下）：算命的人記錄這位命主——備註＋照片。
/// 資料存在 Person.notes／Person.photos，跟 Mac 右側的「備註」「照片與附件」是同一份
struct ChartRecords: View {
    let personID: UUID
    @EnvironmentObject private var store: Store
    @State private var draft = ""
    @State private var item: PhotosPickerItem?
    @State private var viewing: PhotoItem?
    @FocusState private var focused: Bool

    private var person: Person? { store.people.first { $0.id == personID } }

    var body: some View {
        if let p = person {
            VStack(alignment: .leading, spacing: 24) {
                notes(p)
                photos(p)
            }
            .fullScreenCover(item: $viewing) { PhotoViewer(name: $0.name) }
        }
    }

    // MARK: 備註

    private func notes(_ p: Person) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            header("備註", count: p.notes.count)
            HStack(alignment: .bottom, spacing: 8) {
                TextField("記下這次看盤的重點…", text: $draft, axis: .vertical)
                    .lineLimit(1...6)
                    .focused($focused)
                    .zText(.body)
                    .padding(.horizontal, 14).padding(.vertical, 11)
                    .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Color.zHover))
                if !draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Button(action: addNote) {
                        Image(systemName: "arrow.up").font(.system(size: 15, weight: .bold)).foregroundStyle(Color.zBg)
                            .frame(width: 40, height: 40).background(Circle().fill(Color.zText))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("新增備註")
                    .transition(.scale.combined(with: .opacity))
                }
            }
            .animation(Motion.fast, value: draft.isEmpty)
            ForEach(p.notes.reversed()) { n in
                VStack(alignment: .leading, spacing: 4) {
                    Text(n.at, format: .dateTime.year().month().day().hour().minute())
                        .zText(.footnote).foregroundStyle(Color.zText3)
                    Text(n.text).zText(.body).foregroundStyle(Color.zText)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .textSelection(.enabled)
                }
                .padding(.vertical, 6)
                .contentShape(Rectangle())
                .contextMenu {
                    Button("拷貝", systemImage: "doc.on.doc") { UIPasteboard.general.string = n.text }
                    Button("刪除", systemImage: "trash", role: .destructive) { deleteNote(n.id) }
                }
                .transition(.opacity.combined(with: .offset(y: -6)))
            }
        }
    }

    private func addNote() {
        let t = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !t.isEmpty, var p = person else { return }
        withAnimation(Motion.base) { p.notes.append(Note(text: t)); store.update(p) }
        draft = ""
        Platform.haptic(.alignment)
    }

    private func deleteNote(_ id: UUID) {
        guard var p = person else { return }
        withAnimation(Motion.base) { p.notes.removeAll { $0.id == id }; store.update(p) }
    }

    // MARK: 照片

    private func photos(_ p: Person) -> some View {
        let list = p.photos ?? []
        return VStack(alignment: .leading, spacing: 10) {
            header("照片", count: list.count)
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: 3), spacing: 6) {
                PhotosPicker(selection: $item, matching: .images) {
                    RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Color.zHover)
                        .aspectRatio(1, contentMode: .fit)
                        .overlay {
                            VStack(spacing: 4) {
                                Image(systemName: "plus").font(.system(size: 20, weight: .medium))
                                Text("新增照片").zText(.footnote)
                            }
                            .foregroundStyle(Color.zText2)
                        }
                }
                .buttonStyle(.plain)
                ForEach(list, id: \.self) { name in
                    Button { viewing = PhotoItem(name: name) } label: {
                        Color.clear.aspectRatio(1, contentMode: .fit)
                            .overlay { thumb(name) }
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }
                    .buttonStyle(.plain)
                    .contextMenu {
                        Button("刪除照片", systemImage: "trash", role: .destructive) { deletePhoto(name) }
                    }
                }
            }
        }
        .onChange(of: item) { _, it in
            Task {
                guard let data = try? await it?.loadTransferable(type: Data.self), let name = Self.savePhoto(data), var q = person else { return }
                q.photos = (q.photos ?? []) + [name]
                withAnimation(Motion.base) { store.update(q) }
                item = nil
            }
        }
    }

    @ViewBuilder private func thumb(_ name: String) -> some View {
        if let img = UIImage(contentsOfFile: Self.url(name).path) {
            Image(uiImage: img).resizable().scaledToFill()
        } else {
            Color.zHover
        }
    }

    private func deletePhoto(_ name: String) {
        guard var p = person else { return }
        try? FileManager.default.removeItem(at: Self.url(name))
        withAnimation(Motion.base) { p.photos?.removeAll { $0 == name }; store.update(p) }
    }

    private func header(_ t: String, count: Int) -> some View {
        HStack(spacing: 6) {
            Text(t).zText(.headline).foregroundStyle(Color.zText)
            if count > 0 { Text("\(count)").zText(.footnote).foregroundStyle(Color.zText3) }
        }
    }

    // MARK: 檔案（跟 Mac 一樣放 media/）

    static func url(_ name: String) -> URL { Store.dataDir.appendingPathComponent("media").appendingPathComponent(name) }

    /// 長邊縮到 2000、存成 JPEG
    static func savePhoto(_ data: Data) -> String? {
        guard let img = UIImage(data: data) else { return nil }
        let scale = min(1, 2000 / max(img.size.width, img.size.height))
        let size = CGSize(width: img.size.width * scale, height: img.size.height * scale)
        let out = UIGraphicsImageRenderer(size: size).image { _ in img.draw(in: CGRect(origin: .zero, size: size)) }
        guard let jpg = out.jpegData(compressionQuality: 0.85) else { return nil }
        let dir = Store.dataDir.appendingPathComponent("media", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let name = "photo-" + UUID().uuidString + ".jpg"
        guard (try? jpg.write(to: dir.appendingPathComponent(name))) != nil else { return nil }
        return name
    }

    struct PhotoItem: Identifiable { let name: String; var id: String { name } }
}

/// 看大圖：黑底、兩指縮放、點一下或往下滑關掉
private struct PhotoViewer: View {
    let name: String
    @Environment(\.dismiss) private var dismiss
    @State private var zoom: CGFloat = 1
    @State private var base: CGFloat = 1
    @State private var drag: CGSize = .zero

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            if let img = UIImage(contentsOfFile: ChartRecords.url(name).path) {
                Image(uiImage: img).resizable().scaledToFit()
                    .scaleEffect(zoom)
                    .offset(drag)
                    .gesture(MagnifyGesture()
                        .onChanged { zoom = max(1, min(4, base * $0.magnification)) }
                        .onEnded { _ in base = zoom; if zoom < 1.05 { withAnimation(Motion.snap) { zoom = 1; base = 1 } } })
                    .simultaneousGesture(DragGesture()
                        .onChanged { drag = $0.translation }
                        .onEnded { v in
                            if zoom == 1 && v.translation.height > 120 { dismiss() } else { withAnimation(Motion.snap) { drag = .zero } }
                        })
            }
        }
        .overlay(alignment: .topTrailing) {
            Button { dismiss() } label: {
                Image(systemName: "xmark").font(.system(size: 15, weight: .semibold)).foregroundStyle(.white)
                    .frame(width: 44, height: 44).background(Circle().fill(.white.opacity(0.15)))
            }
            .padding(16)
            .accessibilityLabel("關閉")
        }
    }
}
