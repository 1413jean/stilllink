import SwiftUI

/// 所有命盤（從側欄進）：照 Claude App 的 Chats——導覽列中間標題、一列一列（頭貼＋姓名＋生日），
/// 最上面一排分類膠囊（全部／釘選／朋友／家人…），「全部」時依分類分段；
/// 右下角浮著「新增命盤」；左滑刪除、右滑釘選、長按選單照用
struct PeopleList: View {
    @EnvironmentObject private var store: Store
    @State private var query = ""
    @State private var adding = false
    @State private var editing: Person?
    @State private var deleting: Person?
    @State private var routed: UUID?   // 驗證用：ZIWEI_ROUTE=姓名 直接打開那張盤
    @State private var filter: String?  // 分類膠囊：nil＝全部
    @AppStorage("hideBirth") private var hideBirth = false

    var body: some View {
        List {
            if query.isEmpty && store.groups.count > 1 {
                chips
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                    .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 4, trailing: 0))
            }
            ForEach(sections, id: \.0) { title, list in
                Section {
                    ForEach(list) { link($0) }
                } header: {
                    if let title { sectionHeader(title, list.count) }
                }
                .listSectionSeparator(.hidden)
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .background(Color.zBg)
        .environment(\.defaultMinListRowHeight, 64)
        .safeAreaInset(edge: .bottom) { Color.clear.frame(height: 64) }   // 右下角的新增按鈕不蓋到最後一列
        .overlay(alignment: .bottomTrailing) {
            Button { adding = true } label: { Label("新增命盤", systemImage: "plus") }
                .buttonStyle(.capsule(floating: true))
            .padding(.trailing, 16).padding(.bottom, 8)
        }
        .navigationTitle("所有命盤")
        .navigationBarTitleDisplayMode(.inline)
        .searchable(text: $query, placement: .navigationBarDrawer(displayMode: .automatic), prompt: "搜尋")
        // 搜尋框跟著內容：往上滑收走、往下滑回頂端才出現；導覽列沒有底色，捲到上面用漸層霧化
        .zEdgeFades()
        .navigationDestination(for: UUID.self) { id in
            if let p = store.people.first(where: { $0.id == id }) { ChartView(person: p) }
        }
        .navigationDestination(item: $routed) { id in
            if let p = store.people.first(where: { $0.id == id }) { ChartView(person: p) }
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) { sortMenu }
        }
        .overlay {
            if store.people.isEmpty {
                ContentUnavailableView {
                    Label("還沒有命盤", systemImage: "person.crop.circle.badge.plus")
                } description: {
                    Text("新增客人或家人的生辰，就能排盤、記錄")
                } actions: {
                    Button("新增命盤") { adding = true }.buttonStyle(.capsule())
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

    /// 分類（照側欄的順序：釘選在前，其他照資料夾順序），各帶張數
    private var groupList: [(String, [Person])] {
        let order = store.groupOrder
        return store.groups.enumerated().sorted { a, b in
            if a.element.0 == "釘選" || b.element.0 == "釘選" { return a.element.0 == "釘選" && b.element.0 != "釘選" }
            let ia = order.firstIndex(of: a.element.0) ?? Int.max, ib = order.firstIndex(of: b.element.0) ?? Int.max
            return ia != ib ? ia < ib : a.offset < b.offset
        }.map { ($0.element.0, store.sorted($0.element.1)) }
    }

    /// 分段：搜尋時一段不分組（比對姓名、分組、命宮主星）；選了分類只剩那一段；
    /// 全部時：我（側欄有顯示時）放最上面不加標題，其他依分類分段
    private var sections: [(String?, [Person])] {
        let q = query.trimmingCharacters(in: .whitespaces)
        if !q.isEmpty {
            let hits = groupList.flatMap(\.1).filter { p in
                p.name.contains(q) || p.group.contains(q) || (store.soulStars[p.id] ?? "").contains(q)
            }
            return hits.isEmpty ? [] : [(nil, hits)]
        }
        if let filter, let g = groupList.first(where: { $0.0 == filter }) { return [(nil, g.1)] }
        let me = store.showSelfInSidebar ? store.me : nil
        var out: [(String?, [Person])] = me.map { [(nil, [$0])] } ?? []
        for (title, list) in groupList {
            let rest = list.filter { $0.id != me?.id }
            if !rest.isEmpty { out.append((title, rest)) }
        }
        return out
    }

    private var chips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                FilterChip(title: "全部", selected: filter == nil) { withAnimation(Motion.fast) { filter = nil } }
                ForEach(groupList, id: \.0) { g, list in
                    FilterChip(title: g, count: list.count, selected: filter == g) {
                        withAnimation(Motion.fast) { filter = filter == g ? nil : g }
                    }
                }
            }
            .padding(.horizontal, 16)
        }
    }

    private func sectionHeader(_ title: String, _ count: Int) -> some View {
        HStack(spacing: 6) {
            Text(title).zText(.footnoteStrong).foregroundStyle(Color.zText2)
            Text("\(count)").zText(.footnote).foregroundStyle(Color.zText3)
        }
        .padding(.leading, 4)
        .padding(.top, 8)
    }

    private func link(_ p: Person) -> some View {
        NavigationLink(value: p.id) { PersonRow(person: p, hideBirth: hideBirth) }
            .listRowBackground(Color.clear)
            .listRowSeparator(.hidden)
            .listRowInsets(EdgeInsets(top: 6, leading: 20, bottom: 6, trailing: 16))
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
            Image(systemName: "slider.horizontal.3").foregroundStyle(Color.zText)
        }
        .accessibilityLabel("排序")
    }
}

/// 列表的一列（照 Claude Chats）：頭貼＋姓名（性別同字級）＋生日
struct PersonRow: View {
    let person: Person
    var hideBirth = false

    var body: some View {
        HStack(spacing: 14) {
            AvatarView(name: person.avatar, size: 40)
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(hideBirth ? person.name.maskedName : person.name).foregroundStyle(Color.zText)
                    Text(person.gender.rawValue).foregroundStyle(Color.zText3)
                    if person.pinned { Image(systemName: "pin.fill").font(.caption2).foregroundStyle(Color.zAccent) }
                }
                .zText(.body)
                .lineLimit(1)
                if !hideBirth {
                    Text(person.clock ?? person.solar).zText(.subheadline).foregroundStyle(Color.zText3)
                }
            }
        }
    }
}
