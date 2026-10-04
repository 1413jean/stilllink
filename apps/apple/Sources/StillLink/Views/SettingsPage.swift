import SwiftUI

/// 設定窗（照 Claude 設定）：浮在畫面上，左邊搜尋＋分組分類，右邊段落標題＋每列「左標題說明、右控制項」
struct SettingsPage: View {
    @EnvironmentObject var store: Store
    var onClose: () -> Void
    @State private var section: Section
    @State private var query = ""
    @State private var matches: [Part: Int] = [:]     // 搜尋時每一段有幾列符合
    @FocusState private var searchFocused: Bool
    @State private var doc: LegalDoc?        // 關於 → 隱私權政策／使用條款／刪除資料
    @State private var nameDraft = ""
    @State private var confirmErase = false
    @ObservedObject private var updater = AppUpdater.shared

    /// 設定窗開著時，盤面上的捲動攔截（運限表）要讓開
    static var isOpen = false

    init(initial: Section = .general, onClose: @escaping () -> Void) {
        self.onClose = onClose
        _section = State(initialValue: initial)
        // 驗證用：ZIWEI_LEGAL=privacy／terms／delete 直接打開說明頁；ZIWEI_SETTINGS_QUERY=文字 直接搜尋
        let env = ProcessInfo.processInfo.environment
        if let v = env["ZIWEI_LEGAL"] {
            _doc = State(initialValue: LegalDoc.allCases.first { "\($0)" == v })
        }
        if let q = env["ZIWEI_SETTINGS_QUERY"] { _query = State(initialValue: q) }
    }

    /// 左邊的分類
    enum Section: String, CaseIterable, Identifiable {
        case general = "一般", profile = "個人檔案", account = "帳號與同步"
        case chart = "排盤", board = "盤面", periods = "運限"
        case data = "資料", about = "關於"
        var id: String { rawValue }
        var icon: String {
            switch self {
            case .general: "gearshape"
            case .profile: "person.crop.circle"
            case .account: "icloud"
            case .chart: "square.grid.3x3"
            case .board: "eye"
            case .periods: "calendar"
            case .data: "externaldrive"
            case .about: "info.circle"
            }
        }
        /// 這一頁由哪幾段組成
        fileprivate var parts: [Part] {
            switch self {
            case .general: [.appearance, .feel]
            case .profile: [.profile]
            case .account: [.account]
            case .chart: [.chart, .mutagen]
            case .board: [.stars, .display, .panel]
            case .periods: [.periods]
            case .data: [.data]
            case .about: [.about]
            }
        }
        /// 左欄的分組（小灰字標題＋分類）
        static let groups: [(String, [Section])] = [
            ("設定", [.general, .profile, .account]),
            ("命盤", [.chart, .board, .periods]),
            ("其他", [.data, .about]),
        ]
        /// 舊的分類名稱也找得到（ZIWEI_SETTINGS=display、look 之類）
        static func find(_ key: String) -> Section? {
            let alias: [String: Section] = ["look": .general, "display": .board]
            return allCases.first { "\($0)" == key } ?? alias[key]
                ?? Part(rawValue: key).flatMap { p in allCases.first { $0.parts.contains(p) } }
        }
    }

    /// 每一頁裡的一段
    fileprivate enum Part: String {
        case profile, account, chart, mutagen, stars, periods, display, panel, feel, appearance, data, about
        var title: String {
            switch self {
            case .profile: "個人檔案"
            case .account: "帳號與同步"
            case .chart: "排盤"
            case .mutagen: "四化版本"
            case .stars: "星曜"
            case .periods: "運限"
            case .display: "盤面標記"
            case .panel: "右側面板"
            case .feel: "音效與動畫"
            case .appearance: "外觀"
            case .data: "資料"
            case .about: "關於"
            }
        }
    }

    private var q: String { query.trimmingCharacters(in: .whitespaces) }
    private var searching: Bool { !q.isEmpty }

    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            sidebar
            Rectangle().fill(Color.zLine).frame(width: 0.5)
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    if let doc { legalPage(doc) }
                    else if searching {
                        ForEach(Section.allCases) { sec in
                            ForEach(sec.parts, id: \.self) { p in partBox(p, in: sec) }
                        }
                        if matches.values.reduce(0, +) == 0 {
                            Text("找不到「\(q)」相關的設定").zText(.callout).foregroundStyle(Color.zText3)
                                .padding(.top, 40).frame(maxWidth: .infinity)
                        }
                    } else {
                        ForEach(section.parts, id: \.self) { p in partBox(p, in: section) }
                    }
                }
                .frame(maxWidth: 680, alignment: .leading)
                .padding(.horizontal, 32)
                .padding(.top, 28)
                .padding(.bottom, 40)
                .id(doc?.id ?? (searching ? "search" : section.rawValue))
                .transition(.opacity)
            }
            .defaultScrollAnchorTop()
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(Color.zBg)
        // 右上角關閉（Esc 也可以）
        .overlay(alignment: .topTrailing) {
            Button(action: onClose) {
                Image(systemName: "xmark").font(.system(size: 13, weight: .semibold)).foregroundStyle(Color.zText2)
                    .frame(width: 30, height: 30)
                    .background(Circle().fill(Color.zHover.opacity(0.001)))
                    .contentShape(Circle())
            }
            .buttonStyle(PressStyle())
            .keyboardShortcut(.cancelAction)
            .help("關閉（Esc）")
            .padding(14)
        }
        .onChange(of: query) { _ in matches = [:] }
    }

    /// 左欄：搜尋＋分組分類
    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 1) {
            HStack(spacing: 6) {
                TextField("搜尋設定", text: $query).focused($searchFocused)
                ZClearButton(text: $query)
            }
            .zInput(.small, style: .filled, icon: "magnifyingglass")
            .padding(.bottom, 6)

            ForEach(Section.groups, id: \.0) { group in
                Text(group.0).zText(.footnote).foregroundStyle(Color.zText3)
                    .padding(.horizontal, 10).padding(.top, 14).padding(.bottom, 4)
                ForEach(group.1) { s in
                    let on = section == s && !searching && doc == nil
                    Button { withAnimation(Motion.snap) { query = ""; section = s; doc = nil } } label: {
                        HStack(spacing: 9) {
                            Image(systemName: s.icon).font(Font.zIcon).foregroundStyle(on ? Color.zText : Color.zText2).frame(width: 16)
                            Text(s.rawValue).zText(on ? .calloutStrong : .callout).foregroundStyle(Color.zText)
                            Spacer()
                        }
                        .padding(.horizontal, 10)
                        .frame(height: 32)
                        .background(RoundedRectangle(cornerRadius: 8).fill(on ? Color.zSel : Color.clear))
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(PressStyle())
                }
            }
            Spacer()
        }
        .padding(14)
        .frame(width: 214)
    }

    /// 一段設定：段落標題＋內容。搜尋時沒有符合的列就整段藏起來；打到段落或分類名稱就整段顯示
    private func partBox(_ p: Part, in sec: Section) -> some View {
        let partMatch = searching && (p.title.localizedCaseInsensitiveContains(q) || sec.rawValue.localizedCaseInsensitiveContains(q))
        let show = !searching || partMatch || (matches[p] ?? 0) > 0
        return VStack(alignment: .leading, spacing: 0) {
            if show {
                HStack(spacing: 6) {
                    if searching && sec.rawValue != p.title {
                        Text(sec.rawValue).zText(.title3).foregroundStyle(Color.zText3)
                        Image(systemName: "chevron.right").font(.system(size: 10, weight: .semibold)).foregroundStyle(Color.zText3)
                    }
                    Text(p.title).zText(.title3).foregroundStyle(Color.zText)
                }
                .padding(.bottom, 6)
            }
            part(p)
        }
        .environment(\.settingsFilter, SettingsFilter(query: searching ? q : "", partMatch: partMatch))
        .onPreferenceChange(SettingRowMatch.self) { n in if matches[p] != n { matches[p] = n } }
        .padding(.bottom, show ? 34 : 0)
    }

    @ViewBuilder
    private func part(_ p: Part) -> some View {
        let s = $store.settings
        switch p {
        case .profile:
            row("頭貼", "顯示在左下角與你的命盤；上傳後可裁切，會自動壓縮") {
                AvatarField(name: Binding(get: { store.userAvatar }, set: { store.userAvatar = $0 }))
            }
            row("名字", "顯示在左下角，也是你自己命盤的名字") {
                TextField("你的名字", text: $nameDraft)
                    .zInput()
                    .onAppear { nameDraft = store.userName }
                    .onSubmit(saveName)
            }
            .onDisappear(perform: saveName)
            if let me = store.me {
                row("我的命盤", "\(me.gender.rawValue) · \(me.clock ?? me.solar)\(me.place.map { " · " + $0.name } ?? "")") {
                    HStack(spacing: 8) {
                        Spacer()
                        Button("查看") { NotificationCenter.default.post(name: .openSelf, object: nil) }
                            .buttonStyle(ZSecondaryButton(small: true))
                        Button("編輯生辰與出生地") { NotificationCenter.default.post(name: .editChart, object: me.id) }
                            .buttonStyle(ZPrimaryButton(small: true))
                    }
                }
            } else {
                row("我的命盤", "填入自己的生辰八字與出生地，側欄會出現「我」可以直接點開") {
                    HStack { Spacer(); Button("填寫我的生辰") { NotificationCenter.default.post(name: .newSelfChart, object: nil) }
                        .buttonStyle(ZPrimaryButton(small: true)) }
                }
            }
            toggle("在側欄顯示我的命盤", "關閉後側欄不會出現「我」", $store.showSelfInSidebar, last: true)
        case .account:
            note("登入後，命盤、備註、照片、頭貼和設定都會存在你的帳號，換電腦或之後用手機版登入同一個帳號就能看到。")
            row("目前狀態", "尚未登入，資料只存在這台 Mac") {
                HStack { Spacer(); Label("本機", systemImage: "laptopcomputer").font(Font.zCallout).foregroundStyle(Color.zText2) }
            }
            row("使用 Apple 登入", "Sign in with Apple") {
                HStack { Spacer(); Button { Toast.show("雲端同步還在準備中，資料目前存在本機") } label: { Label("使用 Apple 登入", systemImage: "apple.logo") }
                    .buttonStyle(ZSecondaryButton(small: true)) }
            }
            row("使用 Google 登入", "Google 帳號", last: true) {
                HStack { Spacer(); Button { Toast.show("雲端同步還在準備中，資料目前存在本機") } label: { Label("使用 Google 登入", systemImage: "g.circle") }
                    .buttonStyle(ZSecondaryButton(small: true)) }
            }
            note("雲端同步還在準備中：登入按鈕先放好，資料目前都存在本機，不會遺失。")
        case .chart:
            row("安星派別", "影響部分雜曜與流曜的安法") {
                SettingSegment(options: [(.standard, "斗數全書"), (.zhongzhou, "中州派")], selection: s.algorithm)
            }
            row("年分界", "流年從哪一天開始算") {
                SettingSegment(options: [(.normal, "正月初一"), (.exact, "立春")], selection: s.yearDivide)
            }
            row("晚子時", "23:00–24:00 出生的日柱") {
                SettingSegment(options: [(.forward, "視為次日"), (.current, "視為當日")], selection: s.dayDivide)
            }
            row("辛年天魁天鉞", "年干（或大限、流年的干）是辛時，天魁、天鉞放哪兩宮；文墨天機是魁寅鉞午") {
                SettingSegment(options: [("寅午", "魁寅鉞午"), ("午寅", "魁午鉞寅")], selection: s.xinKuiYueMode)
            }
            row("閏月", "本命盤遇到閏月時", last: true) {
                SettingSegment(options: [(true, "月中分界"), (false, "視為本月")], selection: s.leapSplit)
            }
        case .mutagen:
            note("各派四化有差異的天干。會同時影響生年四化與宮干飛化。")
            row("庚干", "庚：太陽化祿、武曲化權…") { SettingMenu(options: Array(ZSettings.gengOptions.keys).sorted(), selection: s.geng) }
            row("辛干", "辛：巨門化祿、太陽化權…") { SettingMenu(options: Array(ZSettings.xinOptions.keys).sorted(), selection: s.xin) }
            row("壬干", "壬：天梁化祿、紫微化權…") { SettingMenu(options: Array(ZSettings.renOptions.keys).sorted(), selection: s.ren) }
            row("癸干", "癸：破軍化祿、巨門化權…", last: true) { SettingMenu(options: Array(ZSettings.guiOptions.keys).sorted(), selection: s.gui) }
        case .stars:
            toggle("顯示雜曜", "天姚、紅鸞等小星", s.showAdj)
            toggle("顯示神煞", "博士、將前、歲前十二神", s.showShensha)
            toggle("顯示長生十二神", "長生、沐浴、冠帶…養，寫在每宮天干地支上面", s.showChangsheng)
            toggle("星曜說明照目前運限", "選到大限、流年、流月…時，滑鼠停在星曜上的說明用那一層的宮位（例：落大官祿）；關掉則一律用本命宮位", s.hoverByScope)
            toggle("夾宮提示", "選到被左右兩宮夾住的宮位時（左右夾、羊陀夾、雙忌夾…），兩道線會夾進來；滑鼠停在線上看說明", s.showClamp)
            toggle("夾宮四化照目前運限", "選到大限、流年…時，那一層的四化也一起算（例：生年祿＋大限祿＝雙祿夾）；關掉只看生年四化", s.clampByScope)
            toggle("顯示流曜", "選到大限、流年時，宮內加上大祿、大羊、年鸞、年喜…這些流曜", s.showFlowStars, last: true)
            Text("星曜顏色").zText(.calloutStrong).foregroundStyle(Color.zText).padding(.top, 18).hiddenWhenSearching()
            note("盤面上四類星曜各用一種顏色，一眼分出主星、輔星、凶星、雜曜。")
            ForEach(ZW.StarClass.allCases, id: \.self) { c in
                row(c.label, c.members, last: c == .misc) {
                    HStack(spacing: 10) {
                        Spacer()
                        Text(c == .major ? "紫微" : c == .aux ? "右弼" : c == .tough ? "擎羊" : "紅鸞")
                            .font(ChartType.font(15, .medium)).foregroundStyle(store.settings.tone(c).color)
                        Text(store.settings.tone(c).label).font(Font.zCallout).foregroundStyle(Color.zText3)
                    }
                }
            }
        case .periods:
            note("四化最多顯示最近三層：選到流年＝生年、大限、流年；流月＝大限、流年、流月；流時＝流月、流日、流時。有流年時另加小限。")
            toggle("打開命盤時預設顯示大限", "開啟後打開命盤會停在目前大限並選到大命；關閉則顯示本命", s.openWithDecade)
            toggle("小限疊盤", "選流年時，盤上一起疊小限宮名與小限四化（預設關閉；運限表的流年那一列一樣會標出小限宮）", s.showMinorOverlay)
            toggle("顯示小限四化", "小限疊盤時，星曜下的青色四化方塊；關掉只留小限宮名", s.showMinorMutagen)
            toggle("顯示流年／小限歲數", "每宮的流年與小限虛歲", s.showAgeLines, last: true)
        case .display:
            toggle("顯示身宮", "身宮標記", s.showBody)
            toggle("顯示來因宮", "生年天干所在的宮位", s.showLaiyin)
            toggle("三方四正指示線", "點宮位時在中宮畫連線", s.showSanfang)
            toggle("自化箭頭", "星曜旁的彩色箭頭：↑ 離心自化、↓ 向心自化", s.showSelf)
            toggle("轉宮宮名", "點選宮位時，各宮顯示「X之Y」（例：福之夫）", s.showTransfer)
            toggle("顯示地理方位", "每宮右上角的方位（南、東南…）", s.showCompass)
            toggle("顯示 AI 對話框", "命盤下方的提問框；AI 解盤未來推出", s.showComposer, last: true)
        case .panel:
            note("看盤時右邊要顯示哪些卡片。")
            let cards = ZSettings.PanelCard.allCases.filter { $0 != .notes || StarNotes.enabled }
            ForEach(cards, id: \.self) { c in
                toggle(c.title, c.detail, Binding(
                    get: { store.settings.showsPanel(c) },
                    set: { on in
                        store.settings.hiddenPanels.removeAll { $0 == c.rawValue }
                        if !on { store.settings.hiddenPanels.append(c.rawValue) }
                    }), last: c == cards.last)
            }
        case .feel:
            toggle("介面動畫", "電腦較慢或覺得卡時可關閉，所有轉場改為瞬間切換", s.motion)
            toggle("觸控板回饋", "點宮位、點運限時觸控板輕微震動", s.haptics)
            toggle("介面音效", "點宮位、點運限時播放", s.sound)
            Group {
                row("音色", "來自 uisfx.com（CC0）") {
                    SettingMenu(options: Sound.styles.map(\.name),
                               selection: Binding(get: { Sound.styles.first { $0.id == store.settings.soundStyle }?.name ?? "" },
                                                  set: { n in if let id = Sound.styles.first(where: { $0.name == n })?.id { store.settings.soundStyle = id; Sound.tap(store.settings, .palace) } }))
                }
                ForEach(Sound.Event.allCases, id: \.self) { e in
                    row(e.label, "這個操作的音效") {
                        HStack(spacing: 8) {
                            Spacer()
                            SettingMenu(options: Sound.cues.map(\.name), selection: cueBinding(e))
                            Button { Sound.tap(store.settings, e) } label: {
                                Image(systemName: "play.fill").font(Font.zIcon).frame(width: 28, height: 28)
                                    .background(RoundedRectangle(cornerRadius: 7).fill(Color.zHover))
                            }
                            .buttonStyle(PressStyle())
                            .help("試聽")
                        }
                    }
                }
                row("音量", "", last: true) {
                    Slider(value: s.volume, in: 0.1...1) { editing in
                        if !editing { Sound.tap(store.settings, .palace) }
                    }
                }
            }
            .disabled(!store.settings.sound).opacity(store.settings.sound ? 1 : 0.4)
        case .appearance:
            row("主題", "跟隨系統、淺色或深色") {
                SettingIconSegment(options: [(.system, "desktopcomputer", "跟隨系統"), (.light, "sun.max", "淺色"), (.dark, "moon", "深色")],
                                   selection: store.appearanceWithTransition)
            }
            row("分組選擇方式", "新增命盤時怎麼選分組：下拉選單，或左右滑的刻度尺", last: true) {
                SettingSegment(options: [(.menu, "下拉選單"), (.dial, "刻度尺")], selection: s.groupPicker)
            }
        case .data:
            note("命盤、備註、照片和設定都存在這台 Mac（不在 App 本身裡面），所以刪掉或重新安裝 App 資料都還在。換電腦或想保險時，可以先備份成一個檔案。")
            if AppInfo.isBeta {
                note("這是測試版，資料和正式版分開存放。想用真實命盤測試：先在正式版「備份」，再到這裡「還原」。")
            }
            row("備份", "把所有命盤、照片、個人檔案與設定存成一個 .stilllink 檔") {
                HStack { Spacer(); Button { store.exportBackup() } label: { Label("備份…", systemImage: "square.and.arrow.down") }
                    .buttonStyle(ZSecondaryButton(small: true)) }
            }
            row("還原", "從備份檔放回來（會取代目前所有資料）") {
                HStack { Spacer(); Button { store.importBackup() } label: { Label("還原…", systemImage: "arrow.counterclockwise") }
                    .buttonStyle(ZSecondaryButton(small: true)) }
            }
            row("清空所有資料", "刪掉全部命盤、照片、個人檔案與設定，回到第一次打開的樣子", last: true) {
                HStack { Spacer(); Button(role: .destructive) { confirmErase = true } label: { Label("清空…", systemImage: "trash") }
                    .buttonStyle(ZSecondaryButton(small: true)) }
            }
            Color.clear.frame(height: 0)
                .alert("要清空所有資料嗎？", isPresented: $confirmErase) {
                    Button("取消", role: .cancel) {}
                    Button("先備份再清空") {
                        store.exportBackup()
                        store.eraseAll(); Toast.show("已清空")
                    }
                    Button("直接清空", role: .destructive) { store.eraseAll(); Toast.show("已清空") }
                } message: {
                    Text("全部 \(store.people.count) 張命盤、照片、個人檔案與設定都會刪除，無法復原。")
                }
        case .about:
            HStack(spacing: 14) {
                Image(nsImage: NSApp.applicationIconImage).resizable().frame(width: 64, height: 64)
                VStack(alignment: .leading, spacing: 3) {
                    Text(AppInfo.name).font(Font.zTitle).foregroundStyle(Color.zText)
                    Text("版本 \(AppInfo.displayVersion)")
                        .font(Font.zCallout).foregroundStyle(Color.zText2)
                }
            }
            .padding(.bottom, 14)
            .hiddenWhenSearching()
            row("檢查更新", updateNote) {
                HStack(spacing: 8) {
                    Spacer()
                    if updater.isAvailable {
                        Button { updater.install() } label: { Label("立即更新", systemImage: "arrow.down.circle") }
                            .buttonStyle(ZPrimaryButton(small: true))
                    }
                    if updater.state == .readyToRelaunch {
                        Button { updater.relaunchNow() } label: { Label("重新開啟", systemImage: "arrow.clockwise.circle") }
                            .buttonStyle(ZPrimaryButton(small: true))
                    }
                    Button { updater.checkNow() } label: {
                        if updater.state == .checking { ProgressView().controlSize(.small).frame(width: 60) } else { Text("檢查更新") }
                    }
                    .buttonStyle(ZSecondaryButton(small: true))
                    .disabled(updater.state == .checking || updater.isBusy)
                }
            }
            row("製作", "設計與開發") {
                HStack { Spacer(); Text("Jean").font(Font.zBody).foregroundStyle(Color.zText) }
            }
            row("問題與建議", "使用上遇到問題、想要的功能") { contactLink("support@jeanui.com") }
            row("合作與其他", "合作邀約、其他聯絡") { contactLink("hi@jeanui.com") }
            row("排盤計算", "開源紫微斗數引擎") {
                HStack { Spacer(); Text("iztro（MIT License）").font(Font.zCallout).foregroundStyle(Color.zText2) }
            }
            row("隱私權政策", "資料只存在你的 Mac，不會上傳") { legalButton(.privacy) }
            row("使用條款", "使用 StillLink 前請先閱讀") { legalButton(.terms) }
            row("刪除資料", "如何清空或完整移除 App 與資料", last: true) { legalButton(.delete) }
        }
    }

    /// 檢查更新那一列的說明文字
    /// 聯絡信箱：點了用預設郵件 App 開新信；地址本身可以選取複製
    private func contactLink(_ address: String) -> some View {
        HStack(spacing: 8) {
            Spacer()
            Text(address).font(Font.zCallout).foregroundStyle(Color.zText2).textSelection(.enabled)
            Button { if let url = URL(string: "mailto:\(address)") { NSWorkspace.shared.open(url) } } label: {
                Label("寫信", systemImage: "envelope")
            }
            .buttonStyle(ZSecondaryButton(small: true))
        }
    }

    private var updateNote: String {
        switch updater.state {
        case .idle: "打開 App 時會自動檢查；有新版本時，工具列會出現「更新」按鈕"
        case .checking: "檢查中…"
        case .upToDate: "已經是最新版本"
        case .available(let v): "有新版本：\(v)"
        case .downloading(let p): p.map { "下載中 \(Int($0 * 100))%" } ?? "下載中…"
        case .installing: "安裝中，完成後會自動重新打開"
        case .readyToRelaunch: "更新已下載好，重新開啟就會換成新版本"
        case .failed(let why): "無法檢查：\(why)"
        }
    }

    /// 「關於」裡的說明列：點了在右邊直接顯示文字
    private func legalButton(_ d: LegalDoc) -> some View {
        HStack {
            Spacer()
            Button("查看") { withAnimation(Motion.snap) { doc = d } }
                .buttonStyle(ZSecondaryButton(small: true))
        }
    }

    /// 說明頁：簡單的標題＋段落
    private func legalPage(_ d: LegalDoc) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Button { withAnimation(Motion.snap) { doc = nil } } label: {
                Label("關於", systemImage: "chevron.left").font(Font.zCallout).foregroundStyle(Color.zText2)
            }
            .buttonStyle(.plain)
            .padding(.bottom, 12)
            title(d.rawValue)
            Text(LegalDoc.updated).font(Font.zCaption).foregroundStyle(Color.zText3).padding(.bottom, 14)
            Text(d.summary).font(Font.zBody).foregroundStyle(Color.zText)
                .fixedSize(horizontal: false, vertical: true).padding(.bottom, 20)
            ForEach(Array(d.sections.enumerated()), id: \.offset) { _, s in
                Text(s.0).font(Font.zBodyStrong).foregroundStyle(Color.zText).padding(.bottom, 4)
                Text(s.1).font(Font.zBody).foregroundStyle(Color.zText2).lineSpacing(3)
                    .fixedSize(horizontal: false, vertical: true)
                    .textSelection(.enabled)
                    .padding(.bottom, 18)
            }
            Text(LegalDoc.contact).font(Font.zCallout).foregroundStyle(Color.zText3)
                .fixedSize(horizontal: false, vertical: true)
                .textSelection(.enabled)
        }
    }

    // MARK: 版面元件（同新增命盤頁）

    /// 說明頁的標題
    private func title(_ t: String) -> some View {
        Text(t).zText(.title3).foregroundStyle(Color.zText).padding(.bottom, 6)
    }

    private func note(_ t: String) -> some View {
        SettingNote(text: t)
    }

    private func row<C: View>(_ t: String, _ n: String, last: Bool = false, @ViewBuilder _ control: () -> C) -> some View {
        SettingRow(title: t, note: n, last: last, control: control())
    }

    private func saveName() {
        let t = nameDraft.trimmingCharacters(in: .whitespaces)
        if !t.isEmpty && t != store.userName { store.renameUser(t); Toast.show("已改名為「\(t)」") }
    }

    private func cueBinding(_ e: Sound.Event) -> Binding<String> {
        Binding(get: { let id = store.settings.cues[e.rawValue] ?? e.defaultCue
                       return Sound.cues.first { $0.id == id }?.name ?? "" },
                set: { n in if let id = Sound.cues.first(where: { $0.name == n })?.id {
                    store.settings.cues[e.rawValue] = id
                    Sound.tap(store.settings, e)
                } })
    }

    private func toggle(_ t: String, _ n: String, _ b: Binding<Bool>, last: Bool = false) -> some View {
        row(t, n, last: last) {
            HStack { Spacer(); Toggle("", isOn: b).toggleStyle(.switch).labelsHidden() }
        }
    }
}

// MARK: - 設定列元件（跟著搜尋過濾）

/// 搜尋條件：往下傳給每一列
struct SettingsFilter: Equatable {
    var query = ""
    var partMatch = false      // 打到的是段落或分類名稱：整段都顯示
    func shows(_ texts: String...) -> Bool {
        query.isEmpty || partMatch || texts.contains { $0.localizedCaseInsensitiveContains(query) }
    }
}

private struct SettingsFilterKey: EnvironmentKey { static let defaultValue = SettingsFilter() }
extension EnvironmentValues {
    var settingsFilter: SettingsFilter {
        get { self[SettingsFilterKey.self] }
        set { self[SettingsFilterKey.self] = newValue }
    }
}

/// 每一段裡顯示了幾列（段落標題要不要出現）
struct SettingRowMatch: PreferenceKey {
    static let defaultValue = 0
    static func reduce(value: inout Int, nextValue: () -> Int) { value += nextValue() }
}

/// 一列設定：左邊標題＋說明，右邊控制項（靠右、寬度跟著內容）
struct SettingRow<C: View>: View {
    let title: String
    let note: String
    var last = false
    let control: C
    @Environment(\.settingsFilter) private var filter

    var body: some View {
        if filter.shows(title, note) {
            HStack(alignment: .center, spacing: 24) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(title).zText(.callout).foregroundStyle(Color.zText)
                    if !note.isEmpty {
                        Text(note).zText(.subheadline).foregroundStyle(Color.zText3)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                control.frame(maxWidth: 300, alignment: .trailing)
            }
            .padding(.vertical, 13)
            .overlay(alignment: .bottom) { if !last { Rectangle().fill(Color.zLine).frame(height: 0.5) } }
            .preference(key: SettingRowMatch.self, value: 1)
        }
    }
}

/// 段落說明：搜尋時藏起來（除非整段符合）
struct SettingNote: View {
    let text: String
    @Environment(\.settingsFilter) private var filter
    var body: some View {
        if filter.query.isEmpty || filter.partMatch {
            Text(text).zText(.subheadline).foregroundStyle(Color.zText3)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.bottom, 6)
        }
    }
}

private struct HiddenWhenSearching: ViewModifier {
    @Environment(\.settingsFilter) private var filter
    func body(content: Content) -> some View {
        if filter.query.isEmpty || filter.partMatch { content }
    }
}
extension View {
    /// 搜尋時藏起來（段落裡的小標題、裝飾）
    func hiddenWhenSearching() -> some View { modifier(HiddenWhenSearching()) }
}

/// 分段選擇（設定用）：寬度貼合文字，選中的那格浮起來
struct SettingSegment<T: Hashable>: View {
    let options: [(T, String)]
    @Binding var selection: T
    @Namespace private var ns

    var body: some View {
        HStack(spacing: 2) {
            ForEach(options, id: \.0) { value, label in
                let on = value == selection
                Button { withAnimation(Motion.snap) { selection = value } } label: {
                    Text(label)
                        .zText(on ? .subheadlineStrong : .subheadline)
                        .foregroundStyle(on ? Color.zText : Color.zText2)
                        .padding(.horizontal, 12)
                        .frame(height: 28)
                        .background {
                            if on {
                                RoundedRectangle(cornerRadius: 6).fill(Color.zRaised)
                                    .shadow(color: Color.zShadow, radius: 2, y: 1)
                                    .matchedGeometryEffect(id: "pill", in: ns)
                            }
                        }
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(3)
        .background(RoundedRectangle(cornerRadius: 8).fill(Color.zHover))
        .fixedSize()
    }
}

/// 圖示分段（主題：系統／淺色／深色）
struct SettingIconSegment<T: Hashable>: View {
    let options: [(T, String, String)]   // 值、SF Symbol、說明
    @Binding var selection: T
    @Namespace private var ns

    var body: some View {
        HStack(spacing: 2) {
            ForEach(options, id: \.0) { value, icon, help in
                let on = value == selection
                Button { withAnimation(Motion.snap) { selection = value } } label: {
                    Image(systemName: icon)
                        .font(.system(size: 13, weight: on ? .semibold : .regular))
                        .foregroundStyle(on ? Color.zText : Color.zText3)
                        .frame(width: 32, height: 28)
                        .background {
                            if on {
                                RoundedRectangle(cornerRadius: 6).fill(Color.zRaised)
                                    .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.zAccent.opacity(0.6), lineWidth: 1))
                                    .matchedGeometryEffect(id: "pill", in: ns)
                            }
                        }
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .help(help)
            }
        }
        .padding(3)
        .background(RoundedRectangle(cornerRadius: 8).fill(Color.zHover))
        .fixedSize()
    }
}

/// 下拉選單（設定用）：右對齊的「值 ⌄」，不畫輸入框
struct SettingMenu: View {
    let options: [String]
    @Binding var selection: String

    var body: some View {
        Menu {
            ForEach(options, id: \.self) { o in Button(o) { selection = o } }
        } label: {
            HStack(spacing: 6) {
                Text(selection).zText(.callout).foregroundStyle(Color.zText)
                Image(systemName: "chevron.down").font(.system(size: 9, weight: .semibold)).foregroundStyle(Color.zText3)
            }
            .padding(.horizontal, 8)
            .frame(height: 28)
            .contentShape(Rectangle())
        }
        .menuStyle(.button)
        .buttonStyle(.plain)
        .menuIndicator(.hidden)
        .fixedSize()
    }
}
