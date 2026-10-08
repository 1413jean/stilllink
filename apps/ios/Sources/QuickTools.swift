import SwiftUI

/// 快捷排盤（照 Mac 版右下角 ✦ 選單）：命盤頁右上角的原生選單
/// 新建命盤、四柱反查、紫占排盤、報數起卦；今年／本月／今日／此時流盤直接切運限
struct QuickMenu: View {
    @Binding var pick: Pick
    var onNew: () -> Void
    var onPillars: () -> Void
    var onTemp: (Person, Int) -> Void
    var onHepan: () -> Void = {}
    @State private var askingNumber = false

    var body: some View {
        Menu {
            Section {
                Button("新建命盤", systemImage: "plus.circle", action: onNew)
                Button("四柱反查", systemImage: "square.grid.2x2", action: onPillars)
                Menu {
                    ForEach(Gender.allCases.reversed(), id: \.self) { g in
                        Section("\(g.rawValue)命") {
                            Button("當前時刻起盤", systemImage: "clock") { onTemp(TempChart.now(g), ZSettings.stored().openLevel) }
                            Button("系統亂序起盤", systemImage: "shuffle") { onTemp(TempChart.random(g), ZSettings.stored().openLevel) }
                            Button("七層限流盤", systemImage: "square.stack.3d.up") { onTemp(TempChart.sevenLayer(g), 5) }
                        }
                    }
                } label: {
                    Label("紫占排盤", systemImage: "sparkles")
                }
                Button("報數起卦", systemImage: "number") { askingNumber = true }
                Button("合盤…", systemImage: "person.2.circle", action: onHepan)
            }
            Section {
                Button("今年流盤", systemImage: "calendar") { flow(2) }
                Button("本月流盤", systemImage: "calendar.day.timeline.left") { flow(3) }
                Button("今日流盤", systemImage: "sun.max") { flow(4) }
                Button("此時流盤", systemImage: "clock.badge") { flow(5) }
            }
        } label: {
            Image(systemName: "sparkles").frame(width: 22, height: 22)
        }
        .accessibilityLabel("快捷排盤")
        // 報數：底部小卡（alert 裡的輸入框在 iOS 26 會跑版）
        .sheet(isPresented: $askingNumber) {
            BaoshuSheet { onTemp(TempChart.baoshu($0), ZSettings.stored().openLevel) }
                .presentationDetents([.height(250)])
                .presentationBackground(Color.zBg)
        }
    }

    /// 回到今天的運限，並切到指定層級
    private func flow(_ level: Int) {
        Platform.haptic(.levelChange)
        var p = Pick.today()
        p.level = level
        pick = p
    }
}

/// 紫占、報數、四柱反查用的暫時命盤（不存檔，命盤頁右上角可以「存入命盤」）
/// 產生方式跟 Mac 版 QuickMenu.swift 的 TempChart 一樣
enum TempChart {
    static let years = 1...9999

    static func now(_ g: Gender) -> Person { make(Date(), g, name: "紫占 · 此刻") }
    static func sevenLayer(_ g: Gender) -> Person { make(Date(), g, name: "七層限流盤") }
    /// 亂序起盤：西元 1～9999 年任一刻
    static func random(_ g: Gender) -> Person {
        make(Int.random(in: years), Int.random(in: 1...12), Int.random(in: 1...28),
             Int.random(in: 0...23), Int.random(in: 0...59), g, name: "匿名")
    }

    /// 報數起卦：報的數字加上起卦當下的分鐘當種子（同一分鐘報同一個數會得到同一張盤）
    static func baoshu(_ n: Int) -> Person {
        let minute = UInt64(Date().timeIntervalSince1970 / 60)
        var rng = SeededRandom(seed: UInt64(n) &* 0x9E3779B97F4A7C15 ^ minute)
        let year = Int.random(in: years, using: &rng)
        let month = Int.random(in: 1...12, using: &rng)
        let day = Int.random(in: 1...28, using: &rng)
        let branch = Int.random(in: 0...11, using: &rng)
        let g: Gender = Bool.random(using: &rng) ? .male : .female
        return make(year, month, day, branch == 0 ? 0 : branch * 2, branch == 0 ? 30 : 0, g, name: "報數 \(n)")
    }

    static func make(_ d: Date, _ g: Gender, name: String) -> Person {
        let c = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: d)
        return make(c.year!, c.month!, c.day!, c.hour!, c.minute!, g, name: name)
    }

    static func make(_ y: Int, _ m: Int, _ d: Int, _ h: Int, _ min: Int, _ g: Gender, name: String) -> Person {
        // 1582-10-5～14 在格里曆改曆時被跳過，不存在（iztro 會報錯）→ 移到 10-15
        let d = (y == 1582 && m == 10 && (5...14).contains(d)) ? 15 : d
        return Person(name: name, gender: g, solar: "\(y)-\(m)-\(d)", hour: SolarTime.shichen(h),
                      group: "占卜", clock: String(format: "%d-%d-%d %02d:%02d", y, m, d, h, min))
    }
}

/// 可指定種子的亂數（SplitMix64，跟 Mac 版同一套）
struct SeededRandom: RandomNumberGenerator {
    private var state: UInt64
    init(seed: UInt64) { state = seed }
    mutating func next() -> UInt64 {
        state &+= 0x9E3779B97F4A7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58476D1CE4E5B9
        z = (z ^ (z >> 27)) &* 0x94D049BB133111EB
        return z ^ (z >> 31)
    }
}

/// 四柱反查：選四柱 → 列出 1900–2100 年符合的時刻，點一筆就排盤
struct PillarSearchSheet: View {
    var onPick: (Person) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var pillars = ["甲子", "丙寅", "甲子", "甲子"]
    @State private var gender: Gender = .male
    @State private var results: [Bazi.Match] = []
    @State private var searched = false
    @State private var searching = false
    private let all = (0..<60).map { ZW.ganzhi($0) }

    var body: some View {
        NavigationStack {
            ZForm {
                Section {
                    ForEach(0..<4, id: \.self) { k in
                        Picker(["年柱", "月柱", "日柱", "時柱"][k], selection: $pillars[k]) {
                            ForEach(all, id: \.self) { Text($0).tag($0) }
                        }
                    }
                    Picker("性別", selection: $gender) {
                        ForEach(Gender.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                    }
                    .pickerStyle(.segmented)
                } footer: {
                    Text("找出 1900–2100 年間符合的出生時刻（台北時間）")
                }

                if searched {
                    Section(results.isEmpty ? "沒有符合的時刻" : "找到 \(results.count) 筆") {
                        if results.isEmpty {
                            Text("請檢查四柱是否成立（例如月柱要配年干）").foregroundStyle(Color.zText3)
                        }
                        ForEach(results) { r in
                            Button {
                                onPick(TempChart.make(r.date, gender, name: pillars.joined(separator: " ")))
                                dismiss()
                            } label: {
                                HStack {
                                    Text(String(format: "%d 年 %d 月 %d 日", r.y, r.m, r.d)).monospacedDigit()
                                    Text(ZW.branches[((r.hour + 1) / 2) % 12] + "時").foregroundStyle(Color.zText2)
                                    Spacer()
                                    Image(systemName: "chevron.right").font(.footnote).foregroundStyle(Color.zText3)
                                }
                                .foregroundStyle(Color.zText)
                            }
                        }
                    }
                }
            }
            .navigationTitle("四柱反查")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("關閉") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    if searching { ProgressView() } else { Button("查詢", action: search) }
                }
            }
        }
    }

    /// 掃 200 年要一點時間，放背景算
    private func search() {
        searching = true
        let target = pillars
        Task {
            let r = await Task.detached { Bazi.search(target) }.value
            results = r
            searching = false
            withAnimation(Motion.base) { searched = true }
        }
    }
}

/// 合盤：選一張命盤（用他的出生年），或直接輸入對方的出生年；疊到目前這張盤上（跟 Mac 一樣只看年干支）
struct HepanSheet: View {
    let current: UUID
    var onPick: (Int, String?) -> Void
    @EnvironmentObject private var store: Store
    @Environment(\.dismiss) private var dismiss
    @State private var yearText = ""

    var body: some View {
        NavigationStack {
            ZForm {
                Section {
                    HStack {
                        TextField("對方出生年，例如 1995", text: $yearText).keyboardType(.numberPad)
                        Button("合盤") { if let y = year { onPick(y, nil); dismiss() } }.disabled(year == nil)
                    }
                } footer: {
                    Text("合盤只用對方的出生年（天干地支）：合命等宮名、合祿合羊合陀、合四化會疊在盤上")
                }
                Section("從命盤選") {
                    ForEach(store.people.filter { $0.id != current }) { p in
                        Button { onPick(p.birthYear, p.name); dismiss() } label: {
                            HStack(spacing: 12) {
                                AvatarView(name: p.avatar, size: 32)
                                Text(p.name).foregroundStyle(Color.zText)
                                Spacer()
                                Text("\(String(p.birthYear)) \(ZW.yearGanzhi(p.birthYear))").foregroundStyle(Color.zText3)
                            }
                        }
                    }
                }
            }
            .navigationTitle("合盤")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("取消") { dismiss() } } }
        }
        .tint(Color.zText)
    }

    private var year: Int? {
        guard let y = Int(yearText.trimmingCharacters(in: .whitespaces)), (1...9999).contains(y) else { return nil }
        return y
    }
}

/// 報數起卦：輸入 0–9999，鍵盤自動打開
struct BaoshuSheet: View {
    var onSubmit: (Int) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var text = ""
    @FocusState private var focused: Bool

    private var value: Int? { Int(text.filter(\.isNumber).prefix(4)) }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("報數起卦").zText(.title3).foregroundStyle(Color.zText)
            Text("心裡想著問題，隨口報一個 0–9999 的數字").zText(.callout).foregroundStyle(Color.zText2)
            TextField("例如：3721", text: $text)
                .keyboardType(.numberPad)
                .focused($focused)
                .zText(.title3)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity).frame(height: 52)
                .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Color.zHover))
                .onChange(of: text) { _, v in let d = String(v.filter(\.isNumber).prefix(4)); if d != v { text = d } }
            HStack(spacing: 10) {
                Button { dismiss() } label: {
                    Text("取消").zText(.bodyStrong).foregroundStyle(Color.zText)
                        .frame(maxWidth: .infinity).frame(height: 48)
                        .background(Capsule().fill(Color.zHover))
                }
                Button { if let v = value { onSubmit(v); dismiss() } } label: {
                    Text("起卦").zText(.bodyStrong).foregroundStyle(Color.zBg)
                        .frame(maxWidth: .infinity).frame(height: 48)
                        .background(Capsule().fill(Color.zText))
                }
                .disabled(value == nil).opacity(value == nil ? 0.4 : 1)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 20).padding(.top, 24)
        .frame(maxHeight: .infinity, alignment: .top)
        .onAppear { focused = true }
    }
}
