import Foundation

/// Supabase 專案設定（Mac、iPhone 共用同一個專案，同一個帳號登入就看到同一份資料）
/// anon key 是「公開金鑰」：本來就會放在 App 裡，資料靠資料庫的 Row Level Security 保護（每人只能讀寫自己的）。
/// 不要把 service_role key 放進來——那把會繞過所有權限。
/// 建專案、拿這兩個值的步驟：docs/account-sync.md
enum CloudConfig {
    static let url = ""        // 例：https://abcdefgh.supabase.co
    static let anonKey = ""    // Project Settings → API → anon public

    /// 還沒填就不顯示登入按鈕的實際功能（按了只提示）
    static var isConfigured: Bool { !url.isEmpty && !anonKey.isEmpty }
    static var base: URL { URL(string: url)! }

    /// 登入完瀏覽器導回 App 的網址（Supabase 後台 Authentication → URL Configuration → Redirect URLs 要加這一條）
    static let callbackScheme = "stilllink"
    static let redirect = "stilllink://auth-callback"
}
