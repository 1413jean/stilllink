import Foundation

/// 隱私權政策、使用條款、刪除資料：直接寫在 App 裡，設定 →「關於」打開
enum LegalDoc: String, CaseIterable, Identifiable {
    case privacy = "隱私權政策"
    case terms = "使用條款"
    case delete = "刪除資料"
    case license = "開源授權"
    var id: String { rawValue }

    static let updated = "最後更新：2026 年 10 月 2 日"
    static let contact = "有問題歡迎寫信到 jean.ui@cinpos.com，或到 GitHub（github.com/1413jean/stilllink）回報。"

    /// 最上面一句話的重點
    var summary: String {
        switch self {
        case .license: "StillLink 採用 MIT 授權：可以免費使用、修改、分享，也可以商用，只要保留版權聲明。"
        case .privacy: "你輸入的命盤只存在你自己的 Mac 上，我們看不到，也拿不到。"
        case .terms: "StillLink 是免費的排盤工具，盤上的內容給你參考，決定還是在你自己手上。開始使用，就表示你同意以下約定。"
        case .delete: "StillLink 沒有帳號，所以沒有帳號要刪。所有資料都在你的 Mac 上，可以自己全部清掉。"
        }
    }

    var sections: [(String, String)] {
        switch self {
        case .license: [
            ("你可以做什麼", "免費使用、修改、分享，也可以拿來商用；轉發或改作時請保留原本的版權與授權聲明。"),
            ("星曜筆記的內容", "星曜筆記的預設內容由原作者整理，版權屬於原作者，不包含在 MIT 授權內。"),
            ("MIT License 全文", Self.bundled("LICENSE")),
            ("第三方元件", Self.bundled("THIRD_PARTY_NOTICES.md")),
        ]
        case .privacy: [
            ("我們會收集你的資料嗎？",
             "不會。StillLink 沒有帳號、沒有登入、沒有雲端，也沒有任何數據分析、廣告或追蹤工具。你建立的命盤（姓名、出生日期與時間、出生地）、備註、照片、頭貼和設定，都只留在你的電腦裡。"),
            ("資料存在哪裡？",
             "正式版在 ~/Library/Application Support/StillLink，測試版在 ~/Library/Application Support/StillLink Beta，偏好設定在 ~/Library/Preferences/app.stilllink.mac.plist。除非你自己匯出備份檔，資料不會離開你的 Mac。"),
            ("排盤在哪裡算？",
             "全部在你的 Mac 上計算，使用開源的排盤引擎 iztro，生辰不會送到任何伺服器。"),
            ("什麼時候會連網？",
             "只有檢查和下載 App 更新的時候。StillLink 會向 GitHub（發佈新版的地方）確認有沒有新版本。GitHub 會收到 IP 位址、App 版本這類一般連線資訊，並依它自己的隱私權聲明處理；你的命盤、備註和照片不會送出。"),
            ("備份檔",
             "在「設定 → 資料 → 備份」可以把資料存成 .stilllink 檔。要放在哪裡由你決定；放到雲端硬碟的話，就適用該服務的隱私規定。備份檔裡可能有別人的生辰，請好好保管。"),
            ("幫別人排盤",
             "家人、朋友或客人的生辰也是他們的個人資料，輸入前請先徵得對方同意。"),
            ("以後如果改了",
             "未來可能加入 Apple／Google 登入和雲端同步。若要加入任何會處理個人資料的功能，會先更新這份政策再上線，並說明收集什麼、怎麼用、怎麼刪。"),
        ]
        case .terms: [
            ("StillLink 是什麼",
             "一款 Mac 上的紫微斗數排盤 App，由 Jean 設計與開發。目前免費，沒有付費方案或 App 內購買。"),
            ("從哪裡下載",
             "官方版本只在 GitHub（github.com/1413jean/stilllink）發佈，還沒有上架 App Store。請只從這裡下載，別人轉傳的檔案可能被修改過。"),
            ("內容僅供參考",
             "StillLink 顯示的命盤與資訊只供參考與娛樂，不是醫療、心理、法律、財務或投資建議。重要的決定請不要只憑盤面，需要時請諮詢相關專業人士。"),
            ("你的資料屬於你",
             "命盤、備註、照片和設定都只存在你的 Mac 上，我們拿不到，也不主張任何權利。輸入別人的姓名或生辰前，請先取得對方同意。"),
            ("記得備份",
             "資料只在你的電腦裡，我們沒有副本，無法幫你救回。電腦故障、重灌、誤刪或清空資料都可能讓資料消失，建議定期在「設定 → 資料」備份。"),
            ("更新與改版",
             "App 會到 GitHub 檢查新版本，新版可能新增、調整或移除功能。測試版（StillLink Beta）可能比較不穩定。StillLink 是個人作品，會盡力維護，但無法保證一直有更新。"),
            ("開源元件",
             "排盤使用 iztro，App 內更新使用 Sparkle，皆依各自的授權條款使用。"),
            ("請不要這樣做",
             "修改 App 後冒用 StillLink 的名義散布、未經同意蒐集或公開他人的生辰資料，或用於任何違法用途。"),
            ("責任範圍",
             "StillLink 以現況提供，會盡力讓它正確好用，但無法保證完全沒有錯誤。在法律允許的範圍內，因使用 StillLink 造成的損失，開發者不負賠償責任。"),
            ("條款更新",
             "條款修改時會更新上方的日期；之後繼續使用，就表示你同意新的內容。"),
        ]
        case .delete: [
            ("在 App 裡清空（最簡單）",
             "到「設定 → 資料」，想留一份就先按「備份」，再按「清空所有資料」並確認。清空後無法復原。"),
            ("連 App 一起移除",
             "結束 StillLink 並把它丟到垃圾桶。接著在 Finder 按 ⇧⌘G，前往 ~/Library/Application Support/，刪掉 StillLink（測試版是 StillLink Beta）資料夾；再前往 ~/Library/Preferences/，刪掉 app.stilllink.mac.plist（測試版是 app.stilllink.mac.beta.plist），最後清空垃圾桶。"),
            ("會刪掉什麼",
             "所有命盤、備註、照片、頭貼，以及你的個人檔案和設定。你自己匯出的 .stilllink 備份檔不會被刪，要刪請自行找到它。"),
            ("以後有帳號的話",
             "如果未來加入帳號和雲端同步，這裡會加上刪除帳號與雲端資料的方法。"),
        ]
        }
    }

    /// App 裡附的授權檔（build.sh 從 repo 根目錄複製進 Resources）
    static func bundled(_ name: String) -> String {
        guard let url = Bundle.main.url(forResource: name, withExtension: nil),
              let text = try? String(contentsOf: url, encoding: .utf8) else { return "（找不到 \(name)）" }
        return text.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
