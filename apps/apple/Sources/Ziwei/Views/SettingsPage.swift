import SwiftUI

/// 設定頁（照 Claude 設定：左邊分類、右邊每列左標題說明＋右控制項）
struct SettingsPage: View {
    @EnvironmentObject var store: Store
    var onClose: () -> Void
    @State private var section: Section = .chart

    enum Section: String, CaseIterable, Identifiable {
        case chart = "排盤", mutagen = "四化", display = "盤面顯示", feel = "音效與動畫", appearance = "外觀"
        var id: String { rawValue }
        var icon: String {
            switch self {
            case .chart: "square.grid.3x3"
            case .mutagen: "sparkle"
            case .display: "eye"
            case .feel: "speaker.wave.2"
            case .appearance: "circle.lefthalf.filled"
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
            toggle("小限疊盤", "選流年時，一起疊上小限宮名與小限四化", s.showMinor)
            toggle("顯示流年／小限歲數", "每宮的流年與小限虛歲", s.showAges)
            toggle("顯示身宮", "身宮標記", s.showBody)
            toggle("顯示來因宮", "生年天干所在的宮位", s.showLaiyin)
            toggle("三方四正指示線", "點宮位時在中宮畫連線", s.showSanfang)
            toggle("自化標記", "宮位右上角 ↑離心／↓向心", s.showSelf)
            toggle("顯示地理方位", "盤面四周的方位文字", s.showCompass, last: true)
        case .feel:
            title("音效與動畫")
            toggle("介面動畫", "關閉後所有轉場改為瞬間切換", s.motion)
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
