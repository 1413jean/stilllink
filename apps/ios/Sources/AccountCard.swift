import SwiftUI

/// 「我的」頁的帳號卡片：沒登入是 Apple／Google 登入，登入後是帳號、同步狀態、立即同步、登出、刪除帳號
struct AccountCard: View {
    @ObservedObject private var account = Account.shared
    @ObservedObject private var sync = CloudSync.shared
    @State private var message: String?
    @State private var confirmSignOut = false
    @State private var confirmDelete = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if let s = account.session { signedIn(s) } else { signedOut }
        }
        .padding(20)
        .background(RoundedRectangle(cornerRadius: 22, style: .continuous).fill(Color.zHover))
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

    private func signedIn(_ s: Account.Session) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 8) {
                Image(systemName: "checkmark.icloud").foregroundStyle(Color.zAccent)
                Text("已登入").zText(.title3).foregroundStyle(Color.zText)
            }
            .padding(.bottom, 6)
            Text([s.email, s.provider.map { $0 == "apple" ? "Apple" : $0 == "google" ? "Google" : $0 }].compactMap { $0 }.joined(separator: " · "))
                .zText(.callout).foregroundStyle(Color.zText2)
            Text(status).zText(.footnote).foregroundStyle(sync.lastError == nil ? Color.zText3 : Color.wmRed)
                .padding(.top, 4).padding(.bottom, 14)
            Button { Task { await sync.syncNow(); Platform.haptic(sync.lastError == nil ? .success : .error) } } label: {
                Label(sync.syncing ? "同步中…" : "立即同步", systemImage: "arrow.triangle.2.circlepath")
            }
            .buttonStyle(.capsule(.outline, fill: true))
            .disabled(sync.syncing)
            .padding(.bottom, 12)
            HStack {
                Button("登出") { confirmSignOut = true }
                Spacer()
                Button("刪除帳號", role: .destructive) { confirmDelete = true }
            }
            .zText(.subheadline)
            .padding(.horizontal, 4)
            .frame(minHeight: 44)
        }
    }

    private var status: String {
        if sync.syncing { return "同步中…" }
        if let e = sync.lastError { return e }
        guard let t = sync.lastSync else { return "還沒同步" }
        return "上次同步：" + t.formatted(.relative(presentation: .named))
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

    private func deleteAccount() {
        Task {
            do { try await account.deleteAccount(); Platform.haptic(.success) }
            catch { Platform.haptic(.error); message = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription }
        }
    }
}
