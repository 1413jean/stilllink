import SwiftUI
import AppKit
import UniformTypeIdentifiers

/// 附件資料夾：~/Library/Application Support/Ziwei/media
enum Media {
    static let dir: URL = {
        let d = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Ziwei/media", isDirectory: true)
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

    private var current: Person { store.people.first { $0.id == person.id } ?? person }

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                card("命主資料") {
                    VStack(alignment: .leading, spacing: 7) {
                        HStack(spacing: 10) {
                            Text(String(current.name.prefix(1)))
                                .font(.serif(16, .medium))
                                .frame(width: 34, height: 34)
                                .background(Circle().fill(Color.zSel))
                            VStack(alignment: .leading, spacing: 1) {
                                Text(current.name).font(.system(size: 14, weight: .medium))
                                Text("\(current.gender.rawValue) · \(current.group)\(chart.map { " · " + $0.fiveElementsClass } ?? "")")
                                    .font(.system(size: 11.5)).foregroundStyle(Color.zText3)
                            }
                        }
                        .padding(.bottom, 4)
                        row("calendar", "國曆", chart?.solarDate ?? current.solar)
                        row("moon", "農曆", chart.map { "\($0.lunarDate) \($0.time)" } ?? "")
                        if let ts = current.trueSolar {
                            row("sun.max", "真太陽時", ts)
                            row("clock", "鐘錶時間", current.clock ?? "")
                        } else {
                            row("clock", "時辰", ZW.hours[current.hour] + "時")
                        }
                        if let pl = current.place {
                            row("mappin.and.ellipse", "出生地", pl.name)
                            row("location", "經緯度", String(format: "%.4f°%@ %.4f°%@", abs(pl.longitude), pl.longitude >= 0 ? "E" : "W",
                                                           abs(pl.latitude), pl.latitude >= 0 ? "N" : "S"))
                        } else {
                            row("mappin.slash", "出生地", "未填（無法換算真太陽時）")
                        }
                        if let chart {
                            row("sparkle", "命主／身主", "\(chart.soul)／\(chart.body)")
                        }
                    }
                }

                card("照片與附件", action: ("plus", pickPhotos)) {
                    let photos = current.photos ?? []
                    if photos.isEmpty {
                        VStack(spacing: 6) {
                            Image(systemName: "photo.on.rectangle.angled").font(.system(size: 20, weight: .light))
                            Text("拖曳照片到這裡，或按＋加入").font(.system(size: 11.5))
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
            .padding(.top, 10)
            .padding(.trailing, 12)
            .padding(.bottom, 16)
        }
        .frame(width: 300)
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

    private func card<C: View>(_ title: String, action: (String, () -> Void)? = nil, @ViewBuilder _ content: () -> C) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(title).font(.system(size: 12, weight: .medium)).foregroundStyle(Color.zText2)
                Spacer()
                if let action {
                    Button(action: action.1) { Image(systemName: action.0).font(.system(size: 12)).foregroundStyle(Color.zText2) }
                        .buttonStyle(.plain)
                }
            }
            content()
        }
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 14).fill(Color.zCard))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.zLine))
    }

    private func row(_ icon: String, _ label: String, _ value: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Image(systemName: icon).font(.system(size: 11)).foregroundStyle(Color.zText3).frame(width: 14)
            Text(label).font(.system(size: 12)).foregroundStyle(Color.zText3).frame(width: 62, alignment: .leading)
            Text(value).font(.system(size: 12.5).monospacedDigit()).foregroundStyle(Color.zText).textSelection(.enabled)
            Spacer(minLength: 0)
        }
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
