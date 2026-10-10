import CryptoKit
import Foundation
import SwiftUI
#if os(macOS)
import AppKit
#else
import UIKit
#endif

/// 命盤、照片、偏好設定跟 Supabase 雙向同步。
///
/// 規則：
/// - 每張命盤各自比修改時間，「最後改的贏」。本機改過還沒推上去的記在 dirty（id → 修改時間），刪掉的記在 deleted
/// - 拉：用伺服器時間 server_at 當游標，只拿上次之後變過的；遠端比本機新就套用（刪除也照做）
/// - 推：dirty、deleted 全部 upsert 上去，成功就清掉
/// - 第一次用這個帳號同步：本機所有命盤都當成 dirty，等於把本機合併上去（不會蓋掉雲端）
/// - 照片／頭貼：檔名不會重複（UUID），沒傳過的上傳、本機沒有的下載
/// - 登出只清登入狀態和同步紀錄，本機資料保留
@MainActor
final class CloudSync: ObservableObject {
    static let shared = CloudSync()

    @Published private(set) var syncing = false
    @Published private(set) var lastSync: Date?
    @Published private(set) var lastError: String?
    /// 手動更新中（⌘R、下拉）：畫面換成骨架，跑完再淡入新資料
    @Published private(set) var refreshing = false

    private struct State: Codable {
        var userID: String?
        var cursor: String?                  // people 上次拉到的 server_at（伺服器原樣字串）
        var dirty: [UUID: Date] = [:]
        var deleted: [UUID: Date] = [:]
        var uploaded: Set<String> = []
        var prefsHash: String?               // 上次同步時偏好設定的內容
        var prefsUpdated: Date?              // 本機偏好設定最後改的時間
        var lastSync: Date?
    }
    private var state: State
    private let stateURL = Store.dataDir.appendingPathComponent("sync-state.json")
    private var pushTask: Task<Void, Never>?
    private var started = false

    private init() {
        state = (try? Data(contentsOf: stateURL)).flatMap { try? JSONDecoder().decode(State.self, from: $0) } ?? State()
        lastSync = state.lastSync
    }

    /// 開 App 時呼叫：已登入就同步，之後回到前景也同步
    func start() {
        guard !started else { return }
        started = true
        // 驗證用：ZIWEI_SKELETON=1 一直停在手動更新的骨架畫面（截圖看骨架）
        if ProcessInfo.processInfo.environment["ZIWEI_SKELETON"] != nil { refreshing = true }
        #if os(macOS)
        let name = NSApplication.didBecomeActiveNotification
        #else
        let name = UIApplication.didBecomeActiveNotification
        #endif
        NotificationCenter.default.addObserver(forName: name, object: nil, queue: .main) { _ in
            MainActor.assumeIsolated { CloudSync.shared.syncSoon(delay: 0.5) }
        }
        syncSoon(delay: 1)
    }

    // MARK: 本機改動

    /// Store.people 變了（不是同步套用的）：記下哪些命盤改了、刪了
    func noteLocal(old: [Person], new: [Person]) {
        // 沒登入不用記：第一次登入時本機全部命盤本來就會合併上去
        guard CloudConfig.isConfigured, Account.shared.isSignedIn else { return }
        let now = Date()
        let before = Dictionary(old.map { ($0.id, $0) }, uniquingKeysWith: { a, _ in a })
        let afterIDs = Set(new.map(\.id))
        var changed = false
        for p in new where p.id != Person.nowID && before[p.id] != p {
            state.dirty[p.id] = now; state.deleted[p.id] = nil; changed = true
        }
        for id in before.keys where !afterIDs.contains(id) && id != Person.nowID {
            state.deleted[id] = now; state.dirty[id] = nil; changed = true
        }
        guard changed else { return }
        saveState()
        syncSoon(delay: 3)   // 連續打字、拖曳時不要每一下都推
    }

    /// 偏好設定（名字、設定…）改了：同步時會比對內容，這裡只要排一次同步
    func notePrefsChanged() { syncSoon(delay: 3) }

    func syncSoon(delay: Double) {
        guard CloudConfig.isConfigured, Account.shared.isSignedIn else { return }
        pushTask?.cancel()
        pushTask = Task {
            try? await Task.sleep(for: .seconds(delay))
            guard !Task.isCancelled else { return }
            await syncNow()
        }
    }

    /// 登出：清掉同步紀錄（下次登入不管是不是同一個帳號，都重新合併一次）
    func reset() {
        pushTask?.cancel()
        state = State()
        lastSync = nil; lastError = nil
        saveState()
    }

    // MARK: 同步

    /// 手動更新：進骨架 → 同步 → 淡入新資料。骨架最少停 0.7 秒，太快結束會像閃一下
    func refresh() async {
        guard Account.shared.isSignedIn, !refreshing else { return }
        withAnimation(Motion.fast) { refreshing = true }
        let start = Date()
        while syncing { try? await Task.sleep(for: .milliseconds(100)) }   // 背景同步正在跑：等它跑完再跑一次
        await syncNow()
        let left = 0.7 - Date().timeIntervalSince(start)
        if left > 0 { try? await Task.sleep(for: .seconds(left)) }
        withAnimation(Motion.base) { refreshing = false }
    }

    func syncNow() async {
        guard CloudConfig.isConfigured, let session = Account.shared.session, !syncing, let store = Store.current else { return }
        syncing = true
        defer { syncing = false }
        do {
            let token = try await Account.shared.validAccessToken()
            let api = API(token: token)
            if state.userID != session.userID {
                // 這個帳號第一次在這台同步：本機全部當成要推上去的
                state = State(userID: session.userID)
                let now = Date()
                for p in store.people where p.id != Person.nowID { state.dirty[p.id] = now }
            }
            try await pull(api, store)
            try await push(api, store)
            try await syncMedia(api, store, uid: session.userID)
            try await syncPrefs(api, store)
            state.lastSync = Date()
            lastSync = state.lastSync
            lastError = nil
        } catch {
            lastError = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        }
        saveState()
    }

    private func pull(_ api: API, _ store: Store) async throws {
        while true {
            var q = "rest/v1/people?select=id,data,updated_at,server_at,deleted&order=server_at.asc&limit=500"
            if let c = state.cursor { q += "&server_at=gt." + (c.addingPercentEncoding(withAllowedCharacters: .alphanumerics) ?? c) }
            let rows = try await api.json(q) as? [[String: Any]] ?? []
            if rows.isEmpty { return }
            var people = store.people
            var touched = false
            for r in rows {
                guard let idStr = r["id"] as? String, let id = UUID(uuidString: idStr),
                      let updated = (r["updated_at"] as? String).flatMap(Self.parseDate) else { continue }
                if let mine = state.dirty[id] ?? state.deleted[id], mine >= updated { continue }   // 本機比較新：等一下推上去
                state.dirty[id] = nil; state.deleted[id] = nil
                if r["deleted"] as? Bool == true {
                    people.removeAll { $0.id == id }; touched = true
                } else if let obj = r["data"], let data = try? JSONSerialization.data(withJSONObject: obj),
                          let p = try? JSONDecoder().decode(Person.self, from: data) {
                    if let i = people.firstIndex(where: { $0.id == id }) { people[i] = p } else { people.insert(p, at: 0) }
                    touched = true
                }
            }
            if touched {
                store.applyingRemote = true
                store.people = people
                store.applyingRemote = false
            }
            state.cursor = rows.last?["server_at"] as? String ?? state.cursor
            if rows.count < 500 { return }
        }
    }

    private func push(_ api: API, _ store: Store) async throws {
        let byID = Dictionary(store.people.map { ($0.id, $0) }, uniquingKeysWith: { a, _ in a })
        var rows: [[String: Any]] = []
        var sent: [(UUID, Date)] = []
        for (id, at) in state.dirty {
            guard let p = byID[id], let data = try? JSONSerialization.jsonObject(with: JSONEncoder().encode(p)) else {
                state.dirty[id] = nil; continue
            }
            rows.append(["id": id.uuidString, "data": data, "updated_at": Self.iso(at), "deleted": false]); sent.append((id, at))
        }
        for (id, at) in state.deleted {
            rows.append(["id": id.uuidString, "data": [String: Any](), "updated_at": Self.iso(at), "deleted": true]); sent.append((id, at))
        }
        guard !rows.isEmpty else { return }
        for chunk in stride(from: 0, to: rows.count, by: 200).map({ Array(rows[$0..<min($0 + 200, rows.count)]) }) {
            _ = try await api.send("rest/v1/people?on_conflict=id", method: "POST", json: chunk,
                                   headers: ["Prefer": "resolution=merge-duplicates,return=minimal"])
        }
        // 推送途中又改了的（時間變新）留著下次再推
        for (id, at) in sent {
            if state.dirty[id] == at { state.dirty[id] = nil }
            if state.deleted[id] == at { state.deleted[id] = nil }
        }
    }

    private func syncMedia(_ api: API, _ store: Store, uid: String) async throws {
        var names = Set(store.people.flatMap { ($0.photos ?? []) + [$0.avatar].compactMap { $0 } })
        if !store.userAvatarRaw.isEmpty { names.insert(store.userAvatarRaw) }
        let dir = Store.dataDir.appendingPathComponent("media", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        for name in names.sorted() {
            let local = dir.appendingPathComponent(name)
            let path = "\(uid)/\(name)"
            if FileManager.default.fileExists(atPath: local.path) {
                guard !state.uploaded.contains(name), let data = try? Data(contentsOf: local) else { continue }
                _ = try await api.send("storage/v1/object/media/\(path)", method: "POST", body: data,
                                       headers: ["Content-Type": "image/jpeg", "x-upsert": "true"])
                state.uploaded.insert(name)
            } else if let data = try? await api.raw("storage/v1/object/authenticated/media/\(path)") {
                try? data.write(to: local, options: .atomic)
                state.uploaded.insert(name)
            }
        }
        if !names.isEmpty { store.objectWillChange.send() }   // 剛下載的頭貼、照片要重畫
    }

    private func syncPrefs(_ api: API, _ store: Store) async throws {
        let (blob, hash) = Self.prefsSnapshot()
        // 跟上次同步的內容不一樣＝本機改過，記下改的時間（第一次同步沒有上次內容，不算改過，讓雲端的先套用）
        if let last = state.prefsHash, last != hash { state.prefsUpdated = Date(); state.prefsHash = nil }
        let rows = try await api.json("rest/v1/prefs?select=data,updated_at") as? [[String: Any]] ?? []
        let remote = rows.first
        let remoteAt = (remote?["updated_at"] as? String).flatMap(Self.parseDate)
        if let remoteAt, remoteAt > (state.prefsUpdated ?? .distantPast),
           let data = remote?["data"] as? [String: Any], let b64 = data["plist"] as? String, let plist = Data(base64Encoded: b64) {
            // 雲端比較新：套用
            Self.applyPrefs(plist, store)
            state.prefsHash = Self.prefsSnapshot().1
            state.prefsUpdated = remoteAt
        } else if remote == nil || state.prefsHash != hash {
            // 雲端沒有、或本機比較新：推上去
            let at = state.prefsUpdated ?? Date()
            _ = try await api.send("rest/v1/prefs?on_conflict=user_id", method: "POST",
                                   json: [["data": ["plist": blob.base64EncodedString()], "updated_at": Self.iso(at)]],
                                   headers: ["Prefer": "resolution=merge-duplicates,return=minimal"])
            state.prefsHash = hash
            state.prefsUpdated = at
        }
    }

    // MARK: 偏好設定

    /// 目前的偏好設定打包成 plist；雜湊用排序過的 key 逐一算（字典的 plist 編碼順序不固定）
    private static func prefsSnapshot() -> (Data, String) {
        let d = UserDefaults.standard
        var dict: [String: Any] = [:]
        var h = SHA256()
        for k in Store.backupKeys.sorted() {
            guard let v = d.object(forKey: k) else { continue }
            dict[k] = v
            h.update(data: Data(k.utf8))
            if let one = try? PropertyListSerialization.data(fromPropertyList: [v], format: .binary, options: 0) { h.update(data: one) }
        }
        let blob = (try? PropertyListSerialization.data(fromPropertyList: dict, format: .binary, options: 0)) ?? Data()
        return (blob, h.finalize().map { String(format: "%02x", $0) }.joined())
    }

    private static func applyPrefs(_ plist: Data, _ store: Store) {
        guard let dict = try? PropertyListSerialization.propertyList(from: plist, format: nil) as? [String: Any] else { return }
        let d = UserDefaults.standard
        for (k, v) in dict where Store.backupKeys.contains(k) { d.set(v, forKey: k) }
        store.settings = ZSettings.stored()
        store.objectWillChange.send()
    }

    // MARK: 工具

    private func saveState() {
        guard let data = try? JSONEncoder().encode(state) else { return }
        try? data.write(to: stateURL, options: .atomic)
    }

    private static func iso(_ d: Date) -> String {
        let f = ISO8601DateFormatter(); f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f.string(from: d)
    }

    /// Postgres 回來的時間是微秒（6 位小數），ISO8601DateFormatter 只吃 3 位：先截成 3 位
    static func parseDate(_ s: String) -> Date? {
        var t = s
        if let dot = t.firstIndex(of: ".") {
            let fracEnd = t[dot...].firstIndex { !$0.isNumber && $0 != "." } ?? t.endIndex
            let digits = t[t.index(after: dot)..<fracEnd]
            t.replaceSubrange(t.index(after: dot)..<fracEnd, with: String((digits + "000").prefix(3)))
        }
        let f = ISO8601DateFormatter(); f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let d = f.date(from: t) { return d }
        f.formatOptions = [.withInternetDateTime]
        return f.date(from: s)
    }

    /// Supabase REST：帶 apikey＋登入者的 token
    private struct API {
        let token: String

        func request(_ path: String, method: String = "GET") -> URLRequest {
            var r = URLRequest(url: URL(string: CloudConfig.url + "/" + path)!)
            r.httpMethod = method
            r.setValue(CloudConfig.anonKey, forHTTPHeaderField: "apikey")
            r.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            return r
        }

        func json(_ path: String) async throws -> Any {
            let data = try await raw(path)
            return try JSONSerialization.jsonObject(with: data)
        }

        func raw(_ path: String) async throws -> Data {
            let (data, resp) = try await URLSession.shared.data(for: request(path))
            try check(resp, data)
            return data
        }

        func send(_ path: String, method: String, json: Any? = nil, body: Data? = nil, headers: [String: String] = [:]) async throws -> Data {
            var r = request(path, method: method)
            if let json { r.httpBody = try JSONSerialization.data(withJSONObject: json); r.setValue("application/json", forHTTPHeaderField: "Content-Type") }
            if let body { r.httpBody = body }
            for (k, v) in headers { r.setValue(v, forHTTPHeaderField: k) }
            let (data, resp) = try await URLSession.shared.data(for: r)
            try check(resp, data)
            return data
        }

        private func check(_ resp: URLResponse, _ data: Data) throws {
            guard let http = resp as? HTTPURLResponse else { return }
            guard (200..<300).contains(http.statusCode) else {
                let msg = (try? JSONSerialization.jsonObject(with: data) as? [String: Any])
                    .flatMap { $0["message"] as? String ?? $0["error"] as? String } ?? "HTTP \(http.statusCode)"
                throw Account.Failure.badResponse("同步失敗：\(msg)")
            }
        }
    }
}
