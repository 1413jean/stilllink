import SwiftUI

/// 排盤規則：影響每一張盤的計算（改了全部重算），放在「我的 → 偏好」
/// 項目和文字跟 Mac 版設定窗一致
struct RulesSettingsView: View {
    @EnvironmentObject private var store: Store

    var body: some View {
        let s = $store.settings
        ZForm {
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
        }
        .navigationTitle("排盤規則")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func stemPicker(_ title: String, _ options: [String: [String]], _ sel: Binding<String>) -> some View {
        Picker(title, selection: sel) {
            ForEach(options.keys.sorted(), id: \.self) { Text($0).tag($0) }
        }
    }
}

/// 盤面顯示：看盤時會想隨手開關的，命盤右上角的設定直接打開這一頁；「我的」也進得來
struct DisplaySettingsView: View {
    @EnvironmentObject private var store: Store
    /// 從命盤打開時，最下面放一個「排盤規則」入口
    var showRulesLink = false

    var body: some View {
        let s = $store.settings
        ZForm {
            Section("盤面") {
                Toggle("顯示雜曜", isOn: s.showAdj).zSwitch()
                Toggle("顯示神煞", isOn: s.showShensha).zSwitch()
                Toggle("顯示長生十二神", isOn: s.showChangsheng).zSwitch()
                Toggle("顯示流曜", isOn: s.showFlowStars).zSwitch()
                Toggle("顯示身宮", isOn: s.showBody).zSwitch()
                Toggle("顯示來因宮", isOn: s.showLaiyin).zSwitch()
                Toggle("三方四正指示線", isOn: s.showSanfang).zSwitch()
                Toggle("自化箭頭", isOn: s.showSelf).zSwitch()
                Toggle("轉宮宮名", isOn: s.showTransfer).zSwitch()
                Toggle("顯示地理方位", isOn: s.showCompass).zSwitch()
            }

            Section {
                Toggle("夾宮提示", isOn: s.showClamp).zSwitch()
                if store.settings.showClamp {
                    Picker("夾宮提示樣式", selection: s.clampStyle) {
                        Text("雙箭頭").tag(ZSettings.ClampStyle.arrows)
                        Text("框線").tag(ZSettings.ClampStyle.frame)
                    }
                    Toggle("夾宮四化照目前運限", isOn: s.clampByScope).zSwitch()
                }
            } header: {
                Text("夾宮")
            } footer: {
                Text("選到被左右兩宮夾住的宮位時（左右夾、羊陀夾、雙忌夾…），交界線上會出現提示")
            }

            Section("運限") {
                Toggle("小限疊盤", isOn: s.showMinorOverlay).zSwitch()
                if store.settings.showMinorOverlay { Toggle("顯示小限四化", isOn: s.showMinorMutagen).zSwitch() }
                Toggle("顯示流年／小限歲數", isOn: s.showAgeLines).zSwitch()
            }

            if showRulesLink {
                Section {
                    NavigationLink("排盤規則") { RulesSettingsView() }
                } footer: {
                    Text("安星派別、年分界、四化版本等，改了每一張盤都會重算")
                }
            }
        }
        .navigationTitle("盤面顯示")
        .navigationBarTitleDisplayMode(.inline)
    }
}
