import Foundation

/// 隱私權政策、使用條款、刪除資料：直接寫在 App 裡，設定 →「關於」打開
enum LegalDoc: String, CaseIterable, Identifiable {
    case privacy = "隱私權政策"
    case terms = "使用條款"
    case delete = "刪除資料"
    case license = "開源授權"
    var id: String { rawValue }

    static let updated = "最後更新：2026 年 10 月 9 日"
    static let contact = "有問題歡迎寫信到 support@jeanui.com，或到 GitHub（github.com/1413jean/stilllink）回報。"

    /// 這台裝置的叫法（條款裡「你的 Mac／iPhone」）
    private static var device: String {
        #if os(macOS)
        "Mac"
        #else
        "iPhone"
        #endif
    }

    /// 最上面一句話的重點
    var summary: String {
        switch self {
        case .license: "StillLink 採用 MIT 授權：可以免費使用、修改、分享，也可以商用，只要保留版權聲明。"
        case .privacy: "沒登入時，命盤只存在你的\(Self.device)上；登入後會同步到你自己的帳號，只有你讀得到。沒有廣告、沒有追蹤。"
        case .terms: "StillLink 是免費的排盤工具，盤上的內容給你參考，決定還是在你自己手上。開始使用，就表示你同意以下約定。"
        case .delete: "登出只會停止同步；要連雲端資料一起刪，請在 App 裡刪除帳號。裝置上的資料可以自己清掉。"
        }
    }

    var sections: [(String, String)] {
        let d = Self.device
        switch self {
        case .license: return [
            ("你可以做什麼", "免費使用、修改、分享，也可以拿來商用；轉發或改作時請保留原本的版權與授權聲明。"),
            ("星曜筆記的內容", "星曜筆記的預設內容由原作者整理，版權屬於原作者，不包含在 MIT 授權內。"),
            ("MIT License 全文", Self.bundled("LICENSE")),
            ("第三方元件", Self.bundled("THIRD_PARTY_NOTICES.md")),
        ]
        case .privacy: return [
            ("不登入也能用",
             "不登入時，StillLink 不會收集任何資料。你建立的命盤（姓名、出生日期與時間、出生地）、備註、照片、頭貼和設定，都只留在你的\(d)上。"),
            ("登入後會存什麼",
             "用 Apple 或 Google 登入後，為了在不同裝置同步，會把下列資料存到你的帳號：登入用的帳號識別碼和 Email、命盤、備註、照片、頭貼，以及偏好設定（名字、命盤設定、排序、外觀等）。我們不會向 Apple 或 Google 要求其他資料；用 Apple 登入時可以選擇隱藏 Email。"),
            ("存在哪裡、怎麼保護",
             "雲端資料存放在 Supabase（雲端資料庫服務，伺服器位於 AWS 亞太區）。傳輸全程加密（HTTPS），資料庫設定成每個帳號只能讀寫自己的資料，照片也存在只有本人能存取的私人空間。"),
            ("誰看得到",
             "只有你。開發者為了維運，技術上可以進入資料庫後台，但不會查看你的內容，也不會拿來分析、做廣告、販售或提供給任何人，除非法律要求。"),
            ("不做的事",
             "沒有廣告、沒有數據分析或追蹤工具，也不會把資料用來訓練任何模型。"),
            ("排盤在哪裡算",
             "全部在你的\(d)上計算，使用開源的排盤引擎 iztro；同步的只是你存的資料，排盤本身不經過伺服器。"),
            ("什麼時候會連網",
             "登入時（連到 Apple 或 Google 與 Supabase）、同步時（連到 Supabase）。Mac 版另外會向 GitHub 檢查 App 更新，GitHub 會收到 IP 位址、App 版本這類一般連線資訊。"),
            ("會用到的服務",
             "Apple、Google：登入。Supabase：存放同步的資料。GitHub：Mac 版的 App 更新。它們各自依自己的隱私權聲明處理連線資訊。"),
            ("保存多久、怎麼刪",
             "雲端資料會保存到你刪除帳號為止。在「帳號」裡按「刪除帳號」，雲端上的命盤、照片和帳號會一起刪除，無法復原；登出則只停止這台裝置的同步，雲端資料保留。詳見「刪除資料」。"),
            ("幫別人排盤",
             "家人、朋友或客人的生辰也是他們的個人資料，輸入前請先徵得對方同意；登入同步後，這些資料也會存到你的帳號。"),
            ("政策更新",
             "政策修改時會更新上方的日期；有重大變更（例如要多收集資料）會在 App 裡先告訴你。"),
        ]
        case .terms:
            #if os(macOS)
            let download = "Mac 版只在 GitHub（github.com/1413jean/stilllink）發佈，還沒有上架 App Store。請只從這裡下載，別人轉傳的檔案可能被修改過。"
            #else
            let download = "iPhone 版目前是測試版，由開發者直接安裝，還沒有上架 App Store。請不要安裝別人轉傳的版本。"
            #endif
            return [
            ("StillLink 是什麼",
             "一款紫微斗數排盤 App（Mac、iPhone），由 Jean 設計與開發。目前免費，沒有付費方案或 App 內購買。"),
            ("從哪裡下載", download),
            ("內容僅供參考",
             "StillLink 顯示的命盤與資訊只供參考與娛樂，不是醫療、心理、法律、財務或投資建議。重要的決定請不要只憑盤面，需要時請諮詢相關專業人士。"),
            ("帳號",
             "登入是選用的，不登入也能使用全部排盤功能。登入後請自己保管好 Apple／Google 帳號；同一個帳號在不同裝置看到的是同一份資料，在一台刪除命盤，其他裝置也會跟著刪除。"),
            ("你的資料屬於你",
             "你建立的命盤、備註、照片和設定屬於你，我們不主張任何權利，只為了同步而存放。輸入別人的姓名或生辰前，請先取得對方同意。"),
            ("記得備份",
             "沒登入時資料只在你的\(d)上，我們沒有副本，無法幫你救回。登入同步會多一份雲端副本，但同步服務無法保證永不中斷，重要資料建議另外備份。"),
            ("更新與改版",
             "新版可能新增、調整或移除功能。測試版（Beta）可能比較不穩定。StillLink 是個人作品，會盡力維護，但無法保證一直有更新或雲端服務永久提供；若要停止雲端服務，會提前在 App 裡通知並讓你下載資料。"),
            ("開源元件",
             "排盤使用 iztro，Mac 版的 App 內更新使用 Sparkle，皆依各自的授權條款使用。"),
            ("請不要這樣做",
             "修改 App 後冒用 StillLink 的名義散布、未經同意蒐集或公開他人的生辰資料、干擾或濫用雲端服務，或用於任何違法用途。"),
            ("責任範圍",
             "StillLink 以現況提供，會盡力讓它正確好用，但無法保證完全沒有錯誤。在法律允許的範圍內，因使用 StillLink 造成的損失，開發者不負賠償責任。"),
            ("條款更新",
             "條款修改時會更新上方的日期；之後繼續使用，就表示你同意新的內容。"),
        ]
        case .delete:
            #if os(macOS)
            let local = ("刪除這台 Mac 上的資料",
                         "到「設定 → 資料」，想留一份就先按「備份」，再按「清空所有資料」並確認（登入中會先自動登出，雲端資料不受影響）。要連 App 一起移除：把 StillLink 丟到垃圾桶，再到 ~/Library/Application Support/ 刪掉 StillLink（測試版是 StillLink Beta）資料夾，以及 ~/Library/Preferences/ 裡的 app.stilllink.mac.plist。")
            #else
            let local = ("刪除這台 iPhone 上的資料",
                         "長按主畫面上的 StillLink →「移除 App」→「刪除 App」，iPhone 上的命盤、照片和設定會一起刪除。雲端資料不受影響。")
            #endif
            return [
            ("刪除帳號與雲端資料",
             "登入後，到「帳號」（iPhone 在「我的」，Mac 在「設定 → 帳號與同步」）按「刪除帳號」並確認。帳號、雲端上的命盤、備註、照片和偏好設定會立即一起刪除，無法復原。裝置上的資料會保留，要刪請看下一段。"),
            local,
            ("只想停止同步",
             "按「登出」就好：這台裝置不再同步，雲端和裝置上的資料都保留，之後再登入會自動合併。"),
            ("沒辦法登入時",
             "如果已經無法登入（例如帳號被停用），請寫信告訴我們登入用的 Email，我們會在 30 天內幫你刪除雲端資料。"),
            ("備份檔",
             "你自己匯出的 .stilllink 備份檔不會被刪，要刪請自行找到它。"),
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
