import SwiftUI

/// Claude／Codex 式側欄：平面列、圓角選取底色、小灰字分組標題、分組像 Codex 的資料夾
struct Sidebar: View {
    @EnvironmentObject var store: Store
    @Binding var route: Route?
    var onNew: () -> Void
    @State private var searching = false
    @State private var search = ""
    @State private var collapsed: Set<String> = []
    @State private var renaming: Person?
    @State private var newName = ""
    @FocusState private var searchFocused: Bool
    @Namespace private var selNS   // 選取底色在列之間滑動

    private var q: String { search.trimmingCharacters(in: .whitespaces) }

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 1) {
                    NavRow(icon: "house", title: "此刻", selected: route == .home || route == nil) { withAnimation(Motion.snap) { route = .home } }
                    if store.showSelfInSidebar {
                        NavRow(icon: "person.crop.circle", title: store.me == nil ? "我（尚未設定）" : "我 · \(store.userName)",
                               selected: store.me.map { route == .person($0.id) } ?? false) {
                            if let me = store.me { route = .person(me.id) }
                            else { NotificationCenter.default.post(name: .openSettings, object: SettingsPage.Section.profile) }
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
                    } else {
                        NavRow(icon: "magnifyingglass", title: "搜尋", shortcut: "⌘F") {
                            searching = true
                            DispatchQueue.main.async { searchFocused = true }
                        }
                    }

                    let pinned = store.people.filter { $0.pinned && matches($0) && $0.id != store.selfID }
                    if !pinned.isEmpty {
                        SectionLabel("釘選").padding(.top, 18)
                        ForEach(pinned) { p in personRow(p, indent: false) }
                    }

                    SectionLabel("命盤", action: onNew).padding(.top, 18)
                    ForEach(groupNames, id: \.self) { g in
                        let list = store.people.filter { !$0.pinned && $0.group == g && matches($0) && $0.id != store.selfID }
                        if !list.isEmpty {
                            FolderRow(name: g, count: list.count, open: !collapsed.contains(g),
                                      onAdd: { NotificationCenter.default.post(name: .newChart, object: g) }) {
                                withAnimation(Motion.base) {
                                    if collapsed.contains(g) { collapsed.remove(g) } else { collapsed.insert(g) }
                                }
                            }
                            if !collapsed.contains(g) {
                                ForEach(list) { p in
                                    personRow(p, indent: true)
                                        .transition(.opacity.combined(with: .offset(y: -4)))
                                }
                            }
                        }
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
        .onChange(of: route) { _, _ in
            if searching { searching = false; search = "" }
        }
        .background(
            Button("") { searching = true; DispatchQueue.main.async { searchFocused = true } }
                .keyboardShortcut("f").hidden()
        )
    }

    private var groupNames: [String] {
        var order: [String] = []
        for p in store.people where !p.pinned && p.id != store.selfID && !order.contains(p.group) { order.append(p.group) }
        return order
    }

    private func matches(_ p: Person) -> Bool { q.isEmpty || p.name.contains(q) }

    private func personRow(_ p: Person, indent: Bool) -> some View {
        let on = route == .person(p.id)
        return Button { withAnimation(Motion.snap) { route = .person(p.id) } } label: {
            HStack(spacing: 9) {
                Circle()
                    .stroke(Color.zText3, lineWidth: 1)
                    .frame(width: 6, height: 6)
                    .padding(.leading, 7) // 圓點對齊資料夾圖示中心
                Text(p.name).font(Font.zBody).foregroundStyle(Color.zText).lineLimit(1)
                Spacer(minLength: 6)
                Text(store.soulStars[p.id] ?? "")
                    .font(Font.zCaption).foregroundStyle(Color.zText3).lineLimit(1)
            }
            .padding(.horizontal, 8)
            .frame(height: 30)
            .background {
                if on { RoundedRectangle(cornerRadius: 8).fill(Color.zSel).matchedGeometryEffect(id: "sel", in: selNS) }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(RowButtonStyle(selected: on))
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
    @State private var hover = false
    init(_ t: String, action: (() -> Void)? = nil) { text = t; self.action = action }
    var body: some View {
        HStack {
            Text(text).font(Font.zCaption).foregroundStyle(Color.zText3)
            Spacer()
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
                    ForEach(Appearance.allCases, id: \.self) { Text($0.label).tag($0) }
                }
                .pickerStyle(.inline)
                Divider()
                Button { } label: { Label("使用 Apple 登入", systemImage: "apple.logo") }
                Button { } label: { Label("使用 Google 登入", systemImage: "g.circle") }
                Divider()
                Button("個人檔案…") { NotificationCenter.default.post(name: .openSettings, object: SettingsPage.Section.profile) }
                Button("設定…") { NotificationCenter.default.post(name: .openSettings, object: nil) }
                    .keyboardShortcut(",")
            } label: {
                HStack(spacing: 8) {
                    Text(String(store.userName.prefix(1)).uppercased())
                        .font(Font.zMicroStrong)
                        .frame(width: 20, height: 20)
                        .background(Circle().fill(Color.zSel))
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
            .padding(.horizontal, 14)
            .frame(height: 44)
        }
    }
}
