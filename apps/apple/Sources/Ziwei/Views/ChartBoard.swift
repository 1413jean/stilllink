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
                        Text(p.name).font(ChartType.font(ChartType.palace(fs))).foregroundStyle(Color.wmRed)
                    }
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
            .font(ChartType.font(ChartType.tag(fs), .semibold))
            .foregroundStyle(Color.zOnColor)
            .frame(width: fs * 1.0, height: fs * 1.0)
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
            VStack(spacing: fs * 0.55) {
                Text("紫微斗數").font(ChartType.font(ChartType.centerTitle(fs), .semibold)).tracking(2)
                Grid(alignment: .leading, horizontalSpacing: 8, verticalSpacing: 2) {
                    GridRow { label("姓名"); Text("\(person.name)　　\(yang ? "陽" : "陰")\(person.gender.rawValue)　\(chart.fiveElementsClass)") }
                    if let ts = person.trueSolar {
                        GridRow { label("真太陽時"); Text(ts) }
                        GridRow { label("鐘錶時間"); Text(person.clock ?? "") }
                    } else {
                        GridRow { label("國曆"); Text("\(chart.solarDate) \(ZW.hours[person.hour])時（\(chart.timeRange)）") }
                    }
                    GridRow { label("農曆"); Text("\(chart.lunarDate) \(chart.time)") }
                    GridRow { label("命主"); Text("\(chart.soul)　身主: \(chart.body)　生肖: \(chart.zodiac)") }
                    if let pl = person.place {
                        GridRow { label("出生地"); Text(pl.name.components(separatedBy: "，").first ?? pl.name).lineLimit(1) }
                    }
                }
                .font(ChartType.font(ChartType.centerBody(fs)))
                HStack(spacing: fs * 0.9) {
                    ForEach(Array(pillars.enumerated()), id: \.offset) { k, gz in
                        VStack(spacing: 0) {
                            ForEach(Array(gz.enumerated()), id: \.offset) { _, ch in
                                Text(String(ch)).font(ChartType.font(ChartType.pillar(fs))).foregroundStyle(ZW.wuxing(String(ch)).color)
                            }
                            Text(["年", "月", "日", "時"][k]).font(ChartType.font(ChartType.meta(fs))).foregroundStyle(Color.zText3)
                        }
                    }
                }
                VStack(spacing: 3) {
                    Text("\(chart.palaces[selected].name)（\(chart.palaces[selected].stem)）飛化")
                        .font(ChartType.font(ChartType.centerSmall(fs))).foregroundStyle(Color.zText2)
                    HStack(spacing: 8) {
                        ForEach(flies, id: \.m) { f in
                            Text("\(f.star)\(f.m.rawValue)→\(f.to.map { chart.palaces[$0].name } ?? "—")")
                                .font(ChartType.font(ChartType.centerSmall(fs), .medium)).foregroundStyle(f.m.color)
                        }
                    }
                }
                HStack(spacing: 4) {
                    Text("宮干四化:").font(ChartType.font(ChartType.centerSmall(fs)))
                    ForEach(Mutagen.allCases, id: \.self) { m in
                        Text(m.rawValue).font(ChartType.font(ChartType.centerSmall(fs), .semibold)).foregroundStyle(Color.zOnColor)
                            .padding(.horizontal, 3).background(m.color)
                    }
                    Text("↑離心自化　↓向心自化").font(ChartType.font(ChartType.meta(fs))).foregroundStyle(Color.zText3)
                }
                if level > 0 {
                    Button(action: onResetLevel) {
                        Label("回本命盤", systemImage: "arrow.uturn.backward")
                            .font(ChartType.font(ChartType.centerSmall(fs)))
                            .padding(.horizontal, 10).padding(.vertical, 4)
                            .background(Capsule().fill(Color.zHover))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(fs)
        }
        .overlay(Rectangle().stroke(Color.zGrid, lineWidth: 0.5))
    }

    private func label(_ s: String) -> some View {
        Text(s + ":").foregroundStyle(Color.zText2)
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
