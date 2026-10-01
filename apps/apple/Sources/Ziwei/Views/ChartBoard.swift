import SwiftUI

/// 照文墨天機排的十二宮盤面（純 SwiftUI 繪製）
struct ChartBoard: View {
    let person: Person
    let model: ChartModel
    let level: Int
    var onResetLevel: () -> Void = {}
    @State private var sel: Int?
    @State private var appeared = false
    @Environment(\.zSettings) private var settings

    var body: some View {
        let chart = model.chart
        let selected = sel ?? chart.soulIndex
        let sf = ZW.sanFang(selected)
        GeometryReader { geo in
            let m: CGFloat = 18
            let cw = (geo.size.width - m * 2) / 4
            let ch = (geo.size.height - m * 2) / 4
            let fs = ChartType.base(cellWidth: cw)
            ZStack(alignment: .topLeading) {
                ForEach(0..<12, id: \.self) { i in
                    let (r, c) = ZW.grid[i]
                    PalaceCell(model: model, index: i, level: level, fs: fs,
                               selected: selected == i, inSF: sf.contains(i) && selected != i,
                               flyStars: Dictionary(model.flying[selected].map { ($0.star, $0.m) }, uniquingKeysWith: { a, _ in a }))
                        .frame(width: cw, height: ch, alignment: .top)
                        .clipped()
                        .contentShape(Rectangle())
                        .onTapGesture { Sound.tap(settings); withAnimation(Motion.snap) { sel = i } }
                        .enterFromBelow(appeared, index: r * 4 + c)
                        .offset(x: m + CGFloat(c) * cw, y: m + CGFloat(r) * ch)
                    if settings.showCompass { compassLabel(i, r: r, c: c, cw: cw, ch: ch, m: m) }
                }
                CenterInfo(person: person, model: model, selected: selected, fs: fs, level: level, onResetLevel: onResetLevel)
                    .enterFromBelow(appeared, index: 8)
                    .frame(width: cw * 2, height: ch * 2)
                    .offset(x: m + cw, y: m + ch)
            }
        }
        .background(RoundedRectangle(cornerRadius: 12).fill(Color.zCard))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.zLine))
        .onAppear { appeared = true }
    }

    @ViewBuilder
    private func compassLabel(_ i: Int, r: Int, c: Int, cw: CGFloat, ch: CGFloat, m: CGFloat) -> some View {
        let text = Text(ZW.compass[i]).font(Font.zMicro).foregroundStyle(Color.zText3)
        if r == 0 && (c == 1 || c == 2) {
            text.frame(width: cw, height: m).offset(x: m + CGFloat(c) * cw, y: 0)
        } else if r == 3 && (c == 1 || c == 2) {
            text.frame(width: cw, height: m).offset(x: m + CGFloat(c) * cw, y: m + 4 * ch)
        } else if c == 0 || c == 3 {
            VerticalText(ZW.compass[i], size: 10, color: .zText3)
                .frame(width: m, height: ch)
                .offset(x: c == 0 ? 0 : m + 4 * cw, y: m + CGFloat(r) * ch)
        }
    }
}

/// 直排文字：一個字一行
struct VerticalText: View {
    let text: String
    let size: CGFloat
    var color: Color = .zText
    var weight: Font.Weight = .regular
    init(_ text: String, size: CGFloat, color: Color = .zText, weight: Font.Weight = .regular) {
        self.text = text; self.size = size; self.color = color; self.weight = weight
    }
    var body: some View {
        VStack(spacing: 0) {
            ForEach(Array(text.enumerated()), id: \.offset) { _, ch in
                Text(String(ch)).font(.system(size: size, weight: weight)).foregroundStyle(color)
            }
        }
    }
}

private struct PalaceCell: View {
    @Environment(\.zSettings) private var settings
    let model: ChartModel
    let index: Int
    let level: Int
    let fs: CGFloat
    let selected: Bool
    let inSF: Bool
    let flyStars: [String: Mutagen]

    var body: some View {
        let chart = model.chart, horo = model.horo
        let p = chart.palaces[index]
        let selfs = model.selfs[index]
        let curDecade = level >= 1 && horo.decadal.index == index
        let minor = level >= 2 && settings.showMinor
        // 來因宮：生年天干所在的宮（寅～亥，子丑與寅卯同干不算）
        let laiyin = settings.showLaiyin && index < 10 && p.stem == String(chart.chineseDate.prefix(1))
        VStack(alignment: .leading, spacing: 2) {
            FlowLayout(spacing: 1, lineSpacing: 4) {
                ForEach(p.stars, id: \.name) { s in
                    StarColumn(star: s, fs: fs, fly: flyStars[s.name],
                               minor: minor ? ZW.mutagen(in: horo.age.mutagen, star: s.name) : nil,
                               scopes: (1...max(1, level)).compactMap { lv in
                                   level >= lv ? ZW.mutagen(in: horo.scope(lv).mutagen, star: s.name).map { (lv, $0) } : nil
                               })
                }
                ForEach(settings.showAdj ? p.adj : [], id: \.name) { s in
                    VerticalText(s.name, size: ChartType.adj(fs), color: .wmBlue)
                }
            }
            .frame(maxWidth: .infinity, minHeight: 0, maxHeight: .infinity, alignment: .topLeading)
            .clipped()
            .layoutPriority(-1)
            HStack(alignment: .bottom, spacing: 2) {
                VStack(alignment: .leading, spacing: 0) {
                    if settings.showGods {
                    Text(p.boshi).foregroundStyle(Color.wmGreen)
                    Text(p.jiangqian)
                    Text(p.suiqian)
                    }
                }
                .font(ChartType.font(ChartType.gods(fs)))
                .foregroundStyle(Color.zText)
                Spacer(minLength: 0)
                VStack(spacing: 2) {
                    if settings.showAges {
                    VStack(spacing: 0) {
                        Text("流年: " + model.yearlyAges[index].map(String.init).joined(separator: ","))
                        Text("小限: " + p.ages.prefix(5).map(String.init).joined(separator: ","))
                    }
                    .font(ChartType.font(ChartType.ages(fs)))
                    .foregroundStyle(Color.zText2)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                    .padding(.bottom, 1)
                    }
                    Text("\(p.range[0])~\(p.range[1])")
                        .font(curDecade ? ChartType.font(ChartType.range(fs)).italic() : ChartType.font(ChartType.range(fs)))
                        .underline(curDecade)
                        .foregroundStyle(curDecade ? Color.wmRed : Color.zText)
                    HStack(spacing: 3) {
                        if minor {
                            Text("小" + String(horo.age.palaceNames[index].prefix(1)))
                                .font(ChartType.font(ChartType.tag(fs), .semibold))
                                .foregroundStyle(Color.minorColor)
                        }
                        if laiyin {
                            Text("來因").font(ChartType.font(ChartType.tag(fs), .semibold)).foregroundStyle(Color.wmRed)
                        }
                        ForEach(1..<(level + 1), id: \.self) { lv in
                            Text(ZW.scopeTags[lv - 1] + String(horo.scope(lv).palaceNames[index].prefix(1)))
                                .font(ChartType.font(ChartType.tag(fs), .semibold))
                                .foregroundStyle(Color.scopeColors[lv - 1])
                        }
                    }
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                    // 宮名單獨一行，不會被運限標籤擠成直排
                    Text(p.name).font(ChartType.font(ChartType.palace(fs))).foregroundStyle(Color.wmRed)
                        .lineLimit(1).fixedSize()
                }
                Spacer(minLength: 0)
                VStack(spacing: 0) {
                    VerticalText(p.changsheng, size: ChartType.meta(fs), color: .zText2)
                        .padding(.bottom, 2)
                    Text(p.stem).font(ChartType.font(ChartType.ganzhi(fs)))
                    Text(p.branch).font(ChartType.font(ChartType.ganzhi(fs)))
                }
                .foregroundStyle(Color.zText)
            }
        }
        .padding(.horizontal, 5)
        .padding(.vertical, 4)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(selected ? Color.wmSel : inSF ? Color.wmSF : Color.clear)
        .overlay(Rectangle().stroke(Color.zGrid, lineWidth: 0.5))
        .overlay(selected ? Rectangle().stroke(Color.wmRed, lineWidth: 1.5) : nil)
        .overlay(alignment: .trailing) {
            if p.isBody && settings.showBody {
                VerticalText("身宮", size: ChartType.tag(fs), color: .wmRed)
                    .padding(.vertical, 3).padding(.horizontal, 1)
                    .overlay(RoundedRectangle(cornerRadius: 3).stroke(Color.wmRed))
                    .padding(.trailing, 4)
            }
        }
        .overlay(alignment: .topTrailing) {
            let marks = !settings.showSelf ? [] : selfs.out.sorted { $0.key < $1.key }.map { ("↑", $0.value) } + selfs.into.sorted { $0.key < $1.key }.map { ("↓", $0.value) }
            if !marks.isEmpty {
                VStack(alignment: .trailing, spacing: 1) {
                    ForEach(Array(marks.enumerated()), id: \.offset) { _, mk in
                        Text(mk.0 + mk.1.rawValue).font(ChartType.font(ChartType.tag(fs), .semibold)).foregroundStyle(mk.1.color)
                    }
                }
                .padding(4)
            }
        }
        .clipped()
    }
}

private struct StarColumn: View {
    let star: Star
    let fs: CGFloat
    let fly: Mutagen?   // 點選宮位的宮干四化落在這顆星
    let minor: Mutagen? // 小限四化
    let scopes: [(Int, Mutagen)]

    var body: some View {
        let tone = ZW.tone(star.type)
        VStack(spacing: 0.5) {
            VerticalText(star.name, size: ChartType.star(fs), color: fly != nil ? .zOnColor : tone.color,
                         weight: star.type == "major" ? .semibold : .regular)
                .padding(.vertical, 1)
                .frame(width: fs * 1.18)
                .background(fly?.color ?? .clear)
            Text(star.brightness.isEmpty ? " " : star.brightness)
                .font(ChartType.font(ChartType.meta(fs)))
                .foregroundStyle(Color.zText2)
            if !star.mutagen.isEmpty {
                box(star.mutagen, fill: .wmRed)
            }
            if let minor {
                box(minor.rawValue, fill: .minorColor)
            }
            ForEach(scopes, id: \.0) { lv, m in
                box(m.rawValue, fill: Color.scopeColors[lv - 1])
            }
        }
        .frame(width: fs * 1.18)
    }

    private func box(_ t: String, fill: Color) -> some View {
        Text(t)
            .font(ChartType.font(fs * 0.84, .semibold))
            .foregroundStyle(Color.zOnColor)
            .frame(width: fs * 1.12, height: fs * 1.12)
            .background(fill)
    }
}

private struct CenterInfo: View {
    @Environment(\.zSettings) private var settings
    let person: Person
    let model: ChartModel
    let selected: Int
    let fs: CGFloat
    let level: Int
    let onResetLevel: () -> Void

    var body: some View {
        let chart = model.chart
        let pillars = chart.chineseDate.split(separator: " ").map(String.init)
        let yang = ["甲", "丙", "戊", "庚", "壬"].contains(String(pillars.first?.prefix(1) ?? ""))
        let flies = model.flying[selected]
        ZStack {
            SanFangShape(points: Quad(ZW.sanFang(selected).map { ZW.anchor[$0] }))
                .stroke(Color.zText3.opacity(0.7), style: StrokeStyle(lineWidth: 1, dash: [5, 4]))
                .opacity(settings.showSanfang ? 1 : 0)
            VStack(spacing: fs * 0.32) {
                Text("紫微斗數").font(ChartType.font(ChartType.centerTitle(fs), .semibold)).tracking(2)
                Grid(alignment: .leading, horizontalSpacing: 6, verticalSpacing: 1) {
                    GridRow { label("姓名"); Text("\(person.name)　　\(yang ? "陽" : "陰")\(person.gender.rawValue)　\(chart.fiveElementsClass)") }
                    if let ts = person.trueSolar {
                        GridRow { label("真太陽時"); Text(ts) }
                        GridRow { label("鐘錶時間"); Text(person.clock ?? "") }
                    } else {
                        GridRow { label("國曆"); Text("\(chart.solarDate) \(ZW.hours[person.hour])時（\(chart.timeRange)）") }
                    }
                    GridRow { label("農曆"); Text("\(chart.lunarDate) \(chart.time)") }
                    GridRow { label("命主"); Text("\(chart.soul)　身主: \(chart.body)　子斗: \(ziDou)") }
                }
                .font(ChartType.font(ChartType.centerBody(fs)))

                // 節氣四柱／非節氣四柱
                HStack(alignment: .top, spacing: fs * 1.6) {
                    pillarSet("節氣四柱", pillars)
                    pillarSet("非節氣四柱", lunarPillars)
                }

                // 八字起運與大運
                Text("出生後 \(qy.years)年 \(qy.months)月 \(qy.days)天 八字起運")
                    .font(ChartType.font(ChartType.centerSmall(fs), .medium))
                HStack(alignment: .top, spacing: fs * 0.32) {
                    ForEach(Array(dayun.enumerated()), id: \.offset) { k, gz in
                        let age = qy.years + 1 + k * 10
                        VStack(spacing: 0) {
                            HStack(alignment: .top, spacing: 0) {
                                Text(String(gz.prefix(1))).font(ChartType.font(ChartType.dayun(fs))).foregroundStyle(ZW.wuxing(String(gz.prefix(1))).color)
                                VerticalText(Bazi.tenGod(day: dayStem, other: String(gz.prefix(1))), size: ChartType.godLabel(fs), color: .mQuan)
                            }
                            Text(String(gz.suffix(1))).font(ChartType.font(ChartType.dayun(fs))).foregroundStyle(ZW.wuxing(String(gz.suffix(1))).color)
                            Text("\(age)歲").font(ChartType.font(ChartType.godLabel(fs))).foregroundStyle(Color.zText2)
                            Text(verbatim: "\(birthYear + age - 1)").font(ChartType.font(ChartType.godLabel(fs)).monospacedDigit()).foregroundStyle(Color.zText3)
                        }
                    }
                }

                // 點選宮位的宮干飛化（一行）
                HStack(spacing: 6) {
                    Text("\(chart.palaces[selected].name)\(chart.palaces[selected].stem)干：")
                        .font(ChartType.font(ChartType.centerSmall(fs))).foregroundStyle(Color.zText2)
                    ForEach(flies, id: \.m) { f in
                        Text("\(f.star)\(f.m.rawValue)→\(f.to.map { chart.palaces[$0].name } ?? "—")")
                            .font(ChartType.font(ChartType.centerSmall(fs), .medium)).foregroundStyle(f.m.color)
                    }
                }
                .lineLimit(1).minimumScaleFactor(0.7)
                HStack(spacing: 4) {
                    ForEach(Mutagen.allCases, id: \.self) { m in
                        Text(m.rawValue).font(ChartType.font(ChartType.centerSmall(fs), .semibold)).foregroundStyle(Color.zOnColor)
                            .padding(.horizontal, 3).background(m.color)
                    }
                    Text("↑離心 ↓向心自化").font(ChartType.font(ChartType.meta(fs))).foregroundStyle(Color.zText3)
                    if level > 0 {
                        Button(action: onResetLevel) {
                            Label("回本命盤", systemImage: "arrow.uturn.backward")
                                .font(ChartType.font(ChartType.meta(fs)))
                                .padding(.horizontal, 8).padding(.vertical, 2)
                                .background(Capsule().fill(Color.zHover))
                        }
                        .buttonStyle(.plain)
                        .padding(.leading, 4)
                    }
                }
            }
            .padding(.horizontal, fs * 0.6)
            .padding(.vertical, fs * 0.4)
            .minimumScaleFactor(0.8)
        }
        .overlay(Rectangle().stroke(Color.zGrid, lineWidth: 0.5))
    }

    private func label(_ s: String) -> some View {
        Text(s + ":").foregroundStyle(Color.zText2)
    }

    private var pillars: [String] { model.chart.chineseDate.split(separator: " ").map(String.init) }
    private var lunarPillars: [String] { Bazi.lunarPillars(lunarYear: model.chart.lunarYear, lunarMonth: model.chart.lunarMonth, jieqi: pillars) }
    private var dayStem: String { String(pillars.count > 2 ? pillars[2].prefix(1) : "") }
    private var hourBranch: Int { person.hour == 12 ? 0 : person.hour }
    private var ziDou: String { Bazi.ziDou(lunarMonth: model.chart.lunarMonth, hourBranch: hourBranch) }

    /// 出生的絕對時間：有鐘錶時間＋出生地就照用，否則以時辰中間點、台北時區估算
    private var birthDate: Date {
        let tz = TimeZone(identifier: person.place?.timeZoneID ?? "Asia/Taipei") ?? .current
        var cal = Calendar(identifier: .gregorian); cal.timeZone = tz
        let src = person.clock ?? "\(person.solar) \(person.hour == 12 ? 23 : person.hour * 2):00"
        let n = src.split(whereSeparator: { " -:".contains($0) }).compactMap { Int($0) }
        guard n.count >= 5 else { return Date() }
        return cal.date(from: DateComponents(year: n[0], month: n[1], day: n[2], hour: n[3], minute: n[4])) ?? Date()
    }
    private var birthYear: Int { Int(person.clock?.prefix(4) ?? person.solar.prefix(4)) ?? person.birthYear }
    private var qy: Bazi.Qiyun { Bazi.qiyun(birth: birthDate, yearStem: String(pillars.first?.prefix(1) ?? ""), male: person.gender == .male) }
    private var dayun: [String] { Bazi.dayun(monthPillar: pillars.count > 1 ? pillars[1] : "", forward: qy.forward) }

    private func pillarSet(_ title: String, _ p: [String]) -> some View {
        VStack(spacing: 1) {
            Text(title).font(ChartType.font(ChartType.meta(fs), .semibold)).foregroundStyle(Color.zText2)
            HStack(spacing: fs * 0.35) {
                ForEach(Array(p.enumerated()), id: \.offset) { _, gz in
                    VStack(spacing: 0) {
                        ForEach(Array(gz.enumerated()), id: \.offset) { _, ch in
                            Text(String(ch)).font(ChartType.font(ChartType.pillarSmall(fs))).foregroundStyle(ZW.wuxing(String(ch)).color)
                        }
                    }
                }
            }
        }
    }
}

/// 三方四正連線：四個錨點可以補間，換宮位時連線會滑過去而不是瞬間跳
struct Quad: VectorArithmetic {
    var v: [Double]
    init(_ pts: [(Double, Double)]) { v = pts.flatMap { [$0.0, $0.1] } }
    init(raw: [Double]) { v = raw }
    static var zero: Quad { Quad(raw: Array(repeating: 0, count: 8)) }
    static func + (a: Quad, b: Quad) -> Quad { Quad(raw: zip(a.padded, b.padded).map(+)) }
    static func - (a: Quad, b: Quad) -> Quad { Quad(raw: zip(a.padded, b.padded).map(-)) }
    mutating func scale(by r: Double) { v = padded.map { $0 * r } }
    var magnitudeSquared: Double { padded.reduce(0) { $0 + $1 * $1 } }
    private var padded: [Double] { v.count == 8 ? v : Array(repeating: 0, count: 8) }
    func point(_ i: Int, in r: CGRect) -> CGPoint { CGPoint(x: padded[i * 2] * r.width, y: padded[i * 2 + 1] * r.height) }
}

struct SanFangShape: Shape {
    var points: Quad
    var animatableData: Quad {
        get { points }
        set { points = newValue }
    }
    func path(in r: CGRect) -> Path {
        var p = Path()
        let a = points.point(0, in: r), b = points.point(1, in: r), c = points.point(2, in: r), d = points.point(3, in: r)
        p.addLines([a, b, c, a])
        p.move(to: a); p.addLine(to: d)
        return p
    }
}

/// 由左而右排、放不下就換行（星曜直排欄位用）
struct FlowLayout: Layout {
    var spacing: CGFloat = 2
    var lineSpacing: CGFloat = 2

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? .infinity
        var x: CGFloat = 0, y: CGFloat = 0, lineH: CGFloat = 0, maxX: CGFloat = 0
        for v in subviews {
            let s = v.sizeThatFits(.unspecified)
            if x > 0 && x + s.width > width { x = 0; y += lineH + lineSpacing; lineH = 0 }
            x += s.width + spacing; lineH = max(lineH, s.height); maxX = max(maxX, x)
        }
        return CGSize(width: min(maxX, width), height: y + lineH)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX, y = bounds.minY, lineH: CGFloat = 0
        for v in subviews {
            let s = v.sizeThatFits(.unspecified)
            if x > bounds.minX && x + s.width > bounds.maxX { x = bounds.minX; y += lineH + lineSpacing; lineH = 0 }
            v.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(s))
            x += s.width + spacing; lineH = max(lineH, s.height)
        }
    }
}
