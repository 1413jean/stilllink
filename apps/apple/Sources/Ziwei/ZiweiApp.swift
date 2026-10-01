import SwiftUI
import AppKit

enum Route: Hashable { case home, person(UUID) }

@main
struct ZiweiApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var delegate
    @StateObject private var store = Store()

    var body: some Scene {
        WindowGroup("紫微") {
            RootView()
                .environmentObject(store)
                .preferredColorScheme(store.appearance.scheme)
                .frame(minWidth: 900, minHeight: 640)
        }
        .defaultSize(width: 1440, height: 920)
        .windowToolbarStyle(.unified(showsTitle: true))
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("新增命盤") { NotificationCenter.default.post(name: .newChart, object: nil) }
                    .keyboardShortcut("n")
            }
        }
    }
}

extension Notification.Name { static let newChart = Notification.Name("zw.newChart") }

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ n: Notification) {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
        Snapshot.scheduleIfRequested()
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
    @State private var creating = false

    var body: some View {
        NavigationSplitView {
            Sidebar(route: $route, onNew: { creating = true })
                .navigationSplitViewColumnWidth(min: 220, ideal: 260, max: 340)
        } detail: {
            switch route {
            case .person(let id):
                if let p = store.people.first(where: { $0.id == id }) {
                    ChartScreen(person: p).id(id)
                } else {
                    HomeView(route: $route, onNew: { creating = true })
                }
            default:
                HomeView(route: $route, onNew: { creating = true })
            }
        }
        .sheet(isPresented: $creating) {
            NewChartSheet { p in route = .person(p.id) }
        }
        .onReceive(NotificationCenter.default.publisher(for: .newChart)) { _ in creating = true }
        .onAppear(perform: applyDebugEnv)
    }

    /// 驗證用：ZIWEI_ROUTE=<姓名> 直接打開那張盤；ZIWEI_THEME=dark/light
    private func applyDebugEnv() {
        let env = ProcessInfo.processInfo.environment
        if let t = env["ZIWEI_THEME"], let a = Appearance(rawValue: t) { store.appearance = a }
        if let name = env["ZIWEI_ROUTE"], let p = store.people.first(where: { $0.name == name }) { route = .person(p.id) }
        if env["ZIWEI_NEW"] != nil { creating = true }
    }
}
