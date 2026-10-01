import SwiftUI

struct Sidebar: View {
    @EnvironmentObject var store: Store
    @Binding var route: Route?
    @Binding var search: String

    private var filtered: [(String, [Person])] {
        let q = search.trimmingCharacters(in: .whitespaces)
        guard !q.isEmpty else { return store.groups }
        return store.groups.compactMap { g, list in
            let hit = list.filter { $0.name.contains(q) }
            return hit.isEmpty ? nil : (g, hit)
        }
    }

    var body: some View {
        List(selection: $route) {
            Label("新增命盤", systemImage: "plus")
                .tag(Route.home)

            ForEach(filtered, id: \.0) { group, list in
                Section(group) {
                    ForEach(list) { p in
                        PersonRow(person: p)
                            .tag(Route.person(p.id))
                            .contextMenu {
                                Button(p.pinned ? "取消釘選" : "釘選") {
                                    var q = p; q.pinned.toggle(); store.update(q)
                                }
                                Divider()
                                Button("刪除", role: .destructive) {
                                    if route == .person(p.id) { route = .home }
                                    store.delete(p.id)
                                }
                            }
                    }
                }
            }
        }
        .listStyle(.sidebar)
        .searchable(text: $search, placement: .sidebar, prompt: "搜尋姓名")
        .safeAreaInset(edge: .bottom, spacing: 0) { AccountBar() }
    }
}

private struct PersonRow: View {
    let person: Person
    var body: some View {
        let soul = Engine.shared.chart(for: person).palaces.first { $0.name == "命宮" }
        HStack(spacing: 8) {
            Circle().fill(Color.zText3.opacity(0.6)).frame(width: 5, height: 5)
            Text(person.name).lineLimit(1)
            Spacer(minLength: 4)
            Text(soul?.major.map(\.name).joined() ?? "")
                .font(.system(size: 11))
                .foregroundStyle(.tertiary)
                .lineLimit(1)
        }
    }
}

/// 左下角帳號列：點開是外觀、登入與設定
private struct AccountBar: View {
    @EnvironmentObject var store: Store

    var body: some View {
        VStack(spacing: 0) {
            Divider()
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
                        .font(.system(size: 11, weight: .semibold))
                        .frame(width: 22, height: 22)
                        .background(Circle().fill(Color.zSel))
                    VStack(alignment: .leading, spacing: 0) {
                        Text("Jean").font(.system(size: 12.5, weight: .medium))
                        Text("本機 · 未登入").font(.system(size: 10.5)).foregroundStyle(.secondary)
                    }
                    Spacer()
                    Image(systemName: "chevron.up.chevron.down").font(.system(size: 10)).foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .contentShape(Rectangle())
            }
            .menuStyle(.button)
            .buttonStyle(.plain)
            .menuIndicator(.hidden)
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
        }
    }
}
