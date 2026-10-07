import SwiftUI

/// 命盤頁：上面十二宮盤面、下面運限表（兩個都跟 Mac 版共用），外框是系統導覽列
struct ChartView: View {
    let person: Person
    @EnvironmentObject private var store: Store
    @Environment(\.zSettings) private var settings
    @State private var pick: Pick
    @State private var model: ChartModel?
    @State private var shownLevel: Int
    @State private var editing = false

    init(person: Person) {
        self.person = person
        // 驗證用：ZIWEI_LEVEL=2 直接開到流年
        let lv = ProcessInfo.processInfo.environment["ZIWEI_LEVEL"].flatMap(Int.init) ?? ZSettings.stored().openLevel
        var p = Pick.today(); p.level = lv
        _pick = State(initialValue: p)
        _shownLevel = State(initialValue: lv)
    }

    private var isNow: Bool { person.id == Person.nowID }

    var body: some View {
        GeometryReader { geo in
            // 手機直拿：盤面左右只留一點邊；iPad／橫放：寬度上限跟 Mac 一樣
            let boardW = min(geo.size.width - 8, 920)
            ScrollView {
                VStack(spacing: 14) {
                    Group {
                        if let model {
                            ChartBoard(person: person, model: model, level: shownLevel, onResetLevel: { pick.level = 0 })
                                .equatable()
                                .transaction(value: pick) { $0.animation = nil }
                                .transition(.opacity)
                        } else {
                            ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
                        }
                    }
                    .frame(width: boardW, height: boardW * 1.12)

                    if let model {
                        PeriodTable(chart: model.chart, birthYear: person.birthYear, pick: $pick)
                            .padding(.horizontal, 12)
                            .transition(.opacity.combined(with: .offset(y: 8)))
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.top, 4)
                .padding(.bottom, 24)
            }
        }
        .background(Color.zBg)
        .navigationTitle(isNow ? "此刻" : person.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if pick.level > 0 {
                ToolbarItem(placement: .topBarLeading) {
                    Button("本命") { pick.level = 0 }
                }
            }
            if !isNow {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { editing = true } label: { Image(systemName: "pencil") }
                        .accessibilityLabel("編輯命主資料")
                }
            }
        }
        .sheet(isPresented: $editing) {
            PersonForm(editing: person)
        }
        .task(id: LoadKey(chart: person.chartKey + settings.calcKey, pick: pick)) {
            let target = pick
            let m = await Engine.shared.model(for: person, pick: target)
            guard !Task.isCancelled else { return }
            // 第一次淡入；之後換運限直接換，不讓整張盤一起動畫
            if model == nil {
                shownLevel = target.level
                withAnimation(Motion.enter) { model = m }
            } else {
                var t = Transaction(); t.disablesAnimations = true
                withTransaction(t) { model = m; shownLevel = target.level }
            }
            Engine.shared.prefetch(person, around: target)
        }
    }

    private struct LoadKey: Equatable { let chart: String; let pick: Pick }
}

/// 此刻：用現在的時間排盤（不存檔），每分鐘更新；性別可切換
struct NowChartView: View {
    @AppStorage("nowGender") private var gender: Gender = .male
    @State private var now = Date()

    var body: some View {
        let c = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: now)
        let p = Person(id: Person.nowID, name: "此刻", gender: gender, solar: "\(c.year!)-\(c.month!)-\(c.day!)",
                       hour: SolarTime.shichen(c.hour!), group: "此刻",
                       clock: String(format: "%d-%d-%d %02d:%02d", c.year!, c.month!, c.day!, c.hour!, c.minute!))
        ChartView(person: p)
            .id(p.chartKey)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Picker("性別", selection: $gender) {
                        ForEach(Gender.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                    }
                    .pickerStyle(.segmented)
                    .fixedSize()
                }
            }
            .onReceive(Timer.publish(every: 60, on: .main, in: .common).autoconnect()) { now = $0 }
    }
}
