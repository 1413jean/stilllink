import SwiftUI
import AppKit

enum Route: Hashable {
    case home, person(UUID), new, newSelf, edit(UUID), settings, pillars, temp(Person, Int)
    /// 新增、編輯、設定這類「頁面」（返回時不回到它們）
    var isPage: Bool { switch self { case .new, .newSelf, .edit, .settings, .pillars: true; default: false } }
}

@main
struct StillLinkApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var delegate
    @StateObject private var store = Store()

    var body: some Scene {
        WindowGroup(AppInfo.name) {
            RootView()
                .environmentObject(store)
                .preferredColorScheme(store.appearance.scheme)
                .tint(Color.zAccent)
                .frame(minWidth: 900, minHeight: 640)
        }
        .defaultSize(width: 1440, height: 920)
        .windowToolbarStyle(.unified(showsTitle: true))
        .commands {
            CommandGroup(replacing: .appSettings) {
                Button("設定…") { NotificationCenter.default.post(name: .openSettings, object: nil) }
                    .keyboardShortcut(",")
            }
            CommandGroup(replacing: .newItem) {
                Button("新增命盤") { NotificationCenter.default.post(name: .newChart, object: nil) }
                    .keyboardShortcut("n")
            }
        }
    }
}

extension Notification.Name {
    static let newChart = Notification.Name("zw.newChart")
    static let editChart = Notification.Name("zw.editChart")
    static let openSettings = Notification.Name("zw.openSettings")
    static let openPillars = Notification.Name("zw.openPillars")
    static let openTemp = Notification.Name("zw.openTemp")
    static let newSelfChart = Notification.Name("zw.newSelfChart")
    static let openSelf = Notification.Name("zw.openSelf")
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ n: Notification) {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
        // 出生地資料（解析 zone.tab＋中文排序）先在背景建好，否則第一次開「新增命盤」會卡約 0.2 秒
        DispatchQueue.global(qos: .utility).async { _ = Places.all }
        Snapshot.scheduleIfRequested()
        Bench.runIfRequested()
        AppUpdater.shared.start()
        // 開啟時不要把鍵盤焦點放在第一顆按鈕（側欄開關）上，不然會一直有藍色光圈
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            for w in NSApp.windows where w.isVisible { w.makeFirstResponder(nil) }
        }
    }
    func applicationShouldTerminateAfterLastWindowClosed(_ s: NSApplication) -> Bool { true }
}

/// 驗證用：ZIWEI_SNAPSHOT=/path.png 時，等畫面穩定後把視窗存成 PNG 並結束
enum Snapshot {
    static func scheduleIfRequested() {
        guard let path = ProcessInfo.processInfo.environment["ZIWEI_SNAPSHOT"] else { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
            guard let win = NSApp.windows.first(where: { $0.isVisible }), let view = win.contentView?.superview else { return }
            let rect = view.bounds
            guard let rep = view.bitmapImageRepForCachingDisplay(in: rect) else { return }
            view.cacheDisplay(in: rect, to: rep)
            try? rep.representation(using: .png, properties: [:])?.write(to: URL(fileURLWithPath: path))
            if ProcessInfo.processInfo.environment["ZIWEI_KEEP_OPEN"] == nil { NSApp.terminate(nil) }
        }
    }
}

struct RootView: View {
    @EnvironmentObject var store: Store
    @State private var route: Route? = .home
    @State private var back: Route = .home   // 取消新增／編輯時回到這頁
    // 瀏覽紀錄（像瀏覽器的上一頁／下一頁）
    @State private var history: [Route] = [.home]
    @State private var cursor = 0
    @State private var stepping = false
    @State private var settingsSection: SettingsPage.Section = .profile
    @State private var newGroup: String?

    var body: some View {
        NavigationSplitView {
            Sidebar(route: $route, onNew: { newGroup = nil; go(.new) })
                .navigationSplitViewColumnWidth(min: 220, ideal: 260, max: 340)
        } detail: {
            Group {
                switch route {
                case .person(let id):
                    if let p = store.people.first(where: { $0.id == id }) {
                        ChartPager(primary: p).id(id)
                    } else {
                        NowChart()
                    }
                case .new:
                    NewChartSheet(defaultGroup: newGroup, onClose: { goBack() }) { p in route = .person(p.id) }
                        .id(newGroup ?? "")
                case .edit(let id):
                    NewChartSheet(editing: store.people.first { $0.id == id }, onClose: { goBack() }) { p in route = .person(p.id) }
                        .id(id)
                case .newSelf:
                    NewChartSheet(asSelf: true, onClose: { goBack() }) { p in route = .person(p.id) }
                case .settings:
                    SettingsPage(initial: settingsSection, onClose: { goBack() })
                        .id(settingsSection)
                case .pillars:
                    PillarSearchPage(onClose: { goBack() })
                case .temp(let p, let lv):
                    ChartPager(primary: p, level: lv).id(p.id)
                default:
                    NowChart()
                }
            }
            // 換頁不做淡入淡出（兩張命盤同時繪製很重），新頁先出骨架再填資料
            .animation(nil, value: route)
            .overlay(alignment: .top) { TopFade(color: .zBg) }
        }
        .toolbarBackground(.hidden, for: .windowToolbar)
        .overlay(alignment: .bottom) { ToastHost() }
        .environment(\.zSettings, store.settings)
        .toolbar {
            ToolbarItemGroup(placement: .navigation) {
                Button { step(-1) } label: { Image(systemName: "arrow.left") }
                    .disabled(cursor == 0).help("上一頁 ⌘[").keyboardShortcut("[", modifiers: .command)
                Button { step(1) } label: { Image(systemName: "arrow.right") }
                    .disabled(cursor >= history.count - 1).help("下一頁 ⌘]").keyboardShortcut("]", modifiers: .command)
            }
        }
        .onChange(of: route) { r in
            guard let r else { return }
            if stepping { stepping = false; return }
            if history.indices.contains(cursor), history[cursor] == r { return }
            history = Array(history.prefix(cursor + 1)) + [r]
            cursor = history.count - 1
        }
        .onReceive(NotificationCenter.default.publisher(for: .newChart)) { n in
            newGroup = n.object as? String   // 從資料夾的 ＋ 進來時帶分組
            go(.new)
        }
        .onReceive(NotificationCenter.default.publisher(for: .editChart)) { n in
            if let id = n.object as? UUID { go(.edit(id)) }
        }
        .onReceive(NotificationCenter.default.publisher(for: .openSettings)) { n in
            settingsSection = (n.object as? SettingsPage.Section) ?? .profile
            go(.settings)
        }
        .onReceive(NotificationCenter.default.publisher(for: .newSelfChart)) { _ in go(.newSelf) }
        .onReceive(NotificationCenter.default.publisher(for: .openSelf)) { _ in if let me = store.me { route = .person(me.id) } }
        .onReceive(NotificationCenter.default.publisher(for: .openPillars)) { _ in go(.pillars) }
        .onReceive(NotificationCenter.default.publisher(for: .openTemp)) { n in
            if let r = n.object as? TempRequest { route = .temp(r.person, r.level) }
        }
        .onAppear(perform: applyDebugEnv)
    }

    private func go(_ r: Route) {
        if let cur = route, !cur.isPage { back = cur }
        route = r
    }
    private func goBack() { route = back }

    private func step(_ d: Int) {
        let i = cursor + d
        guard history.indices.contains(i) else { return }
        cursor = i
        stepping = true
        route = history[i]
    }

    /// 驗證用：ZIWEI_ROUTE=<姓名> 直接打開那張盤；ZIWEI_THEME=dark/light
    private func applyDebugEnv() {
        let env = ProcessInfo.processInfo.environment
        if let t = env["ZIWEI_THEME"], let a = Appearance(rawValue: t) { store.appearance = a }
        if let name = env["ZIWEI_ROUTE"], let p = store.people.first(where: { $0.name == name }) { route = .person(p.id) }
        if env["ZIWEI_NEW"] != nil { go(.new) }
        if env["ZIWEI_NEWSELF"] != nil { go(.newSelf) }
        if let v = env["ZIWEI_SETTINGS"] {   // ZIWEI_SETTINGS=display 可直接開到某一節
            if let s = SettingsPage.Section.allCases.first(where: { "\($0)" == v }) {
                NotificationCenter.default.post(name: .openSettings, object: s)
            } else { go(.settings) }
        }
        if let name = env["ZIWEI_EDIT"], let p = store.people.first(where: { $0.name == name }) { go(.edit(p.id)) }
        if let t = env["ZIWEI_NEW_AFTER"].flatMap(Double.init) {
            DispatchQueue.main.asyncAfter(deadline: .now() + t) { go(.new) }
        }
    }
}
