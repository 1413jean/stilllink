import SwiftUI

/// 設定頁（照 Claude 設定：左邊分類、右邊每列左標題說明＋右控制項）
struct SettingsPage: View {
    @EnvironmentObject var store: Store
    var onClose: () -> Void
    @State private var section: Section
    @State private var nameDraft = ""

    init(initial: Section = .profile, onClose: @escaping () -> Void) {
        self.onClose = onClose
        _section = State(initialValue: initial)
    }

    enum Section: String, CaseIterable, Identifiable {
        case profile = "個人檔案", account = "帳號與同步", chart = "排盤", mutagen = "四化", display = "盤面顯示", feel = "音效與動畫", appearance = "外觀", about = "關於"
        var id: String { rawValue }
        var icon: String {
            switch self {
            case .profile: "person.crop.circle"
            case .account: "icloud"
            case .chart: "square.grid.3x3"
            case .mutagen: "sparkle"
            case .display: "eye"
            case .feel: "speaker.wave.2"
            case .appearance: "circle.lefthalf.filled"
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
                    Button { withAnimation(Motion.snap) { section = s } } label: {
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
                    content
                }
                .frame(maxWidth: 720, alignment: .leading)
                .padding(.horizontal, 32)
                .padding(.top, 20)
                .padding(.bottom, 40)
                .id(section)
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
        case .display:
            title("盤面顯示")
            toggle("顯示雜曜", "天姚、紅鸞等小星", s.showAdj)
            toggle("顯示神煞", "博士、將前、歲前十二神", s.showGods)
            toggle("打開命盤時預設顯示大限", "開啟後打開命盤會停在目前大限並選到大命；關閉則顯示本命", s.openWithDecade)
            toggle("小限疊盤", "選流年時，一起疊上小限宮名與小限四化", s.showMinor)
            toggle("顯示小限四化", "小限疊盤時，星曜旁的青色四化方塊；關掉只留小限宮名", s.showMinorMutagen)
            toggle("顯示流年／小限歲數", "每宮的流年與小限虛歲", s.showAges)
            toggle("顯示身宮", "身宮標記", s.showBody)
            toggle("顯示來因宮", "生年天干所在的宮位", s.showLaiyin)
            toggle("三方四正指示線", "點宮位時在中宮畫連線", s.showSanfang)
            toggle("自化箭頭", "星曜旁的彩色箭頭：↑ 離心自化、↓ 向心自化", s.showSelf)
            toggle("轉宮宮名", "點選宮位時，各宮顯示「X之Y」（例：福之夫）", s.showTransfer)
            toggle("顯示地理方位", "盤面四周的方位文字", s.showCompass)
            toggle("顯示 AI 對話框", "命盤下方的提問框；AI 解盤未來推出", s.showComposer, last: true)
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
                ZSegmented(options: Appearance.allCases.map { ($0, $0.label) }, selection: $store.appearance)
            }
        case .about:
            title("關於")
            HStack(spacing: 14) {
                Image(nsImage: NSApp.applicationIconImage).resizable().frame(width: 64, height: 64)
                VStack(alignment: .leading, spacing: 3) {
                    Text("StillLink").font(Font.zTitle).foregroundStyle(Color.zText)
                    Text("版本 \(Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "")")
                        .font(Font.zCallout).foregroundStyle(Color.zText2)
                }
            }
            .padding(.bottom, 14)
            row("製作", "設計與開發") {
                HStack { Spacer(); Text("Jean").font(Font.zBody).foregroundStyle(Color.zText) }
            }
            row("排盤計算", "開源紫微斗數引擎", last: true) {
                HStack { Spacer(); Text("iztro（MIT License）").font(Font.zCallout).foregroundStyle(Color.zText2) }
            }
            note("Jean 是 UX/UI 設計師。原本常用的排盤軟體不能用了，就自己做了一個：盤面照傳統排法，看得清楚、操作簡單，方便幫人排盤、看盤。")
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
