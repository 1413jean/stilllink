import SwiftUI
import AppKit

/// 照文墨天機排的十二宮盤面（純 SwiftUI 繪製）
struct ChartBoard: View, Equatable {
    let person: Person
    let model: ChartModel
    let level: Int
    /// 放大倍率：直接用放大後的尺寸重新排版（字是向量，放大不會糊）
    var zoom: CGFloat = 1
    var onResetLevel: () -> Void = {}

    /// 只有資料真的換了才重畫（點運限表時，盤面不會先拿舊資料多畫一次）
    static func == (a: ChartBoard, b: ChartBoard) -> Bool {
        a.person == b.person && a.model.id == b.model.id && a.level == b.level && a.zoom == b.zoom
    }
    @State private var sel: Int?
    @State private var appeared = false
    @State private var locked: Int?    // 長按鎖定的宮位（比較兩組三方四正）
    @State private var taiji: Int?     // 轉宮：以這一宮為命
    @State private var userPicked = false   // 使用者自己點的宮位（自動跳到運限命宮時不算）
    @Environment(\.zSettings) private var settings

    var body: some View {
        let chart = model.chart
        let selected = sel ?? chart.soulIndex
        let sf = ZW.sanFang(selected)
        GeometryReader { geo in
            let m: CGFloat = 18 * zoom
            let cw = (geo.size.width - m * 2) / 4
            let ch = (geo.size.height - m * 2) / 4
            let fs = ChartType.base(cellWidth: cw / zoom) * zoom
            let lsf = locked.map(ZW.sanFang) ?? []
            ZStack(alignment: .topLeading) {
                ForEach(0..<12, id: \.self) { i in
                    let (r, c) = ZW.grid[i]
                    PalaceCell(model: model, index: i, level: level, fs: fs,
                               selected: selected == i, inSF: sf.contains(i) && selected != i,
                               isLocked: locked == i, inLockedSF: lsf.contains(i) && locked != i,
                               taijiLabel: effectiveTaiji(selected, chart).map { ZW.transferredName(taiji: $0, index: i, chart: chart) },
                               flyStars: Dictionary(model.flying[selected].map { ($0.star, $0.m) }, uniquingKeysWith: { a, _ in a }))
                        .frame(width: cw, height: ch, alignment: .top)
                        .clipped()
                        .contentShape(Rectangle())
                        // 長按：鎖定／解除；點一下：選宮位
                        .gesture(LongPressGesture(minimumDuration: 0.45).onEnded { _ in toggleLock(i, chart) }
                            .exclusively(before: TapGesture().onEnded { Sound.tap(settings); userPicked = true; withAnimation(Motion.snap) { sel = i } }))
                        .contextMenu {
                            if taiji == i {
                                Button("取消轉宮") { setTaiji(nil, chart) }
                            } else {
                                Button("以「\(chart.palaces[i].name)」為命（轉宮）") { setTaiji(i, chart) }
                                if taiji != nil { Button("取消轉宮") { setTaiji(nil, chart) } }
                            }
                            Divider()
                            Button(locked == i ? "解除鎖定" : "鎖定此宮三方四正") { toggleLock(i, chart) }
                        }
                        .enterFromBelow(appeared, index: r * 4 + c)
                        .offset(x: m + CGFloat(c) * cw, y: m + CGFloat(r) * ch)
                    if settings.showCompass { compassLabel(i, r: r, c: c, cw: cw, ch: ch, m: m) }
                    if settings.showSelf { selfArrows(model.selfs[i], r: r, c: c, cw: cw, ch: ch, m: m) }
                }
                CenterInfo(person: person, model: model, selected: selected, locked: locked, taiji: taiji,
                           fs: fs, level: level, onResetLevel: onResetLevel, onClearTaiji: { setTaiji(nil, chart) })
                    .enterFromBelow(appeared, index: 8)
                    .frame(width: cw * 2, height: ch * 2)
                    .offset(x: m + cw, y: m + ch)
            }
        }
        .background(RoundedRectangle(cornerRadius: 12).fill(Color.zCard))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.zLine))
        .onAppear { appeared = true; sel = focusIndex }
        // 切換大限／流年…時，自動選到那一層的命宮（大命、流命…），本命就回命宮
        .onChange(of: model.id) { _, _ in
            userPicked = false
            withAnimation(Motion.snap) { sel = focusIndex }
        }
    }

    /// 目前層級的命宮所在宮位
    private var focusIndex: Int {
        level == 0 ? model.chart.soulIndex : model.horo.scope(level).index
    }

    /// 轉宮的太極：右鍵指定的優先；否則點選的宮位（命宮本身不用顯示「命之X」）
    private func effectiveTaiji(_ selected: Int, _ chart: Chart) -> Int? {
        guard settings.showTransfer else { return nil }
        if let taiji { return taiji }
        return userPicked && selected != chart.soulIndex ? selected : nil
    }

    private func toggleLock(_ i: Int, _ chart: Chart) {
        NSHapticFeedbackManager.defaultPerformer.perform(.levelChange, performanceTime: .now)
        withAnimation(Motion.snap) {
            if locked != nil {
                locked = nil
                Toast.show("已解除鎖定")
            } else {
                locked = i
                Toast.show("已鎖定「\(chart.palaces[i].name)」三方四正，點其他宮位比較；長按解除")
            }
        }
    }

    private func setTaiji(_ i: Int?, _ chart: Chart) {
        withAnimation(Motion.base) { taiji = i }
        if let i { Toast.show("轉宮：以「\(chart.palaces[i].name)」為命") } else { Toast.show("已取消轉宮") }
    }

    /// 自化箭頭（照文墨天機）：畫在宮位外緣的留白處，離心朝外、向心朝內，顏色＝四化
    @ViewBuilder
    private func selfArrows(_ s: (out: [String: Mutagen], into: [String: Mutagen]), r: Int, c: Int, cw: CGFloat, ch: CGFloat, m: CGFloat) -> some View {
        let marks = s.out.sorted { $0.key < $1.key }.map { ($0.value, true) } + s.into.sorted { $0.key < $1.key }.map { ($0.value, false) }
        if !marks.isEmpty {
            // 朝外的方向：上排往上、下排往下、左欄往左、右欄往右；角落斜向
            let dx: CGFloat = c == 0 ? -1 : c == 3 ? 1 : 0
            let dy: CGFloat = r == 0 ? -1 : r == 3 ? 1 : 0
            let x0 = m + CGFloat(c) * cw, y0 = m + CGFloat(r) * ch
            // 錨點：外緣上避開方位字（邊宮放在靠內的 1/4 處，角宮放在外角）
            let ax = dx < 0 ? x0 : dx > 0 ? x0 + cw : x0 + cw * (c == 1 ? 0.78 : 0.22)
            let ay = dy < 0 ? y0 : dy > 0 ? y0 + ch : y0 + ch * (r == 1 ? 0.78 : 0.22)
            let angle = atan2(dy, dx)
            // 沿外緣切線方向排開
            let tx = dy == 0 ? 0 : 1.0, ty = dy == 0 ? 1.0 : 0
            ForEach(Array(marks.enumerated()), id: \.offset) { k, mk in
                let off = (CGFloat(k) - CGFloat(marks.count - 1) / 2) * 13
                Image(systemName: "arrow.right")
                    .font(.system(size: 11, weight: .heavy))
                    .foregroundStyle(mk.0.color)
                    .rotationEffect(.radians(Double(angle) + (mk.1 ? 0 : .pi)))
                    .frame(width: 14, height: 14)
                    .position(x: ax + dx * m * 0.5 + tx * off, y: ay + dy * m * 0.5 + ty * off)
                    .help(mk.1 ? "離心自化\(mk.0.rawValue)" : "向心自化\(mk.0.rawValue)")
            }
        }
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
    /// 一個 Text 換行排直（不用每個字一個 Text，盤面上上百個字時差很多）
    var body: some View {
        Text(text.map(String.init).joined(separator: "\n"))
            .font(ChartType.font(size, weight))
            .foregroundStyle(color)
            .multilineTextAlignment(.center)
            .lineSpacing(-size * 0.18)
            .fixedSize()
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
    let isLocked: Bool
    let inLockedSF: Bool
    let taijiLabel: String?
    let flyStars: [String: Mutagen]

    var body: some View {
        let chart = model.chart, horo = model.horo
        let p = chart.palaces[index]
        let curDecade = level >= 1 && horo.decadal.index == index
        let minor = level >= 2 && settings.showMinor
        // 來因宮：生年天干所在的宮（寅～亥，子丑與寅卯同干不算）
        let laiyin = settings.showLaiyin && index < 10 && p.stem == String(chart.chineseDate.prefix(1))
        VStack(alignment: .leading, spacing: 2) {
            // 放不下時先縮雜曜，再一起縮主星與四化，選第一個塞得下的
            ViewThatFits(in: .vertical) {
                ForEach(Array([(1.0, 1.0), (1.0, 0.78), (0.86, 0.68), (0.74, 0.62)].enumerated()), id: \.offset) { _, k in
                    starFlow(p: p, horo: horo, minor: minor, f: fs * k.0, adjF: ChartType.adj(fs) * k.1)
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
                        .lineLimit(1).fixedSize()
                    // 運限宮名垂直往上疊在宮名上面（由下而上：宮名、大X、年X），一欄三行；
                    // 疊滿往左開新欄（月X、日X、時X），由右至左。小限緊貼在宮名右邊。
                    let tags: [(String, Color)] = (1..<(level + 1)).map { lv in
                        (ZW.scopeTags[lv - 1] + String(horo.scope(lv).palaceNames[index].prefix(1)), Color.scopeColors[lv - 1])
                    }
                    let first = Array(tags.prefix(2))              // 跟宮名同一欄
                    let rest = Array(tags.dropFirst(2))            // 往左的欄，每欄 3 個
                    let restCols = stride(from: 0, to: rest.count, by: 3).map { Array(rest[$0..<min($0 + 3, rest.count)]) }
                    HStack(alignment: .bottom, spacing: 4) {
                        if let taijiLabel {
                            Text(taijiLabel).font(ChartType.font(ChartType.tag(fs) + 1)).foregroundStyle(Color.mQuan)
                                .lineLimit(1).fixedSize()
                        }
                        // 越後面的欄越靠左
                        ForEach(Array(restCols.enumerated().reversed()), id: \.offset) { _, col in
                            VStack(spacing: 0) {
                                ForEach(Array(col.enumerated().reversed()), id: \.offset) { _, t in tagLine(t.0, t.1) }
                            }
                        }
                        VStack(alignment: .nameCenter, spacing: 0) {
                            ForEach(Array(first.enumerated().reversed()), id: \.offset) { _, t in
                                tagLine(t.0, t.1).alignmentGuide(.nameCenter) { $0[HorizontalAlignment.center] }
                            }
                            HStack(spacing: 3) {
                                Text(p.name).font(ChartType.font(ChartType.palace(fs))).foregroundStyle(Color.wmRed)
                                    .lineLimit(1).fixedSize()
                                    .alignmentGuide(.nameCenter) { $0[HorizontalAlignment.center] }
                                if minor {
                                    tagLine("小" + String(horo.age.palaceNames[index].prefix(1)), .minorColor)
                                }
                                if laiyin {
                                    Text("來因").font(ChartType.font(ChartType.meta(fs), .semibold)).foregroundStyle(Color.zOnColor)
                                        .padding(.horizontal, 2).background(RoundedRectangle(cornerRadius: 2).fill(Color.wmRed))
                                        .fixedSize()
                                }
                            }
                        }
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
        .background(selected ? Color.wmSel : inSF || inLockedSF ? Color.wmSF : Color.clear)   // 鎖定那組只靠框線區分，底色一樣用三方灰
        .overlay(Rectangle().stroke(Color.zGrid, lineWidth: 0.5))
        // 鎖定的宮位：粗實線；它的三方四正：細一點的強調色邊框
        .overlay(isLocked ? Rectangle().strokeBorder(Color.zAccent, lineWidth: 3) : nil)
        .overlay(inLockedSF ? Rectangle().strokeBorder(Color.zAccent.opacity(0.8), lineWidth: 1.6) : nil)
        .overlay(selected ? Rectangle().stroke(Color.zAccent, lineWidth: 1.5) : nil)
        .overlay(alignment: .topLeading) {
            if isLocked {
                Image(systemName: "lock.fill").font(.system(size: max(8, fs * 0.6))).foregroundStyle(Color.zAccent).padding(3)
            }
        }
        .overlay(alignment: .trailing) {
            if p.isBody && settings.showBody {
                VerticalText("身宮", size: ChartType.tag(fs), color: .wmRed)
                    .padding(.vertical, 3).padding(.horizontal, 1)
                    .overlay(RoundedRectangle(cornerRadius: 3).stroke(Color.wmRed))
                    .padding(.trailing, 4)
            }
        }
        .clipped()
    }
}

/// 讓運限宮名對齊宮名的中線
extension HorizontalAlignment {
    private enum NameCenter: AlignmentID {
        static func defaultValue(in d: ViewDimensions) -> CGFloat { d[HorizontalAlignment.center] }
    }
    static let nameCenter = HorizontalAlignment(NameCenter.self)
}

extension PalaceCell {
    func tagLine(_ t: String, _ c: Color) -> some View {
        Text(t).font(ChartType.font(ChartType.tag(fs), .semibold)).foregroundStyle(c).lineLimit(1).fixedSize()
    }

    func starFlow(p: Palace, horo: Horoscope, minor: Bool, f: CGFloat, adjF: CGFloat) -> some View {
        FlowLayout(spacing: 1, lineSpacing: 4) {
            ForEach(p.stars, id: \.name) { s in
                StarColumn(star: s, fs: f, fly: flyStars[s.name],

                           minor: minor && settings.showMinorMutagen ? ZW.mutagen(in: horo.age.mutagen, star: s.name) : nil,
                           scopes: (1...max(1, level)).compactMap { lv in
                               level >= lv ? ZW.mutagen(in: horo.scope(lv).mutagen, star: s.name).map { (lv, $0) } : nil
                           })
            }
            ForEach(settings.showAdj ? p.adj : [], id: \.name) { s in
                VerticalText(s.name, size: adjF, color: .wmBlue)
            }
        }
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
        let (main, side) = columns
        let two = !main.isEmpty && !side.isEmpty
        let size: CGFloat = two ? 0.95 : 1.12
        // 星名對齊右邊那一欄（本命＋大限）；流年以後的四化排在左邊另一欄
        VStack(alignment: .trailing, spacing: 0.5) {
            VStack(spacing: 0.5) {
                VerticalText(star.name, size: ChartType.star(fs), color: fly != nil ? .zOnColor : tone.color,
                             weight: star.type == "major" ? .semibold : .regular)
                    .padding(.vertical, 1)
                    .frame(width: fs * 1.18)
                    .background(fly?.fill ?? .clear)
                Text(star.brightness.isEmpty ? " " : star.brightness)
                    .font(ChartType.font(ChartType.meta(fs)))
                    .foregroundStyle(Color.zText2)
            }
            .frame(width: fs * 1.18)
            HStack(alignment: .top, spacing: 1) {
                if two {
                    VStack(spacing: 1) { ForEach(Array(side.enumerated()), id: \.offset) { _, b in box(b.0, fill: b.1, size: size) } }
                }
                VStack(spacing: 1) {
                    ForEach(Array((two ? main : main + side).enumerated()), id: \.offset) { _, b in box(b.0, fill: b.1, size: size) }
                }
                .frame(width: fs * 1.18)
            }
        }
        .frame(minWidth: fs * 1.18)
    }

    /// 四化方塊分兩欄：主欄＝生年、大限（直排在星名下）；側欄＝小限、流年、流月、流日、流時
    private var columns: ([(String, Color)], [(String, Color)]) {
        var main: [(String, Color)] = [], side: [(String, Color)] = []
        if !star.mutagen.isEmpty { main.append((star.mutagen, .fBirth)) }
        if let minor { side.append((minor.rawValue, .fMinor)) }
        for (lv, m) in scopes {
            if lv == 1 { main.append((m.rawValue, Color.fScopes[0])) } else { side.append((m.rawValue, Color.fScopes[lv - 1])) }
        }
        return (main, side)
    }

    private func box(_ t: String, fill: Color, size: CGFloat = 1.12) -> some View {
        Text(t)
            .font(ChartType.font(fs * size * 0.8))
            .foregroundStyle(Color.zOnColor)
            .frame(width: fs * size, height: fs * size)
            .background(fill)
    }
}

private struct CenterInfo: View {
    @Environment(\.zSettings) private var settings
    @AppStorage("hideBirth") private var hideBirth = false
    private func mask(_ s: String) -> String { hideBirth ? "••••••" : s }
    let person: Person
    let model: ChartModel
    let selected: Int
    let locked: Int?
    let taiji: Int?
    let fs: CGFloat
    let level: Int
    let onResetLevel: () -> Void
    let onClearTaiji: () -> Void

    var body: some View {
        let chart = model.chart
        let pillars = chart.chineseDate.split(separator: " ").map(String.init)
        let yang = ["甲", "丙", "戊", "庚", "壬"].contains(String(pillars.first?.prefix(1) ?? ""))
        let flies = model.flying[selected]
        ZStack {
            SanFangShape(points: Quad(ZW.sanFang(selected).map { ZW.anchor[$0] }))
                .stroke(Color.zText3.opacity(0.7), style: StrokeStyle(lineWidth: 1, dash: [5, 4]))
                .opacity(settings.showSanfang ? 1 : 0)
            if let locked {
                SanFangShape(points: Quad(ZW.sanFang(locked).map { ZW.anchor[$0] }))
                    .stroke(Color.zAccent, style: StrokeStyle(lineWidth: 2.6, lineCap: .round, dash: [7, 4]))
                    .transition(.opacity)
            }
            VStack(spacing: fs * 0.32) {
                Text("紫微斗數").font(ChartType.font(ChartType.centerTitle(fs), .semibold)).tracking(2)
                Grid(alignment: .leading, horizontalSpacing: 6, verticalSpacing: 1) {
                    GridRow { label("姓名"); Text("\(person.name)　　\(yang ? "陽" : "陰")\(person.gender.rawValue)　\(chart.fiveElementsClass)") }
                    if let ts = person.trueSolar {
                        GridRow { label("真太陽時"); Text(mask(ts)) }
                        GridRow { label("鐘錶時間"); Text(mask(person.clock ?? "")) }
                    } else {
                        GridRow { label("國曆"); Text(mask("\(chart.solarDate) \(ZW.hours[person.hour])時（\(chart.timeRange)）")) }
                    }
                    GridRow { label("農曆"); Text(mask("\(chart.lunarDate) \(chart.time)")) }
                    GridRow { label("命主"); Text("\(chart.soul)　身主: \(chart.body)　子斗: \(ziDou)") }
                }
                .font(ChartType.font(ChartType.centerBody(fs)))

                // 隱藏生辰時：四柱、起運、大運都不顯示（看得出出生時間）
                if hideBirth {
                    Label("生辰已隱藏（四柱、起運、大運）", systemImage: "eye.slash")
                        .font(ChartType.font(ChartType.centerSmall(fs)))
                        .foregroundStyle(Color.zText3)
                        .padding(.vertical, fs * 0.6)
                } else {
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
                }

                // 點選宮位的宮干飛化（一行）
                HStack(spacing: 6) {
                    Text("\(chart.palaces[selected].name)\(chart.palaces[selected].stem)干：")
                        .font(ChartType.font(ChartType.centerSmall(fs))).foregroundStyle(Color.zText2)
                    ForEach(flies, id: \.m) { f in
                        Text("\(f.star)\(f.m.rawValue)")
                            .font(ChartType.font(ChartType.centerSmall(fs), .medium)).foregroundStyle(f.m.color)
                    }
                }
                .lineLimit(1).minimumScaleFactor(0.7)
                HStack(spacing: 4) {
                    ForEach(Mutagen.allCases, id: \.self) { m in
                        Text(m.rawValue).font(ChartType.font(ChartType.centerSmall(fs))).foregroundStyle(Color.zOnColor)
                            .padding(.horizontal, 3).background(m.fill)
                    }
                    Text("自化：↑離心 ↓向心").font(ChartType.font(ChartType.meta(fs))).foregroundStyle(Color.zText3)
                    if let taiji {
                        Button(action: onClearTaiji) {
                            Label("轉宮：\(chart.palaces[taiji].name)為命", systemImage: "xmark")
                                .font(ChartType.font(ChartType.meta(fs)))
                                .foregroundStyle(Color.zAccent)
                                .padding(.horizontal, 8).padding(.vertical, 2)
                                .background(Capsule().fill(Color.zAccent.opacity(0.12)))
                        }
                        .buttonStyle(.plain)
                        .padding(.leading, 4)
                    }
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

    private var bz: BaziInfo { model.bazi }
    private var pillars: [String] { bz.pillars }
    private var lunarPillars: [String] { bz.lunarPillars }
    private var dayStem: String { bz.dayStem }
    private var ziDou: String { bz.ziDou }
    private var birthYear: Int { bz.birthYear }
    private var qy: Bazi.Qiyun { bz.qiyun }
    private var dayun: [String] { bz.dayun }

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
