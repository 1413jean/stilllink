import Foundation

/// 版本與通道：測試版（beta）和正式版（release）是兩個獨立的 App，由 build.sh 寫進 Info.plist
enum AppInfo {
    static let isBeta = (Bundle.main.object(forInfoDictionaryKey: "StillLinkChannel") as? String) != "release"
    static let name = isBeta ? "StillLink Beta" : "StillLink"
    static let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? ""
    static let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? ""
    /// 關於頁顯示：正式版「0.1.0」、測試版「0.1.0 測試版（build 80）」
    static var displayVersion: String { isBeta ? "\(version) 測試版（build \(build)）" : version }
    /// 資料資料夾名稱：兩個版本的命盤分開放，測試版亂掉不會影響正式版
    static let dataFolder = isBeta ? "StillLink Beta" : "StillLink"
}
