import SwiftUI

/// 設定頁（照 Claude 設定：左邊分類、右邊每列左標題說明＋右控制項）
struct SettingsPage: View {
    @EnvironmentObject var store: Store
    var onClose: () -> Void
    @State private var section: Section
    @State private var doc: LegalDoc?        // 關於 → 隱私權政策／使用條款／刪除資料
    @State private var nameDraft = ""
    @State private var confirmErase = false
    @ObservedObject private var updater = AppUpdater.shared

    init(initial: Section = .profile, onClose: @escaping () -> Void) {
        self.onClose = onClose
        _section = State(initialValue: initial)
        // 驗證用：ZIWEI_LEGAL=privacy／terms／delete 直接打開說明頁
        if let v = ProcessInfo.processInfo.environment["ZIWEI_LEGAL"] {
            _doc = State(initialValue: LegalDoc.allCases.first { "\($0)" == v })
        }
    }

    enum Section: String, CaseIterable, Identifiable {
        case profile = "個人檔案", account = "帳號與同步", chart = "排盤", mutagen = "四化", stars = "星曜", periods = "運限", display = "盤面標記", panel = "右側面板", feel = "音效與動畫", appearance = "外觀", data = "資料", about = "關於"
        var id: String { rawValue }
        var icon: String {
            switch self {
            case .profile: "person.crop.circle"
            case .account: "icloud"
            case .chart: "square.grid.3x3"
            case .mutagen: "sparkle"
            case .stars: "sparkles"
            case .periods: "calendar"
            case .display: "eye"
            case .panel: "sidebar.right"
            case .feel: "speaker.wave.2"
            case .appearance: "circle.lefthalf.filled"
            case .data: "externaldrive"
            case .about: "info.circle"
            }
        }
    }

    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            VStack(alignment: .leading, spacing: 1) {
                Text("設定").font(Font.zCaption).foregroundStyle(Color.zText3)
                    .padding(.horizontal, 10).padding(.bottom, 6)
                ForEach(Section.allCases) { s in
                    Button { withAnimation(Motion.snap) { section = s; doc = nil } } label: {
                        HStack(spacing: 9) {
                            Image(systemName: s.icon).font(Font.zIcon).foregroundStyle(Color.zText2).frame(width: 16)
                            Text(s.rawValue).font(Font.zBody).foregroundStyle(Color.zText)
                            Spacer()
                        }
                        .padding(.horizontal, 10)
                        .frame(height: 32)
                        .background(RoundedRectangle(cornerRadius: 8).fill(section == s ? Color.zSel : Color.clear))
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(PressStyle())
                }
                Spacer()
            }
            .padding(.top, 20)
            .padding(.horizontal, 12)
            .frame(width: 210)

            Rectangle().fill(Color.zLine).frame(width: 0.5)

            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    if let doc { legalPage(doc) } else { content }
                }
                .frame(maxWidth: 720, alignment: .leading)
                .padding(.horizontal, 32)
                .padding(.top, 20)
                .padding(.bottom, 40)
                .id(doc?.id ?? section.rawValue)
                .transition(.opacity)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(Color.zBg)
        .navigationTitle("")
    }

    @ViewBuilder
    private var content: some View {
        let s = $store.settings
        switch section {
        case .profile:
            title("個人檔案")
            row("頭貼", "顯示在左下角與你的命盤；上傳後可裁切，會自動壓縮") {
                AvatarField(name: Binding(get: { store.userAvatar }, set: { store.userAvatar = $0 }))
            }
            row("名字", "顯示在左下角，也是你自己命盤的名字") {
                TextField("你的名字", text: $nameDraft)
                    .textFieldStyle(.plain)
                    .inputBox()
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
            title("帳號與同步")
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
            title("排盤")
            row("安星派別", "影響部分雜曜與流曜的安法") {
                ZSegmented(options: [(.standard, "斗數全書"), (.zhongzhou, "中州派")], selection: s.algorithm)
            }
            row("年分界", "流年從哪一天開始算") {
                ZSegmented(options: [(.normal, "正月初一"), (.exact, "立春")], selection: s.yearDivide)
            }
            row("晚子時", "23:00–24:00 出生的日柱") {
                ZSegmented(options: [(.forward, "視為次日"), (.current, "視為當日")], selection: s.dayDivide)
            }
            row("閏月", "本命盤遇到閏月時", last: true) {
                ZSegmented(options: [(true, "月中分界"), (false, "視為本月")], selection: s.leapSplit)
            }
        case .mutagen:
            title("四化版本")
            note("各派四化有差異的天干。會同時影響生年四化與宮干飛化。")
            row("庚干", "庚：太陽化祿、武曲化權…") { ZMenuField(options: Array(ZSettings.gengOptions.keys).sorted(), selection: s.geng) }
            row("辛干", "辛：巨門化祿、太陽化權…") { ZMenuField(options: Array(ZSettings.xinOptions.keys).sorted(), selection: s.xin) }
            row("壬干", "壬：天梁化祿、紫微化權…") { ZMenuField(options: Array(ZSettings.renOptions.keys).sorted(), selection: s.ren) }
            row("癸干", "癸：破軍化祿、巨門化權…", last: true) { ZMenuField(options: Array(ZSettings.guiOptions.keys).sorted(), selection: s.gui) }
        case .stars:
            title("星曜")
            toggle("顯示雜曜", "天姚、紅鸞等小星", s.showAdj)
            toggle("顯示神煞", "博士、將前、歲前十二神", s.showShensha)
            toggle("顯示長生十二神", "長生、沐浴、冠帶…養，寫在每宮天干地支上面", s.showChangsheng)
            toggle("顯示流曜", "選到大限、流年時，宮內加上大祿、大羊、年鸞、年喜…這些流曜", s.showFlowStars, last: true)
            Text("星曜顏色").font(Font.zBodyStrong).foregroundStyle(Color.zText).padding(.top, 18)
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
            title("運限")
            note("四化最多顯示最近三層：選到流年＝生年、大限、流年；流月＝大限、流年、流月；流時＝流月、流日、流時。有流年時另加小限。")
            toggle("打開命盤時預設顯示大限", "開啟後打開命盤會停在目前大限並選到大命；關閉則顯示本命", s.openWithDecade)
            toggle("小限疊盤", "選流年時，盤上一起疊小限宮名與小限四化（預設關閉；運限表的流年那一列一樣會標出小限宮）", s.showMinorOverlay)
            toggle("顯示小限四化", "小限疊盤時，星曜下的青色四化方塊；關掉只留小限宮名", s.showMinorMutagen)
            toggle("顯示流年／小限歲數", "每宮的流年與小限虛歲", s.showAgeLines, last: true)
        case .display:
            title("盤面標記")
            toggle("顯示身宮", "身宮標記", s.showBody)
            toggle("顯示來因宮", "生年天干所在的宮位", s.showLaiyin)
            toggle("三方四正指示線", "點宮位時在中宮畫連線", s.showSanfang)
            toggle("自化箭頭", "星曜旁的彩色箭頭：↑ 離心自化、↓ 向心自化", s.showSelf)
            toggle("轉宮宮名", "點選宮位時，各宮顯示「X之Y」（例：福之夫）", s.showTransfer)
            toggle("顯示地理方位", "每宮右上角的方位（南、東南…）", s.showCompass)
            toggle("顯示 AI 對話框", "命盤下方的提問框；AI 解盤未來推出", s.showComposer, last: true)
        case .panel:
            title("右側面板")
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
            title("音效與動畫")
            toggle("介面動畫", "電腦較慢或覺得卡時可關閉，所有轉場改為瞬間切換", s.motion)
            toggle("觸控板回饋", "點宮位、點運限時觸控板輕微震動", s.haptics)
            toggle("介面音效", "點宮位、點運限時播放", s.sound)
            Group {
                row("音色", "來自 uisfx.com（CC0）") {
                    ZMenuField(options: Sound.styles.map(\.name),
                               selection: Binding(get: { Sound.styles.first { $0.id == store.settings.soundStyle }?.name ?? "" },
                                                  set: { n in if let id = Sound.styles.first(where: { $0.name == n })?.id { store.settings.soundStyle = id; Sound.tap(store.settings, .palace) } }))
                }
                ForEach(Sound.Event.allCases, id: \.self) { e in
                    row(e.label, "這個操作的音效") {
                        HStack(spacing: 8) {
                            ZMenuField(options: Sound.cues.map(\.name), selection: cueBinding(e))
                            Button { Sound.tap(store.settings, e) } label: {
                                Image(systemName: "play.fill").font(Font.zIcon).frame(width: 38, height: 38)
                                    .background(RoundedRectangle(cornerRadius: 9).fill(Color.zHover))
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
            title("外觀")
            row("主題", "淺色、深色或跟隨系統", last: true) {
                ZSegmented(options: Appearance.allCases.map { ($0, $0.label) }, selection: store.appearanceWithTransition)
            }
        case .data:
            title("資料")
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
            title("關於")
            HStack(spacing: 14) {
                Image(nsImage: NSApp.applicationIconImage).resizable().frame(width: 64, height: 64)
                VStack(alignment: .leading, spacing: 3) {
                    Text(AppInfo.name).font(Font.zTitle).foregroundStyle(Color.zText)
                    Text("版本 \(AppInfo.displayVersion)")
                        .font(Font.zCallout).foregroundStyle(Color.zText2)
                }
            }
            .padding(.bottom, 14)
            row("檢查更新", updateNote) {
                HStack(spacing: 8) {
                    Spacer()
                    if updater.isAvailable {
                        Button { updater.install() } label: { Label("立即更新", systemImage: "arrow.down.circle") }
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
            row("排盤計算", "開源紫微斗數引擎") {
                HStack { Spacer(); Text("iztro（MIT License）").font(Font.zCallout).foregroundStyle(Color.zText2) }
            }
            row("隱私權政策", "資料只存在你的 Mac，不會上傳") { legalButton(.privacy) }
            row("使用條款", "使用 StillLink 前請先閱讀") { legalButton(.terms) }
            row("刪除資料", "如何清空或完整移除 App 與資料", last: true) { legalButton(.delete) }
        }
    }

    /// 檢查更新那一列的說明文字
    private var updateNote: String {
        switch updater.state {
        case .idle: "有新版本時，工具列會出現「更新」按鈕"
        case .checking: "檢查中…"
        case .upToDate: "已經是最新版本"
        case .available(let v): "有新版本：\(v)"
        case .downloading(let p): p.map { "下載中 \(Int($0 * 100))%" } ?? "下載中…"
        case .installing: "安裝中，完成後會自動重新打開"
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

    private func title(_ t: String) -> some View {
        Text(t).font(Font.zTitle).foregroundStyle(Color.zText).padding(.bottom, 8)
    }

    private func note(_ t: String) -> some View {
        Text(t).font(Font.zCallout).foregroundStyle(Color.zText3).padding(.bottom, 6)
    }

    private func row<C: View>(_ t: String, _ n: String, last: Bool = false, @ViewBuilder _ control: () -> C) -> some View {
        HStack(alignment: .center, spacing: 24) {
            VStack(alignment: .leading, spacing: 3) {
                Text(t).font(Font.zBody).foregroundStyle(Color.zText)
                if !n.isEmpty { Text(n).font(Font.zCallout).foregroundStyle(Color.zText3) }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            control().frame(width: 300)
        }
        .padding(.vertical, 12)
        .overlay(alignment: .bottom) { if !last { Rectangle().fill(Color.zLine).frame(height: 0.5) } }
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
