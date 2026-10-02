import SwiftUI
import UniformTypeIdentifiers

/// Claude／Codex 式側欄：平面列、圓角選取底色、小灰字分組標題、分組像 Codex 的資料夾
struct Sidebar: View {
    @EnvironmentObject var store: Store
    @Binding var route: Route?
    var onNew: () -> Void
    @State private var searching = false
    @State private var search = ""
    @State private var collapsed: Set<String> = []
    /// 拖曳中：正在拖的那一列（原位淡掉）＋要放下的位置（細線）
    @State private var dragKey: String?
    @State private var dropLine: DropLine?
    @State private var renaming: Person?
    @State private var newName = ""
    @FocusState private var searchFocused: Bool
    /// 搜尋先關掉（Jean：先不用到），要打開改成 true
    static let searchEnabled = false
    @State private var searchHover = false

    private var q: String { search.trimmingCharacters(in: .whitespaces) }

    var body: some View {
        VStack(spacing: 0) {
            // 側欄頂端：產品名（像 Codex）；右邊搜尋目前關閉
            HStack(spacing: 4) {
                HStack(spacing: 6) {
                    Text("StillLink").font(Font.zBrand).foregroundStyle(Color.zText)
                    // 測試版：產品名旁邊一個小標籤
                    if AppInfo.isBeta {
                        Text("Beta").font(Font.zMicroStrong).foregroundStyle(Color.zAccent)
                            .padding(.horizontal, 6).frame(height: 18)
                            .background(Capsule().fill(Color.zAccent.opacity(0.12)))
                    }
                }
                .padding(.horizontal, 8).frame(height: 30)
                Spacer()
                if Self.searchEnabled {
                Button {
                    if searching { searching = false; search = "" }
                    else { searching = true; DispatchQueue.main.async { searchFocused = true } }
                } label: {
                    Image(systemName: "magnifyingglass").font(Font.zCallout).foregroundStyle(searching ? Color.zText : Color.zText2)
                        .frame(width: 30, height: 30)
                        .background(RoundedRectangle(cornerRadius: 8).fill(searching || searchHover ? Color.zHover : .clear))
                        .contentShape(Rectangle())
                }
                .buttonStyle(RowPressStyle())
                .onHover { searchHover = $0 }
                .help("搜尋 ⌘F")
                }
            }
            .padding(.horizontal, 10)
            .padding(.top, 6)
            .padding(.bottom, 4)

            ScrollView {
                VStack(alignment: .leading, spacing: 1) {
                    NavRow(icon: "house", title: "此刻", selected: route == .home || route == nil) { route = .home }
                    if store.showSelfInSidebar {
                        NavRow(icon: "person.crop.circle", title: store.me == nil ? "請填寫個人檔案" : store.userName,
                               selected: store.me.map { route == .person($0.id) } ?? false) {
                            if let me = store.me { route = .person(me.id) }
                            else { NotificationCenter.default.post(name: .newSelfChart, object: nil) }   // 還沒有個人檔案：先填，存好後就打開自己的命盤
                        }
                        .contextMenu {
                            Button("從側欄隱藏") { store.showSelfInSidebar = false; Toast.show("已隱藏，可在設定 → 個人檔案重新打開") }
                            Button("個人檔案…") { NotificationCenter.default.post(name: .openSettings, object: SettingsPage.Section.profile) }
                        }
                    }
                    NavRow(icon: "plus", title: "新增命盤", shortcut: "⌘N", selected: route == .new, action: onNew)
                    if searching {
                        HStack(spacing: 8) {
                            Image(systemName: "magnifyingglass").font(Font.zCallout).foregroundStyle(Color.zText2).frame(width: 16)
                            TextField("搜尋姓名", text: $search)
                                .textFieldStyle(.plain)
                                .font(Font.zBody)
                                .focused($searchFocused)
                                .onExitCommand { searching = false; search = "" }
                            Button { searching = false; search = "" } label: {
                                Image(systemName: "xmark.circle.fill").foregroundStyle(Color.zText3)
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(.horizontal, 10)
                        .frame(height: 30)
                        .background(RoundedRectangle(cornerRadius: 8).fill(Color.zSel))
                    }

                    let pinned = store.sorted(store.people.filter { $0.pinned && matches($0) && $0.id != store.selfID })
                    if !pinned.isEmpty {
                        SectionLabel("釘選").padding(.top, 18)
                        ForEach(pinned) { p in personRow(p, indent: false) }
                    }

                    SectionLabel("命盤", action: onNew, sort: $store.sortMode).padding(.top, 18)
                    ForEach(groupNames, id: \.self) { g in
                        let list = store.sorted(store.people.filter { !$0.pinned && $0.group == g && matches($0) && $0.id != store.selfID })
                        if !list.isEmpty {
                            FolderRow(name: g, count: list.count, open: !collapsed.contains(g),
                                      onAdd: { NotificationCenter.default.post(name: .newChart, object: g) }) {
                                withAnimation(Motion.base) {
                                    if collapsed.contains(g) { collapsed.remove(g) } else { collapsed.insert(g) }
                                }
                            }
                            .opacity(dragKey == "g:" + g ? 0.35 : 1)
                            .modifier(DropMarker(key: "g:" + g, line: dropLine))
                            .onDrag { beginDrag("g:" + g) } preview: { DragPreview(icon: "folder", title: g) }
                            .onDrop(of: [.text], delegate: RowDrop(key: "g:" + g, dragKey: $dragKey, line: $dropLine,
                                                                  accepts: { _ in true }, perform: drop))
                            if !collapsed.contains(g) {
                                ForEach(list) { p in
                                    personRow(p, indent: true)
                                        .transition(.opacity.combined(with: .offset(y: -4)))
                                }
                            }
                        }
                    }
                    // 空狀態：還沒有任何命盤
                    if groupNames.isEmpty {
                        Text("還沒有命盤，按 ＋ 新增")
                            .font(Font.zCaption).foregroundStyle(Color.zText3)
                            .padding(.horizontal, 10).padding(.top, 4)
                    }
                }
                .padding(.horizontal, 8)
                .padding(.top, 6)
                .padding(.bottom, 12)
            }
            AccountBar()
        }
        .dimmedBlur()
        .background(Color.zSide)
        // 側欄右緣細線：側欄和主區顏色接近，靠這條線分開
        .overlay(alignment: .trailing) { Rectangle().fill(Color.zLine).frame(width: 1).ignoresSafeArea() }
        .overlay(alignment: .top) { TopFade(color: .zSide) }
        .alert("重新命名", isPresented: Binding(get: { renaming != nil }, set: { if !$0 { renaming = nil } })) {
            TextField("名字", text: $newName)
            Button("取消", role: .cancel) { renaming = nil }
            Button("儲存") {
                let t = newName.trimmingCharacters(in: .whitespaces)
                if var p = renaming, !t.isEmpty { p.name = t; store.update(p); Toast.show("已改名為「\(t)」") }
                renaming = nil
            }
        } message: {
            Text("命盤的生辰不會改變")
        }
        .onAppear {
            // 驗證用：ZIWEI_DRAGDEMO=1 時停在「拖第二張命盤、放到第一張下面」的畫面
            guard ProcessInfo.processInfo.environment["ZIWEI_DRAGDEMO"] != nil else { return }
            let list = groupNames.flatMap { g in store.sorted(store.people.filter { !$0.pinned && $0.group == g && $0.id != store.selfID }) }
            if list.count >= 2 {
                dragKey = "p:" + list[1].id.uuidString
                dropLine = DropLine(key: "p:" + list[0].id.uuidString, pos: .below)
            }
        }
        .onChange(of: route) { _, _ in
            if searching { searching = false; search = "" }
        }
        .background(
            Button("") { searching = true; DispatchQueue.main.async { searchFocused = true } }
                .keyboardShortcut("f").hidden()
                .disabled(!Self.searchEnabled)
        )
    }

    /// 資料夾順序：先照使用者拖曳排好的順序，新出現的分組排在後面
    private var groupNames: [String] {
        var seen: [String] = []
        for p in store.people where !p.pinned && p.id != store.selfID && !seen.contains(p.group) { seen.append(p.group) }
        let saved = store.groupOrder.filter(seen.contains)
        return saved + seen.filter { !saved.contains($0) }
    }

    /// 開始拖：記下是哪一列；放開滑鼠（不管有沒有放到地方）就清掉
    private func beginDrag(_ key: String) -> NSItemProvider {
        dragKey = key
        Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { t in
            if NSEvent.pressedMouseButtons & 1 == 0 {
                t.invalidate()
                DispatchQueue.main.async { dragKey = nil; dropLine = nil }
            }
        }
        return NSItemProvider(object: key as NSString)
    }

    /// 放下：命盤用 "p:<id>"、資料夾用 "g:<名稱>"；pos 是放在目標的上、下或正中（只有資料夾有正中）
    private func drop(_ item: String, on target: String, _ pos: DropLine.Pos) {
        let id = item.hasPrefix("p:") ? UUID(uuidString: String(item.dropFirst(2))) : nil
        let tid = target.hasPrefix("p:") ? UUID(uuidString: String(target.dropFirst(2))) : nil
        let g = target.hasPrefix("g:") ? String(target.dropFirst(2)) : nil
        if let id, let tid {
            store.movePerson(id, near: tid, after: pos == .below)
        } else if let id, let g {
            store.movePerson(id, toGroup: g)
            Toast.show("已移到「\(g)」")
        } else if item.hasPrefix("g:"), let g {
            store.moveGroup(String(item.dropFirst(2)), near: g, after: pos == .below, current: groupNames)
        }
    }

    private func matches(_ p: Person) -> Bool { q.isEmpty || p.name.contains(q) }

    private func personRow(_ p: Person, indent: Bool) -> some View {
        let on = route == .person(p.id)
        return Button { route = .person(p.id) } label: {
            HStack(spacing: 9) {
                Group {
                    if p.avatar != nil {
                        AvatarView(name: p.avatar, size: 16)
                    } else {
                        Circle().stroke(Color.zText3, lineWidth: 1).frame(width: 6, height: 6).frame(width: 16)
                    }
                }
                .padding(.leading, 2)
                Text(p.name).font(Font.zBody).foregroundStyle(Color.zText).lineLimit(1)
                Spacer(minLength: 6)
                Text(store.soulStars[p.id] ?? "")
                    .font(Font.zCaption).foregroundStyle(Color.zText3).lineLimit(1)
            }
            .padding(.horizontal, 8)
            .frame(height: 30)
            .background {
                if on { RoundedRectangle(cornerRadius: 8).fill(Color.zSel) }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(RowButtonStyle(selected: on))
        .opacity(dragKey == "p:" + p.id.uuidString ? 0.35 : 1)
        .modifier(DropMarker(key: "p:" + p.id.uuidString, line: dropLine))
        .onDrag { beginDrag("p:" + p.id.uuidString) } preview: { DragPreview(icon: nil, title: p.name, avatar: p.avatar) }
        .onDrop(of: [.text], delegate: RowDrop(key: "p:" + p.id.uuidString, dragKey: $dragKey, line: $dropLine,
                                              accepts: { $0.hasPrefix("p:") }, perform: drop))
        .contextMenu {
            Button("重新命名…") { newName = p.name; renaming = p }
            Button(p.pinned ? "取消釘選" : "釘選") { var q = p; q.pinned.toggle(); store.update(q) }
            Divider()
            Button("刪除", role: .destructive) {
                if route == .person(p.id) { route = .home }
                store.delete(p.id)
            }
        }
    }
}

/// 拖曳放下的位置：某一列的上緣、下緣，或資料夾正中（移進資料夾）
struct DropLine: Equatable {
    enum Pos { case above, below, into }
    let key: String
    let pos: Pos
}

/// 列的放下判定：上半部插在前面、下半部插在後面；命盤拖到資料夾正中間＝移進去
private struct RowDrop: DropDelegate {
    let key: String
    @Binding var dragKey: String?
    @Binding var line: DropLine?
    let accepts: (String) -> Bool
    let perform: (String, String, DropLine.Pos) -> Void
    private let rowHeight: CGFloat = 30

    private func pos(_ info: DropInfo) -> DropLine.Pos {
        let y = info.location.y
        if key.hasPrefix("g:"), dragKey?.hasPrefix("p:") == true { return .into }
        return y < rowHeight / 2 ? .above : .below
    }
    func validateDrop(info: DropInfo) -> Bool {
        guard let d = dragKey else { return false }
        return d != key && accepts(d)
    }
    func dropUpdated(info: DropInfo) -> DropProposal? {
        guard validateDrop(info: info) else { line = nil; return DropProposal(operation: .forbidden) }
        let new = DropLine(key: key, pos: pos(info))
        if line != new { line = new }
        return DropProposal(operation: .move)
    }
    func dropExited(info: DropInfo) { if line?.key == key { line = nil } }
    func performDrop(info: DropInfo) -> Bool {
        guard let d = dragKey, validateDrop(info: info) else { return false }
        let p = pos(info)
        line = nil; dragKey = nil
        perform(d, key, p)
        return true
    }
}

/// 放下位置的提示：上／下緣一條主色細線（像 Codex），資料夾正中則整列框起來
private struct DropMarker: ViewModifier {
    let key: String
    let line: DropLine?
    func body(content: Content) -> some View {
        content.overlay(alignment: line?.pos == .above ? .top : .bottom) {
            if let line, line.key == key {
                if line.pos == .into {
                    RoundedRectangle(cornerRadius: 8).stroke(Color.zAccent, lineWidth: 1.5)
                } else {
                    Capsule().fill(Color.zAccent).frame(height: 2)
                        .padding(.leading, 6)
                        .offset(y: line.pos == .above ? -1.5 : 1.5)
                        .allowsHitTesting(false)
                }
            }
        }
    }
}

/// 拖曳時跟著游標的那一列：長得跟側欄列一樣，半透明
private struct DragPreview: View {
    let icon: String?
    let title: String
    var avatar: String? = nil
    var body: some View {
        HStack(spacing: 9) {
            if let icon {
                Image(systemName: icon).font(Font.zCallout).foregroundStyle(Color.zText2).frame(width: 16)
            } else if avatar != nil {
                AvatarView(name: avatar, size: 16)
            } else {
                Circle().stroke(Color.zText3, lineWidth: 1).frame(width: 6, height: 6).frame(width: 16)
            }
            Text(title).font(Font.zBody).foregroundStyle(Color.zText).lineLimit(1)
        }
        .padding(.horizontal, 10)
        .frame(width: 200, height: 30, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 8).fill(Color.zSel))
        .opacity(0.9)
    }
}

private struct RowButtonStyle: ButtonStyle {
    var selected = false
    @State private var hover = false
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background(RoundedRectangle(cornerRadius: 8).fill(!selected && hover ? Color.zHover : Color.clear))
            .opacity(configuration.isPressed ? 0.7 : 1)
            .animation(Motion.fast, value: hover)
            .onHover { hover = $0 }
    }
}

private struct NavRow: View {
    let icon: String
    let title: String
    var shortcut: String? = nil
    var selected = false
    let action: () -> Void
    @State private var hover = false
    var body: some View {
        Button(action: action) {
            HStack(spacing: 9) {
                Image(systemName: icon).font(Font.zCallout).foregroundStyle(Color.zText2).frame(width: 16)
                Text(title).font(Font.zBody).foregroundStyle(Color.zText)
                Spacer()
                if hover, let shortcut { Text(shortcut).font(Font.zCaption).foregroundStyle(Color.zText3) }
            }
            .padding(.horizontal, 10)
            .frame(height: 30)
            .background(RoundedRectangle(cornerRadius: 8).fill(selected ? Color.zSel : hover ? Color.zHover : Color.clear))
            .contentShape(Rectangle())
            .animation(Motion.fast, value: hover)
        }
        .buttonStyle(RowPressStyle())
        .onHover { hover = $0 }
    }
}

private struct FolderRow: View {
    let name: String
    let count: Int
    let open: Bool
    var onAdd: (() -> Void)? = nil   // 在這個資料夾下新增命盤
    let action: () -> Void
    @State private var hover = false
    @State private var plusHover = false
    var body: some View {
        Button(action: action) {
            HStack(spacing: 9) {
                Image(systemName: open ? "folder" : "folder.fill")
                    .font(Font.zCallout).foregroundStyle(Color.zText2).frame(width: 16)
                Text(name).font(Font.zBody).foregroundStyle(open ? Color.zText : Color.zText2)
                Spacer()
                // 滑過時把數量換成 ＋，點了在這個資料夾下新增
                if hover, let onAdd {
                    Button(action: onAdd) {
                        Image(systemName: "plus").font(Font.zCaptionStrong)
                            .foregroundStyle(plusHover ? Color.zText : Color.zText2)
                            .frame(width: 22, height: 22)
                            .background(RoundedRectangle(cornerRadius: 6).fill(plusHover ? Color.zSel : .clear))
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(RowPressStyle())
                    .onHover { plusHover = $0 }
                    .help("在「\(name)」新增命盤")
                } else {
                    Text("\(count)").font(Font.zCaption).foregroundStyle(Color.zText3)
                }
            }
            .padding(.horizontal, 10)
            .frame(height: 30)
            .background(RoundedRectangle(cornerRadius: 8).fill(hover ? Color.zHover : Color.clear))
            .contentShape(Rectangle())
            .animation(Motion.fast, value: hover)
        }
        .buttonStyle(RowPressStyle())
        .onHover { hover = $0 }
    }
}

private struct SectionLabel: View {
    let text: String
    var action: (() -> Void)? = nil
    var sort: Binding<Store.SortMode>? = nil
    @State private var hover = false
    @State private var sortHover = false
    init(_ t: String, action: (() -> Void)? = nil, sort: Binding<Store.SortMode>? = nil) { text = t; self.action = action; self.sort = sort }
    var body: some View {
        HStack(spacing: 2) {
            Text(text).font(Font.zCaption).foregroundStyle(Color.zText3)
            Spacer()
            if let sort {
                // 排序：新增時間、名稱、出生日期、自訂
                Menu {
                    Picker("排序", selection: sort) {
                        ForEach(Store.SortMode.allCases, id: \.self) { m in Label(m.label, systemImage: m.icon).tag(m) }
                    }
                    .pickerStyle(.inline)
                } label: {
                    Image(systemName: sort.wrappedValue == .custom ? "line.3.horizontal.decrease" : "line.3.horizontal.decrease.circle.fill")
                        .font(Font.zCaptionStrong)
                        .foregroundStyle(sortHover || sort.wrappedValue != .custom ? Color.zText : Color.zText3)
                        .frame(width: 22, height: 22)
                        .background(RoundedRectangle(cornerRadius: 6).fill(sortHover ? Color.zHover : .clear))
                        .contentShape(Rectangle())
                }
                .menuStyle(.button)
                .buttonStyle(.plain)
                .menuIndicator(.hidden)
                .labelStyle(.titleAndIcon)
                .tint(Color.primary)
                .fixedSize()
                .onHover { h in withAnimation(Motion.fast) { sortHover = h } }
                .help("排序：\(sort.wrappedValue.label)")
            }
            if let action {
                Button(action: action) {
                    Image(systemName: "plus").font(Font.zCaptionStrong).foregroundStyle(hover ? Color.zText : Color.zText3)
                        .frame(width: 22, height: 22)
                        .background(RoundedRectangle(cornerRadius: 6).fill(hover ? Color.zHover : .clear))
                        .contentShape(Rectangle())
                }
                .buttonStyle(RowPressStyle())
                .onHover { h in withAnimation(Motion.fast) { hover = h } }
                .help("新增命盤")
            }
        }
        .padding(.leading, 10).padding(.trailing, 4).padding(.bottom, 2)
    }
}

/// 左下角帳號列：點開是外觀、登入與設定
private struct AccountBar: View {
    @EnvironmentObject var store: Store

    var body: some View {
        VStack(spacing: 0) {
            Rectangle().fill(Color.zLine).frame(height: 0.5)
            Menu {
                Picker("外觀", selection: $store.appearance) {
                    ForEach(Appearance.allCases, id: \.self) { Label($0.label, systemImage: $0.icon).tag($0) }
                }
                .pickerStyle(.inline)
                Divider()
                Button { NotificationCenter.default.post(name: .openSettings, object: SettingsPage.Section.account) } label: {
                    Label("帳號與同步…", systemImage: "icloud")
                }
                Divider()
                Button { NotificationCenter.default.post(name: .openSettings, object: SettingsPage.Section.profile) } label: {
                    Label("個人檔案…", systemImage: "person.crop.circle")
                }
                Button { NotificationCenter.default.post(name: .openSettings, object: nil) } label: {
                    Label("設定…", systemImage: "gearshape")
                }
                .keyboardShortcut(",")
            } label: {
                HStack(spacing: 8) {
                    AvatarView(name: store.userAvatar, size: 20)
                    Text(store.userName).font(Font.zCallout).foregroundStyle(Color.zText).lineLimit(1)
                    Text("· 本機").font(Font.zCaption).foregroundStyle(Color.zText3)
                    Image(systemName: "chevron.down").font(Font.zMicro).foregroundStyle(Color.zText3)
                    Spacer()
                }
                .frame(maxWidth: .infinity)
                .contentShape(Rectangle())
            }
            .menuStyle(.button)
            .buttonStyle(.plain)
            .menuIndicator(.hidden)
            .labelStyle(.titleAndIcon)
            .tint(Color.primary)   // 選單 icon 跟文字同色，不用主色
            .padding(.horizontal, 14)
            .frame(height: 44)
        }
    }
}
