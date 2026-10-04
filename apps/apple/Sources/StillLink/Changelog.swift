import SwiftUI

/// 更新紀錄（「新功能」視窗的內容）
/// 發佈新版時在最上面加一筆；major＝重大更新，右上角會出現「新功能」提醒，點過就消失
struct ReleaseNote: Identifiable {
    let version: String
    let date: String
    var major = false
    var new: [String] = []
    var improved: [String] = []
    var fixed: [String] = []
    var id: String { version }
}

enum Changelog {
    static let notes: [ReleaseNote] = [
        ReleaseNote(version: "2.1.5.3", date: "2026 年 10 月 4 日",
            improved: [
                "更新下載好後會先問你要不要現在重新開啟；選「稍後」不會打斷你，工具列會留一顆「重新開啟」，下次關閉 App 時也會自動完成更新",
            ]),
        ReleaseNote(version: "2.1.5.2", date: "2026 年 10 月 4 日",
            improved: [
                "「回報問題」改成在 App 裡直接寫、按送出就寄給我們，不用再打開郵件 App；可以留下 email 收到回覆",
                "設定 → 關於加上聯絡信箱：問題與建議 support@jeanui.com、合作與其他 hi@jeanui.com",
            ]),
        ReleaseNote(version: "2.1.5.1", date: "2026 年 10 月 4 日",
            fixed: [
                "八字跟文墨天機對齊：節氣四柱的月柱改以「節」換月（之前誤用農曆月，跟非節氣四柱一樣），大運也跟著修正",
                "八字起運改照文墨天機的算法（數時辰差），大運歲數改用虛歲、從起運那年算",
            ]),
        ReleaseNote(version: "2.1.5", date: "2026 年 10 月 4 日",
            new: [
                "星曜說明卡可以照目前運限顯示宮位：看大限、流年時 hover 星曜，會寫「大官祿」這類運限宮名（設定 → 盤面可關）",
            ],
            improved: [
                "盤面切換、捲動運限時重畫快了將近三倍",
                "小限改寫在轉宮名上面，不再擠在宮位角落",
                "右側備註卡字放大、每則上下留白，不再貼著分隔線",
                "提示條改停在工具列上方；深色模式下「復原」按鈕看得更清楚",
                "全 App 的輸入框統一大小與字級，點進去會出現主色框線",
            ],
            fixed: [
                "刪除備註、關閉選單時，卡片不會再往旁邊飛出去",
                "切換命盤後，提示條偶爾會掉到視窗最底下",
            ]),
        ReleaseNote(version: "2.1.4", date: "2026 年 10 月 4 日", major: true,
            new: [
                "排盤跟文墨天機對齊：出生時間一律照鐘錶時間排（不扣日光節約、不做經度校正）；有出生地時，中宮同時列出鐘錶時間和真太陽時",
                "設定 → 排盤新增「辛年天魁天鉞」：預設魁寅鉞午（同文墨天機），也可以改回魁午鉞寅；大限、流年的魁鉞一起跟著",
                "雜曜也可以 hover 出說明卡（紅鸞、天喜、咸池、天姚、天刑）",
            ],
            improved: [
                "龍德跟文墨天機一樣排進雜曜",
                "主色調深一點，按鈕、開關在深色模式下更清楚",
                "左下角帳號選單每一項都顯示圖示",
            ],
            fixed: [
                "滑鼠停在盤上任何地方都會跳出「向心自化祿」的提示文字",
            ]),
        ReleaseNote(version: "2.1.3.1", date: "2026 年 10 月 3 日",
            improved: [
                "左下角帳號選單精簡成外觀、設定、新功能、回報問題，每一項都有圖示",
            ],
            fixed: [
                "「此刻」盤上固定出現的綠色小點：其實是畫筆模式下不小心點一下留下的標註；現在只點一下不會留下點，以前留下的也會自動消失",
            ]),
        ReleaseNote(version: "2.1.3", date: "2026 年 10 月 3 日", major: true,
            new: [
                "滑鼠停在星曜上一下，會跳出小卡說明這顆星的重點，以及落在這一宮的意思",
                "設定改成浮在畫面上的設定窗：左上角可以搜尋，分類整理成「設定、命盤、其他」三組，關掉馬上看到盤面變化",
                "運限表每一列 hover 時左右出現箭頭：點一下捲一段、按住持續捲；也可以按住盤面左右拖",
                "新增命盤的分組可以選「下拉選單」或「刻度尺」（設定 → 一般），預設下拉選單",
                "說明選單與左下角「?」新增「回報問題…」：一鍵複製版本、系統、螢幕資訊，貼給我們",
                "右上角「新功能」：重大更新時會出現，看完就消失",
            ],
            improved: [
                "刻度尺可以直接點、按住拖、用滑鼠滾輪一格換一個，游標在邊邊也滑得動",
                "左下角帳號選單每一項都加上圖示",
            ],
            fixed: [
                "「此刻」盤在部分外接螢幕上出現綠色小點：此刻盤不再每分鐘整盤重畫",
            ]),
        ReleaseNote(version: "2.1.2", date: "2026 年 10 月 3 日",
            improved: [
                "備註預覽卡和對話串在深色模式更清楚（浮起底色、細框、較重的陰影）",
                "在備註圖釘上按右鍵可以「標成已解決」或「刪除」，刪除後可以復原",
                "滑鼠停在備註上會換回一般箭頭",
            ],
            fixed: [
                "滑鼠移開備註圖釘後，預覽卡不會消失",
            ]),
        ReleaseNote(version: "2.1.1", date: "2026 年 10 月 3 日",
            improved: [
                "紅鸞、天喜、咸池、天姚、天刑跟主星一樣大，排在雜曜最前面",
                "雜曜改成鐵灰色，跟流曜分得開；四化方塊加大",
                "選到大限時，各宮顯示流年走到這一宮的年份與歲數（例：2034年38歲）",
                "小限改成橫的小框，放在左下流月上面；層級開關移進中宮置中",
                "提示條對齊底部工具列中間，加上圖示和背景模糊",
            ]),
        ReleaseNote(version: "2.1.0", date: "2026 年 10 月 3 日", major: true,
            new: [
                "中宮層級開關：本・限・年・月・日・時，點一下開關那一層的四化（最多同時三層），旁邊另有小限開關",
                "備註（C）：點盤面放圖釘寫備註，可以回覆、編輯、標成已解決、拖曳換位置",
                "箭頭直線工具（A）；每個工具有自己的游標",
            ],
            improved: [
                "四化方塊依層級放固定位置，一眼看出疊在第幾層",
                "轉宮改以目前層級的命宮（大命、流命）為基準",
                "宮名固定置中；主星和雜曜優先排同一排",
                "看盤小提示改成左下角的「?」按鈕；視窗變窄時先自動收起左側欄",
            ],
            fixed: [
                "宮格線固定 1 個實際像素，一般外接螢幕也看得清楚",
            ]),
        ReleaseNote(version: "2.0.0", date: "2026 年 10 月 3 日", major: true,
            new: [
                "標註工具列：畫筆、螢光筆、框線、橡皮擦，可選顏色與粗細，標註跟著每張命盤存起來",
                "星曜分四類各一色：主星、輔星、凶星、雜曜",
                "右側面板可拖拉調寬；可以設定要顯示哪些卡片",
            ],
            improved: [
                "點兩下宮位也能鎖定三方四正；右鍵可以取消轉宮",
                "頂部、底部改成漸進式背景模糊；文字全面套用設計系統",
                "盤面依視窗高度縮小，一打開就看得到運限表",
            ],
            fixed: [
                "身宮格開著長生十二神時，星曜被擠掉的問題",
            ]),
    ]

    /// 這個版本看得到的紀錄（測試版連還沒發佈的下一版也看得到）
    static var visible: [ReleaseNote] {
        notes.filter { AppInfo.isBeta || compare($0.version, AppInfo.version) <= 0 }
    }

    /// 最新一筆重大更新（右上角「新功能」提醒用）
    static var latestMajor: ReleaseNote? { visible.first { $0.major } }

    private static let seenKey = "whatsNewSeen"

    /// 要不要在右上角提醒：有比上次看過更新的重大更新
    static var shouldRemind: Bool {
        guard let m = latestMajor else { return false }
        guard let seen = UserDefaults.standard.string(forKey: seenKey) else { return true }
        return compare(m.version, seen) > 0
    }

    static func markSeen() {
        if let m = latestMajor { UserDefaults.standard.set(m.version, forKey: seenKey) }
    }

    /// 版本號比大小（2.1.10 > 2.1.9）
    static func compare(_ a: String, _ b: String) -> Int {
        let x = a.split(separator: ".").map { Int($0) ?? 0 }, y = b.split(separator: ".").map { Int($0) ?? 0 }
        for i in 0..<max(x.count, y.count) {
            let p = i < x.count ? x[i] : 0, q = i < y.count ? y[i] : 0
            if p != q { return p < q ? -1 : 1 }
        }
        return 0
    }
}

/// 「新功能」視窗（照 Claude 的 What's new）：日期＋版本號，分新功能／改進／修正
struct WhatsNewView: View {
    var onClose: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("新功能").zText(.title1).foregroundStyle(Color.zText)
                Spacer()
                Button(action: onClose) {
                    Image(systemName: "xmark").font(.system(size: 13, weight: .semibold)).foregroundStyle(Color.zText2)
                        .frame(width: 30, height: 30).contentShape(Circle())
                }
                .buttonStyle(PressStyle())
                .keyboardShortcut(.cancelAction)
                .help("關閉（Esc）")
            }
            .padding(.horizontal, 32).padding(.top, 26).padding(.bottom, 8)

            ScrollView {
                VStack(alignment: .leading, spacing: 30) {
                    ForEach(Changelog.visible) { n in entry(n) }
                }
                .padding(.horizontal, 32).padding(.top, 8).padding(.bottom, 32)
            }
        }
        .background(Color.zBg)
    }

    private func entry(_ n: ReleaseNote) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .firstTextBaseline) {
                Text(n.date).zText(.title3).foregroundStyle(Color.zText)
                Spacer()
                Text(n.version).font(.system(size: 12, design: .monospaced)).foregroundStyle(Color.zText2)
                    .padding(.horizontal, 8).padding(.vertical, 3)
                    .background(RoundedRectangle(cornerRadius: 6).fill(Color.zHover))
            }
            .padding(.bottom, 6)
            group("新功能", n.new)
            group("改進", n.improved)
            group("修正", n.fixed)
        }
    }

    @ViewBuilder
    private func group(_ title: String, _ items: [String]) -> some View {
        if !items.isEmpty {
            Text(title).zText(.eyebrow).foregroundStyle(Color.zText3).padding(.top, 14).padding(.bottom, 6)
            ForEach(items, id: \.self) { t in
                HStack(alignment: .firstTextBaseline, spacing: 10) {
                    Circle().fill(Color.zText3).frame(width: 4, height: 4).alignmentGuide(.firstTextBaseline) { $0[.bottom] + 5 }
                    Text(t).zText(.body).foregroundStyle(Color.zText)
                        .fixedSize(horizontal: false, vertical: true)
                        .textSelection(.enabled)
                }
                .padding(.bottom, 6)
            }
        }
    }
}
