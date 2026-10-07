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
        // 外層量安全區域；內層整個用螢幕完整尺寸排（主畫面推開時圓角要貼齊螢幕上下緣，跟 Claude 一樣）
        GeometryReader { outer in
            let inset = outer.safeAreaInsets
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
                    // 側欄自己避開狀態列和 Home 橫條
                    .padding(.top, inset.top)
                    .padding(.bottom, inset.bottom)
                    .frame(width: w, height: geo.size.height)
                    // 主畫面蓋回來時側欄逐漸變暗（照 Claude），拖的時候跟著手指
                    .overlay(Color.black.opacity(0.28 * (1 - x / w)).allowsHitTesting(false))
                    .offset(x: (x - w) * 0.25)   // 側欄跟著慢一點滑進來，有層次

                    // 分頁列跟主畫面一起被推開，停在 Home 橫條上方
                    ZStack(alignment: .bottom) {
                        tabs
                        GlassTabBar(tab: $tab)
                            .padding(.bottom, max(12, inset.bottom - 12))
                    }
                    .frame(width: geo.size.width, height: geo.size.height)
                    .background(Color.zBg)
                    // 圓角跟著推開的距離長出來，不是一動就整個變圓
                    .clipShape(RoundedRectangle(cornerRadius: 52 * min(1, x / 60), style: .continuous))
                    .overlay {
                        // 推開時主畫面左緣一條細框，跟側欄分得開
                        RoundedRectangle(cornerRadius: 52 * min(1, x / 60), style: .continuous)
                            .stroke(Color.zLine, lineWidth: 0.5)
                            .opacity(min(1, x / 60))
                    }
                    .shadow(color: .black.opacity(0.1 * min(1, x / 60)), radius: 20, x: -2)
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
                            Color.clear.frame(width: 24).contentShape(Rectangle())
                                .padding(.top, inset.top + 80)
                                .gesture(dragGesture(w))
                        }
                    }
                    .offset(x: x)
                }
            }
            .ignoresSafeArea()
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
            // 驗證用：ZIWEI_DRAWER_CLOSE=秒 幾秒後自動關上（錄關閉動畫）
            if let t = env["ZIWEI_DRAWER_CLOSE"].flatMap(Double.init) {
                DispatchQueue.main.asyncAfter(deadline: .now() + t) { show(store.people.first?.id) }
            }
        }
    }

    private var tabs: some View {
        TabView(selection: $tab) {
            NavigationStack {
                HomeView(personID: homeID, openDrawer: openDrawer)
            }
            .tabContent()
            .tag(Tab.home)
            NavigationStack { PeopleList() }
                .tabContent()
                .tag(Tab.people)
            NavigationStack { SettingsView() }
                .tabContent()
                .tag(Tab.settings)
        }
        // 系統分頁列藏起來，換成自己的 GlassTabBar（圖示置中、Instagram 式），放在 body 裡
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

    /// 側欄開關：快進慢停、不回彈（照 Claude 約 0.3 秒）
    static let drawerAnim = Animation.snappy(duration: 0.3, extraBounce: 0)

    private func openDrawer() {
        withAnimation(RootView.drawerAnim) { drawer = true; drag = 0 }
    }
    private func closeDrawer() {
        withAnimation(RootView.drawerAnim) { drawer = false; drag = 0 }
    }

    private func dragGesture(_ w: CGFloat) -> some Gesture {
        DragGesture(minimumDistance: 8)
            .onChanged { drag = $0.translation.width }
            .onEnded { v in
                let end = v.predictedEndTranslation.width
                let open = drawer ? end > -w / 3 : end > w / 3
                withAnimation(RootView.drawerAnim) { drawer = open; drag = 0 }
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
                Button(action: openDrawer) { SidebarGlyph().foregroundStyle(Color.zText) }
                    .accessibilityLabel("側欄")
            }
        }
    }
}

private extension View {
    /// 每個分頁：藏掉系統分頁列，底部留出自己分頁列的高度，捲到底內容不會被蓋住
    func tabContent() -> some View {
        toolbar(.hidden, for: .tabBar)
            .safeAreaInset(edge: .bottom, spacing: 0) { Color.clear.frame(height: 76) }
    }
}
