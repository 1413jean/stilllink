import SwiftUI

/// 設定分頁＝個人檔案（照 Figma Stillink-UI「Profile 個人檔案」71:45）：
/// 小標＋大標、頭像與名字、保存命盤（登入）卡片、出生資料、偏好、關於
struct SettingsView: View {
    @EnvironmentObject private var store: Store
    @AppStorage("appearance") private var appearance: Appearance = .system
    @State private var editingSelf = false
    @State private var soon = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("PROFILE · 設定").zText(.eyebrow).foregroundStyle(Color.zAccent)
                    Text("個人檔案").zText(.titleLarge).foregroundStyle(Color.zText)
                }
                .padding(.bottom, 16)

                me.padding(.bottom, 24)
                saveCard.padding(.bottom, 28)

                group("出生資料") {
                    if let p = store.me {
                        row("出生日期", value: birthDate(p)) { editingSelf = true }
                        row("出生時間", value: birthTime(p)) { editingSelf = true }
                        row("出生地", value: p.place?.name ?? "未填") { editingSelf = true }
                        row("命盤", value: p.gender == .female ? "女命" : "男命", last: true) { editingSelf = true }
                    } else {
                        row("填寫我的命盤", value: "", last: true) { editingSelf = true }
                    }
                }
                .padding(.bottom, 20)

                group("偏好") {
                    Menu {
                        Picker("外觀", selection: $appearance) {
                            ForEach(Appearance.allCases, id: \.self) { Label($0.label, systemImage: $0.icon).tag($0) }
                        }
                    } label: {
                        rowLabel("外觀", value: appearance.label, chevron: "chevron.up.chevron.down")
                    }
                    divider
                    NavigationLink { ChartSettingsView() } label: {
                        rowLabel("排盤與盤面", value: store.settings.algorithm == .standard ? "斗數全書" : "中州派")
                    }
                    divider
                    Toggle(isOn: $store.settings.sound) { Text("介面音效").zText(.body).foregroundStyle(Color.zText) }
                        .padding(.horizontal, 16).frame(height: 52)
                    divider
                    Toggle(isOn: $store.settings.haptics) { Text("觸覺回饋").zText(.body).foregroundStyle(Color.zText) }
                        .padding(.horizontal, 16).frame(height: 52)
                }
                .padding(.bottom, 20)

                group("關於") {
                    rowLabel("版本", value: AppInfo.displayVersion, chevron: nil)
                    divider
                    Link(destination: URL(string: "mailto:support@jeanui.com")!) {
                        rowLabel("問題與建議", value: "support@jeanui.com")
                    }
                    divider
                    Link(destination: URL(string: "https://github.com/SylarLong/iztro")!) {
                        rowLabel("排盤計算", value: "iztro")
                    }
                }
            }
            .padding(.horizontal, 24)
            .padding(.top, 8)
            .padding(.bottom, 24)
        }
        .background(Color.zBg)
        .toolbar(.hidden, for: .navigationBar)
        .sheet(isPresented: $editingSelf) {
            if let p = store.me { PersonForm(editing: p) } else { PersonForm(asSelf: true) }
        }
        .alert("即將推出", isPresented: $soon) {
            Button("好", role: .cancel) {}
        } message: {
            Text("登入後命盤和紀錄可以在不同裝置同步。目前資料只存在這台裝置。")
        }
    }

    // MARK: 區塊

    private var me: some View {
        HStack(spacing: 16) {
            AvatarView(name: store.userAvatar, size: 68)
            VStack(alignment: .leading, spacing: 2) {
                Text(store.userName).zText(.title2).foregroundStyle(Color.zText)
                Text(subtitle).zText(.subheadline).foregroundStyle(Color.zText3)
            }
        }
    }

    private var subtitle: String {
        guard let p = store.me else { return "還沒填自己的命盤" }
        let soul = store.soulStars[p.id] ?? ""
        return soul.isEmpty ? "命無主星" : "命宮主星 · \(soul)"
    }

    private var saveCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("保存你的命盤").zText(.title3).foregroundStyle(Color.zText).padding(.bottom, 10)
            Text("命盤和紀錄可以在不同裝置同步。不用填表單，也不用密碼。")
                .zText(.callout).foregroundStyle(Color.zText2).padding(.bottom, 14)
            Button { soon = true } label: {
                Label("使用 Apple 登入", systemImage: "apple.logo")
                    .zText(.bodyStrong)
                    .foregroundStyle(Color.zBg)
                    .frame(maxWidth: .infinity, minHeight: 52)
                    .background(Capsule().fill(Color.zText))
            }
            .buttonStyle(.plain)
            .padding(.bottom, 12)
            Button { soon = true } label: {
                HStack(spacing: 10) {
                    Text("G").font(.system(size: 18, weight: .bold))
                    Text("使用 Google 登入").zText(.bodyStrong)
                }
                .foregroundStyle(Color.zText)
                .frame(maxWidth: .infinity, minHeight: 52)
                .background(Capsule().fill(Color.zCard))
                .overlay(Capsule().stroke(Color.zLine))
            }
            .buttonStyle(.plain)
        }
        .padding(20)
        .background(RoundedRectangle(cornerRadius: 22, style: .continuous).fill(Color.zHover))
    }

    // MARK: 列

    private func group<C: View>(_ title: String, @ViewBuilder _ content: () -> C) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title).zText(.eyebrow).foregroundStyle(Color.zText3)
            VStack(spacing: 0) { content() }
                .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(Color.zHover))
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
    }

    private var divider: some View {
        Rectangle().fill(Color.zLine).frame(height: 0.5).padding(.leading, 16)
    }

    private func row(_ title: String, value: String, last: Bool = false, action: @escaping () -> Void) -> some View {
        VStack(spacing: 0) {
            Button(action: action) { rowLabel(title, value: value) }.buttonStyle(.plain)
            if !last { divider }
        }
    }

    private func rowLabel(_ title: String, value: String, chevron: String? = "chevron.right") -> some View {
        HStack(spacing: 8) {
            Text(title).zText(.body).foregroundStyle(Color.zText)
            Spacer(minLength: 12)
            Text(value).zText(.body).foregroundStyle(Color.zText3).lineLimit(1)
            if let chevron {
                Image(systemName: chevron).font(.system(size: 13, weight: .semibold)).foregroundStyle(Color.zText3)
            }
        }
        .padding(.horizontal, 16)
        .frame(height: 52)
        .contentShape(Rectangle())
    }

    // MARK: 資料

    private func parts(_ p: Person) -> [Int] {
        (p.clock ?? p.solar).split(whereSeparator: { " -:".contains($0) }).compactMap { Int($0) }
    }
    private func birthDate(_ p: Person) -> String {
        let n = parts(p)
        return n.count >= 3 ? "\(n[0]) 年 \(n[1]) 月 \(n[2]) 日" : p.solar
    }
    private func birthTime(_ p: Person) -> String {
        let n = parts(p)
        guard n.count >= 5 else { return ZW.hours[p.hour] + "時" }
        return String(format: "%02d:%02d", n[3], n[4]) + " · " + ZW.hours[SolarTime.shichen(n[3])] + "時"
    }
}
