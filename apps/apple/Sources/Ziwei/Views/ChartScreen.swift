import SwiftUI

/// 運限選擇：level 0 本命、1 大限、2 流年、3 流月、4 流日、5 流時；年月日都是農曆
struct Pick: Equatable {
    var level = 2
    var year: Int
    var lm: Int
    var ld: Int
    var hour: Int

    static func today() -> Pick {
        let now = Date()
        let c = Calendar.current.dateComponents([.year, .month, .day, .hour], from: now)
        let l = Engine.shared.solarToLunar("\(c.year!)-\(c.month!)-\(c.day!)")
        return Pick(year: l.year, lm: l.month, ld: l.day, hour: ((c.hour! + 1) % 24) / 2)
    }
}

struct ChartScreen: View {
    @EnvironmentObject var store: Store
    let person: Person
    @State private var pick = Pick.today()
    @State private var showNotes = true
    @State private var horo: Horoscope?

    var body: some View {
        let chart = Engine.shared.chart(for: person)
        ScrollView {
            VStack(spacing: 16) {
                if let horo {
                    ChartBoard(person: person, chart: chart, horo: horo, level: pick.level)
                        .aspectRatio(1.08, contentMode: .fit)
                        .frame(maxWidth: 1120)
                }
                PeriodTable(chart: chart, birthYear: person.birthYear, pick: $pick)
                    .frame(maxWidth: 1120)
            }
            .padding(20)
            .frame(maxWidth: .infinity)
        }
        .background(Color.zBg)
        .navigationTitle(person.name)
        .navigationSubtitle("\(person.gender.rawValue) · \(person.solar) \(ZW.hours[person.hour])時 · \(chart.fiveElementsClass)")
        .toolbar {
            ToolbarItem(placement: .principal) {
                Picker("運限", selection: $pick.level) {
                    ForEach(0..<6, id: \.self) { Text(ZW.levels[$0]).tag($0) }
                }
                .pickerStyle(.segmented)
                .fixedSize()
            }
            ToolbarItem(placement: .primaryAction) {
                Button { showNotes.toggle() } label: { Image(systemName: "sidebar.right") }
                    .help("筆記")
            }
        }
        .inspector(isPresented: $showNotes) {
            NotesPanel(person: person)
                .inspectorColumnWidth(min: 280, ideal: 340, max: 440)
        }
        .onAppear(perform: recompute)
        .onChange(of: pick) { _, _ in recompute() }
    }

    private func recompute() {
        var day = pick.ld
        var solar = Engine.shared.lunarToSolar(pick.year, pick.lm, day)
        // 小月沒有三十，往前退一天
        while !solar.contains("-") && day > 28 { day -= 1; solar = Engine.shared.lunarToSolar(pick.year, pick.lm, day) }
        horo = Engine.shared.horoscope(for: person, date: solar, hour: pick.hour)
    }
}
