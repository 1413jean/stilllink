import SwiftUI

/// 排盤與盤面：系統 Form。項目和文字跟 Mac 版設定窗一致，只放手機上有意義的
struct ChartSettingsView: View {
    @EnvironmentObject private var store: Store

    var body: some View {
        let s = $store.settings
        Form {
            Section {
                Picker("安星派別", selection: s.algorithm) {
                    Text("斗數全書").tag(ZSettings.Algorithm.standard)
                    Text("中州派").tag(ZSettings.Algorithm.zhongzhou)
                }
                Picker("年分界", selection: s.yearDivide) {
                    Text("正月初一").tag(ZSettings.YearDivide.normal)
                    Text("立春").tag(ZSettings.YearDivide.exact)
                }
                Picker("晚子時", selection: s.dayDivide) {
                    Text("視為次日").tag(ZSettings.DayDivide.forward)
                    Text("視為當日").tag(ZSettings.DayDivide.current)
                }
                Picker("辛年天魁天鉞", selection: s.xinKuiYueMode) {
                    Text("魁寅鉞午").tag("寅午")
                    Text("魁午鉞寅").tag("午寅")
                }
                Picker("閏月", selection: s.leapSplit) {
                    Text("月中分界").tag(true)
                    Text("視為本月").tag(false)
                }
            } header: {
                Text("排盤")
            } footer: {
                Text("文墨天機的預設是：斗數全書、正月初一、晚子時視為次日、魁寅鉞午")
            }

            Section {
                stemPicker("庚干", ZSettings.gengOptions, s.geng)
                stemPicker("辛干", ZSettings.xinOptions, s.xin)
                stemPicker("壬干", ZSettings.renOptions, s.ren)
                stemPicker("癸干", ZSettings.guiOptions, s.gui)
            } header: {
                Text("四化版本")
            } footer: {
                Text("各派四化有差異的天干。會同時影響生年四化與宮干飛化。")
            }

            Section("盤面") {
                Toggle("顯示雜曜", isOn: s.showAdj)
                Toggle("顯示神煞", isOn: s.showShensha)
                Toggle("顯示長生十二神", isOn: s.showChangsheng)
                Toggle("顯示流曜", isOn: s.showFlowStars)
                Toggle("顯示身宮", isOn: s.showBody)
                Toggle("顯示來因宮", isOn: s.showLaiyin)
                Toggle("三方四正指示線", isOn: s.showSanfang)
                Toggle("自化箭頭", isOn: s.showSelf)
                Toggle("轉宮宮名", isOn: s.showTransfer)
                Toggle("顯示地理方位", isOn: s.showCompass)
            }

            Section {
                Toggle("夾宮提示", isOn: s.showClamp)
                if store.settings.showClamp {
                    Picker("夾宮提示樣式", selection: s.clampStyle) {
                        Text("雙箭頭").tag(ZSettings.ClampStyle.arrows)
                        Text("框線").tag(ZSettings.ClampStyle.frame)
                    }
                    Toggle("夾宮四化照目前運限", isOn: s.clampByScope)
                }
            } header: {
                Text("夾宮")
            } footer: {
                Text("選到被左右兩宮夾住的宮位時（左右夾、羊陀夾、雙忌夾…），交界線上會出現提示")
            }

            Section("運限") {
                Toggle("打開命盤時預設顯示大限", isOn: s.openWithDecade)
                Toggle("小限疊盤", isOn: s.showMinorOverlay)
                if store.settings.showMinorOverlay { Toggle("顯示小限四化", isOn: s.showMinorMutagen) }
                Toggle("顯示流年／小限歲數", isOn: s.showAgeLines)
            }

            Section("動態與回饋") {
                Toggle("介面動畫", isOn: s.motion)
                Toggle("觸覺回饋", isOn: s.haptics)
                Toggle("介面音效", isOn: s.sound)
                if store.settings.sound {
                    Picker("音色", selection: s.soundStyle) {
                        ForEach(Sound.styles, id: \.id) { Text($0.name).tag($0.id) }
                    }
                    .onChange(of: store.settings.soundStyle) { _, v in Sound.play(v, "select", volume: store.settings.volume) }
                    HStack {
                        Image(systemName: "speaker.fill").foregroundStyle(Color.zText3)
                        Slider(value: s.volume, in: 0...1) { editing in
                            if !editing { Sound.play(store.settings.soundStyle, "select", volume: store.settings.volume) }
                        }
                        Image(systemName: "speaker.wave.3.fill").foregroundStyle(Color.zText3)
                    }
                }
            }

        }
        .navigationTitle("排盤與盤面")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func stemPicker(_ title: String, _ options: [String: [String]], _ sel: Binding<String>) -> some View {
        Picker(title, selection: sel) {
            ForEach(options.keys.sorted(), id: \.self) { Text($0).tag($0) }
        }
    }
}
