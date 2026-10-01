import SwiftUI

/// 照文墨天機排的十二宮盤面（純 SwiftUI 繪製）
struct ChartBoard: View {
    let person: Person
    let chart: Chart
    let horo: Horoscope
    let level: Int
    @State private var sel: Int?

    var body: some View {
        let selected = sel ?? chart.soulIndex
        let sf = ZW.sanFang(selected)
        GeometryReader { geo in
            let m: CGFloat = 18
            let cw = (geo.size.width - m * 2) / 4
            let ch = (geo.size.height - m * 2) / 4
            let fs = max(10, min(16, cw / 13.5))
            ZStack(alignment: .topLeading) {
                ForEach(0..<12, id: \.self) { i in
                    let (r, c) = ZW.grid[i]
                    PalaceCell(chart: chart, horo: horo, index: i, level: level, fs: fs,
                               selected: selected == i, inSF: sf.contains(i) && selected != i,
                               flyIn: ZW.flying(chart, selected).filter { $0.to == i }.map(\.m))
                        .frame(width: cw, height: ch, alignment: .top)
                        .clipped()
                        .contentShape(Rectangle())
                        .onTapGesture { sel = i }
                        .offset(x: m + CGFloat(c) * cw, y: m + CGFloat(r) * ch)
                    compassLabel(i, r: r, c: c, cw: cw, ch: ch, m: m)
                }
                CenterInfo(person: person, chart: chart, selected: selected, fs: fs)
                    .frame(width: cw * 2, height: ch * 2)
                    .offset(x: m + cw, y: m + ch)
            }
        }
        .background(RoundedRectangle(cornerRadius: 12).fill(Color.zCard))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.zLine))
    }

    @ViewBuilder
    private func compassLabel(_ i: Int, r: Int, c: Int, cw: CGFloat, ch: CGFloat, m: CGFloat) -> some View {
        let text = Text(ZW.compass[i]).font(.system(size: 10)).foregroundStyle(Color.zText3)
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
    let chart: Chart
    let horo: Horoscope
    let index: Int
    let level: Int
    let fs: CGFloat
    let selected: Bool
    let inSF: Bool
    let flyIn: [Mutagen]

    var body: some View {
        let p = chart.palaces[index]
        let selfs = ZW.selfTransforms(chart, index)
        let curDecade = level >= 1 && horo.decadal.index == index
        VStack(alignment: .leading, spacing: 2) {
            FlowLayout(spacing: 1, lineSpacing: 4) {
                ForEach(p.stars, id: \.name) { s in
                    StarColumn(star: s, fs: fs, selfOut: selfs.out[s.name], selfIn: selfs.into[s.name],
                               scopes: (1...max(1, level)).compactMap { lv in
                                   level >= lv ? ZW.mutagen(in: horo.scope(lv).mutagen, star: s.name).map { (lv, $0) } : nil
                               })
                }
                ForEach(p.adj, id: \.name) { s in
                    VerticalText(s.name, size: fs - 3, color: .wmBlue)
                }
            }
            .frame(maxWidth: .infinity, minHeight: 0, maxHeight: .infinity, alignment: .topLeading)
            .clipped()
            .layoutPriority(-1)
            VStack(spacing: 0) {
                Text("流年: " + ZW.yearlyAges(chart, index).map(String.init).joined(separator: ","))
                Text("小限: " + p.ages.prefix(5).map(String.init).joined(separator: ","))
            }
            .font(.system(size: max(8.5, fs * 0.6)))
            .foregroundStyle(Color.zText2)
            .frame(maxWidth: .infinity)

            HStack(alignment: .bottom, spacing: 2) {
                VStack(alignment: .leading, spacing: 0) {
                    Text(p.boshi).foregroundStyle(Color.wmGreen)
                    Text(p.jiangqian)
                    Text(p.suiqian)
                }
                .font(.system(size: fs * 0.74))
                .foregroundStyle(Color.zText)
                Spacer(minLength: 0)
                VStack(spacing: 2) {
                    Text("\(p.range[0])~\(p.range[1])")
                        .font(curDecade ? .system(size: fs * 0.88).italic() : .system(size: fs * 0.88))
                        .underline(curDecade)
                        .foregroundStyle(curDecade ? Color.wmRed : Color.zText)
                    HStack(spacing: 3) {
                        ForEach(1..<(level + 1), id: \.self) { lv in
                            Text(ZW.scopeTags[lv - 1] + String(horo.scope(lv).palaceNames[index].prefix(1)))
                                .font(.system(size: fs * 0.7, weight: .semibold))
                                .foregroundStyle(Color.scopeColors[lv - 1])
                        }
                        Text(p.name).font(.system(size: fs)).foregroundStyle(Color.wmRed)
                    }
                }
                Spacer(minLength: 0)
                VStack(spacing: 0) {
                    VerticalText(p.changsheng, size: fs * 0.68, color: .zText2)
                        .padding(.bottom, 2)
                    Text(p.stem).font(.system(size: fs * 1.3))
                    Text(p.branch).font(.system(size: fs * 1.3))
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
            if p.isBody {
                VerticalText("身宮", size: fs * 0.7, color: .wmRed)
                    .padding(.vertical, 3).padding(.horizontal, 1)
                    .overlay(RoundedRectangle(cornerRadius: 3).stroke(Color.wmRed))
                    .padding(.trailing, 4)
            }
        }
        .overlay(alignment: .topTrailing) {
            if !flyIn.isEmpty {
                VStack(alignment: .trailing, spacing: 1) {
                    ForEach(flyIn, id: \.self) { m in
                        Text("→" + m.rawValue).font(.system(size: fs * 0.72, weight: .semibold)).foregroundStyle(m.color)
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
    let selfOut: Mutagen?
    let selfIn: Mutagen?
    let scopes: [(Int, Mutagen)]

    var body: some View {
        let tone = ZW.tone(star.type)
        VStack(spacing: 1) {
            VerticalText(star.name, size: fs, color: selfOut != nil ? .white : tone.color,
                         weight: star.type == "major" ? .semibold : .regular)
                .padding(.vertical, 1)
                .frame(width: fs * 1.18)
                .background(selfOut?.color ?? .clear)
                .overlay(selfIn.map { Rectangle().stroke($0.color, lineWidth: 1.5) })
            Text(star.brightness.isEmpty ? " " : star.brightness)
                .font(.system(size: fs * 0.68))
                .foregroundStyle(Color.zText2)
            if !star.mutagen.isEmpty {
                box(star.mutagen, fill: .wmRed)
            }
            ForEach(scopes, id: \.0) { lv, m in
                box(m.rawValue, stroke: Color.scopeColors[lv - 1])
            }
        }
        .frame(width: fs * 1.18)
    }

    private func box(_ t: String, fill: Color? = nil, stroke: Color? = nil) -> some View {
        Text(t)
            .font(.system(size: fs * 0.78, weight: .semibold))
            .foregroundStyle(fill != nil ? .white : (stroke ?? .zText))
            .frame(width: fs * 1.12, height: fs * 1.12)
            .background(fill ?? .clear)
            .overlay(stroke.map { Rectangle().stroke($0, lineWidth: 1) })
    }
}

private struct CenterInfo: View {
    let person: Person
    let chart: Chart
    let selected: Int
    let fs: CGFloat

    var body: some View {
        let pillars = chart.chineseDate.split(separator: " ").map(String.init)
        let yang = ["甲", "丙", "戊", "庚", "壬"].contains(String(pillars.first?.prefix(1) ?? ""))
        let flies = ZW.flying(chart, selected)
        ZStack {
            Canvas { ctx, size in
                let pts = ZW.sanFang(selected).map { CGPoint(x: ZW.anchor[$0].0 * size.width, y: ZW.anchor[$0].1 * size.height) }
                var tri = Path()
                tri.addLines([pts[0], pts[1], pts[2], pts[0]])
                tri.move(to: pts[0]); tri.addLine(to: pts[3])
                ctx.stroke(tri, with: .color(Color.zText3.opacity(0.7)), style: StrokeStyle(lineWidth: 1, dash: [5, 4]))
            }
            VStack(spacing: fs * 0.55) {
                Text("紫微斗數").font(.serif(fs * 1.45, .semibold)).tracking(2)
                Grid(alignment: .leading, horizontalSpacing: 8, verticalSpacing: 2) {
                    GridRow { label("姓名"); Text("\(person.name)　　\(yang ? "陽" : "陰")\(person.gender.rawValue)　\(chart.fiveElementsClass)") }
                    GridRow { label("國曆"); Text("\(chart.solarDate) \(ZW.hours[person.hour])時（\(chart.timeRange)）") }
                    GridRow { label("農曆"); Text("\(chart.lunarDate) \(chart.time)") }
                    GridRow { label("命主"); Text("\(chart.soul)　身主: \(chart.body)　生肖: \(chart.zodiac)") }
                }
                .font(.system(size: fs * 0.9))
                HStack(spacing: fs * 0.9) {
                    ForEach(Array(pillars.enumerated()), id: \.offset) { k, gz in
                        VStack(spacing: 0) {
                            ForEach(Array(gz.enumerated()), id: \.offset) { _, ch in
                                Text(String(ch)).font(.system(size: fs * 1.35)).foregroundStyle(ZW.wuxing(String(ch)).color)
                            }
                            Text(["年", "月", "日", "時"][k]).font(.system(size: fs * 0.62)).foregroundStyle(Color.zText3)
                        }
                    }
                }
                VStack(spacing: 3) {
                    Text("\(chart.palaces[selected].name)（\(chart.palaces[selected].stem)）飛化")
                        .font(.system(size: fs * 0.75)).foregroundStyle(Color.zText2)
                    HStack(spacing: 8) {
                        ForEach(flies, id: \.m) { f in
                            Text("\(f.star)\(f.m.rawValue)→\(f.to.map { chart.palaces[$0].name } ?? "—")")
                                .font(.system(size: fs * 0.75, weight: .medium)).foregroundStyle(f.m.color)
                        }
                    }
                }
                HStack(spacing: 4) {
                    Text("自化圖示:").font(.system(size: fs * 0.8))
                    ForEach(Mutagen.allCases, id: \.self) { m in
                        Text(m.rawValue).font(.system(size: fs * 0.8, weight: .semibold)).foregroundStyle(.white)
                            .padding(.horizontal, 3).background(m.color)
                    }
                    Text("實底＝離心　框線＝向心").font(.system(size: fs * 0.66)).foregroundStyle(Color.zText3)
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
