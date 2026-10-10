import AuthenticationServices
import CryptoKit
import Foundation
import Security
#if os(macOS)
import AppKit
#else
import UIKit
#endif

/// 登入狀態（Supabase Auth）。Apple、Google 都走同一條路：
/// 系統的安全瀏覽器（ASWebAuthenticationSession）打開 Supabase 的登入頁 → 使用者選帳號 →
/// 導回 stilllink://auth-callback?code=… → 用 PKCE 換成 access／refresh token，存進鑰匙圈。
/// 不用裝 Google／Supabase 的 SDK，Mac 和 iPhone 同一份程式。
@MainActor
final class Account: NSObject, ObservableObject {
    static let shared = Account()

    struct Session: Codable, Equatable {
        var accessToken: String
        var refreshToken: String
        var expiresAt: Date
        var userID: String
        var email: String?
        var provider: String?
    }

    enum Provider: String { case apple, google
        var label: String { self == .apple ? "Apple" : "Google" }
    }

    enum Failure: LocalizedError {
        case notConfigured, cancelled, badResponse(String)
        var errorDescription: String? {
            switch self {
            case .notConfigured: "雲端同步還沒設定好"
            case .cancelled: "已取消登入"
            case .badResponse(let s): s
            }
        }
    }

    @Published private(set) var session: Session?
    @Published private(set) var signingIn = false
    var isSignedIn: Bool { session != nil }

    private override init() {
        super.init()
        session = Keychain.load()
    }

    // MARK: 登入

    func signIn(_ provider: Provider) async throws {
        guard CloudConfig.isConfigured else { throw Failure.notConfigured }
        signingIn = true
        defer { signingIn = false }
        let verifier = Self.randomString(64)
        let challenge = Data(SHA256.hash(data: Data(verifier.utf8))).base64URL
        var c = URLComponents(url: CloudConfig.base.appendingPathComponent("auth/v1/authorize"), resolvingAgainstBaseURL: false)!
        c.queryItems = [
            .init(name: "provider", value: provider.rawValue),
            .init(name: "redirect_to", value: CloudConfig.redirect),
            .init(name: "code_challenge", value: challenge),
            .init(name: "code_challenge_method", value: "s256"),
        ]
        let callback = try await webAuth(c.url!)
        guard let code = URLComponents(url: callback, resolvingAgainstBaseURL: false)?.queryItems?.first(where: { $0.name == "code" })?.value else {
            let msg = URLComponents(url: callback, resolvingAgainstBaseURL: false)?.queryItems?.first { $0.name == "error_description" }?.value
            throw Failure.badResponse(msg ?? "登入沒有完成")
        }
        let s = try await token(grant: "pkce", body: ["auth_code": code, "code_verifier": verifier])
        set(s)
    }

    func signOut() {
        // 只登出這台裝置：本機資料保留，之後再登入會合併回去
        if let s = session {
            var r = Self.request("auth/v1/logout", method: "POST")
            r.setValue("Bearer \(s.accessToken)", forHTTPHeaderField: "Authorization")
            Task.detached { _ = try? await URLSession.shared.data(for: r) }
        }
        set(nil)
    }

    /// 刪除帳號（含雲端上的命盤、照片）；本機資料保留
    func deleteAccount() async throws {
        let token = try await validAccessToken()
        var r = Self.request("rest/v1/rpc/delete_my_account", method: "POST")
        r.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        r.httpBody = Data("{}".utf8)
        let (data, resp) = try await URLSession.shared.data(for: r)
        guard (resp as? HTTPURLResponse).map({ (200..<300).contains($0.statusCode) }) == true else {
            throw Failure.badResponse(String(data: data, encoding: .utf8) ?? "刪除失敗")
        }
        set(nil)
    }

    /// 拿可以用的 access token：快過期就先換新的
    func validAccessToken() async throws -> String {
        guard let s = session else { throw Failure.badResponse("尚未登入") }
        if s.expiresAt.timeIntervalSinceNow > 60 { return s.accessToken }
        do {
            let n = try await token(grant: "refresh_token", body: ["refresh_token": s.refreshToken])
            set(n)
            return n.accessToken
        } catch {
            // refresh token 也失效（例如在別台刪了帳號）：當成登出
            if case Failure.badResponse = error { set(nil) }
            throw error
        }
    }

    private func set(_ s: Session?) {
        let wasSignedIn = session != nil
        session = s
        if let s { Keychain.save(s) } else { Keychain.clear() }
        if s == nil { CloudSync.shared.reset() }
        else if !wasSignedIn { CloudSync.shared.syncSoon(delay: 0) }   // 剛登入：馬上合併一次
    }

    // MARK: Supabase Auth API

    static func request(_ path: String, method: String = "GET") -> URLRequest {
        var r = URLRequest(url: CloudConfig.base.appendingPathComponent(path))
        r.httpMethod = method
        r.setValue(CloudConfig.anonKey, forHTTPHeaderField: "apikey")
        r.setValue("application/json", forHTTPHeaderField: "Content-Type")
        return r
    }

    private func token(grant: String, body: [String: String]) async throws -> Session {
        var c = URLComponents(url: CloudConfig.base.appendingPathComponent("auth/v1/token"), resolvingAgainstBaseURL: false)!
        c.queryItems = [.init(name: "grant_type", value: grant)]
        var r = Self.request("auth/v1/token", method: "POST")
        r.url = c.url
        r.httpBody = try JSONSerialization.data(withJSONObject: body)
        let (data, resp) = try await URLSession.shared.data(for: r)
        guard let http = resp as? HTTPURLResponse, (200..<300).contains(http.statusCode),
              let j = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let access = j["access_token"] as? String, let refresh = j["refresh_token"] as? String,
              let user = j["user"] as? [String: Any], let uid = user["id"] as? String else {
            let msg = (try? JSONSerialization.jsonObject(with: data) as? [String: Any])
                .flatMap { $0["error_description"] as? String ?? $0["msg"] as? String }
            throw Failure.badResponse(msg ?? "登入失敗")
        }
        let expires = (j["expires_in"] as? Double) ?? 3600
        let provider = (user["app_metadata"] as? [String: Any])?["provider"] as? String
        return Session(accessToken: access, refreshToken: refresh, expiresAt: Date().addingTimeInterval(expires),
                       userID: uid, email: user["email"] as? String, provider: provider)
    }

    // MARK: 系統安全瀏覽器

    private var webSession: ASWebAuthenticationSession?

    private func webAuth(_ url: URL) async throws -> URL {
        try await withCheckedThrowingContinuation { cont in
            let s = ASWebAuthenticationSession(url: url, callbackURLScheme: CloudConfig.callbackScheme) { url, error in
                if let url { cont.resume(returning: url) }
                else if let e = error as? ASWebAuthenticationSessionError, e.code == .canceledLogin { cont.resume(throwing: Failure.cancelled) }
                else { cont.resume(throwing: error ?? Failure.cancelled) }
            }
            s.presentationContextProvider = self
            s.prefersEphemeralWebBrowserSession = false   // 記得瀏覽器裡已登入的 Google／Apple 帳號，不用每次重打
            webSession = s
            s.start()
        }
    }

    private static func randomString(_ n: Int) -> String {
        let chars = Array("ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-._~")
        return String((0..<n).map { _ in chars[Int.random(in: 0..<chars.count)] })
    }
}

extension Account: ASWebAuthenticationPresentationContextProviding {
    nonisolated func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        MainActor.assumeIsolated {
            #if os(macOS)
            NSApp.keyWindow ?? NSApp.windows.first ?? ASPresentationAnchor()
            #else
            UIApplication.shared.connectedScenes.compactMap { ($0 as? UIWindowScene)?.keyWindow }.first ?? ASPresentationAnchor()
            #endif
        }
    }
}

private extension Data {
    var base64URL: String {
        base64EncodedString().replacingOccurrences(of: "+", with: "-").replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }
}

/// 登入憑證存在鑰匙圈（不放 UserDefaults：那是明文檔案）
private enum Keychain {
    static let service = "app.stilllink.session"
    static var account: String { AppInfo.isBeta ? "beta" : "release" }

    static func load() -> Account.Session? {
        let q: [String: Any] = [kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: service,
                                kSecAttrAccount as String: account, kSecReturnData as String: true]
        var out: AnyObject?
        guard SecItemCopyMatching(q as CFDictionary, &out) == errSecSuccess, let d = out as? Data else { return nil }
        return try? JSONDecoder().decode(Account.Session.self, from: d)
    }

    static func save(_ s: Account.Session) {
        guard let d = try? JSONEncoder().encode(s) else { return }
        clear()
        let q: [String: Any] = [kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: service,
                                kSecAttrAccount as String: account, kSecValueData as String: d,
                                kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock]
        SecItemAdd(q as CFDictionary, nil)
    }

    static func clear() {
        let q: [String: Any] = [kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: service,
                                kSecAttrAccount as String: account]
        SecItemDelete(q as CFDictionary)
    }
}
