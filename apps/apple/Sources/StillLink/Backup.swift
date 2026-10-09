import AppKit
import Foundation

/// 備份檔（.stilllink，內容是 JSON）：命盤、照片／頭貼、個人檔案與設定全部打包成一個檔
struct BackupFile: Codable {
    var version = 1
    var createdAt = Date()
    var people: [Person]
    var prefs: Data                 // 偏好設定（plist）
    var media: [String: Data]       // 照片、頭貼：檔名 → 內容
}

@MainActor
extension Store {
    func makeBackup() throws -> Data {
        let d = UserDefaults.standard
        var prefs: [String: Any] = [:]
        for k in Store.backupKeys { if let v = d.object(forKey: k) { prefs[k] = v } }
        var media: [String: Data] = [:]
        let files = (try? FileManager.default.contentsOfDirectory(at: Media.dir, includingPropertiesForKeys: nil)) ?? []
        for f in files { media[f.lastPathComponent] = try? Data(contentsOf: f) }
        let file = BackupFile(people: people,
                              prefs: try PropertyListSerialization.data(fromPropertyList: prefs, format: .binary, options: 0),
                              media: media)
        return try JSONEncoder().encode(file)
    }

    /// 還原：先清空，再把備份檔裡的東西放回去
    func restore(_ data: Data) throws {
        let file = try JSONDecoder().decode(BackupFile.self, from: data)
        let prefs = try PropertyListSerialization.propertyList(from: file.prefs, format: nil) as? [String: Any] ?? [:]
        eraseAll()
        for (name, content) in file.media { try? content.write(to: Media.url(name)) }
        let d = UserDefaults.standard
        for (k, v) in prefs where Store.backupKeys.contains(k) { d.set(v, forKey: k) }
        settings = ZSettings.stored()
        people = file.people
        objectWillChange.send()
    }

    /// 清空：命盤、照片／頭貼、個人檔案與設定全部刪掉，回到第一次打開的樣子
    func eraseAll() {
        // 登入中清空會被同步當成「全部刪除」推上雲端：先登出，雲端那份保留
        if Account.shared.isSignedIn { Account.shared.signOut() }
        let files = (try? FileManager.default.contentsOfDirectory(at: Media.dir, includingPropertiesForKeys: nil)) ?? []
        for f in files { try? FileManager.default.removeItem(at: f) }
        let d = UserDefaults.standard
        for k in Store.backupKeys { d.removeObject(forKey: k) }
        settings = ZSettings()
        people = []
        objectWillChange.send()
    }

    /// 存成檔案（跳出存檔視窗）
    func exportBackup() {
        let panel = NSSavePanel()
        let f = DateFormatter(); f.dateFormat = "yyyy-MM-dd"
        panel.nameFieldStringValue = "StillLink 備份 \(f.string(from: Date())).stilllink"
        panel.canCreateDirectories = true
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            try makeBackup().write(to: url, options: .atomic)
            Toast.show("已備份 \(people.count) 張命盤")
        } catch {
            Toast.show("備份失敗：\(error.localizedDescription)")
        }
    }

    /// 選備份檔還原
    func importBackup() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.message = "選擇 StillLink 備份檔（.stilllink）"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            try restore(Data(contentsOf: url))
            Toast.show("已還原 \(people.count) 張命盤")
        } catch {
            Toast.show("這不是 StillLink 的備份檔")
        }
    }
}
