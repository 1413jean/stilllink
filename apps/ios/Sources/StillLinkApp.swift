import SwiftUI

/// iOS 版入口：外框全部用系統元件（TabView、NavigationStack、List、Form），
/// 盤面、運限表、排盤引擎跟 Mac 版共用同一份程式
@main
struct StillLinkApp: App {
    @StateObject private var store = Store()
    @AppStorage("appearance") private var appearance: Appearance = .system

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(store)
                .environment(\.zSettings, store.settings)
                .tint(Color.zAccent)
                .preferredColorScheme(appearance.scheme)
        }
    }
}

/// 外層：左邊側欄（照 Claude App：整個畫面往右推開）＋三個分頁（首頁、命盤、設定，只放圖示）
struct RootView: View {
    enum Tab: String { case home, people, settings }
    @EnvironmentObject private var store: Store
    @AppStorage("tab") private var tab: Tab = .home
    /// 首頁顯示哪一張盤：nil＝此刻
    @AppStorage("homeChart") private var homeRaw = ""
    @AppStorage("recentCharts") private var recentRaw = ""
    @State private var drawer = false
    @State private var drag: CGFloat = 0
    @State private var adding = false

    private var homeID: UUID? { UUID(uuidString: homeRaw) }

    var body: some View {
        GeometryReader { geo in
            let w = min(geo.size.width * 0.82, 360)
            // 主畫面往右推的距離：開著時可以往左拖回去，關著時從左緣往右拉
            let x = drawer ? max(0, w + min(0, drag)) : max(0, min(w, drag))
            ZStack(alignment: .leading) {
                SidebarView(current: homeID, onPick: show, onAllCharts: {
                    tab = .people; closeDrawer()
                }, onNew: {
                    closeDrawer(); adding = true
                }, onProfile: {
                    tab = .settings; closeDrawer()
                })
                .frame(width: w)
                .offset(x: (x - w) * 0.25)   // 側欄跟著慢一點滑進來，有層次

                tabs
                    .clipShape(RoundedRectangle(cornerRadius: x > 0 ? 44 : 0, style: .continuous))
                    .shadow(color: .black.opacity(x > 0 ? 0.14 : 0), radius: 24, x: -4)
                    // 開著時點右邊露出的畫面＝關起來；也可以往左拖
                    .overlay {
                        if drawer {
                            Color.black.opacity(0.001)
                                .onTapGesture(perform: closeDrawer)
                                .gesture(dragGesture(w))
                        }
                    }
                    // 首頁：從左緣往右拉打開側欄（避開上方導覽列的按鈕）
                    .overlay(alignment: .leading) {
                        if !drawer && tab == .home {
                            Color.clear.frame(width: 18).contentShape(Rectangle())
                                .padding(.top, 140)
                                .gesture(dragGesture(w))
                        }
                    }
                    .offset(x: x)
                    .ignoresSafeArea()
            }
        }
        .background(Color.zSide.ignoresSafeArea())
        .sheet(isPresented: $adding) {
            PersonForm(onCreated: { show($0.id) })
        }
        .onAppear {
            let env = ProcessInfo.processInfo.environment
            // 驗證用：ZIWEI_TAB=people 直接開到命盤分頁；ZIWEI_DRAWER=1 打開側欄
            if let t = env["ZIWEI_TAB"].flatMap(Tab.init) { tab = t }
            if env["ZIWEI_DRAWER"] != nil { drawer = true }
        }
    }

    private var tabs: some View {
        TabView(selection: $tab) {
            NavigationStack {
                HomeView(personID: homeID, openDrawer: openDrawer)
            }
            .tabItem { Image(systemName: "house").accessibilityLabel("首頁") }
            .tag(Tab.home)
            NavigationStack { PeopleList() }
                .tabItem { Image(systemName: "person.2").accessibilityLabel("命盤") }
                .tag(Tab.people)
            NavigationStack { SettingsView() }
                .tabItem { Image(systemName: "gearshape").accessibilityLabel("設定") }
                .tag(Tab.settings)
        }
        .tabViewStyle(.sidebarAdaptable)
    }

    /// 首頁換成某張盤（nil＝此刻），記進最近紀錄
    private func show(_ id: UUID?) {
        homeRaw = id?.uuidString ?? ""
        if let id {
            var list = recentRaw.split(separator: ",").map(String.init).filter { $0 != id.uuidString }
            list.insert(id.uuidString, at: 0)
            recentRaw = list.prefix(20).joined(separator: ",")
        }
        tab = .home
        closeDrawer()
    }

    private func openDrawer() {
        withAnimation(.spring(response: 0.35, dampingFraction: 0.86)) { drawer = true; drag = 0 }
    }
    private func closeDrawer() {
        withAnimation(.spring(response: 0.35, dampingFraction: 0.86)) { drawer = false; drag = 0 }
    }

    private func dragGesture(_ w: CGFloat) -> some Gesture {
        DragGesture(minimumDistance: 8)
            .onChanged { drag = $0.translation.width }
            .onEnded { v in
                let end = v.predictedEndTranslation.width
                let open = drawer ? end > -w / 3 : end > w / 3
                withAnimation(.spring(response: 0.35, dampingFraction: 0.86)) { drawer = open; drag = 0 }
            }
    }
}

/// 首頁：預設是此刻盤；從側欄點了某張命盤就換成那張
struct HomeView: View {
    let personID: UUID?
    var openDrawer: () -> Void
    @EnvironmentObject private var store: Store

    var body: some View {
        Group {
            if let id = personID, let p = store.people.first(where: { $0.id == id }) {
                ChartView(person: p).id(p.id)
            } else {
                NowChartView()
            }
        }
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button(action: openDrawer) { Image(systemName: "text.alignleft") }
                    .accessibilityLabel("側欄")
            }
        }
    }
}
