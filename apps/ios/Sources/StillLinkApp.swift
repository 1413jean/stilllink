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

/// 三個分頁：此刻、命盤、設定（iPad 上 TabView 會自動變成側欄）
struct RootView: View {
    enum Tab: String { case now, people, settings }
    @AppStorage("tab") private var tab: Tab = .now

    var body: some View {
        TabView(selection: $tab) {
            NavigationStack { NowChartView() }
                .tabItem { Label("此刻", systemImage: "clock") }
                .tag(Tab.now)
            NavigationStack { PeopleList() }
                .tabItem { Label("命盤", systemImage: "person.2") }
                .tag(Tab.people)
            NavigationStack { SettingsView() }
                .tabItem { Label("設定", systemImage: "gearshape") }
                .tag(Tab.settings)
        }
        .tabViewStyle(.sidebarAdaptable)
        .onAppear {
            // 驗證用：ZIWEI_TAB=people 直接開到命盤分頁
            if let t = ProcessInfo.processInfo.environment["ZIWEI_TAB"].flatMap(Tab.init) { tab = t }
        }
    }
}
