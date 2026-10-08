import SwiftUI

/// 側欄（照 Claude App）：上面是我的命盤、所有命盤，下面是釘選與最近看過的紀錄；
/// 左下角頭像（到設定）、右下角黑色「新增命盤」
struct SidebarView: View {
    let current: UUID?
    var showingAll = false
    var onPick: (UUID?) -> Void
    var onAllCharts: () -> Void
    var onNew: () -> Void
    var onProfile: () -> Void
    @EnvironmentObject private var store: Store
    @AppStorage("recentCharts") private var recentRaw = ""
    @AppStorage("hideBirth") private var hideBirth = false
    @State private var editing: Person?
    @State private var deleting: Person?

    var body: some View {
        ZStack(alignment: .bottom) {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    Text("StillLink")
                        .zText(.title1)
                        .foregroundStyle(Color.zText)
                        .padding(.horizontal, 20)
                        .padding(.top, 12)
                        .padding(.bottom, 20)

                    row("我的命盤", icon: "person.crop.circle", selected: current == nil && !showingAll) { onPick(nil) }
                        .contextMenu {
                            if let me = store.me { Button("編輯命主資料", systemImage: "pencil") { editing = me } }
                        }
                    row("所有命盤", icon: "person.2", selected: showingAll, action: onAllCharts)

                    let pinned = store.people.filter(\.pinned)
                    if !pinned.isEmpty {
                        section("釘選")
                        ForEach(pinned) { p in personRow(p) }
                    }
                    if !recent.isEmpty {
                        section("最近")
                        ForEach(recent) { p in personRow(p) }
                    }
                }
                .padding(.horizontal, 8)
                .padding(.bottom, 110)   // 留給底部按鈕
            }
            .scrollIndicators(.hidden)

            bottomBar
        }
        .background(Color.zSide.ignoresSafeArea())
        .sheet(item: $editing) { PersonForm(editing: $0) }
        .confirmationDialog("刪除「\(deleting?.name ?? "")」的命盤？", isPresented: Binding(get: { deleting != nil }, set: { if !$0 { deleting = nil } }),
                            titleVisibility: .visible) {
            Button("刪除", role: .destructive) {
                if let p = deleting { withAnimation { store.delete(p.id) }; if current == p.id { onPick(nil) } }
                deleting = nil
            }
        } message: { Text("刪除後無法復原") }
    }

    /// 最近看過的命盤（首頁打開過的），不夠就用最近新增的補到 12 筆；釘選的不重複列
    private var recent: [Person] {
        let byID = Dictionary(store.people.map { ($0.id, $0) }, uniquingKeysWith: { a, _ in a })
        var out = recentRaw.split(separator: ",").compactMap { UUID(uuidString: String($0)).flatMap { byID[$0] } }
        for p in store.people.sorted(by: { $0.createdAt > $1.createdAt }) where out.count < 12 && !out.contains(p) { out.append(p) }
        return out.filter { !$0.pinned && $0.id != store.selfID }.prefix(12).map { $0 }   // 自己的盤在最上面「我的命盤」
    }

    private func section(_ t: String) -> some View {
        Text(t)
            .zText(.subheadline)
            .foregroundStyle(Color.zText3)
            .padding(.horizontal, 12)
            .padding(.top, 24)
            .padding(.bottom, 6)
    }

    private func personRow(_ p: Person) -> some View {
        row(hideBirth ? p.name.maskedName : p.name, icon: nil, selected: current == p.id,
            detail: store.soulStars[p.id].map { $0.isEmpty ? "命無主星" : $0 }, loading: store.soulStars[p.id] == nil) { onPick(p.id) }
            // 長按：跟 Claude 一樣浮起來＋選單
            .contextMenu {
                Button(p.pinned ? "取消釘選" : "釘選", systemImage: p.pinned ? "pin.slash" : "pin") {
                    var q = p; q.pinned.toggle(); withAnimation { store.update(q) }
                }
                Button("編輯命主資料", systemImage: "pencil") { editing = p }
                Divider()
                Button("刪除", systemImage: "trash", role: .destructive) { deleting = p }
            }
    }

    private func row(_ title: String, icon: String?, selected: Bool, detail: String? = nil, loading: Bool = false, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 14) {
                // 命盤列不放圖示，只有功能列（我的命盤、所有命盤）有
                if let icon {
                    Image(systemName: icon)
                        .font(.system(size: 18, weight: .regular))
                        .foregroundStyle(Color.zText2)
                        .frame(width: 26)
                }
                Text(title).zText(.body).foregroundStyle(Color.zText).lineLimit(1)
                Spacer(minLength: 8)
                if let detail { Text(detail).zText(.footnote).foregroundStyle(Color.zText3).lineLimit(1) }
                else if loading { SkeletonBar(width: 40, height: 10) }
            }
            .padding(.horizontal, 12)
            .frame(height: 48)
            // 底色用側欄色（不是透明）：長按浮起來的預覽才是一整列圓角卡片，不會只剩幾個字飄著、看起來錯位
            .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(selected ? Color.zSel : Color.zSide))
            .contentShape(Rectangle())
            .contentShape(.contextMenuPreview, RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private var bottomBar: some View {
        HStack {
            Button(action: onProfile) {
                AvatarView(name: store.userAvatar, size: 52)
                    .overlay(Circle().stroke(Color.zLine))
                    .shadow(color: .black.opacity(0.08), radius: 8, y: 2)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("個人檔案與設定")
            Spacer()
            Button(action: onNew) {
                Label("新增命盤", systemImage: "plus")
                    .zText(.bodyStrong)
                    .foregroundStyle(Color.zBg)
                    .padding(.horizontal, 22)
                    .frame(height: 52)
                    .background(Capsule().fill(Color.zText))
                    .shadow(color: .black.opacity(0.15), radius: 10, y: 3)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 8)
        .background(alignment: .bottom) {
            // 底部按鈕後面淡出，捲到下面的列不會跟按鈕疊在一起
            LinearGradient(colors: [Color.zSide.opacity(0), Color.zSide], startPoint: .top, endPoint: .center)
                .frame(height: 110)
                .ignoresSafeArea()
                .allowsHitTesting(false)
        }
    }
}

/// 側欄按鈕（照 Claude）：三條由長到短的細線
struct SidebarGlyph: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            ForEach([20.0, 15, 9], id: \.self) { w in
                Capsule().frame(width: w, height: 1.8)
            }
        }
        .frame(width: 20, height: 20, alignment: .leading)   // 框跟最長那條一樣寬，放在按鈕裡才會置中
    }
}
