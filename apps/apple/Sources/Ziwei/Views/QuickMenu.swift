import SwiftUI

/// 右下角「快捷排盤」：新建命盤、四柱反查、紫占排盤、今年／本月／今日／此時流盤
struct QuickMenu: View {
    @Binding var pick: Pick
    @State private var hover = false

    var body: some View {
        Menu {
            Button { NotificationCenter.default.post(name: .newChart, object: nil) } label: { Label("新建命盤", systemImage: "plus") }
            Button { NotificationCenter.default.post(name: .openPillars, object: nil) } label: { Label("四柱反查", systemImage: "magnifyingglass") }
            Menu {
                Button("當前時刻起盤（男盤）") { TempChart.open(.now(.male)) }
                Button("當前時刻起盤（女盤）") { TempChart.open(.now(.female)) }
                Divider()
                Button("系統亂序起盤（男盤）") { TempChart.open(.random(.male)) }
                Button("系統亂序起盤（女盤）") { TempChart.open(.random(.female)) }
                Divider()
                Button("當前時刻起七層限流盤（男盤）") { TempChart.open(.sevenLayer(.male)) }
                Button("當前時刻起七層限流盤（女盤）") { TempChart.open(.sevenLayer(.female)) }
            } label: { Label("紫占排盤", systemImage: "sparkles") }
            Divider()
            Button { flow(2) } label: { Label("今年流盤", systemImage: "calendar") }
            Button { flow(3) } label: { Label("本月流盤", systemImage: "calendar.day.timeline.left") }
            Button { flow(4) } label: { Label("今日流盤", systemImage: "sun.max") }
            Button { flow(5) } label: { Label("此時流盤", systemImage: "clock") }
        } label: {
            Image(systemName: "sparkles")
                .font(Font.zHeadline)
                .foregroundStyle(Color.zOnColor)
                .frame(width: 44, height: 44)
                .background(Circle().fill(Color.zAccent))
                .shadow(color: Color.zShadow, radius: 10, y: 4)
                .scaleEffect(hover && !Motion.reduce ? 1.06 : 1)
                .animation(Motion.fast, value: hover)
                .contentShape(Circle())
        }
        .menuStyle(.button)
        .buttonStyle(.plain)
        .menuIndicator(.hidden)
        .fixedSize()
        .onHover { hover = $0 }
        .help("快捷排盤")
    }

    /// 回到今天的運限，並切到指定層級
    private func flow(_ level: Int) {
        var p = Pick.today()
        p.level = level
        withAnimation(Motion.snap) { pick = p }
    }
}

/// 紫占用的暫時命盤（不存檔，可在右側「存入命盤」）
enum TempChart {
    enum Kind { case now(Gender), random(Gender), sevenLayer(Gender) }

    static func open(_ k: Kind) {
        let p: Person, level: Int
        switch k {
        case .now(let g): p = make(Date(), g, name: "紫占 · 此刻"); level = 2
        case .sevenLayer(let g): p = make(Date(), g, name: "七層限流盤"); level = 5
        case .random(let g):
            var cal = Calendar(identifier: .gregorian); cal.timeZone = .current
            let d = cal.date(from: DateComponents(year: Int.random(in: 1940...2015), month: Int.random(in: 1...12),
                                                  day: Int.random(in: 1...28), hour: Int.random(in: 0...23), minute: Int.random(in: 0...59)))!
            p = make(d, g, name: "紫占 · 亂序"); level = 2
        }
        NotificationCenter.default.post(name: .openTemp, object: TempRequest(person: p, level: level))
    }

    static func make(_ d: Date, _ g: Gender, name: String) -> Person {
        let c = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: d)
        return Person(name: name, gender: g, solar: "\(c.year!)-\(c.month!)-\(c.day!)", hour: SolarTime.shichen(c.hour!),
                      group: "占卜", clock: String(format: "%d-%d-%d %02d:%02d", c.year!, c.month!, c.day!, c.hour!, c.minute!))
    }
}

final class TempRequest { let person: Person; let level: Int; init(person: Person, level: Int) { self.person = person; self.level = level } }

/// 四柱反查頁：選四柱 → 列出 1900–2100 年符合的時刻，點一筆就排盤
struct PillarSearchPage: View {
    var onClose: () -> Void
    @State private var pillars = ["甲子", "丙寅", "甲子", "甲子"]
    @State private var gender: Gender = .male
    @State private var results: [Bazi.Match] = []
    @State private var searched = false
    private let all = (0..<60).map { ZW.ganzhi($0) }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                Text("四柱反查").font(.zTitle).foregroundStyle(Color.zText).padding(.bottom, 4)
                Text("輸入八字四柱，找出 1900–2100 年間符合的出生時刻（台北時間）。")
                    .font(Font.zCallout).foregroundStyle(Color.zText3).padding(.bottom, 12)
                ForEach(0..<4, id: \.self) { k in
                    row(["年柱", "月柱", "日柱", "時柱"][k]) { ZMenuField(options: all, selection: $pillars[k]) }
                }
                row("性別", last: true) { ZSegmented(options: Gender.allCases.map { ($0, $0.rawValue) }, selection: $gender) }
                HStack {
                    Spacer()
                    Button("查詢") {
                        results = Bazi.search(pillars)
                        withAnimation(Motion.base) { searched = true }
                    }
                    .buttonStyle(ZPrimaryButton())
                    .keyboardShortcut(.defaultAction)
                }
                .padding(.vertical, 16)

                if searched {
                    Text(results.isEmpty ? "沒有符合的時刻，請檢查四柱是否成立（例如月柱要配年干）。" : "找到 \(results.count) 筆")
                        .font(Font.zCalloutStrong).foregroundStyle(Color.zText2).padding(.bottom, 8)
                    ForEach(Array(results.enumerated()), id: \.element.id) { i, r in
                        Button {
                            let p = TempChart.make(r.date, gender, name: pillars.joined(separator: " "))
                            NotificationCenter.default.post(name: .openTemp, object: TempRequest(person: p, level: 0))
                        } label: {
                            HStack {
                                Text(String(format: "%d 年 %d 月 %d 日", r.y, r.m, r.d)).font(Font.zBody.monospacedDigit())
                                Text(ZW.branches[((r.hour + 1) / 2) % 12] + "時").font(Font.zBody).foregroundStyle(Color.zText2)
                                Spacer()
                                Image(systemName: "chevron.right").font(Font.zCaption).foregroundStyle(Color.zText3)
                            }
                            .padding(.horizontal, 12).frame(height: 40)
                            .background(RoundedRectangle(cornerRadius: 9).fill(Color.zCard))
                            .overlay(RoundedRectangle(cornerRadius: 9).stroke(Color.zLine))
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(PressStyle())
                        .padding(.bottom, 6)
                        .enterFromBelow(searched, index: i)
                    }
                }
            }
            .frame(maxWidth: 680, alignment: .leading)
            .padding(.horizontal, 32).padding(.vertical, 20)
            .frame(maxWidth: .infinity)
        }
        .background(Color.zBg)
        .navigationTitle("")
    }

    private func row<C: View>(_ t: String, last: Bool = false, @ViewBuilder _ c: () -> C) -> some View {
        HStack {
            Text(t).font(Font.zBody).foregroundStyle(Color.zText)
            Spacer()
            c().frame(width: 300)
        }
        .padding(.vertical, 12)
        .overlay(alignment: .bottom) { if !last { Rectangle().fill(Color.zLine).frame(height: 0.5) } }
    }
}
