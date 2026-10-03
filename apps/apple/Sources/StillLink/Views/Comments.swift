import SwiftUI

/// 盤上的備註（像 Figma 留言）：點盤面任一處放一個圖釘，寫下備註；點圖釘打開對話串，可以回覆、標成已解決、刪除
struct CommentThread: Codable, Identifiable, Equatable {
    struct Message: Codable, Identifiable, Equatable {
        var id = UUID()
        var text: String
        var date = Date()
    }
    var id = UUID()
    var point: CGPoint          // 0～1，相對盤面大小
    var messages: [Message]
    var resolved = false
}

/// 每張命盤的備註，存在資料夾的 comments.json（命盤 id → 備註）
@MainActor
final class CommentStore: ObservableObject {
    static let shared = CommentStore()
    @Published private(set) var threads: [UUID: [CommentThread]] = [:]
    private let url = Store.dataDir.appendingPathComponent("comments.json")

    private init() {
        if let d = try? Data(contentsOf: url), let v = try? JSONDecoder().decode([String: [CommentThread]].self, from: d) {
            threads = Dictionary(uniqueKeysWithValues: v.compactMap { k, t in UUID(uuidString: k).map { ($0, t) } })
        }
    }

    func list(_ id: UUID) -> [CommentThread] { threads[id] ?? [] }

    func update(_ id: UUID, _ change: (inout [CommentThread]) -> Void) {
        var t = list(id)
        change(&t)
        threads[id] = t.isEmpty ? nil : t
        let out = Dictionary(uniqueKeysWithValues: threads.map { ($0.key.uuidString, $0.value) })
        if let d = try? JSONEncoder().encode(out) { try? d.write(to: url, options: .atomic) }
    }
}

/// 疊在盤面上的備註層：圖釘永遠可以點；選到「備註」工具時，點空白處新增
struct CommentLayer: View {
    let chartID: UUID
    let active: Bool                  // 目前是不是備註工具
    @EnvironmentObject private var app: Store
    @ObservedObject private var store = CommentStore.shared
    @State private var draft: CGPoint?        // 新增中的圖釘位置
    @State private var draftText = ""
    @State private var open: UUID?            // 打開的對話串
    @State private var reply = ""
    @State private var undo: (thread: CommentThread, label: String)?
    @FocusState private var focused: Bool

    private let pin: CGFloat = 26
    private let cardW: CGFloat = 280

    var body: some View {
        GeometryReader { g in
            let size = g.size
            ZStack(alignment: .topLeading) {
                // 備註工具：點空白處放新圖釘；其他情況點空白處關掉打開的對話串
                Color.clear.contentShape(Rectangle())
                    .onTapGesture(coordinateSpace: .local) { p in
                        if open != nil { withAnimation(Motion.fast) { open = nil } ; return }
                        guard active else { return }
                        withAnimation(Motion.fast) { draft = CGPoint(x: p.x / size.width, y: p.y / size.height); draftText = "" }
                        DispatchQueue.main.async { focused = true }
                    }
                    .allowsHitTesting(active || open != nil)

                ForEach(store.list(chartID).filter { !$0.resolved }) { t in
                    pinView(selected: open == t.id)
                        .position(x: t.point.x * size.width + pin / 2, y: t.point.y * size.height - pin / 2)
                        .onTapGesture { withAnimation(Motion.fast) { open = open == t.id ? nil : t.id; draft = nil; reply = "" } }
                        .help(t.messages.first?.text ?? "")
                }

                if let d = draft {
                    composer(at: d, size: size)
                }
                if let id = open, let t = store.list(chartID).first(where: { $0.id == id }) {
                    threadCard(t, size: size)
                }
            }
            .overlay(alignment: .bottom) { undoBar }
        }
        .onChange(of: active) { a in if !a { draft = nil } }
        // 驗證用：ZIWEI_OPEN_COMMENT 直接打開第一則備註
        .onAppear { if ProcessInfo.processInfo.environment["ZIWEI_OPEN_COMMENT"] != nil { open = store.list(chartID).first?.id } }
    }

    // MARK: 圖釘

    private func pinView(selected: Bool) -> some View {
        AvatarView(name: app.userAvatar, size: pin - 6)
            .frame(width: pin, height: pin)
            .background(UnevenRoundedRectangle(topLeadingRadius: pin / 2, bottomLeadingRadius: 2, bottomTrailingRadius: pin / 2, topTrailingRadius: pin / 2)
                .fill(Color.zCard))
            .overlay(UnevenRoundedRectangle(topLeadingRadius: pin / 2, bottomLeadingRadius: 2, bottomTrailingRadius: pin / 2, topTrailingRadius: pin / 2)
                .stroke(selected ? Color.zAccent : Color.zLine, lineWidth: selected ? 2 : 1))
            .shadow(color: Color.zShadow, radius: 6, y: 2)
            .contentShape(Rectangle())
    }

    // MARK: 新增

    private func composer(at d: CGPoint, size: CGSize) -> some View {
        let x = d.x * size.width, y = d.y * size.height
        return HStack(spacing: 8) {
            UnevenRoundedRectangle(topLeadingRadius: pin / 2, bottomLeadingRadius: 2, bottomTrailingRadius: pin / 2, topTrailingRadius: pin / 2)
                .fill(Color.zAccent).frame(width: pin, height: pin)
            HStack(spacing: 6) {
                TextField("新增備註", text: $draftText, axis: .vertical)
                    .textFieldStyle(.plain).zText(.callout).lineLimit(1...6)
                    .focused($focused)
                    .onSubmit(send)
                    .onExitCommand { withAnimation(Motion.fast) { draft = nil } }
                Button(action: send) {
                    Image(systemName: "arrow.up").font(.system(size: 11, weight: .bold)).foregroundStyle(Color.zOnColor)
                        .frame(width: 24, height: 24)
                        .background(Circle().fill(draftText.trimmingCharacters(in: .whitespaces).isEmpty ? Color.zText3 : Color.zAccent))
                }
                .buttonStyle(PressStyle())
                .disabled(draftText.trimmingCharacters(in: .whitespaces).isEmpty)
            }
            .padding(.leading, 12).padding(.trailing, 6).padding(.vertical, 6)
            .frame(width: 240)
            .background(RoundedRectangle(cornerRadius: 12).fill(Color.zCard))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.zAccent, lineWidth: 1.5))
            .shadow(color: Color.zShadow, radius: 10, y: 4)
        }
        .fixedSize()
        .offset(x: min(x, size.width - 280), y: max(0, y - pin))
    }

    private func send() {
        let text = draftText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let d = draft, !text.isEmpty else { return }
        let t = CommentThread(point: d, messages: [.init(text: text)])
        store.update(chartID) { $0.append(t) }
        withAnimation(Motion.fast) { draft = nil; draftText = "" }
    }

    // MARK: 對話串

    private func threadCard(_ t: CommentThread, size: CGSize) -> some View {
        let x = t.point.x * size.width + pin + 8, y = t.point.y * size.height - pin
        return VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 10) {
                Text("備註").zText(.calloutStrong).foregroundStyle(Color.zText)
                Spacer()
                Menu {
                    Button("刪除這則備註", role: .destructive) { remove(t) }
                } label: {
                    Image(systemName: "ellipsis").font(Font.zIcon).foregroundStyle(Color.zText2).frame(width: 22, height: 22)
                }
                .menuStyle(.borderlessButton).menuIndicator(.hidden).fixedSize()
                .help("更多")
                Button { resolve(t) } label: {
                    Image(systemName: "checkmark.circle").font(Font.zIcon).foregroundStyle(Color.zText2).frame(width: 22, height: 22)
                }
                .buttonStyle(PressStyle()).help("標成已解決")
                Button { withAnimation(Motion.fast) { open = nil } } label: {
                    Image(systemName: "xmark").font(Font.zIcon).foregroundStyle(Color.zText2).frame(width: 22, height: 22)
                }
                .buttonStyle(PressStyle()).help("關閉")
            }
            .padding(.horizontal, 14).padding(.vertical, 10)
            Rectangle().fill(Color.zLine).frame(height: 0.5)
            VStack(alignment: .leading, spacing: 14) {
                ForEach(t.messages) { m in
                    HStack(alignment: .top, spacing: 8) {
                        AvatarView(name: app.userAvatar, size: 22)
                        VStack(alignment: .leading, spacing: 2) {
                            HStack(spacing: 6) {
                                Text(app.userName).zText(.footnoteStrong).foregroundStyle(Color.zText)
                                Text(m.date, style: .relative).zText(.caption1).foregroundStyle(Color.zText3)
                            }
                            Text(m.text).zText(.callout).foregroundStyle(Color.zText).fixedSize(horizontal: false, vertical: true)
                                .textSelection(.enabled)
                        }
                    }
                }
            }
            .padding(14)
            HStack(spacing: 8) {
                AvatarView(name: app.userAvatar, size: 22)
                HStack(spacing: 6) {
                    TextField("回覆", text: $reply, axis: .vertical)
                        .textFieldStyle(.plain).zText(.callout).lineLimit(1...4)
                        .onSubmit { sendReply(t) }
                    Button { sendReply(t) } label: {
                        Image(systemName: "arrow.up").font(.system(size: 10, weight: .bold)).foregroundStyle(Color.zOnColor)
                            .frame(width: 20, height: 20)
                            .background(Circle().fill(reply.trimmingCharacters(in: .whitespaces).isEmpty ? Color.zText3 : Color.zAccent))
                    }
                    .buttonStyle(PressStyle())
                    .disabled(reply.trimmingCharacters(in: .whitespaces).isEmpty)
                }
                .padding(.leading, 10).padding(.trailing, 5).padding(.vertical, 5)
                .background(RoundedRectangle(cornerRadius: 10).fill(Color.zHover))
            }
            .padding(.horizontal, 14).padding(.bottom, 14)
        }
        .frame(width: cardW)
        .background(RoundedRectangle(cornerRadius: 14).fill(Color.zCard))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.zLine))
        .shadow(color: Color.zShadow, radius: 14, y: 6)
        .offset(x: x + cardW > size.width ? max(0, t.point.x * size.width - cardW - 8) : x, y: min(max(0, y), size.height - 200))
        .transition(.opacity)
    }

    private func sendReply(_ t: CommentThread) {
        let text = reply.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        store.update(chartID) { list in
            if let i = list.firstIndex(where: { $0.id == t.id }) { list[i].messages.append(.init(text: text)) }
        }
        reply = ""
    }

    private func resolve(_ t: CommentThread) {
        store.update(chartID) { list in if let i = list.firstIndex(where: { $0.id == t.id }) { list[i].resolved = true } }
        withAnimation(Motion.fast) { open = nil }
        showUndo(t, "已標成已解決")
    }

    private func remove(_ t: CommentThread) {
        store.update(chartID) { $0.removeAll { $0.id == t.id } }
        withAnimation(Motion.fast) { open = nil }
        showUndo(t, "已刪除備註")
    }

    // MARK: 復原提示（像 Figma 的「Comment resolved · Undo」）

    private func showUndo(_ t: CommentThread, _ label: String) {
        withAnimation(Motion.enter) { undo = (t, label) }
        let id = t.id
        DispatchQueue.main.asyncAfter(deadline: .now() + 4) {
            if undo?.thread.id == id { withAnimation(Motion.exit) { undo = nil } }
        }
    }

    @ViewBuilder
    private var undoBar: some View {
        if let u = undo {
            HStack(spacing: 14) {
                Text(u.label).zText(.calloutStrong)
                Button("復原") {
                    store.update(chartID) { list in
                        if let i = list.firstIndex(where: { $0.id == u.thread.id }) { list[i] = u.thread } else { list.append(u.thread) }
                    }
                    withAnimation(Motion.exit) { undo = nil }
                }
                .buttonStyle(.plain).zText(.calloutStrong).foregroundStyle(Color.zAccent)
            }
            .foregroundStyle(Color.zBg)
            .padding(.horizontal, 16).frame(height: 36)
            .background(Capsule().fill(Color.zText))
            .shadow(color: .black.opacity(0.18), radius: 12, y: 5)
            .padding(.bottom, 12)
            .transition(.opacity.combined(with: .offset(y: 10)))
        }
    }
}
