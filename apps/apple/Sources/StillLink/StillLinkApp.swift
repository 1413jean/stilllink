import SwiftUI
import AppKit

enum Route: Hashable {
    case home, person(UUID), new, newSelf, edit(UUID), settings, pillars, starNotes(String?), temp(Person, Int)
    /// 新增、編輯、設定這類「頁面」（返回時不回到它們）
    var isPage: Bool { switch self { case .new, .newSelf, .edit, .settings, .pillars, .starNotes: true; default: false } }
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
            CommandGroup(replacing: .help) {
                Button("新功能…") { NotificationCenter.default.post(name: .openWhatsNew, object: nil) }
                Button("回報問題…") { BugReport.run(store: store) }
            }
        }
    }
}

extension Notification.Name {
    static let newChart = Notification.Name("zw.newChart")
    static let editChart = Notification.Name("zw.editChart")
    static let openSettings = Notification.Name("zw.openSettings")
    static let openWhatsNew = Notification.Name("zw.openWhatsNew")
    static let openPillars = Notification.Name("zw.openPillars")
    /// 右側面板拉得夠寬（true）或縮回來（false）：側欄跟著自動收起／打開
    static let infoPanelWide = Notification.Name("zw.infoPanelWide")
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
    @State private var settingsSection: SettingsPage.Section = .general
    @State private var showSettings = false        // 設定窗（浮在畫面上，不換頁）
    @State private var settingsToken = 0           // 每次打開都重建，才會停在指定的分類
    @State private var showWhatsNew = false        // 「新功能」視窗
    @State private var remindWhatsNew = Changelog.shouldRemind   // 右上角「新功能」提醒（看過就消失）
    @ObservedObject private var accountMenu = AccountMenuState.shared
    @State private var newGroup: String?
    @State private var columns: NavigationSplitViewVisibility = .all
    @State private var sidebarAutoHidden = false   // 右側面板拉寬時自動收起側欄（拉回來再打開）

    var body: some View {
        NavigationSplitView(columnVisibility: $columns) {
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
                case .starNotes(let k):
                    StarNotesPage(initial: k, onClose: { goBack() }).id(k ?? "")
                case .temp(let p, let lv):
                    ChartPager(primary: p, level: lv).id(p.id)
                default:
                    NowChart()
                }
            }
            // 視窗最小寬度：側欄收起後，命盤區最少保留這麼寬（再窄右側面板會暫時藏起來）
            .frame(minWidth: 640)
            // 換頁不做淡入淡出（兩張命盤同時繪製很重），新頁先出骨架再填資料
            .transaction(value: route) { $0.animation = nil }
            .overlay(alignment: .top) { TopFade(color: .zBg, height: 80) }
        }
        .toolbarBackground(.hidden, for: .windowToolbar)
        // 左下角帳號選單：從帳號列往上展開，點旁邊或按 Esc 關閉
        .overlay {
            if accountMenu.open {
                GeometryReader { g in
                    let f = g.frame(in: .global)
                    ZStack(alignment: .bottomLeading) {
                        Color.black.opacity(0.001).onTapGesture { accountMenu.close() }
                        AccountMenuPanel(close: { accountMenu.close() })
                            .padding(.leading, max(8, accountMenu.anchor.minX - f.minX + 6))
                            .padding(.bottom, max(8, f.maxY - accountMenu.anchor.minY + 4))
                            .transition(.opacity.combined(with: .scale(scale: 0.97, anchor: .bottomLeading)))
                    }
                }
                .ignoresSafeArea()
            }
        }
        // 設定窗：蓋在整個視窗上，點旁邊、按 ×、按 Esc 關閉；關掉馬上看到盤面的變化
        .overlay {
            if showSettings {
                ZStack {
                    Color.black.opacity(0.32).ignoresSafeArea()
                        .onTapGesture { closeSettings() }
                    GeometryReader { g in
                        SettingsPage(initial: settingsSection, onClose: closeSettings)
                            .id(settingsToken)
                            .frame(width: min(1000, g.size.width - 48), height: min(780, g.size.height - 48))
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                            .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.zRaisedLine, lineWidth: 0.5))
                            .raisedShadow()
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                }
                .transition(.opacity.combined(with: .scale(scale: 0.98)))
            }
        }
        // 「新功能」視窗：跟設定窗同一種浮窗
        .overlay {
            if showWhatsNew {
                ZStack {
                    Color.black.opacity(0.32).ignoresSafeArea()
                        .onTapGesture { closeWhatsNew() }
                    GeometryReader { g in
                        WhatsNewView(onClose: closeWhatsNew)
                            .frame(width: min(680, g.size.width - 48), height: min(780, g.size.height - 48))
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                            .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.zRaisedLine, lineWidth: 0.5))
                            .raisedShadow()
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                }
                .transition(.opacity.combined(with: .scale(scale: 0.98)))
            }
        }
        .overlay(alignment: .bottom) { ToastHost() }
        .environment(\.zSettings, store.settings)
        .toolbar {
            // 重大更新：右上角出現「新功能」，點開看過就消失
            ToolbarItem(placement: .primaryAction) {
                if remindWhatsNew {
                    Button { openWhatsNew() } label: {
                        Label("新功能", systemImage: "sparkles").labelStyle(.titleAndIcon)
                            .zText(.subheadlineStrong).foregroundStyle(Color.zAccent)
                            .padding(.horizontal, 12).frame(height: 26)
                            .background(Capsule().fill(Color.zAccent.opacity(0.12)))
                            .contentShape(Capsule())
                            .padding(.horizontal, 6)   // 跟工具列玻璃膠囊的邊緣留空，不要貼邊
                    }
                    .buttonStyle(.plain)
                    .help("看這次更新了什麼")
                }
            }
            ToolbarItemGroup(placement: .navigation) {
                Button { step(-1) } label: { Image(systemName: "arrow.left") }
                    .disabled(cursor == 0).help("上一頁 ⌘[").keyboardShortcut("[", modifiers: .command)
                Button { step(1) } label: { Image(systemName: "arrow.right") }
                    .disabled(cursor >= history.count - 1).help("下一頁 ⌘]").keyboardShortcut("]", modifiers: .command)
            }
        }
        .onChange(of: route) { _, r in
            guard let r else { return }
            if stepping { stepping = false; return }
            if history.indices.contains(cursor), history[cursor] == r { return }
            history = Array(history.prefix(cursor + 1)) + [r]
            cursor = history.count - 1
        }
        .onReceive(NotificationCenter.default.publisher(for: .newChart)) { n in
            closeSettings()
            newGroup = n.object as? String   // 從資料夾的 ＋ 進來時帶分組
            go(.new)
        }
        .onReceive(NotificationCenter.default.publisher(for: .editChart)) { n in
            closeSettings()
            if let id = n.object as? UUID { go(.edit(id)) }
        }
        .onReceive(NotificationCenter.default.publisher(for: .openSettings)) { n in
            settingsSection = (n.object as? SettingsPage.Section) ?? .general
            settingsToken += 1
            SettingsPage.isOpen = true
            withAnimation(Motion.fast) { showSettings = true }
        }
        .onReceive(NotificationCenter.default.publisher(for: .openWhatsNew)) { _ in openWhatsNew() }
        .onReceive(NotificationCenter.default.publisher(for: .newSelfChart)) { _ in closeSettings(); go(.newSelf) }
        .onReceive(NotificationCenter.default.publisher(for: .openSelf)) { _ in closeSettings(); if let me = store.me { route = .person(me.id) } }
        .onReceive(NotificationCenter.default.publisher(for: .openPillars)) { _ in go(.pillars) }
        .onReceive(NotificationCenter.default.publisher(for: .infoPanelWide)) { n in
            let wide = (n.object as? Bool) ?? false
            withAnimation(Motion.base) {
                if wide, columns != .detailOnly { columns = .detailOnly; sidebarAutoHidden = true }
                else if !wide, sidebarAutoHidden { columns = .all; sidebarAutoHidden = false }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .openStarNotes)) { n in if StarNotes.enabled { go(.starNotes(n.object as? String)) } }
        .onReceive(NotificationCenter.default.publisher(for: .openTemp)) { n in
            if let r = n.object as? TempRequest { route = .temp(r.person, r.level) }
        }
        .onAppear(perform: applyDebugEnv)
    }

    private func openWhatsNew() {
        closeSettings()
        Changelog.markSeen()
        withAnimation(Motion.fast) { remindWhatsNew = false; showWhatsNew = true }
    }

    private func closeWhatsNew() {
        withAnimation(Motion.fast) { showWhatsNew = false }
    }

    private func closeSettings() {
        guard showSettings else { return }
        SettingsPage.isOpen = false
        withAnimation(Motion.fast) { showSettings = false }
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
        if let p = env["ZIWEI_REPORT"] {   // 驗證用：把問題回報內容寫到檔案
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) { try? BugReport.report(store: store).write(toFile: p, atomically: true, encoding: .utf8) }
        }
        if env["ZIWEI_ACCOUNT_MENU"] != nil { DispatchQueue.main.asyncAfter(deadline: .now() + 2) { accountMenu.open = true } }   // 驗證用：打開帳號選單
        if env["ZIWEI_WHATSNEW"] != nil { DispatchQueue.main.asyncAfter(deadline: .now() + 1) { openWhatsNew() } }   // 驗證用：打開「新功能」
        if let t = env["ZIWEI_TOAST"] { DispatchQueue.main.asyncAfter(deadline: .now() + 3) { Toast.show(t) } }   // 驗證用：跳一個提示條
        if let k = env["ZIWEI_NOTES"] { go(.starNotes(k.isEmpty ? nil : k)) }
        if let v = env["ZIWEI_SETTINGS"] {   // ZIWEI_SETTINGS=display 可直接開到某一節
            if let s = SettingsPage.Section.find(v) {
                NotificationCenter.default.post(name: .openSettings, object: s)
            } else { NotificationCenter.default.post(name: .openSettings, object: nil) }
        }
        if let name = env["ZIWEI_EDIT"], let p = store.people.first(where: { $0.name == name }) { go(.edit(p.id)) }
        if let t = env["ZIWEI_NEW_AFTER"].flatMap(Double.init) {
            DispatchQueue.main.asyncAfter(deadline: .now() + t) { go(.new) }
        }
    }
}
