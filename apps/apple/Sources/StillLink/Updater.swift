import AppKit
import Foundation

/// 檢查更新：讀 GitHub Releases，正式版看一般發佈（tag v0.2.0），測試版看 Pre-release（tag v0.2.0-b80，b 後面是 build 號）
enum Updater {
    /// 放 DMG 的 GitHub repo（必須是公開的，App 才讀得到）
    static let repo = "1413jean/stilllink"

    struct Release: Decodable {
        let tag_name: String
        let prerelease: Bool
        let draft: Bool
        let html_url: String
        let assets: [Asset]
        struct Asset: Decodable { let name: String; let browser_download_url: String }

        /// tag 拆成版本與 build：v0.2.0-b80 → ([0, 2, 0], 80)
        var parsed: (version: [Int], build: Int) {
            let t = tag_name.hasPrefix("v") ? String(tag_name.dropFirst()) : tag_name
            let parts = t.split(separator: "-b", maxSplits: 1).map(String.init)
            return (parts[0].split(separator: ".").compactMap { Int($0) }, parts.count > 1 ? Int(parts[1]) ?? 0 : 0)
        }
        /// 看實際系統版本挑 DMG：macOS 13 下載檔名有「macOS13」的；14 以上下載一般版（裝了 13 版的人升級系統後會自動換回一般版）
        var dmgURL: URL? {
            let dmgs = assets.filter { $0.name.hasSuffix(".dmg") }
            let isOld = ProcessInfo.processInfo.operatingSystemVersion.majorVersion < 14
            let pick = isOld ? dmgs.first { $0.name.contains("macOS13") } : dmgs.first { !$0.name.contains("macOS13") }
            return (pick ?? dmgs.first).flatMap { URL(string: $0.browser_download_url) }
        }
        /// 給人看的版本：0.2.0 或 0.2.0 測試版（build 80）
        var display: String {
            let p = parsed, v = p.version.map(String.init).joined(separator: ".")
            return prerelease ? "\(v) 測試版（build \(p.build)）" : v
        }
    }

    enum Result {
        case upToDate
        case available(Release)
        case failed(String)
    }

    static func check() async -> Result {
        guard let url = URL(string: "https://api.github.com/repos/\(repo)/releases?per_page=30") else { return .failed("網址錯誤") }
        var req = URLRequest(url: url, timeoutInterval: 15)
        req.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        do {
            let (data, resp) = try await URLSession.shared.data(for: req)
            if let http = resp as? HTTPURLResponse, http.statusCode != 200 {
                return .failed(http.statusCode == 404 ? "找不到發佈頁面（Releases 還沒公開）" : "伺服器回應 \(http.statusCode)")
            }
            let all = try JSONDecoder().decode([Release].self, from: data).filter { !$0.draft && $0.prerelease == AppInfo.isBeta }
            let current = (version: AppInfo.version.split(separator: ".").compactMap { Int($0) }, build: Int(AppInfo.build) ?? 0)
            guard let newest = all.max(by: { isNewer($1.parsed, than: $0.parsed) }), isNewer(newest.parsed, than: current) else {
                return .upToDate
            }
            return .available(newest)
        } catch {
            return .failed("連不上網路")
        }
    }

    /// 先比版本號，一樣再比 build（測試版同一個版本號會出很多個 build）
    static func isNewer(_ a: (version: [Int], build: Int), than b: (version: [Int], build: Int)) -> Bool {
        for i in 0..<max(a.version.count, b.version.count) {
            let x = i < a.version.count ? a.version[i] : 0, y = i < b.version.count ? b.version[i] : 0
            if x != y { return x > y }
        }
        return AppInfo.isBeta && a.build > b.build
    }

    /// 下載新的 DMG（沒有 DMG 就打開發佈頁）
    static func download(_ r: Release) {
        NSWorkspace.shared.open(r.dmgURL ?? URL(string: r.html_url)!)
    }
}
