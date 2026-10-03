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
    var tool: AnnoTool = .select      // 目前的工具（離開備註時換回它的游標）
    @EnvironmentObject private var app: Store
    @ObservedObject private var store = CommentStore.shared
    @State private var draft: CGPoint?        // 新增中的圖釘位置
    @State private var draftText = ""
    @State private var open: UUID?            // 打開的對話串
    @State private var reply = ""
    @State private var editing: UUID?          // 編輯中的留言
    @State private var editText = ""
    @State private var hoverMsg: UUID?
    @State private var hoverPin: UUID?         // 滑鼠停著的圖釘（顯示預覽）
    @State private var dragging: (id: UUID, offset: CGSize)?   // 正在拖的圖釘
    @State private var undo: (thread: CommentThread, label: String)?
    @FocusState private var focused: Bool

    private let pin: CGFloat = 28
    private let cardW: CGFloat = 300
    /// 備註的強調色：用 App 主色（原本照 Figma 用藍色，Jean 要改主色系）
    private let figmaBlue = Color.zAccent
    private var bubble: UnevenRoundedRectangle {
        UnevenRoundedRectangle(topLeadingRadius: pin / 2, bottomLeadingRadius: 3, bottomTrailingRadius: pin / 2, topTrailingRadius: pin / 2)
    }

    var body: some View {
        GeometryReader { g in
            let size = g.size
            ZStack(alignment: .topLeading) {
                // 備註工具：點空白處放新圖釘；其他情況點空白處關掉打開的對話串
                Color.clear.contentShape(Rectangle())
                    .onTapGesture(coordinateSpace: .local) { p in
                        if open != nil { withAnimation(Motion.fast) { open = nil } ; return }
                        // 正在寫的備註：點旁邊就取消這次的備註
                        if draft != nil { withAnimation(Motion.exit) { draft = nil; draftText = "" }; return }
                        guard active else { return }
                        draftText = ""
                        withAnimation(.spring(response: 0.34, dampingFraction: 0.82)) { draft = CGPoint(x: p.x / size.width, y: p.y / size.height) }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { focused = true }
                    }
                    .allowsHitTesting(active || open != nil || draft != nil)

                ForEach(store.list(chartID).filter { !$0.resolved }) { t in
                    let d = dragging?.id == t.id ? dragging!.offset : .zero
                    pinView(selected: open == t.id)
                        // 拖曳圖釘可以換位置（放開才存）
                        .gesture(DragGesture(minimumDistance: 3, coordinateSpace: .named("comments"))   // 用整層的座標，圖釘跟著動也不會抖
                            .onChanged { v in dragging = (t.id, v.translation); open = nil; hoverPin = nil }
                            .onEnded { v in
                                let nx = min(1, max(0, t.point.x + v.translation.width / size.width))
                                let ny = min(1, max(0, t.point.y + v.translation.height / size.height))
                                store.update(chartID) { list in if let i = list.firstIndex(where: { $0.id == t.id }) { list[i].point = CGPoint(x: nx, y: ny) } }
                                dragging = nil
                            })
                        .onTapGesture { withAnimation(.spring(response: 0.32, dampingFraction: 0.85)) { open = open == t.id ? nil : t.id; draft = nil; reply = "" } }
                        .onHover { h in
                            ToolCursor.setOverComment(h, tool: tool)
                            withAnimation(Motion.fast) { hoverPin = h ? t.id : (hoverPin == t.id ? nil : hoverPin) }
                        }
                        // 右鍵：標成已解決／刪除（刪掉可以從下方提示條復原）
                        .contextMenu {
                            Button { resolve(t) } label: { Label("標成已解決", systemImage: "checkmark.circle") }
                            Divider()
                            Button(role: .destructive) { hoverPin = nil; remove(t) } label: { Label("刪除", systemImage: "trash") }
                        }
                        // position 要放最後：它會把 view 撐滿整個盤面，hover 掛在它後面就永遠不會「離開」
                        .position(x: t.point.x * size.width + pin / 2 + d.width, y: t.point.y * size.height - pin / 2 + d.height)
                }
                if let id = hoverPin, open != id, let t = store.list(chartID).first(where: { $0.id == id }) {
                    preview(t, size: size)
                }

                if let d = draft {
                    composer(at: d, size: size)
                }
                if let id = open, let t = store.list(chartID).first(where: { $0.id == id }) {
                    threadCard(t, size: size)
                }
            }
            .coordinateSpace(name: "comments")
            .overlay(alignment: .bottom) { undoBar }
        }
        .onChange(of: active) { a in if !a { draft = nil } }
        // 驗證用：ZIWEI_OPEN_COMMENT 直接打開第一則備註
        .onAppear {
            let env = ProcessInfo.processInfo.environment
            if env["ZIWEI_OPEN_COMMENT"] != nil { open = store.list(chartID).first?.id }
            if let t = env["ZIWEI_DRAFT"] { draft = CGPoint(x: 0.3, y: 0.42); draftText = t }   // 驗證用：直接打開輸入框
        }
    }

    // MARK: 圖釘

    private func pinView(selected: Bool) -> some View {
        AvatarView(name: app.userAvatar, size: pin - 6)
            .frame(width: pin, height: pin)
            .background(bubble.fill(Color.zRaised))
            .overlay(bubble.stroke(selected ? figmaBlue : Color.zRaised, lineWidth: selected ? 2.5 : 2))
            .overlay(bubble.stroke(Color.zRaisedLine, lineWidth: 0.5).padding(-1))
            .raisedShadow(small: true)
            .scaleEffect(selected ? 1.08 : 1)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: selected)
            .contentShape(Rectangle())
    }

    // MARK: 新增

    private func composer(at d: CGPoint, size: CGSize) -> some View {
        let x = d.x * size.width, y = d.y * size.height
        let empty = draftText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        let fieldW: CGFloat = 300
        // 圖釘的左邊就是滑鼠點的位置，輸入框從這裡往右展開
        let left = x
        return HStack(alignment: .top, spacing: 8) {
            // 新增中的圖釘：藍色實心＋白框，像 Figma
            bubble.fill(figmaBlue).frame(width: pin, height: pin)
                .overlay(bubble.stroke(Color.white, lineWidth: 2))
                .shadow(color: figmaBlue.opacity(0.35), radius: 6, y: 2)
            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .center, spacing: 8) {
                    TextField("新增備註", text: $draftText, axis: .vertical)
                        .textFieldStyle(.plain).zText(.body).lineLimit(1...8)
                        .focused($focused)
                        .onSubmit(send)
                        .onExitCommand { withAnimation(Motion.exit) { draft = nil } }
                    if empty { sendButton(empty: true) }
                }
                // 有字之後下面多一排工具（表情符號），送出鍵移到右下，像 Figma
                if !empty {
                    HStack(spacing: 14) {
                        Button { NSApp.orderFrontCharacterPalette(nil) } label: {
                            Image(systemName: "face.smiling").font(.system(size: 15)).foregroundStyle(Color.zText2)
                        }
                        .buttonStyle(PressStyle()).help("表情符號")
                        Spacer()
                        sendButton(empty: false)
                    }
                    .transition(.opacity.combined(with: .move(edge: .top)))
                }
            }
            .padding(.leading, 14).padding(.trailing, 8).padding(.vertical, 8)
            .frame(width: fieldW, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: empty ? 21 : 14).fill(Color.zRaised))
            // 被選取的感覺：藍色外框＋外圈淡藍光暈；空白時是一條膠囊
            .overlay(RoundedRectangle(cornerRadius: empty ? 21 : 14).stroke(figmaBlue.opacity(0.85), lineWidth: 1))
            .background(RoundedRectangle(cornerRadius: empty ? 24 : 17).stroke(figmaBlue.opacity(focused ? 0.1 : 0), lineWidth: 3).padding(-2.5))
            .raisedShadow()
            .animation(.spring(response: 0.3, dampingFraction: 0.85), value: empty)
            .transition(.asymmetric(insertion: .scale(scale: 0.2, anchor: .leading).combined(with: .opacity),
                                    removal: .opacity))
        }
        .fixedSize()
        .offset(x: left, y: max(0, y - pin))
        .transition(.opacity)
    }

    private func sendButton(empty: Bool) -> some View {
        Button(action: send) {
            Image(systemName: "arrow.up").font(.system(size: 12, weight: .bold)).foregroundStyle(Color.white)
                .frame(width: 26, height: 26)
                .background(Circle().fill(empty ? Color.zText3.opacity(0.6) : figmaBlue))
        }
        .buttonStyle(PressStyle())
        .disabled(empty)
        .help("送出（Enter）")
    }

    private func send() {
        let text = draftText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let d = draft, !text.isEmpty else { return }
        let t = CommentThread(point: d, messages: [.init(text: text)])
        store.update(chartID) { $0.append(t) }
        withAnimation(Motion.exit) { draft = nil; draftText = "" }
    }

    // MARK: 對話串

    private func threadCard(_ t: CommentThread, size: CGSize) -> some View {
        let x = t.point.x * size.width + pin + 8, y = t.point.y * size.height - pin
        return VStack(alignment: .leading, spacing: 0) {
            // 標題列：備註　⋯（複製、刪除）　✓（已解決）　×
            HStack(spacing: 6) {
                Text("備註").zText(.calloutStrong).foregroundStyle(Color.zText)
                Spacer()
                Menu {
                    Button("複製內容") {
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString(t.messages.map(\.text).joined(separator: "\n"), forType: .string)
                        Toast.show("已複製")
                    }
                    Divider()
                    Button("刪除這則備註", role: .destructive) { remove(t) }
                } label: { iconLabel("ellipsis") }
                .menuStyle(.borderlessButton).menuIndicator(.hidden).fixedSize()
                .help("更多")
                Button { resolve(t) } label: { iconLabel("checkmark.circle") }
                    .buttonStyle(PressStyle()).help("標成已解決")
                Button { withAnimation(Motion.fast) { open = nil; editing = nil } } label: { iconLabel("xmark") }
                    .buttonStyle(PressStyle()).help("關閉")
            }
            .padding(.leading, 16).padding(.trailing, 10).padding(.vertical, 10)
            Rectangle().fill(Color.zLine).frame(height: 0.5)
            VStack(alignment: .leading, spacing: 16) {
                ForEach(t.messages) { m in
                    if editing == m.id { editBox(t, m) } else { message(t, m) }
                }
            }
            .padding(.horizontal, 16).padding(.vertical, 14)
            // 回覆
            HStack(spacing: 10) {
                AvatarView(name: app.userAvatar, size: 26)
                HStack(spacing: 6) {
                    TextField("回覆", text: $reply, axis: .vertical)
                        .textFieldStyle(.plain).zText(.callout).lineLimit(1...4)
                        .onSubmit { sendReply(t) }
                    Button { sendReply(t) } label: {
                        Image(systemName: "arrow.up").font(.system(size: 10, weight: .bold)).foregroundStyle(Color.white)
                            .frame(width: 22, height: 22)
                            .background(Circle().fill(reply.trimmingCharacters(in: .whitespaces).isEmpty ? Color.zText3.opacity(0.6) : figmaBlue))
                    }
                    .buttonStyle(PressStyle())
                    .disabled(reply.trimmingCharacters(in: .whitespaces).isEmpty)
                }
                .padding(.leading, 12).padding(.trailing, 6).padding(.vertical, 7)
                .background(RoundedRectangle(cornerRadius: 12).fill(Color.zHover))
            }
            .padding(.horizontal, 16).padding(.bottom, 16)
        }
        .frame(width: cardW)
        .background(RoundedRectangle(cornerRadius: 14).fill(Color.zRaised))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.zRaisedLine, lineWidth: 0.5))
        .raisedShadow()
        .onHover { ToolCursor.setOverComment($0, tool: tool) }
        .offset(x: x + cardW > size.width ? max(0, t.point.x * size.width - cardW - 8) : x, y: min(max(0, y), size.height - 220))
        .transition(.scale(scale: 0.9, anchor: .topLeading).combined(with: .opacity))
    }

    private func iconLabel(_ name: String) -> some View {
        Image(systemName: name).font(.system(size: 13)).foregroundStyle(Color.zText2)
            .frame(width: 26, height: 26).contentShape(Rectangle())
    }

    /// 一則留言：頭貼、名字、時間；滑過右邊出現 ⋯（編輯、刪除）
    private func message(_ t: CommentThread, _ m: CommentThread.Message) -> some View {
        HStack(alignment: .top, spacing: 10) {
            AvatarView(name: app.userAvatar, size: 26)
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(app.userName).zText(.calloutStrong).foregroundStyle(Color.zText)
                    Text(m.date, style: .relative).zText(.footnote).foregroundStyle(Color.zText3)
                    Spacer(minLength: 0)
                    Menu {
                        Button("編輯") { editText = m.text; withAnimation(Motion.fast) { editing = m.id } }
                        if t.messages.count > 1 {
                            Button("刪除這則回覆", role: .destructive) {
                                store.update(chartID) { list in
                                    if let i = list.firstIndex(where: { $0.id == t.id }) { list[i].messages.removeAll { $0.id == m.id } }
                                }
                            }
                        }
                    } label: { iconLabel("ellipsis") }
                    .menuStyle(.borderlessButton).menuIndicator(.hidden).fixedSize()
                    .opacity(hoverMsg == m.id ? 1 : 0)
                }
                Text(m.text).zText(.body).foregroundStyle(Color.zText).fixedSize(horizontal: false, vertical: true)
                    .textSelection(.enabled)
            }
        }
        .contentShape(Rectangle())
        .onHover { h in hoverMsg = h ? m.id : (hoverMsg == m.id ? nil : hoverMsg) }
    }

    /// 編輯中的留言：藍框輸入框＋工具列＋取消／儲存（像 Figma）
    private func editBox(_ t: CommentThread, _ m: CommentThread.Message) -> some View {
        HStack(alignment: .top, spacing: 10) {
            AvatarView(name: app.userAvatar, size: 26)
            VStack(alignment: .leading, spacing: 10) {
                TextField("", text: $editText, axis: .vertical)
                    .textFieldStyle(.plain).zText(.body).lineLimit(2...8)
                    .onExitCommand { withAnimation(Motion.fast) { editing = nil } }
                HStack(spacing: 14) {
                    Button { NSApp.orderFrontCharacterPalette(nil) } label: {
                        Image(systemName: "face.smiling").font(.system(size: 15)).foregroundStyle(Color.zText2)
                    }
                    .buttonStyle(PressStyle()).help("表情符號")
                    Spacer()
                    Button("取消") { withAnimation(Motion.fast) { editing = nil } }
                        .buttonStyle(.plain).zText(.calloutStrong).foregroundStyle(Color.zText)
                        .padding(.horizontal, 12).frame(height: 28)
                        .background(RoundedRectangle(cornerRadius: 7).stroke(Color.zLine))
                    Button("儲存") {
                        let text = editText.trimmingCharacters(in: .whitespacesAndNewlines)
                        if !text.isEmpty {
                            store.update(chartID) { list in
                                if let i = list.firstIndex(where: { $0.id == t.id }), let k = list[i].messages.firstIndex(where: { $0.id == m.id }) {
                                    list[i].messages[k].text = text
                                }
                            }
                        }
                        withAnimation(Motion.fast) { editing = nil }
                    }
                    .buttonStyle(.plain).zText(.calloutStrong).foregroundStyle(Color.white)
                    .padding(.horizontal, 12).frame(height: 28)
                    .background(RoundedRectangle(cornerRadius: 7).fill(figmaBlue))
                    .keyboardShortcut(.defaultAction)
                }
            }
            .padding(12)
            .background(RoundedRectangle(cornerRadius: 12).fill(Color.zRaised))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(figmaBlue.opacity(0.85), lineWidth: 1))
        }
    }

    /// 滑鼠停在圖釘上：小預覽卡（像 Figma）
    private func preview(_ t: CommentThread, size: CGSize) -> some View {
        let x = t.point.x * size.width + pin + 6, y = t.point.y * size.height - pin
        return HStack(alignment: .top, spacing: 8) {
            AvatarView(name: app.userAvatar, size: 22)
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(app.userName).zText(.footnoteStrong).foregroundStyle(Color.zText)
                    Text(t.messages.first?.date ?? Date(), style: .relative).zText(.caption1).foregroundStyle(Color.zText3)
                }
                Text(t.messages.first?.text ?? "").zText(.footnote).foregroundStyle(Color.zText).lineLimit(2)
                if t.messages.count > 1 {
                    Text("\(t.messages.count - 1) 則回覆").zText(.caption1).foregroundStyle(figmaBlue)
                }
            }
        }
        .padding(10)
        .frame(width: 220, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 12).fill(Color.zRaised))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.zRaisedLine, lineWidth: 0.5))
        .raisedShadow()
        .offset(x: x + 220 > size.width ? t.point.x * size.width - 226 : x, y: max(0, y))
        .allowsHitTesting(false)
        .transition(.opacity.combined(with: .scale(scale: 0.96, anchor: .topLeading)))
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
                .buttonStyle(.plain).zText(.calloutStrong).foregroundStyle(figmaBlue)
                Button { withAnimation(Motion.exit) { undo = nil } } label: {
                    Image(systemName: "xmark").font(.system(size: 10, weight: .bold)).foregroundStyle(Color.zBg.opacity(0.7))
                }
                .buttonStyle(.plain)
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

extension View {
    /// 浮在盤面上的卡片陰影：一層大而柔、一層貼著輪廓；深色模式底很暗，陰影要更重才看得出浮起來
    func raisedShadow(small: Bool = false) -> some View {
        self.shadow(color: .black.opacity(small ? 0.3 : 0.28), radius: small ? 7 : 18, y: small ? 3 : 8)
            .shadow(color: .black.opacity(0.14), radius: small ? 1 : 2, y: 1)
    }
}
