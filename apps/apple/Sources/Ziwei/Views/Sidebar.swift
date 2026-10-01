import SwiftUI

/// Claude／Codex 式側欄：平面列、圓角選取底色、小灰字分組標題、分組像 Codex 的資料夾
struct Sidebar: View {
    @EnvironmentObject var store: Store
    @Binding var route: Route?
    var onNew: () -> Void
    @State private var searching = false
    @State private var search = ""
    @State private var collapsed: Set<String> = []
    @FocusState private var searchFocused: Bool

    private var q: String { search.trimmingCharacters(in: .whitespaces) }

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 1) {
                    NavRow(icon: "house", title: "此刻", selected: route == .home || route == nil) { route = .home }
                    NavRow(icon: "plus", title: "新增命盤", shortcut: "⌘N", action: onNew)
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

                    let pinned = store.people.filter { $0.pinned && matches($0) }
                    if !pinned.isEmpty {
                        SectionLabel("釘選").padding(.top, 18)
                        ForEach(pinned) { p in personRow(p, indent: false) }
                    }

                    SectionLabel("命盤").padding(.top, 18)
                    ForEach(groupNames, id: \.self) { g in
                        let list = store.people.filter { !$0.pinned && $0.group == g && matches($0) }
                        if !list.isEmpty {
                            FolderRow(name: g, count: list.count, open: !collapsed.contains(g)) {
                                withAnimation(.easeOut(duration: 0.15)) {
                                    if collapsed.contains(g) { collapsed.remove(g) } else { collapsed.insert(g) }
                                }
                            }
                            if !collapsed.contains(g) {
                                ForEach(list) { p in personRow(p, indent: true) }
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
        .background(Color.zSide)
        .background(
            Button("") { searching = true; DispatchQueue.main.async { searchFocused = true } }
                .keyboardShortcut("f").hidden()
        )
    }

    private var groupNames: [String] {
        var order: [String] = []
        for p in store.people where !p.pinned && !order.contains(p.group) { order.append(p.group) }
        return order
    }

    private func matches(_ p: Person) -> Bool { q.isEmpty || p.name.contains(q) }

    private func personRow(_ p: Person, indent: Bool) -> some View {
        let on = route == .person(p.id)
        return Button { route = .person(p.id) } label: {
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
            .background(RoundedRectangle(cornerRadius: 8).fill(on ? Color.zSel : Color.clear))
            .contentShape(Rectangle())
        }
        .buttonStyle(RowButtonStyle(selected: on))
        .contextMenu {
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
        }
        .buttonStyle(.plain)
        .onHover { hover = $0 }
    }
}

private struct FolderRow: View {
    let name: String
    let count: Int
    let open: Bool
    let action: () -> Void
    @State private var hover = false
    var body: some View {
        Button(action: action) {
            HStack(spacing: 9) {
                Image(systemName: open ? "folder" : "folder.fill")
                    .font(Font.zCallout).foregroundStyle(Color.zText2).frame(width: 16)
                Text(name).font(Font.zBody).foregroundStyle(open ? Color.zText : Color.zText2)
                Spacer()
                Text("\(count)").font(Font.zCaption).foregroundStyle(Color.zText3)
            }
            .padding(.horizontal, 10)
            .frame(height: 30)
            .background(RoundedRectangle(cornerRadius: 8).fill(hover ? Color.zHover : Color.clear))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hover = $0 }
    }
}

private struct SectionLabel: View {
    let text: String
    init(_ t: String) { text = t }
    var body: some View {
        Text(text).font(Font.zCaption).foregroundStyle(Color.zText3)
            .padding(.horizontal, 10).padding(.bottom, 4)
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
                Button("命盤設定…") { }
            } label: {
                HStack(spacing: 8) {
                    Text("J")
                        .font(Font.zMicroStrong)
                        .frame(width: 20, height: 20)
                        .background(Circle().fill(Color.zSel))
                    Text("Jean").font(Font.zCallout).foregroundStyle(Color.zText)
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
