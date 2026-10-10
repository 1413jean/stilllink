import SwiftUI

/// 「我的」頁的登入卡片：只在沒登入時出現（Apple／Google 登入）。
/// 登入後的帳號、同步、登出、刪除帳號放在「我的」最下面的「帳號」區塊（AccountSection）
struct AccountCard: View {
    @ObservedObject private var account = Account.shared
    @State private var message: String?

    var body: some View {
        signedOut
            .padding(20)
            .background(RoundedRectangle(cornerRadius: 22, style: .continuous).fill(Color.zHover))
            .alert(message ?? "", isPresented: Binding(get: { message != nil }, set: { if !$0 { message = nil } })) {
                Button("好", role: .cancel) {}
            }
    }

    private var signedOut: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("保存你的命盤").zText(.title3).foregroundStyle(Color.zText).padding(.bottom, 10)
            Text("登入後命盤、備註、照片會存在你的帳號，Mac 和 iPhone 登入同一個帳號就看得到。不用填表單，也不用密碼。")
                .zText(.callout).foregroundStyle(Color.zText2).padding(.bottom, 14)
            Button { signIn(.apple) } label: { Label("使用 Apple 登入", systemImage: "apple.logo") }
                .buttonStyle(.capsule(fill: true))
                .padding(.bottom, 12)
            Button { signIn(.google) } label: {
                HStack(spacing: 10) {
                    Text("G").font(.system(size: 18, weight: .bold))
                    Text("使用 Google 登入")
                }
            }
            .buttonStyle(.capsule(.outline, fill: true))
        }
        .disabled(account.signingIn)
        .overlay { if account.signingIn { ProgressView() } }
    }

    private func signIn(_ p: Account.Provider) {
        guard CloudConfig.isConfigured else { message = "雲端同步還在準備中，資料目前存在這台裝置，不會遺失。"; return }
        Task {
            do {
                try await account.signIn(p)
                Platform.haptic(.success)
            } catch Account.Failure.cancelled {
            } catch {
                Platform.haptic(.error)
                message = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
            }
        }
    }

}

/// 登入後「我的」最下面的帳號區塊：帳號、同步狀態、立即同步、登出、刪除帳號
struct AccountSection: View {
    let session: Account.Session
    @ObservedObject private var account = Account.shared
    @ObservedObject private var sync = CloudSync.shared
    @State private var message: String?
    @State private var confirmSignOut = false
    @State private var confirmDelete = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("帳號").zText(.eyebrow).foregroundStyle(Color.zText3)
            VStack(spacing: 0) {
                line("帳號", value: session.email ?? providerName)
                // 登入後自動同步，平常不用顯示；只有失敗（沒網路等）才出現一列讓人重試
                if let e = sync.lastError {
                    divider
                    Button { Task { await sync.syncNow(); Platform.haptic(sync.lastError == nil ? .success : .error) } } label: {
                        line(sync.syncing ? "同步中…" : "同步失敗 · 點這裡重試", value: "", titleColor: Color.wmRed)
                    }
                    .buttonStyle(.plain).disabled(sync.syncing)
                    .accessibilityHint(e)
                }
                divider
                Button { confirmSignOut = true } label: { line("登出", value: providerName) }.buttonStyle(.plain)
                divider
                Button { confirmDelete = true } label: { line("刪除帳號", value: "", titleColor: Color.wmRed) }.buttonStyle(.plain)
            }
            .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(Color.zHover))
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
        .alert(message ?? "", isPresented: Binding(get: { message != nil }, set: { if !$0 { message = nil } })) {
            Button("好", role: .cancel) {}
        }
        .confirmationDialog("登出這台 iPhone？", isPresented: $confirmSignOut, titleVisibility: .visible) {
            Button("登出", role: .destructive) { account.signOut() }
        } message: {
            Text("這台 iPhone 上的命盤會保留，之後再登入會自動合併。")
        }
        .confirmationDialog("刪除帳號？", isPresented: $confirmDelete, titleVisibility: .visible) {
            Button("刪除帳號與雲端資料", role: .destructive) { deleteAccount() }
        } message: {
            Text("雲端上的命盤、照片會一起刪除，無法復原。這台 iPhone 上的資料會保留。")
        }
    }

    // 跟「我的」其他區塊同一種分隔線
    private var divider: some View { Rectangle().fill(Color.zLine).frame(height: 0.5).padding(.leading, 16) }

    private var providerName: String {
        session.provider == "apple" ? "Apple" : session.provider == "google" ? "Google" : (session.provider ?? "")
    }

    private func line(_ title: String, value: String, titleColor: Color = Color.zText, valueColor: Color = Color.zText3) -> some View {
        HStack(spacing: 8) {
            Text(title).zText(.body).foregroundStyle(titleColor)
            Spacer(minLength: 12)
            Text(value).zText(.body).foregroundStyle(valueColor).lineLimit(1)
        }
        .padding(.horizontal, 16)
        .frame(minHeight: 52)
        .contentShape(Rectangle())
    }

    private func deleteAccount() {
        Task {
            do { try await account.deleteAccount(); Platform.haptic(.success) }
            catch { Platform.haptic(.error); message = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription }
        }
    }
}
