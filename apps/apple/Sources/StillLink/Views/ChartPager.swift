import SwiftUI

/// 多張盤左右滑動：第一頁是原本的盤，按盤面旁的「＋」可以再加（已存命盤或臨時輸入），每頁運限各自獨立
struct ChartPager: View {
    @EnvironmentObject var store: Store
    let primary: Person
    var level: Int? = nil
    @State private var extras: [Person] = []
    @State private var page: Int? = 0
    @State private var picking = false
    @AppStorage("showInfoPanel") private var showInfo = true

    private var pages: [Person] { [primary] + extras }
    private var current: Int { min(page ?? 0, pages.count - 1) }

    var body: some View {
        // 系統只會幫第一個捲動區自動讓開工具列，後面的頁不會 → 自己量工具列高度，每頁都讓出一樣的距離
        GeometryReader { outer in
            let top = outer.safeAreaInsets.top
            GeometryReader { geo in
                let row = LazyHStack(spacing: 0) {
                    ForEach(Array(pages.enumerated()), id: \.element.id) { i, p in
                        ChartScreen(person: p, level: i == 0 ? level : nil, chrome: false, onAdd: { picking = true })
                            .padding(.top, top)
                            .frame(width: geo.size.width, height: geo.size.height)
                            .id(i)
                    }
                }
                // 不要用 scrollDisabled：它會連裡面的捲動（整頁往下捲、運限表）一起關掉
                // 驗證用：ZIWEI_FORCE13=1 在新系統上也走 macOS 13 的做法
                if #available(macOS 14, *), ProcessInfo.processInfo.environment["ZIWEI_FORCE13"] == nil {
                    ScrollView(.horizontal) { row.scrollTargetLayout() }
                        .scrollTargetBehavior(.paging)
                        .scrollPosition(id: $page)
                        .scrollIndicators(.never)
                } else {
                    // macOS 13：沒有整頁吸附 → 不用橫向捲動，所有頁疊在一起只顯示目前那頁，點頁籤切換（每頁狀態都保留）
                    ZStack {
                        ForEach(Array(pages.enumerated()), id: \.element.id) { i, p in
                            // 一律照鐘錶時間排盤（跟文墨天機一樣），舊命盤也重算；真太陽時只顯示
                            ChartScreen(person: p.resolved(), level: i == 0 ? level : nil, chrome: false, isCurrent: i == current, onAdd: { picking = true })
                                .padding(.top, top)
                                .frame(width: geo.size.width, height: geo.size.height)
                                .opacity(i == current ? 1 : 0)
                                .allowsHitTesting(i == current)
                        }
                    }
                }
            }
            .ignoresSafeArea(edges: .top)
        }
        .navigationTitle(ChartScreen.title(pages[current]))
        .toolbar {
            if !extras.isEmpty {
                ToolbarItem(placement: .principal) { pageBar }
            }
            ToolbarItem(placement: .primaryAction) {
                Button { withAnimation(Motion.enter) { showInfo.toggle() } } label: { Image(systemName: "sidebar.right") }
                    .help("客人資料")
            }
        }
        .onAppear {
            // 驗證用：ZIWEI_PAGER_DEMO=1／2 → 自動加一張臨時盤，停在第 1／2 頁
            if let v = ProcessInfo.processInfo.environment["ZIWEI_PAGER_DEMO"], extras.isEmpty {
                extras = [TempChart.make(2000, 1, 1, 8, 0, .male, name: "臨時盤")]
                if v == "2" { DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { page = 1 } }
            }
        }
        .sheet(isPresented: $picking) {
            AddChartSheet(exclude: Set(pages.map(\.id))) { p in
                extras.append(p)
                let target = pages.count - 1
                DispatchQueue.main.async { withAnimation(Motion.base) { page = target } }
            }
            .environmentObject(store)
        }
    }

    /// 上方的頁籤：點名字切頁，加進來的盤可以按 × 關掉
    private var pageBar: some View {
        HStack(spacing: 4) {
            ForEach(Array(pages.enumerated()), id: \.element.id) { i, p in
                HStack(spacing: 4) {
                    Text(p.id == NowChart.id ? "此刻" : p.name).font(Font.zCaptionStrong).lineLimit(1)
                    if i > 0 {
                        Button { remove(i) } label: { Image(systemName: "xmark").font(Font.zMicroStrong) }
                            .buttonStyle(.plain)
                            .help("關掉這張盤")
                    }
                }
                .foregroundStyle(i == current ? Color.zText : Color.zText3)
                .padding(.horizontal, 10).frame(height: 24)
                .background(Capsule().fill(i == current ? Color.zSel : Color.clear))
                .contentShape(Capsule())
                .onTapGesture { withAnimation(Motion.base) { page = i } }
            }
        }
    }

    private func remove(_ i: Int) {
        let wasCurrent = i == current
        extras.remove(at: i - 1)
        if wasCurrent || current >= pages.count { page = max(0, i - 1) }
    }
}

/// 「＋」之後選第二張盤：已存的命盤，或臨時輸入生辰（不存檔）
struct AddChartSheet: View {
    @EnvironmentObject var store: Store
    @Environment(\.dismiss) private var dismiss
    let exclude: Set<UUID>
    let onPick: (Person) -> Void
    @State private var entering = false
    @State private var query = ""

    var body: some View {
        Group {
            if entering {
                NewChartSheet(temporary: true, onClose: { dismiss() }) { p in onPick(p) }
            } else {
                list
            }
        }
        .frame(width: entering ? 640 : 420, height: entering ? 700 : 520)
        .background(Color.zBg)
    }

    private var list: some View {
        let people = store.people.filter { !exclude.contains($0.id) && (query.isEmpty || $0.name.contains(query)) }
        return VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("加一張盤").font(Font.zTitle).foregroundStyle(Color.zText)
                Spacer()
                Button("取消") { dismiss() }.buttonStyle(ZSecondaryButton(small: true))
            }
            HStack(spacing: 6) { TextField("搜尋姓名", text: $query); ZClearButton(text: $query) }.zInput(icon: "magnifyingglass")
            Button { entering = true } label: {
                Label("臨時輸入生辰…（不存檔）", systemImage: "square.and.pencil")
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(ZSecondaryButton())
            Text("已存的命盤").font(Font.zCaption).foregroundStyle(Color.zText3).padding(.top, 4)
            ScrollView {
                VStack(spacing: 1) {
                    if people.isEmpty {
                        Text(store.people.isEmpty ? "還沒有存任何命盤" : "沒有符合的命盤")
                            .font(Font.zCallout).foregroundStyle(Color.zText3).padding(.vertical, 20)
                    }
                    ForEach(people) { p in
                        PickRow(person: p, soul: store.soulStars[p.id] ?? "") { onPick(p); dismiss() }
                    }
                }
            }
        }
        .padding(20)
    }
}

private struct PickRow: View {
    let person: Person
    let soul: String
    let action: () -> Void
    @State private var hover = false
    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                AvatarView(name: person.avatar, size: 22)
                VStack(alignment: .leading, spacing: 1) {
                    Text(person.name).font(Font.zBody).foregroundStyle(Color.zText)
                    Text("\(person.gender.rawValue) · \(person.clock ?? person.solar) · \(person.group)")
                        .font(Font.zCaption).foregroundStyle(Color.zText3)
                }
                Spacer()
                Text(soul).font(Font.zCaption).foregroundStyle(Color.zText3)
            }
            .padding(.horizontal, 10).frame(height: 44)
            .background(RoundedRectangle(cornerRadius: 8).fill(hover ? Color.zHover : .clear))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hover = $0 }
    }
}
