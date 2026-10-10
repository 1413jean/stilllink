import SwiftUI

/// 所有命盤（從側欄進）：照 Claude App 的 Chats——導覽列中間標題、一列一列（頭貼＋姓名＋生日）。
/// 導覽列以下（搜尋框、分類膠囊、名單）全部是同一個列表：捲動、下拉更新時一起動，不會互相疊到；
/// 右下角浮著「新增命盤」；左滑刪除、右滑釘選、長按選單照用
struct PeopleList: View {
    @EnvironmentObject private var store: Store
    @State private var query = ""
    @State private var adding = false
    @State private var editing: Person?
    @State private var deleting: Person?
    @State private var routed: UUID?   // 驗證用：ZIWEI_ROUTE=姓名 直接打開那張盤
    @State private var filter: String?  // 分類膠囊：nil＝全部
    @State private var refreshing = false   // 下拉更新中：名單換成骨架
    @AppStorage("hideBirth") private var hideBirth = false

    var body: some View {
        ScrollViewReader { proxy in
            List {
                // 搜尋框、分類列放在列表裡（不用系統導覽列的搜尋抽屜）：下拉時跟名單一起往下
                ZSearchField(text: $query).headerRow(top: 4)
                if showChips { chips.headerRow(top: 2) }
                if refreshing {
                    ForEach(0..<max(6, min(rows.count, 10)), id: \.self) { _ in
                        PersonRowSkeleton()
                            .listRowBackground(Color.clear)
                            .listRowSeparator(.hidden)
                            .listRowInsets(EdgeInsets(top: 6, leading: 20, bottom: 6, trailing: 16))
                    }
                } else {
                    ForEach(rows) { link($0) }
                }
            }
            .refreshable { await CloudSync.refreshWithSkeleton($refreshing) }   // 下拉更新：跟雲端同步一次，同步中名單換成骨架
            .onAppear {
                // 驗證用：ZIWEI_SCROLL=1 一打開就捲到底（看滑動後頂端的樣子）
                guard ProcessInfo.processInfo.environment["ZIWEI_SCROLL"] == "1", let last = rows.last?.id else { return }
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { proxy.scrollTo(last, anchor: .bottom) }
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .scrollDismissesKeyboard(.immediately)
        .background(Color.zBg)
        .environment(\.defaultMinListRowHeight, 0)   // 命盤列自己撐到 64（見 link），搜尋框、分類列照自己的高度
        .safeAreaInset(edge: .bottom) { Color.clear.frame(height: 64) }   // 右下角的新增按鈕不蓋到最後一列
        .navigationTitle("所有命盤")
        .navigationBarTitleDisplayMode(.inline)
        // 頂部跟首頁一樣；底部漸層蓋到新增按鈕那一帶，名單淡出得比較自然
        .zEdgeFades(bottom: 72)
        // 新增按鈕要浮在底部漸層霧化上面，所以放在 zEdgeFades 之後
        .overlay(alignment: .bottomTrailing) {
            Button { adding = true } label: { Label("新增命盤", systemImage: "plus") }
                .buttonStyle(.capsule(floating: true))
            .padding(.trailing, 16).padding(.bottom, 8)
        }
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
            } else if !query.isEmpty && rows.isEmpty {
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

    /// 一整條（不分段）：我（側欄有顯示時）→ 照分類順序；選了分類只剩那一類；搜尋時比對姓名、分組、命宮主星
    private var rows: [Person] {
        let q = query.trimmingCharacters(in: .whitespaces)
        if !q.isEmpty {
            return groupList.flatMap(\.1).filter { p in
                p.name.contains(q) || p.group.contains(q) || (store.soulStars[p.id] ?? "").contains(q)
            }
        }
        if let filter { return groupList.first { $0.0 == filter }?.1 ?? [] }
        let me = store.showSelfInSidebar ? store.me : nil
        return (me.map { [$0] } ?? []) + groupList.flatMap(\.1).filter { $0.id != me?.id }
    }

    private var showChips: Bool { query.isEmpty && groupList.count > 1 }

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
        .scrollClipDisabled()
    }

    private func link(_ p: Person) -> some View {
        NavigationLink(value: p.id) { PersonRow(person: p, hideBirth: hideBirth).frame(minHeight: 52) }   // ＋上下 6＝一列 64
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

/// 命盤列的骨架（下拉更新時）：跟 PersonRow 同尺寸，換回來不會跳
struct PersonRowSkeleton: View {
    var body: some View {
        HStack(spacing: 14) {
            Circle().fill(Color.zHover).frame(width: 40, height: 40)
            VStack(alignment: .leading, spacing: 8) {
                RoundedRectangle(cornerRadius: 5).fill(Color.zHover).frame(width: 96, height: 12)
                RoundedRectangle(cornerRadius: 4).fill(Color.zHover).frame(width: 128, height: 9)
            }
            Spacer()
        }
        .frame(minHeight: 52)
        .shimmer()
        .accessibilityLabel("載入中")
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

private extension View {
    /// 列表頂端的搜尋框、分類列：沒有底色、沒有分隔線，左右自己排
    func headerRow(top: CGFloat) -> some View {
        listRowBackground(Color.clear)
            .listRowSeparator(.hidden)
            .listRowInsets(EdgeInsets(top: top, leading: 0, bottom: 4, trailing: 0))
    }
}
