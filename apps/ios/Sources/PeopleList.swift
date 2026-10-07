import SwiftUI

/// 所有命盤（從側欄進）：跟「我的」「日記」同一套樣式——小標＋大標、暖白底、淺灰圓角卡片；
/// 底下還是系統 List，左滑刪除、右滑釘選、長按選單都照用
struct PeopleList: View {
    @EnvironmentObject private var store: Store
    @State private var query = ""
    @State private var adding = false
    @State private var editing: Person?
    @State private var deleting: Person?
    @State private var routed: UUID?   // 驗證用：ZIWEI_ROUTE=姓名 直接打開那張盤
    @AppStorage("hideBirth") private var hideBirth = false

    var body: some View {
        List {
            let showMe = query.isEmpty && store.showSelfInSidebar && store.me != nil
            if showMe, let me = store.me {
                Section { link(me) } header: { header("我", first: true) }
            }
            ForEach(Array(sections.enumerated()), id: \.element.0) { i, sec in
                Section {
                    ForEach(sec.1) { link($0) }
                } header: { header(sec.0, first: !showMe && i == 0) }
            }
        }
        .listStyle(.insetGrouped)
        .listSectionSpacing(20)
        .scrollContentBackground(.hidden)
        .background(Color.zBg)
        .environment(\.defaultMinListRowHeight, 64)
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .searchable(text: $query, placement: .navigationBarDrawer(displayMode: .automatic), prompt: "搜尋姓名、分組、命宮主星")
        // 搜尋框跟著內容：往上滑收走、往下滑回頂端才出現；導覽列沒有底色，捲到上面用漸層霧化
        .zEdgeFades()
        .navigationDestination(for: UUID.self) { id in
            if let p = store.people.first(where: { $0.id == id }) { ChartView(person: p) }
        }
        .navigationDestination(item: $routed) { id in
            if let p = store.people.first(where: { $0.id == id }) { ChartView(person: p) }
        }
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                sortMenu
                Button { adding = true } label: { Image(systemName: "plus").foregroundStyle(Color.zText) }
                    .accessibilityLabel("新增命盤")
            }
        }
        .overlay {
            if store.people.isEmpty {
                ContentUnavailableView {
                    Label("還沒有命盤", systemImage: "person.crop.circle.badge.plus")
                } description: {
                    Text("新增客人或家人的生辰，就能排盤、記錄")
                } actions: {
                    Button("新增命盤") { adding = true }.buttonStyle(.borderedProminent)
                }
            } else if !query.isEmpty && sections.isEmpty {
                ContentUnavailableView.search(text: query)
            }
        }
        .sheet(isPresented: $adding) { PersonForm() }
        .sheet(item: $editing) { PersonForm(editing: $0) }
        .confirmationDialog("刪除「\(deleting?.name ?? "")」的命盤？", isPresented: Binding(get: { deleting != nil }, set: { if !$0 { deleting = nil } }),
                            titleVisibility: .visible) {
            Button("刪除", role: .destructive) {
                if let p = deleting { withAnimation { store.delete(p.id) } }
                deleting = nil
            }
        } message: {
            Text("刪除後無法復原")
        }
        .onAppear {
            // 驗證用：ZIWEI_NEW=1 直接打開新增命盤
            let env = ProcessInfo.processInfo.environment
            if env["ZIWEI_NEW"] != nil { adding = true }
            if let name = env["ZIWEI_ROUTE"], routed == nil { routed = store.people.first { $0.name == name }?.id }
        }
    }

    /// 分組（釘選在最前面）；搜尋時比對姓名、分組、命宮主星
    private var sections: [(String, [Person])] {
        let q = query.trimmingCharacters(in: .whitespaces)
        let hide = store.showSelfInSidebar ? store.selfID : nil
        return store.groups.compactMap { g, list in
            let shown = store.sorted(list).filter { p in
                if q.isEmpty { return p.id != hide }
                return p.name.contains(q) || p.group.contains(q) || (store.soulStars[p.id] ?? "").contains(q)
            }
            return shown.isEmpty ? nil : (g, shown)
        }
    }

    /// 分組標題；第一個分組上面再放頁面的小標＋大標
    private func header(_ t: String, first: Bool = false) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            if first {
                Text("CHARTS · 命盤").zText(.eyebrow).foregroundStyle(Color.zAccent).padding(.bottom, 4)
                Text("所有命盤").zText(.titleLarge).foregroundStyle(Color.zText).padding(.bottom, 20)
            }
            Text(t).zText(.eyebrow).foregroundStyle(Color.zText3)
        }
        .textCase(nil)
        .padding(.leading, first ? 0 : -16)
    }

    private func link(_ p: Person) -> some View {
        NavigationLink(value: p.id) { PersonRow(person: p, soul: store.soulStars[p.id], hideBirth: hideBirth) }
            .listRowBackground(Color.zHover)
            .listRowSeparatorTint(Color.zLine)
            .swipeActions(edge: .trailing) {
                Button("刪除", systemImage: "trash", role: .destructive) { deleting = p }
                Button("編輯", systemImage: "pencil") { editing = p }.tint(.gray)
            }
            .swipeActions(edge: .leading) {
                Button(p.pinned ? "取消釘選" : "釘選", systemImage: p.pinned ? "pin.slash" : "pin") { togglePin(p) }
                    .tint(Color.zAccent)
            }
            .contextMenu {
                Button("編輯命主資料", systemImage: "pencil") { editing = p }
                Button(p.pinned ? "取消釘選" : "釘選", systemImage: p.pinned ? "pin.slash" : "pin") { togglePin(p) }
                Divider()
                Button("刪除", systemImage: "trash", role: .destructive) { deleting = p }
            }
    }

    private func togglePin(_ p: Person) {
        var q = p; q.pinned.toggle()
        withAnimation { store.update(q) }
    }

    private var sortMenu: some View {
        Menu {
            Picker("排序", selection: $store.sortMode) {
                ForEach(Store.SortMode.allCases.filter { $0 != .custom }, id: \.self) { m in
                    Label(m.label, systemImage: m.icon).tag(m)
                }
                Label("加入順序", systemImage: "hand.draw").tag(Store.SortMode.custom)
            }
            Divider()
            Toggle("隱藏生辰", isOn: $hideBirth)
        } label: {
            Image(systemName: "arrow.up.arrow.down").foregroundStyle(Color.zText)
        }
        .accessibilityLabel("排序")
    }
}

/// 列表的一列：頭貼（沒有就用姓的第一個字）＋姓名、命宮主星、生日
struct PersonRow: View {
    let person: Person
    let soul: String?
    var hideBirth = false

    var body: some View {
        HStack(spacing: 12) {
            AvatarView(name: person.avatar, size: 40)
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(hideBirth ? person.name.maskedName : person.name).font(.zHeadline).foregroundStyle(Color.zText)
                    Text(person.gender.rawValue).zText(.footnote).foregroundStyle(Color.zText3)
                    if person.pinned { Image(systemName: "pin.fill").font(.caption2).foregroundStyle(Color.zAccent) }
                }
                HStack(spacing: 6) {
                    // 主星用次要灰，「命」再淡一階：名字才是主角
                    if soul == nil { SkeletonBar(width: 56, height: 11) }
                    if let soul {
                        if soul.isEmpty { Text("命無主星").foregroundStyle(Color.zText3) }
                        else { Text("命 ").foregroundStyle(Color.zText3) + Text(soul).foregroundStyle(Color.zText2) }
                    }
                    if !hideBirth { Text(person.clock ?? person.solar).foregroundStyle(Color.zText3) }
                }
                .zText(.footnote)
            }
        }
        .padding(.vertical, 2)
    }
}
