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
                .tint(Color.zText)   // 按鈕、選單一律用主文字色；分頁列、開關用 zAccent
                .preferredColorScheme(appearance.scheme)
        }
    }
}

/// 外層：左邊側欄（照 Claude App：整個畫面往右推開）＋命盤首頁
struct RootView: View {
    @EnvironmentObject private var store: Store
    @State private var showProfile = false   // 我的（個人檔案、設定）：從側欄左下角頭像打開
    /// 首頁顯示什麼：空字串＝我的命盤、"all"＝所有命盤、UUID＝那張盤
    @AppStorage("homeChart") private var homeRaw = ""
    @AppStorage("recentCharts") private var recentRaw = ""
    @State private var drawer = false
    @State private var homePath = NavigationPath()
    /// 拖曳中的位移：用 GestureState，手勢被取消（例如被點宮位搶走）時系統會自動歸零，畫面不會卡在推開一半
    // 放手時位移歸零也要跟開關同一個動畫：不然先「跳」回原位再滑，看起來卡一下
    @GestureState(resetTransaction: Transaction(animation: RootView.drawerAnim)) private var drag: CGFloat = 0
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
                    SidebarView(current: homeID, showingAll: homeRaw == "all", onPick: show, onAllCharts: {
                        homeRaw = "all"; homePath = NavigationPath(); closeDrawer()
                    }, onNew: {
                        closeDrawer(); adding = true
                    }, onProfile: {
                        closeDrawer(); showProfile = true
                    })
                    // 側欄自己避開狀態列和 Home 橫條
                    .padding(.top, inset.top)
                    .padding(.bottom, inset.bottom)
                    .frame(width: w, height: geo.size.height)
                    // 主畫面蓋回來時側欄逐漸變暗（照 Claude），拖的時候跟著手指
                    .overlay(Color.black.opacity(0.28 * (1 - x / w)).allowsHitTesting(false))
                    .offset(x: (x - w) * 0.25)   // 側欄跟著慢一點滑進來，有層次
                    .simultaneousGesture(drawer ? dragGesture(w) : nil)   // 在側欄上往左滑也能關（跟 Claude 一樣）

                    // 分頁列（系統原生）在主畫面裡，跟著一起被推開
                    tabs
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
                        if !drawer {
                            Color.clear.frame(width: 14).contentShape(Rectangle())   // 窄一點：不要蓋到盤面左邊那一欄
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
            if env["ZIWEI_TAB"] == "people" { homeRaw = "all" }
            if env["ZIWEI_TAB"] == "home" { homeRaw = "" }
            if env["ZIWEI_TAB"] == "settings" { showProfile = true }
            if env["ZIWEI_DRAWER"] != nil { drawer = true }
            // 驗證用：ZIWEI_DRAWER_CLOSE=秒 幾秒後自動關上（錄關閉動畫）
            if let t = env["ZIWEI_DRAWER_CLOSE"].flatMap(Double.init) {
                DispatchQueue.main.asyncAfter(deadline: .now() + t) { show(store.people.first?.id) }
            }
        }
    }

    /// 只有一個首頁（命盤），沒有分頁列；我的從側欄頭像進
    private var tabs: some View {
        NavigationStack(path: $homePath) {
            HomeView(mode: homeRaw, openDrawer: openDrawer)
        }
        .tint(Color.zText)
        .sheet(isPresented: $showProfile) {
            NavigationStack {
                SettingsView()
                    .toolbar { ToolbarItem(placement: .confirmationAction) { Button("完成") { showProfile = false } } }
            }
            .tint(Color.zText)
        }
    }

    /// 首頁換成某張盤（nil＝我的命盤），記進最近紀錄
    private func show(_ id: UUID?) {
        homeRaw = id?.uuidString ?? ""
        homePath = NavigationPath()
        if let id {
            var list = recentRaw.split(separator: ",").map(String.init).filter { $0 != id.uuidString }
            list.insert(id.uuidString, at: 0)
            recentRaw = list.prefix(20).joined(separator: ",")
        }
        closeDrawer()
    }

    /// 側欄開關：快進慢停、不回彈（照 Claude 約 0.3 秒）
    static let drawerAnim = Animation.snappy(duration: 0.3, extraBounce: 0)

    private func openDrawer() {
        withAnimation(RootView.drawerAnim) { drawer = true }
    }
    private func closeDrawer() {
        withAnimation(RootView.drawerAnim) { drawer = false }
    }

    /// 用整個螢幕當座標量位移：手勢掛在會跟著手指移動的主畫面上，用自己的座標量的話，
    /// 畫面一動位移就被抵銷，越拉越黏、放手時以為只拉了一點點，會彈回去
    private func dragGesture(_ w: CGFloat) -> some Gesture {
        DragGesture(minimumDistance: 10, coordinateSpace: .global)
            .updating($drag) { v, state, _ in
                // 上下為主的滑動不歸側欄管（清單照常捲、點宮位不會推動畫面）
                guard state != 0 || abs(v.translation.width) > abs(v.translation.height) * 1.5 else { return }
                state = v.translation.width
            }
            .onEnded { v in
                guard abs(v.translation.width) > abs(v.translation.height) * 1.5 else { return }
                // 放手時看實際拉的距離＋甩的速度：拉過三分之一，或往那個方向甩，就照那個方向
                let moved = v.translation.width
                let fling = v.predictedEndTranslation.width - moved
                let open = drawer ? !(moved < -w / 3 || fling < -120) : (moved > w / 3 || fling > 120)
                withAnimation(RootView.drawerAnim) { drawer = open }
            }
    }

}

/// 首頁：預設是自己的命盤（還沒填就請他填）；從側欄點「所有命盤」換成命盤列表，點某張命盤就換成那張
struct HomeView: View {
    let mode: String
    var openDrawer: () -> Void
    @EnvironmentObject private var store: Store

    var body: some View {
        Group {
            if mode == "all" {
                PeopleList()
            } else if let id = UUID(uuidString: mode), let p = store.people.first(where: { $0.id == id }) {
                ChartView(person: p).id(p.id)
            } else if let me = store.me {
                // 首頁預設就是自己的命盤
                ChartView(person: me).id(me.id)
            } else {
                SelfOnboarding()
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

/// 還沒填自己的命盤：首頁請他先填（填完首頁就是他的盤）
struct SelfOnboarding: View {
    @State private var filling = false

    var body: some View {
        VStack(spacing: 14) {
            Spacer()
            Image(systemName: "person.crop.circle.badge.plus")
                .font(.system(size: 52, weight: .light))
                .foregroundStyle(Color.zText3)
            Text("先填你的命盤").zText(.title2).foregroundStyle(Color.zText)
            Text("輸入你的出生日期、時間和地點，\n打開 App 就會看到自己的命盤").zText(.callout)
                .foregroundStyle(Color.zText2).multilineTextAlignment(.center)
            Button("填寫我的命盤") { filling = true }
                .buttonStyle(.capsule())
                .padding(.top, 8)
            Spacer()
            Spacer()
        }
        .padding(.horizontal, 32)
        .frame(maxWidth: .infinity)
        .background(Color.zBg)
        .sheet(isPresented: $filling) { PersonForm(asSelf: true) }
    }
}
