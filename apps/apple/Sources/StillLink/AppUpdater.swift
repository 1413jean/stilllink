import AppKit
import Sparkle

/// App 內更新：Sparkle 負責檢查、下載、驗證簽名、安裝；介面不用它的彈窗，
/// 有新版時只在工具列出現「更新」按鈕，按下去就下載；下載好跳系統彈窗問要不要現在重新開啟。
@MainActor
final class AppUpdater: NSObject, ObservableObject {
    static let shared = AppUpdater()

    enum State: Equatable {
        case idle
        case checking                 // 使用者按了「檢查更新」
        case upToDate                 // 已經是最新版本
        case available(String)        // 有新版（顯示用版本號）
        case downloading(Double?)     // 下載中（0～1，未知時 nil）
        case installing
        case readyToRelaunch          // 下載好了，使用者選了「稍後」：工具列留一顆「重新開啟」
        case failed(String)
    }

    @Published private(set) var state: State = .idle {
        didSet {   // 驗證用：ZIWEI_UPDATE_LOG=/path 記錄每次狀態變化
            if let p = ProcessInfo.processInfo.environment["ZIWEI_UPDATE_LOG"],
               let h = FileHandle(forWritingAtPath: p) ?? { FileManager.default.createFile(atPath: p, contents: nil); return FileHandle(forWritingAtPath: p) }() {
                h.seekToEndOfFile(); h.write("\(Date().timeIntervalSince1970) \(state)\n".data(using: .utf8)!); h.closeFile()
            }
        }
    }
    private var updater: SPUUpdater?
    private var choice: ((SPUUserUpdateChoice) -> Void)?
    private var relaunchReply: ((SPUUserUpdateChoice) -> Void)?
    private var pendingVersion = ""
    private var expected: UInt64 = 0
    private var received: UInt64 = 0

    /// 開 App 時啟動：之後 Sparkle 會自己定期在背景檢查
    func start() {
        guard updater == nil, Bundle.main.object(forInfoDictionaryKey: "SUFeedURL") != nil else { return }
        let u = SPUUpdater(hostBundle: .main, applicationBundle: .main, userDriver: self, delegate: nil)
        do { try u.start(); updater = u } catch { state = .failed("更新功能無法啟動") }
        // 驗證用：ZIWEI_AUTO_UPDATE=check → 馬上檢查；=install → 找到新版就自動按「更新」
        if ProcessInfo.processInfo.environment["ZIWEI_AUTO_UPDATE"] != nil { u.checkForUpdatesInBackground() }
    }

    /// 「關於」頁的檢查更新
    func checkNow() {
        guard let updater, updater.canCheckForUpdates else { return }
        updater.checkForUpdates()
    }

    /// 工具列「更新」按鈕：開始下載並安裝
    func install() {
        guard let reply = choice else { return }
        choice = nil
        state = .downloading(nil)
        reply(.install)
    }

    /// 工具列「重新開啟」：安裝下載好的更新並重開
    func relaunchNow() {
        guard let reply = relaunchReply else { return }
        relaunchReply = nil
        state = .installing
        reply(.install)
    }

    var isAvailable: Bool { if case .available = state { return true } else { return false } }
    var isBusy: Bool {
        switch state { case .downloading, .installing: return true; default: return false }
    }
}

extension AppUpdater: SPUUserDriver {
    // 第一次啟動不問「要不要自動檢查」，直接開（不傳送系統資訊）
    func show(_ request: SPUUpdatePermissionRequest, reply: @escaping (SUUpdatePermissionResponse) -> Void) {
        reply(SUUpdatePermissionResponse(automaticUpdateChecks: true, sendSystemProfile: false))
    }

    func showUserInitiatedUpdateCheck(cancellation: @escaping () -> Void) { state = .checking }

    func showUpdateFound(with appcastItem: SUAppcastItem, state s: SPUUserUpdateState, reply: @escaping (SPUUserUpdateChoice) -> Void) {
        // 已經下載好（之前按過更新但沒裝完）就直接裝；否則等使用者按工具列的「更新」
        if s.stage == .downloaded || s.stage == .installing {
            state = .installing
            reply(.install)
            return
        }
        choice = reply
        pendingVersion = appcastItem.displayVersionString
        state = .available(appcastItem.displayVersionString)
        // install＝自動按更新並自動重開；download＝自動按更新，但下載好照常跳彈窗問要不要重開
        if ["install", "download"].contains(ProcessInfo.processInfo.environment["ZIWEI_AUTO_UPDATE"] ?? "") { install() }
    }

    func showUpdateReleaseNotes(with downloadData: SPUDownloadData) {}
    func showUpdateReleaseNotesFailedToDownloadWithError(_ error: Error) {}

    func showUpdateNotFoundWithError(_ error: Error, acknowledgement: @escaping () -> Void) {
        state = .upToDate
        acknowledgement()
    }

    func showUpdaterError(_ error: Error, acknowledgement: @escaping () -> Void) {
        state = .failed((error as NSError).localizedDescription)
        acknowledgement()
    }

    func showDownloadInitiated(cancellation: @escaping () -> Void) { expected = 0; received = 0; state = .downloading(nil) }
    func showDownloadDidReceiveExpectedContentLength(_ expectedContentLength: UInt64) { expected = expectedContentLength }
    func showDownloadDidReceiveData(ofLength length: UInt64) {
        received += length
        state = .downloading(expected > 0 ? min(1, Double(received) / Double(expected)) : nil)
    }
    func showDownloadDidStartExtractingUpdate() { state = .installing }
    func showExtractionReceivedProgress(_ progress: Double) { state = .installing }

    // 下載、驗證完：跳系統彈窗問要不要現在重新開啟；選「稍後」就留在工具列，關 App 時 Sparkle 也會自動裝好
    func showReady(toInstallAndRelaunch reply: @escaping (SPUUserUpdateChoice) -> Void) {
        relaunchReply = reply
        state = .readyToRelaunch
        if ProcessInfo.processInfo.environment["ZIWEI_AUTO_UPDATE"] == "install" { relaunchNow(); return }
        let alert = NSAlert()
        alert.messageText = pendingVersion.isEmpty ? "StillLink 更新好了" : "StillLink \(pendingVersion) 更新好了"
        alert.informativeText = "要現在重新開啟嗎？重新開啟後就會換成新版本。\n選「稍後」的話，下次關閉 StillLink 時會自動完成更新。"
        alert.addButton(withTitle: "立即重新開啟")
        alert.addButton(withTitle: "稍後")
        NSApp.activate(ignoringOtherApps: true)
        if alert.runModal() == .alertFirstButtonReturn { relaunchNow() }
    }

    func showInstallingUpdate(withApplicationTerminated applicationTerminated: Bool, retryTerminatingApplication: @escaping () -> Void) {
        state = .installing
    }

    func showUpdateInstalledAndRelaunched(_ relaunched: Bool, acknowledgement: @escaping () -> Void) {
        state = .idle
        acknowledgement()
    }

    func showUpdateInFocus() {}

    func dismissUpdateInstallation() {
        // 使用者還沒按「更新」時保留按鈕；其他情況（裝完、取消、檢查結束）回到原狀
        switch state {
        case .available, .upToDate, .failed, .readyToRelaunch: break
        default: state = .idle
        }
    }
}

import SwiftUI

/// 左上角紅黃綠旁邊的「更新」：有新版才出現；下載中、安裝中顯示進度
struct UpdateToolbarButton: View {
    @ObservedObject private var updater = AppUpdater.shared
    var body: some View {
        switch updater.state {
        case .available(let v):
            // 系統原生的強調按鈕，染成主色（整顆工具列按鈕就是橘色）
            Button { updater.install() } label: {
                HStack(spacing: 3) {   // icon 和文字靠近一點
                    Image(systemName: "arrow.down.circle.fill")
                    Text("更新")
                }
                .font(Font.zCaptionStrong)
            }
            .buttonStyle(.borderedProminent)
            .tint(Color.zAccent)
            .help("更新到 \(v)，完成後會自動重新打開")
        case .downloading(let p):
            chip { Text(p.map { "更新中 \(Int($0 * 100))%" } ?? "更新中…").monospacedDigit() }
        case .installing:
            chip { Text("安裝中…") }
        case .readyToRelaunch:
            Button { updater.relaunchNow() } label: {
                HStack(spacing: 3) {
                    Image(systemName: "arrow.clockwise.circle.fill")
                    Text("重新開啟")
                }
                .font(Font.zCaptionStrong)
            }
            .buttonStyle(.borderedProminent)
            .tint(Color.zAccent)
            .help("更新已下載好，重新開啟就會換成新版本")
        default:
            EmptyView()
        }
    }

    /// 進行中的狀態：淡灰小膠囊＋轉圈
    private func chip<C: View>(@ViewBuilder _ text: () -> C) -> some View {
        HStack(spacing: 4) {
            ProgressView().controlSize(.mini)
            text()
        }
        .font(Font.zCaptionStrong).foregroundStyle(Color.zText2)
        .padding(.horizontal, 8).frame(height: 22)
        .background(Capsule().fill(Color.zHover))
        .padding(.horizontal, 4)
    }
}
