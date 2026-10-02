import AppKit
import Sparkle

/// App 內更新：Sparkle 負責檢查、下載、驗證簽名、安裝；介面不用它的彈窗，
/// 有新版時只在工具列出現「更新」按鈕，按下去就下載、安裝並重新打開。
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
        case failed(String)
    }

    @Published private(set) var state: State = .idle
    private var updater: SPUUpdater?
    private var choice: ((SPUUserUpdateChoice) -> Void)?
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
        state = .available(appcastItem.displayVersionString)
        if ProcessInfo.processInfo.environment["ZIWEI_AUTO_UPDATE"] == "install" { install() }
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

    // 下載、驗證完：直接安裝並重新打開
    func showReady(toInstallAndRelaunch reply: @escaping (SPUUserUpdateChoice) -> Void) {
        state = .installing
        reply(.install)
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
        case .available, .upToDate, .failed: break
        default: state = .idle
        }
    }
}

import SwiftUI

/// 工具列上的「更新」：有新版才出現；下載中顯示進度
struct UpdateToolbarButton: View {
    @ObservedObject private var updater = AppUpdater.shared
    var body: some View {
        switch updater.state {
        case .available(let v):
            Button { updater.install() } label: {
                Label("更新", systemImage: "arrow.down.circle.fill")
                    .labelStyle(.titleAndIcon)
                    .font(Font.zCaptionStrong).foregroundStyle(Color.zOnColor)
                    .padding(.horizontal, 10).frame(height: 24)
                    .background(Capsule().fill(Color.zAccent))
            }
            .buttonStyle(.plain)
            .help("更新到 \(v)，完成後會自動重新打開")
        case .downloading(let p):
            HStack(spacing: 6) {
                ProgressView(value: p ?? 0).progressViewStyle(.circular).controlSize(.small)
                Text(p.map { "更新中 \(Int($0 * 100))%" } ?? "更新中…").font(Font.zCaptionStrong).foregroundStyle(Color.zText2)
            }
        case .installing:
            HStack(spacing: 6) {
                ProgressView().controlSize(.small)
                Text("安裝中…").font(Font.zCaptionStrong).foregroundStyle(Color.zText2)
            }
        default:
            EmptyView()
        }
    }
}
