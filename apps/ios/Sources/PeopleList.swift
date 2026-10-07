import SwiftUI

/// 命盤列表：分組成 Section，可搜尋、左滑刪除、右滑釘選、長按選單
struct PeopleList: View {
    @EnvironmentObject private var store: Store
    @State private var query = ""
    @State private var adding = false
    @State private var editing: Person?
    @State private var deleting: Person?
    @AppStorage("hideBirth") private var hideBirth = false

    var body: some View {
        List {
            if query.isEmpty, store.showSelfInSidebar, let me = store.me {
                Section("我") { link(me) }
            }
            ForEach(sections, id: \.0) { title, list in
                Section(title) {
                    ForEach(list) { link($0) }
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("命盤")
        .navigationDestination(for: UUID.self) { id in
            if let p = store.people.first(where: { $0.id == id }) { ChartView(person: p) }
        }
        .searchable(text: $query, prompt: "搜尋姓名、分組、命宮主星")
        .toolbar {
            ToolbarItem(placement: .topBarLeading) { sortMenu }
            ToolbarItem(placement: .topBarTrailing) {
                Button { adding = true } label: { Image(systemName: "plus") }
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
            if ProcessInfo.processInfo.environment["ZIWEI_NEW"] != nil { adding = true }
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

    private func link(_ p: Person) -> some View {
        NavigationLink(value: p.id) { PersonRow(person: p, soul: store.soulStars[p.id], hideBirth: hideBirth) }
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
            Image(systemName: "arrow.up.arrow.down")
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
            Text(String(person.name.prefix(1)))
                .font(.zHeadline)
                .foregroundStyle(Color.zText2)
                .frame(width: 40, height: 40)
                .background(Circle().fill(Color.zHover))
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(hideBirth ? person.name.maskedName : person.name).font(.zHeadline).foregroundStyle(Color.zText)
                    Text(person.gender.rawValue).zText(.footnote).foregroundStyle(Color.zText3)
                    if person.pinned { Image(systemName: "pin.fill").font(.caption2).foregroundStyle(Color.zAccent) }
                }
                HStack(spacing: 6) {
                    if let soul { Text(soul.isEmpty ? "命無主星" : "命 \(soul)").foregroundStyle(Color.wmRed) }
                    if !hideBirth { Text(person.clock ?? person.solar).foregroundStyle(Color.zText3) }
                }
                .zText(.footnote)
            }
        }
        .padding(.vertical, 2)
    }
}
