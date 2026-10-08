import SwiftUI

/// 照文墨天機排的十二宮盤面（純 SwiftUI 繪製）
struct ChartBoard: View, Equatable {
    let person: Person
    let model: ChartModel
    let level: Int
    /// 放大倍率：直接用放大後的尺寸重新排版（字是向量，放大不會糊）
    var zoom: CGFloat = 1
    /// 合盤（對方出生年）；nil＝沒合盤
    var hepan: Hepan? = nil
    var onResetLevel: () -> Void = {}
    /// 選取的宮位變了（nil＝取消選取），給右側星曜筆記用
    var onSelect: (Int?) -> Void = { _ in }
    /// 外圈留給自化箭頭的寬度（iPhone 螢幕窄，傳小一點）
    var margin: CGFloat = 14
    /// true＝整張盤（含外圈）放在一張卡片裡（Mac）；false＝不要外框卡片，只有十二宮格本身圓角＋細框（iPhone）
    var outerCard = true

    /// 只有資料真的換了才重畫（點運限表時，盤面不會先拿舊資料多畫一次）
    static func == (a: ChartBoard, b: ChartBoard) -> Bool {
        samePerson(a.person, b.person) && a.model.id == b.model.id && a.level == b.level && a.zoom == b.zoom && a.hepan == b.hepan
    }
    /// 「此刻」盤每分鐘換一次鐘錶時間，但盤面用不到它（只有換時辰才變）：不要因此整盤重畫
    /// （每分鐘整盤重畫，在部分外接螢幕上會留下綠色殘點）
    private static func samePerson(_ a: Person, _ b: Person) -> Bool {
        guard a.id == Person.nowID, b.id == Person.nowID else { return a == b }
        var x = a, y = b
        x.clock = nil; y.clock = nil
        return x == y
    }
    @State private var sel: Int?
    @State private var appeared = false
    @State private var locked: Int?    // 長按鎖定的宮位（比較兩組三方四正）
    @State private var taiji: Int?     // 轉宮：以這一宮為命
    @State private var userPicked = false   // 使用者自己點的宮位（自動跳到運限命宮時不算）
    @State private var pickedLayers: [Int]?   // 中宮層級開關：使用者點過的層（0 本命、1 大限…5 流時），nil＝預設最近三層
    @EnvironmentObject private var store: Store
    @State private var hoverStar: StarHoverInfo?
    @State private var hoverTask: Task<Void, Never>?
    @State private var hoverKey: (String, String)?   // 目前滑鼠停的星與宮（同一顆星上移動不重設計時）
    @State private var lastTap: (Int, Date)?   // 上一次點的宮位與時間（判斷點兩下）
    @State private var cleared = false      // 再點一次已選的宮位＝取消選取（不顯示三方四正、飛化）
    @State private var squeeze: CGFloat = 0 // 夾宮：點到被夾的宮位時，兩個鄰宮輕輕撞進來再彈回（0～1，撞完回 0）；本宮不動
    @Environment(\.zSettings) private var settings

    var body: some View {
        let chart = model.chart
        let selected = sel ?? chart.soulIndex
        let sf = cleared ? [] : ZW.sanFang(selected)
        let clamps = settings.showClamp && !cleared ? ZW.clamps(chart, horo: model.horo, center: selected, level: settings.clampByScope ? level : 0, hepan: hepan) : []
        GeometryReader { geo in
            let m: CGFloat = margin * zoom   // 外圈留給自化箭頭；縮小一點讓宮格大一點
            let cw = (geo.size.width - m * 2) / 4
            let ch = (geo.size.height - m * 2) / 4
            let fs = ChartType.base(cellWidth: cw / zoom) * zoom
            let lsf = locked.map(ZW.sanFang) ?? []
            ZStack(alignment: .topLeading) {
                ForEach(0..<12, id: \.self) { i in
                    let (r, c) = ZW.grid[i]
                    PalaceCell(model: model, index: i, level: level, layers: layers, fs: fs, hepan: hepan,
                               selected: !cleared && selected == i, inSF: sf.contains(i) && selected != i,
                               isLocked: locked == i, inLockedSF: lsf.contains(i) && locked != i,
                               taijiLabel: effectiveTaiji(selected, chart).map { ZW.transferredName(taiji: $0, index: i, chart: chart, names: scopeNames) },
                               flyStars: cleared ? [:] : Dictionary(model.flying[selected].map { ($0.star, $0.m) }, uniquingKeysWith: { a, _ in a }))
                        .frame(width: cw, height: ch, alignment: .top)
                        .clipped()
                        .contentShape(Rectangle())
                        // 長按或點兩下：鎖定／解除；點一下：選宮位（單擊不等雙擊判定，選取不會慢半拍）
                        .gesture(LongPressGesture(minimumDuration: 0.45).onEnded { _ in toggleLock(i, chart) }
                            .exclusively(before: TapGesture().onEnded {
                                // 同一宮在系統雙擊間隔內點第二下＝點兩下：鎖定（不是取消選取）
                                let now = Date()
                                if let (j, t) = lastTap, j == i, now.timeIntervalSince(t) < Platform.doubleTapInterval {
                                    lastTap = nil
                                    withAnimation(Motion.snap) { cleared = false; sel = i }
                                    toggleLock(i, chart)
                                    return
                                }
                                lastTap = (i, now)
                                Sound.tap(settings); userPicked = true
                                withAnimation(Motion.snap) {
                                    if !cleared && selected == i { cleared = true } else { cleared = false; sel = i }
                                }
                            }))
                        .contextMenu {
                            // 轉宮中（右鍵指定或點宮位產生的 X之Y）都可以取消
                            let transferring = effectiveTaiji(selected, chart) != nil
                            if taiji != i {
                                Button("以「\(chart.palaces[i].name)」為命（轉宮）") { setTaiji(i, chart) }
                            }
                            if transferring { Button("取消轉宮") { setTaiji(nil, chart) } }
                            Divider()
                            Button(locked == i ? "解除鎖定" : "鎖定此宮三方四正") { toggleLock(i, chart) }
                        }
                        .enterFromBelow(appeared, index: r * 4 + c)
                        .modifier(ClampSqueeze(on: !clamps.isEmpty, index: i, selected: selected, amount: squeeze))
                        .offset(x: m + CGFloat(c) * cw, y: m + CGFloat(r) * ch)
                    if settings.showSelf { selfArrows(model.selfs[i], r: r, c: c, cw: cw, ch: ch, m: m) }
                }
                // 沒有外框卡片時：宮格四角修成圓角（蓋掉方格露出的角）＋細框
                if !outerCard {
                    let gw = geo.size.width - m * 2, gh = geo.size.height - m * 2
                    GridCorners(radius: 12)
                        .fill(Color.zBg, style: FillStyle(eoFill: true))
                        .frame(width: gw, height: gh)
                        .offset(x: m, y: m)
                        .allowsHitTesting(false)
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(Color.zLine)
                        .frame(width: gw, height: gh)
                        .offset(x: m, y: m)
                        .allowsHitTesting(false)
                }
                // 夾宮提示：選到的宮位被左右鄰宮夾時，交界線上各壓一個指向它的雙箭頭；換宮位就重播
                if !clamps.isEmpty {
                    Group {
                        if settings.clampStyle == .frame {
                            ClampFrameOverlay(clamps: clamps, selected: selected, m: m, cw: cw, ch: ch, boardSize: geo.size, fs: fs)
                        } else {
                            ClampOverlay(clamps: clamps, selected: selected, m: m, cw: cw, ch: ch, boardSize: geo.size, fs: fs)
                        }
                    }
                    .id("\(selected)-\(level)-\(settings.clampStyle)-\(clamps.map(\.name).joined())")
                }
                CenterInfo(person: person, model: model, selected: selected, cleared: cleared, locked: locked, taiji: taiji,
                           fs: fs, level: level, layers: layers, onToggleLayer: toggleLayer,
                           onToggleMinor: { withAnimation(Motion.fast) { store.settings.showMinorOverlay.toggle() } },
                           onResetLevel: onResetLevel, onClearTaiji: { setTaiji(nil, chart) })
                    .enterFromBelow(appeared, index: 8)
                    .frame(width: cw * 2, height: ch * 2)
                    .offset(x: m + cw, y: m + ch)
                // 滑鼠停在星曜上：深色小卡顯示這顆星落在這一宮的重點（正式版也有；筆記頁本身只開在測試版）
                if let h = hoverStar {
                    let shown = hoverPalace(h.palace)
                    StarHoverCard(key: h.key, palaceName: shown.name, label: shown.label)
                        .offset(x: min(h.rect.maxX + 6, geo.size.width - 246), y: max(4, h.rect.minY))
                        .transition(.opacity)
                }
            }
            .coordinateSpace(name: "board")
            .environment(\.starHover, { info in setHover(info) })
        }
        .background {
            if outerCard {
                RoundedRectangle(cornerRadius: 12).fill(Color.zCard)
            } else {
                GeometryReader { g in
                    let m = margin * zoom
                    RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Color.zCard)
                        .frame(width: g.size.width - m * 2, height: g.size.height - m * 2)
                        .offset(x: m, y: m)
                }
            }
        }
        .overlay { if outerCard { RoundedRectangle(cornerRadius: 12).stroke(Color.zLine) } }
        .onAppear {
            appeared = true; sel = focusIndex; onSelect(focusIndex)
            // 驗證用：ZIWEI_PICK=宮位編號 直接當成使用者點了那一宮
            if let v = ProcessInfo.processInfo.environment["ZIWEI_PICK"].flatMap(Int.init) {
                let wait = ProcessInfo.processInfo.environment["ZIWEI_PICK_DELAY"].flatMap(Double.init) ?? 1.2   // 錄動畫時延後點，先開始錄
                DispatchQueue.main.asyncAfter(deadline: .now() + wait) { userPicked = true; sel = v; onSelect(v) }
            }
        }
        .onChange(of: cleared ? -1 : (sel ?? model.chart.soulIndex)) { _, v in
            onSelect(v < 0 ? nil : v)
            // 選到被夾的宮位：鄰宮撞一下（加速衝進來、碰到就彈回去）
            guard v >= 0, settings.showClamp, settings.clampStyle == .arrows, !Motion.reduce,
                  !ZW.clamps(model.chart, horo: model.horo, center: v, level: settings.clampByScope ? level : 0, hepan: hepan).isEmpty else { return }
            withAnimation(.easeIn(duration: 0.09)) { squeeze = 1 }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.09) {
                withAnimation(.spring(response: 0.36, dampingFraction: 0.36)) { squeeze = 0 }   // 碰到後往外彈一點再回來（2026-10 Jean：彈跳小一點）
            }
        }
        // 切換大限／流年…時，自動選到那一層的命宮（大命、流命…），本命就回命宮
        // 新命宮的位置直接放進偵測的值裡：macOS 13 的 onChange 拿到的是上一次的 model，不能在裡面再算
        .onChange(of: level) { _, _ in pickedLayers = nil }   // 換層級就回到預設的最近三層
        .onChange(of: FocusKey(model: model.id, focus: focusIndex)) { _, k in
            userPicked = false
            withAnimation(Motion.snap) { cleared = false; sel = k.focus }
        }
    }

    private struct FocusKey: Equatable { let model: UUID; let focus: Int }

    /// 目前層級的命宮所在宮位
    private var focusIndex: Int {
        level == 0 ? model.chart.soulIndex : model.horo.scope(level).index
    }

    /// 轉宮的太極：右鍵指定的優先；否則點選的宮位（命宮本身不用顯示「命之X」）
    private func effectiveTaiji(_ selected: Int, _ chart: Chart) -> Int? {
        guard settings.showTransfer else { return nil }
        if let taiji { return taiji }
        return userPicked && selected != focusIndex ? selected : nil   // 目前層級的命宮（大命、流命）本身不用轉
    }

    /// 目前要顯示四化的層（最多三層，由小到大）
    private var layers: [Int] {
        let base = pickedLayers ?? Array(max(0, level - 2)...level)
        return base.filter { $0 <= level }.sorted()
    }

    /// 點層級開關：開過的關掉；沒開的打開，超過三層就把最早開的那層關掉
    private func toggleLayer(_ lv: Int) {
        var cur = pickedLayers ?? Array(max(0, level - 2)...level)
        cur = cur.filter { $0 <= level }
        if let i = cur.firstIndex(of: lv) { cur.remove(at: i) } else { cur.append(lv); if cur.count > 3 { cur.removeFirst() } }
        withAnimation(Motion.fast) { pickedLayers = cur }
    }

    /// hover 說明要用的宮位：設定開著且選到運限時，用那一層在這一宮的宮名（例：本命田宅 → 大官祿）
    private func hoverPalace(_ natal: String) -> (name: String, label: String) {
        guard settings.hoverByScope, level >= 1, let names = scopeNames,
              let i = model.chart.palaces.firstIndex(where: { $0.name == natal }), names.indices.contains(i) else { return (natal, natal) }
        let name = names[i]
        return (name, ZW.scopeTags[level - 1] + name)
    }

    /// 目前層級的宮名：本命用本命宮名；選了大限、流年…用那一層的宮名
    private var scopeNames: [String]? { level == 0 ? nil : model.horo.scope(level).palaceNames }

    /// 停 0.35 秒才出現，滑過去不會一直閃
    private func setHover(_ info: StarHoverInfo?) {
        // 滑鼠在同一顆星上移動：維持原本的計時，不重設
        if let info, info.key == hoverKey?.0, info.palace == hoverKey?.1 { return }
        hoverTask?.cancel()
        hoverKey = info.map { ($0.key, $0.palace) }
        guard let info, StarNotes.shared.hasNote(info.key) else {
            if hoverStar != nil { withAnimation(Motion.fast) { hoverStar = nil } }
            return
        }
        hoverTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 350_000_000)
            guard !Task.isCancelled else { return }
            withAnimation(Motion.fast) { hoverStar = info }
        }
    }

    private func toggleLock(_ i: Int, _ chart: Chart) {
        Platform.haptic(.levelChange)
        withAnimation(Motion.snap) {
            if locked != nil {
                locked = nil
                Toast.show("已解除鎖定")
            } else {
                locked = i
                Toast.show("已鎖定「\(chart.palaces[i].name)」三方四正，點其他宮位比較；長按或點兩下解除")
            }
        }
    }

    private func setTaiji(_ i: Int?, _ chart: Chart) {
        withAnimation(Motion.base) { taiji = i; if i == nil { userPicked = false } }
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
            }
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
    /// 直排用的字串：每個字一行
    static func join(_ t: String) -> String { t.map(String.init).joined(separator: "\n") }

    /// 一個 Text 換行排直（不用每個字一個 Text，盤面上上百個字時差很多）
    var body: some View {
        Text(Self.join(text))
            .font(ChartType.font(size, weight))
            .foregroundStyle(color)
            .multilineTextAlignment(.center)
            .lineSpacing(-size * 0.18)
            .fixedSize()
    }
}

private struct PalaceCell: View {
    @Environment(\.zSettings) private var settings
    @Environment(\.displayScale) private var displayScale
    let model: ChartModel
    let index: Int
    let level: Int
    var layers: [Int] = []
    let fs: CGFloat
    let hepan: Hepan?
    let selected: Bool
    let inSF: Bool
    let isLocked: Bool
    let inLockedSF: Bool
    let taijiLabel: String?
    let flyStars: [String: Mutagen]

    /// 目前大限裡，流年走到這一宮的那一年與虛歲
    private var decadeYearAge: (year: Int, age: Int)? {
        let r = model.chart.palaces[model.horo.decadal.index].range
        guard r.count == 2, let first = model.yearlyAges[index].first else { return nil }
        guard let age = (r[0]...r[1]).first(where: { ($0 - first) % 12 == 0 && $0 >= first }) else { return nil }
        return (model.bazi.birthYear + age - 1, age)
    }

    /// 流月：這一宮是流年的哪個農曆月＋月干。流年斗君＝子斗順數到流年地支，從那宮起正月順排；月干用五虎遁由流年天干推
    private var monthLabel: String? {
        guard level >= 2 else { return nil }   // 選到流年以後才顯示
        #if os(iOS)
        // iPhone 宮格窄：選到流月以後，同一個位置改放「月X」宮名（照文墨天機），兩個疊在一起會重疊
        guard level == 2 else { return nil }
        #endif
        let b = ZW.branches
        guard let dou = b.firstIndex(of: model.bazi.ziDou),
              let yb = b.firstIndex(of: model.horo.yearly.branch),
              let ys = ZW.stems.firstIndex(of: model.horo.yearly.stem),
              let pb = b.firstIndex(of: model.chart.palaces[index].branch) else { return nil }
        let douJun = (dou + yb) % 12
        let m = (pb - douJun + 12) % 12 + 1
        return ZW.lunarMonths[m - 1] + ZW.stems[((ys % 5) * 2 + 2 + m - 1) % 10]
    }

    var body: some View {
        let chart = model.chart, horo = model.horo
        let p = chart.palaces[index]
        let curDecade = level >= 1 && horo.decadal.index == index
        let minor = level >= 2 && settings.showMinorOverlay
        // 來因宮：生年天干所在的宮（寅～亥，子丑與寅卯同干不算）
        let laiyin = settings.showLaiyin && index < 10 && p.stem == String(chart.chineseDate.prefix(1))
        VStack(alignment: .leading, spacing: 2) {
            // 第一行：左上合盤宮名（合命、合兄…）、右上地理方位
            // 來因也放這一行（放底部會跟運限宮名、干支擠在一起）
            let hn = hepan?.palaceName(at: p.branch)
            if hn != nil || settings.showCompass || laiyin {
                HStack(spacing: 3) {
                    if let hn { Text(hn).font(ChartType.font(ChartType.tag(fs), .semibold)).foregroundStyle(Color.wmEarth) }
                    if laiyin {
                        Text("來因").font(ChartType.font(ChartType.meta(fs), .semibold)).foregroundStyle(Color.zOnColor)
                            .padding(.horizontal, 2).padding(.vertical, 1)
                            .background(RoundedRectangle(cornerRadius: 2).fill(Color.wmRed))
                    }

                    Spacer(minLength: 0)
                    if settings.showCompass {
                        Text(ZW.compass[index]).font(ChartType.font(ChartType.meta(fs))).foregroundStyle(Color.zText3)
                    }
                }
                .lineLimit(1)
            }
            #if os(iOS)
            // iPhone 照文墨天機：星曜只看寬度決定字級（一排、同字級、欄距 0），
            // 四化方塊從星名底下往下掛進宮格中間的空白，不佔版面高度、不會因為高度不夠把整排縮小；
            // 底部（神煞、運限宮名、干支）固定貼在宮格最下面
            Color.clear
                .frame(maxWidth: .infinity)
                .frame(height: fs * 2.7)   // 星名兩字＋亮度
                .zIndex(1)   // 往下掛的四化方塊畫在最上層，不被神煞、運限宮名蓋住
                .overlay(alignment: .topLeading) {
                    GeometryReader { g in
                        let c = fitChoice(p, horo: horo, minor: minor, w: g.size.width, h: .infinity)
                        starFlow(p: p, horo: horo, minor: minor, f: fs * c.0, adjF: StarLayout.adjBase(fs) * c.1, wrap: c.2)
                            .fixedSize(horizontal: false, vertical: true)
                            .frame(width: g.size.width, alignment: .topLeading)
                    }
                }
            Spacer(minLength: 0)
            #else
            HStack(alignment: .top, spacing: 3) {
                // 放不下時先縮雜曜，再一起縮主星與四化，選第一個塞得下的
                // 先試「主星和雜曜同一排」：放不下就先縮雜曜、再一起縮；真的縮到底還放不下才換第二排
                fittedStars(p: p, horo: horo, minor: minor)
                .frame(maxWidth: .infinity, minHeight: 0, maxHeight: .infinity, alignment: .topLeading)
                .clipped()
            }
            .frame(minHeight: fs * 2.4, alignment: .top)   // 星曜區至少留一行主星的高度，不會被下方擠到消失
            .layoutPriority(-1)
            #endif
            // 流曜（大祿、年鸞…）與合祿／合羊／合陀：照文墨天機放在運限宮名上面、靠右，
            // 不跟本命星曜搶同一排（擠在右上角會讓主星被迫換行）；大限的排最右邊，一排 6 個
            let extra = extraStars(p, horo)
            if !extra.isEmpty {
                VStack(alignment: .trailing, spacing: 3) {
                    let list = Array(extra.reversed())
                    ForEach(Array(stride(from: 0, to: list.count, by: 6)), id: \.self) { k in
                        HStack(alignment: .top, spacing: 1) {
                            ForEach(Array(list[k..<min(k + 6, list.count)]), id: \.0) { name, color in
                                VerticalText(name, size: ChartType.adj(fs) * 0.76, color: color)   // 流曜是輔助資訊，比雜曜小一點
                            }
                        }
                    }
                }
                .fixedSize()
                .frame(maxWidth: .infinity, alignment: .trailing)
            }
            HStack(alignment: .bottom, spacing: 2) {
                VStack(alignment: .leading, spacing: 0) {
                    // 小限宮名、轉宮名疊在流月上面（左下這一欄），不會擠歪中間的宮名
                    if minor {
                        tagLine("小" + String(horo.age.palaceNames[index].prefix(1)), .minorColor)
                    }
                    // 小限疊盤關著時：小限命宮標一個橫的小框「小限」，放在轉宮名上面
                    if level >= 2 && !settings.showMinorOverlay && horo.age.index == index {
                        Text("小限").font(ChartType.font(ChartType.meta(fs))).foregroundStyle(Color.zText2)
                            .padding(.horizontal, 3).padding(.vertical, 1)
                            .overlay(RoundedRectangle(cornerRadius: 2).stroke(Color.zText3, lineWidth: 0.8))
                            .fixedSize()
                            .padding(.bottom, 2)
                    }
                    if let taijiLabel {
                        Text(taijiLabel).font(ChartType.font(ChartType.tag(fs) + 1)).foregroundStyle(Color.mQuan)
                            .lineLimit(1).fixedSize()
                    }
                    // 流月（同文墨天機，例：冬月庚）：寫在神煞欄最上面
                    if let monthLabel { Text(monthLabel).foregroundStyle(Color.wmEarth) }
                    if settings.showShensha {
                    Text(p.boshi).foregroundStyle(Color.wmGreen)
                    Text(p.jiangqian)
                    Text(p.suiqian)
                    }
                }
                .fixedSize()   // 這一欄不被右邊的宮名擠扁
                .font(ChartType.font(ChartType.gods(fs)))
                .foregroundStyle(Color.zText)
                Spacer(minLength: 0)
                VStack(spacing: 2) {
                    if settings.showAgeLines {
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
                    // 選到大限以後：改寫「這個大限裡、流年走到這一宮的那一年」（例：2034年38歲），像文墨天機
                    if level >= 1, let ya = decadeYearAge {
                        #if os(iOS)
                        // iPhone 宮格窄：照文墨天機不寫（流年、歲數在下面的運限表看得到），把空間留給星曜
                        EmptyView()
                        #else
                        Text("\(String(ya.year))年\(ya.age)歲")
                            .font(ChartType.font(ChartType.range(fs)))
                            .foregroundStyle(Color.zText2)
                            .lineLimit(1).fixedSize()
                        #endif
                    } else {
                        Text("\(p.range[0])~\(p.range[1])")
                            .font(curDecade ? ChartType.font(ChartType.range(fs)).italic() : ChartType.font(ChartType.range(fs)))
                            .underline(curDecade)
                            // 選到大限時輪不到的宮（一個大限只有 10 年）：大限歲數變淡
                            .foregroundStyle(curDecade ? Color.wmRed : level >= 1 ? Color.zText3 : Color.zText)
                            .lineLimit(1).fixedSize()
                    }
                    // 運限宮名垂直往上疊在宮名上面（由下而上：宮名、大X、年X），一欄三行；
                    // 疊滿往左開新欄（月X、日X、時X），由右至左。小限緊貼在宮名右邊。
                    let tags: [(String, Color)] = (1..<(level + 1)).map { lv in
                        (ZW.scopeTags[lv - 1] + String(horo.scope(lv).palaceNames[index].prefix(1)), Color.scopeColors[lv - 1])
                    }
                    let first = Array(tags.prefix(2))              // 跟宮名同一欄
                    let rest = Array(tags.dropFirst(2))            // 往左的欄，每欄 3 個
                    let restCols = stride(from: 0, to: rest.count, by: 3).map { Array(rest[$0..<min($0 + 3, rest.count)]) }
                    // 宮名那一欄自己置中；小限宮名、轉宮名、往左疊的運限宮名都掛在左邊、不佔寬度，宮名不會被推歪
                    VStack(alignment: .nameCenter, spacing: 0) {
                        ForEach(Array(first.enumerated().reversed()), id: \.offset) { _, t in
                            tagLine(t.0, t.1).alignmentGuide(.nameCenter) { $0[HorizontalAlignment.center] }
                        }
                        // 本命宮名跟上面的運限宮名（年命、大兄…）同樣大小、粗細
                        Text(p.name).font(ChartType.font(ChartType.tag(fs), .semibold)).foregroundStyle(Color.wmRed)
                            .lineLimit(1).fixedSize()
                            .alignmentGuide(.nameCenter) { $0[HorizontalAlignment.center] }
                    }
                    .overlay(alignment: .bottomLeading) {
                        HStack(alignment: .bottom, spacing: 4) {
                            // 越後面的欄越靠左
                            ForEach(Array(restCols.enumerated().reversed()), id: \.offset) { _, col in
                                VStack(spacing: 0) {
                                    ForEach(Array(col.enumerated().reversed()), id: \.offset) { _, t in tagLine(t.0, t.1) }
                                }
                            }
                        }
                        .fixedSize()
                        .alignmentGuide(.leading) { $0[.trailing] + 4 }
                    }
                }
                Spacer(minLength: 0)
                // 身宮、來因放在天干地支左邊並排（往上疊會太高，把星曜區擠沒）
                HStack(alignment: .bottom, spacing: 2) {
                    if p.isBody && settings.showBody {
                        VerticalText("身宮", size: ChartType.tag(fs), color: .wmRed)
                            .padding(.vertical, 3).padding(.horizontal, 1)
                            .overlay(RoundedRectangle(cornerRadius: 3).stroke(Color.wmRed))
                            .padding(.bottom, 2)
                    }
                    VStack(spacing: 0) {
                        // 長生十二神：自己一個開關（預設關）
                        if settings.showChangsheng {
                            VerticalText(p.changsheng, size: ChartType.meta(fs), color: .zText2)
                                .padding(.bottom, 2)
                        }
                        Text(p.stem).font(ChartType.font(ChartType.ganzhi(fs)))
                        Text(p.branch).font(ChartType.font(ChartType.ganzhi(fs)))
                    }
                }
                .foregroundStyle(Color.zText)
            }
        }
        .padding(.horizontal, 5)
        .padding(.vertical, 4)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(selected ? Color.wmSel : inSF || inLockedSF ? Color.wmSF : Color.clear)   // 鎖定那組只靠框線區分，底色一樣用三方灰
        .overlay(Rectangle().stroke(Color.zGrid, lineWidth: max(0.5, 1 / displayScale)))   // 固定 1 個實際像素：一般螢幕（1x）上 0.5pt 會淡到看不見
        // 鎖定的宮位：粗實線；它的三方四正：細一點的強調色邊框
        .overlay(isLocked ? Rectangle().strokeBorder(Color.zAccent, lineWidth: 3) : nil)
        .overlay(inLockedSF ? Rectangle().strokeBorder(Color.zAccent.opacity(0.8), lineWidth: 1.6) : nil)
        .overlay(selected ? Rectangle().stroke(Color.zAccent, lineWidth: 1.5) : nil)
        .overlay(alignment: .topLeading) {
            if isLocked {
                Image(systemName: "lock.fill").font(.system(size: max(8, fs * 0.6))).foregroundStyle(Color.zAccent).padding(3)
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

    /// 宮內的流曜（大限、流年）和合盤星
    func extraStars(_ p: Palace, _ horo: Horoscope) -> [(String, Color)] {
        var out: [(String, Color)] = []
        if settings.showFlowStars {
            if level >= 1, let st = horo.decadal.stars, index < st.count { out += st[index].map { ($0, Color.scopeColors[0]) } }
            if level >= 2, let st = horo.yearly.stars, index < st.count { out += st[index].map { ($0, Color.scopeColors[1]) } }
        }
        if let hepan { out += hepan.stars(at: p.branch).map { ($0, Color.wmEarth) } }
        return out
    }

    /// 星曜區：選第一個塞得下的字級組合（先試同一排、先縮雜曜再一起縮，縮到底才換行）
    /// 不用 ViewThatFits：它會把 11 種組合都實際排一次版，整盤重畫要 200ms 以上（點宮位、換流年會頓）。
    /// 改成量好每一項的寬高、用算的挑出組合，只排一次版。
    func fittedStars(p: Palace, horo: Horoscope, minor: Bool) -> some View {
        GeometryReader { g in
            let c = fitChoice(p, horo: horo, minor: minor, w: g.size.width, h: g.size.height)
            starFlow(p: p, horo: horo, minor: minor, f: fs * c.0, adjF: StarLayout.adjBase(fs) * c.1, wrap: c.2)
                // 量出來跟實際排版差一點點時，多出來的寬度往右溢（被裁掉的是最後的雜曜），不要置中把左邊的主星切掉
                .frame(width: g.size.width, height: g.size.height, alignment: .topLeading)
        }
    }

    #if os(iOS)
    /// iPhone 照文墨天機：所有星曜同一個字級、整排一起縮，縮到很小還放不下才換第二排
    private static let fitCandidates: [(CGFloat, CGFloat, Bool)] =
        [1.0, 0.93, 0.86, 0.8, 0.74, 0.68, 0.63, 0.58].map { ($0, $0, false) } + [(0.7, 0.7, true), (0.6, 0.6, true)]
    #else
    private static let fitCandidates: [(CGFloat, CGFloat, Bool)] =
        [(1.0, 1.0), (1.0, 0.9), (1.0, 0.82), (0.94, 0.76), (0.88, 0.72), (0.82, 0.68)].map { ($0.0, $0.1, false) } +
        [(1.0, 1.0), (0.92, 0.84), (0.84, 0.78), (0.76, 0.72), (0.68, 0.66)].map { ($0.0, $0.1, true) }
    #endif

    private func fitChoice(_ p: Palace, horo: Horoscope, minor: Bool, w: CGFloat, h: CGFloat) -> (CGFloat, CGFloat, Bool) {
        for c in Self.fitCandidates {
            let items = itemSizes(p, horo: horo, minor: minor, f: fs * c.0, adjF: StarLayout.adjBase(fs) * c.1)
            if Self.fits(items, w: w, h: h, wrap: c.2) { return c }
        }
        return Self.fitCandidates.last!
    }

    /// 每一項（星曜欄、重要雜曜、雜曜）排出來的寬高：跟 StarColumn／VerticalText 的版面一致
    private func itemSizes(_ p: Palace, horo: Horoscope, minor: Bool, f: CGFloat, adjF: CGFloat) -> [CGSize] {
        let showMinorMutagen = minor && settings.showMinorMutagen
        var out: [CGSize] = []
        for star in p.stars {
            // 方塊數：每一層固定一格（最後面的空格不算），再加小限、合盤
            var n = 0
            for (i, lv) in layers.enumerated() {
                let m: Mutagen? = lv == 0 ? Mutagen(rawValue: star.mutagen) : ZW.mutagen(in: horo.scope(lv).mutagen, star: star.name)
                if m != nil { n = i + 1 }
            }
            if showMinorMutagen, ZW.mutagen(in: horo.age.mutagen, star: star.name) != nil { n += 1 }
            if hepan?.mutagen(star: star.name) != nil { n += 1 }
            let size = StarLayout.boxScale(n)
            let name = TextMeasure.size(VerticalText.join(star.name), ChartType.star(f), bold: star.type == "major")
            let bright = TextMeasure.size(star.brightness.isEmpty ? " " : star.brightness, ChartType.meta(f))
            let boxes = n > 0 ? CGFloat(n) * f * size + CGFloat(n - 1) : 0
            out.append(CGSize(width: max(StarLayout.columnWidth(f), n > 0 ? f * size : 0), height: name.height + 2 + 0.5 + bright.height + 0.5 + boxes))
        }
        let adj = settings.showAdj ? p.adj : []
        for s in adj where ZW.keyAdjective.contains(s.name) { out.append(StarLayout.column(TextMeasure.size(VerticalText.join(s.name), ChartType.star(f)), f)) }
        for s in adj where !ZW.keyAdjective.contains(s.name) { out.append(StarLayout.column(TextMeasure.size(VerticalText.join(s.name), adjF), adjF)) }
        return out
    }

    /// 同一排：總寬（間距 1）放得下、最高的一欄放得下；換行：照 FlowLayout 的擺法（行距 4）算總高
    private static func fits(_ items: [CGSize], w: CGFloat, h: CGFloat, wrap: Bool) -> Bool {
        let tol: CGFloat = 0.5
        if !wrap {
            let width = items.reduce(0) { $0 + $1.width } + StarLayout.gap * CGFloat(max(0, items.count - 1))
            return width <= w + tol && (items.map(\.height).max() ?? 0) <= h + tol
        }
        var x: CGFloat = 0, y: CGFloat = 0, lineH: CGFloat = 0
        for it in items {
            if x > 0 && x + it.width > w + tol { x = 0; y += lineH + 4; lineH = 0 }
            if it.width > w + tol { return false }
            x += it.width + StarLayout.gap; lineH = max(lineH, it.height)
        }
        return y + lineH <= h + tol
    }

    @ViewBuilder
    func starFlow(p: Palace, horo: Horoscope, minor: Bool, f: CGFloat, adjF: CGFloat, wrap: Bool) -> some View {
        if wrap {
            FlowLayout(spacing: StarLayout.gap, lineSpacing: 4) { starItems(p: p, horo: horo, minor: minor, f: f, adjF: adjF) }
        } else {
            HStack(alignment: .top, spacing: StarLayout.gap) { starItems(p: p, horo: horo, minor: minor, f: f, adjF: adjF) }
                .fixedSize()
        }
    }

    @ViewBuilder
    func starItems(p: Palace, horo: Horoscope, minor: Bool, f: CGFloat, adjF: CGFloat) -> some View {
        // 四化只顯示最近三層（0 生年、1 大限、2 流年、3 流月、4 流日、5 流時）＋小限（有流年時）
        // 例：選到流月＝大限、流年、流月；選到流時＝流月、流日、流時
        let showMinorMutagen = minor && settings.showMinorMutagen
            ForEach(p.stars, id: \.name) { s in
                StarColumn(star: s, fs: f, palaceName: p.name, fly: flyStars[s.name],
                           minor: showMinorMutagen ? ZW.mutagen(in: horo.age.mutagen, star: s.name) : nil,
                           hepanMut: hepan?.mutagen(star: s.name),
                           // 每一層一個固定位置（沒有四化就空著），一眼看出是疊在第幾層
                           slots: layers.map { lv in
                               let m: Mutagen? = lv == 0 ? Mutagen(rawValue: s.mutagen) : ZW.mutagen(in: horo.scope(lv).mutagen, star: s.name)
                               return (m, lv == 0 ? Color.fBirth : Color.fScopes[lv - 1])
                           })
            }
            // 重要雜曜（紅鸞、天喜、咸池、天姚、天刑）用主星字級排在前面，其他雜曜小字
            let adj = settings.showAdj ? p.adj : []
            ForEach(adj.filter { ZW.keyAdjective.contains($0.name) }, id: \.name) { s in
                VerticalText(s.name, size: ChartType.star(f), color: settings.tone(.misc).color)
                    .frame(width: StarLayout.columnWidth(f))
                    .starHoverArea(s.name, palace: p.name)
            }
            ForEach(adj.filter { !ZW.keyAdjective.contains($0.name) }, id: \.name) { s in
                VerticalText(s.name, size: adjF, color: settings.tone(.misc).color)
                    .frame(width: StarLayout.columnWidth(adjF))
                    .starHoverArea(s.name, palace: p.name)
            }
    }
}

private struct StarColumn: View {
    @Environment(\.zSettings) private var settings
    @Environment(\.starHover) private var starHover
    let star: Star
    let fs: CGFloat
    var palaceName = ""
    let fly: Mutagen?    // 點選宮位的宮干四化落在這顆星
    let minor: Mutagen?  // 小限四化
    var hepanMut: Mutagen? = nil   // 合盤：對方年干的四化
    let slots: [(Mutagen?, Color)]  // 目前顯示的每一層（由小到大）：這顆星在那一層的四化，沒有就 nil

    var body: some View {
        let tone = settings.starTone(type: star.type)
        let list = boxes
        let size = StarLayout.boxScale(list.count)   // Mac 四化方塊放大一點比星名醒目；iPhone 跟一欄一樣寬（照文墨天機）
        // 星名下同一直排：生年 → 大限 → 流年 → 小限 → 流月…（最多三層＋小限）
        VStack(spacing: 0.5) {
            VerticalText(star.name, size: ChartType.star(fs), color: fly != nil ? .zOnColor : tone.color,
                         weight: star.type == "major" ? .semibold : .regular)
                .padding(.vertical, 1)
                .frame(width: StarLayout.columnWidth(fs))
                .background(fly?.fill ?? .clear)
                // 滑鼠停在星名上：回報位置給盤面顯示小卡
                .starHoverArea(star.name, palace: palaceName)
            Text(star.brightness.isEmpty ? " " : star.brightness)
                .font(ChartType.font(ChartType.meta(fs)))
                .foregroundStyle(Color.zText2)
            VStack(spacing: 1) {
                ForEach(Array(list.enumerated()), id: \.offset) { _, b in
                    if let b { box(b.0, fill: b.1, size: size) } else { Color.clear.frame(width: fs * size, height: fs * size) }
                }
            }
        }
        .frame(minWidth: StarLayout.columnWidth(fs))
    }

    /// 方塊清單：每一層固定一格（沒有四化的層留空白，最後面的空白不用留），再接小限、合盤
    private var boxes: [(String, Color)?] {
        var b: [(String, Color)?] = slots.map { m, c in m.map { ($0.rawValue, c) } }
        while let last = b.last, last == nil { b.removeLast() }
        if let minor { b.append((minor.rawValue, .fMinor)) }
        if let hepanMut { b.append((hepanMut.rawValue, .fHepan)) }   // 合四化放最後（方塊用 fHepan，比文字用的 wmEarth 沉）
        return b
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
    @Environment(\.displayScale) private var displayScale

    private var layerBar: some View {
        let names = ["本", "限", "年", "月", "日", "時"]
        return HStack(spacing: 6) {
            HStack(spacing: 0) {
                ForEach(0..<6, id: \.self) { lv in
                    let on = layers.contains(lv), able = lv <= level
                    Button { onToggleLayer(lv) } label: {
                        Text(names[lv]).font(ChartType.font(ChartType.tag(fs), .semibold))
                            .foregroundStyle(on ? Color.zOnColor : able ? Color.zText2 : Color.zText3.opacity(0.5))
                            .frame(width: fs * 1.8, height: fs * 1.6)
                            .background(Rectangle().fill(on ? (lv == 0 ? Color.fBirth : Color.fScopes[lv - 1]) : Color.zHover))
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(PressStyle())
                    .disabled(!able)
                    .help(able ? "\(["本命", "大限", "流年", "流月", "流日", "流時"][lv])四化：\(on ? "隱藏" : "顯示")（最多三層）" : "")
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 5))
            .overlay(RoundedRectangle(cornerRadius: 5).stroke(Color.zLine))
            let minorOn = settings.showMinorOverlay
            Button(action: onToggleMinor) {
                Text("小限").font(ChartType.font(ChartType.tag(fs), .semibold))
                    .foregroundStyle(minorOn ? Color.zOnColor : level >= 2 ? Color.zText2 : Color.zText3.opacity(0.5))
                    .padding(.horizontal, fs * 0.5).frame(height: fs * 1.6)
                    .background(RoundedRectangle(cornerRadius: 5).fill(minorOn ? Color.fMinor : Color.zHover))
                    .overlay(RoundedRectangle(cornerRadius: 5).stroke(Color.zLine))
                    .contentShape(Rectangle())
            }
            .buttonStyle(PressStyle())
            .disabled(level < 2)
            .help("小限疊盤：小限宮名與小限四化")
        }
    }
    @Environment(\.zSettings) private var settings
    @AppStorage("hideBirth") private var hideBirth = false
    private func mask(_ s: String) -> String { hideBirth ? "••••••" : s }
    let person: Person
    let model: ChartModel
    let selected: Int
    var cleared = false
    let locked: Int?
    let taiji: Int?
    let fs: CGFloat
    let level: Int
    var layers: [Int] = []
    var onToggleLayer: (Int) -> Void = { _ in }
    var onToggleMinor: () -> Void = {}
    let onResetLevel: () -> Void
    let onClearTaiji: () -> Void

    var body: some View {
        let chart = model.chart
        // 陰陽男女照盤面的年干（跟著「年界」設定）；四柱本身用 bz.pillars（節氣四柱：月以「節」換），不能再從 chineseDate 取（那是農曆月）
        let yearStem = String(chart.chineseDate.prefix(1))
        let yang = ["甲", "丙", "戊", "庚", "壬"].contains(yearStem)
        let flies = model.flying[selected]
        ZStack {
            SanFangShape(points: Quad(ZW.sanFang(selected).map { ZW.anchor[$0] }))
                .stroke(Color.zText3.opacity(0.7), style: StrokeStyle(lineWidth: 1, dash: [5, 4]))
                .opacity(settings.showSanfang && !cleared ? 1 : 0)
            if let locked {
                SanFangShape(points: Quad(ZW.sanFang(locked).map { ZW.anchor[$0] }))
                    .stroke(Color.zAccent, style: StrokeStyle(lineWidth: 2.6, lineCap: .round, dash: [7, 4]))
                    .transition(.opacity)
            }
            VStack(spacing: fs * 0.32) {
                Text("紫微斗數").font(ChartType.font(ChartType.centerTitle(fs), .semibold)).tracking(2)
                Grid(alignment: .leading, horizontalSpacing: 6, verticalSpacing: 1) {
                    GridRow { label("姓名"); Text("\(hideBirth ? person.name.maskedName : person.name)　　\(yang ? "陽" : "陰")\(person.gender.rawValue)　\(chart.fiveElementsClass)") }
                    if let ts = person.trueSolar {
                        GridRow { label("真太陽時"); Text(mask(ts)) }
                        GridRow { label("鐘錶時間"); Text(mask(person.clock ?? "")) }
                    } else {
                        GridRow { label("國曆"); Text(mask("\(chart.solarDate) \(ZW.hours[person.hour])時（\(chart.timeRange)）")) }
                    }
                    GridRow { label("農曆"); Text(mask("\(chart.lunarGanzhiDate) \(chart.time)")) }
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
                    HStack(alignment: .top, spacing: 0) {
                        ForEach(Array(dayun.enumerated()), id: \.offset) { k, gz in
                            // 虛歲（照文墨天機）：第一步從起運那年算，之後每步十年
                            let age = bz.dayunStartYear - birthYear + 1 + k * 10
                            VStack(spacing: 0) {
                                // 十神小字掛在天干右邊、不佔寬度，干支和歲數才會對齊同一條中線
                                Text(String(gz.prefix(1))).font(ChartType.font(ChartType.dayun(fs))).foregroundStyle(ZW.wuxing(String(gz.prefix(1))).color)
                                    .overlay(alignment: .topTrailing) {
                                        VerticalText(Bazi.tenGod(day: dayStem, other: String(gz.prefix(1))), size: ChartType.godLabel(fs), color: .mQuan)
                                            .fixedSize()
                                            .offset(x: ChartType.godLabel(fs) + 1)
                                    }
                                Text(String(gz.suffix(1))).font(ChartType.font(ChartType.dayun(fs))).foregroundStyle(ZW.wuxing(String(gz.suffix(1))).color)
                                Text(k == dayun.count - 1 ? "\(age)虛歲" : "\(age)歲").font(ChartType.font(ChartType.godLabel(fs))).foregroundStyle(Color.zText2)
                                    .lineLimit(1).minimumScaleFactor(0.6)
                                Text(verbatim: "\(bz.dayunStartYear + k * 10)").font(ChartType.font(ChartType.godLabel(fs)).monospacedDigit()).foregroundStyle(Color.zText3)
                                    .lineLimit(1).minimumScaleFactor(0.6)
                            }
                            .frame(width: fs * 1.75)
                        }
                    }
                }

                // 點選宮位的宮干飛化（一行）；iPhone 中宮窄，照文墨天機不寫
                if !StarLayout.compact {
                HStack(spacing: 6) {
                    Text("\(chart.palaces[selected].name)\(chart.palaces[selected].stem)干：")
                        .font(ChartType.font(ChartType.centerSmall(fs))).foregroundStyle(Color.zText2)
                    ForEach(flies, id: \.m) { f in
                        Text("\(f.star)\(f.m.rawValue)")
                            .font(ChartType.font(ChartType.centerSmall(fs), .medium)).foregroundStyle(f.m.color)
                    }
                }
                .lineLimit(1).minimumScaleFactor(0.7)
                }
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
                    if level > 0 && !StarLayout.compact {
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
                // 層級開關：本・限・年・月・日・時（最多同時顯示三層），旁邊小限另外開關；跟中宮資訊一起置中
                if level >= 1 { layerBar.padding(.top, fs * 0.5) }
            }
            .padding(.horizontal, fs * 0.6)
            .padding(.vertical, fs * 0.4)
            .minimumScaleFactor(0.8)
        }

        .overlay(Rectangle().stroke(Color.zGrid, lineWidth: max(0.5, 1 / displayScale)))   // 固定 1 個實際像素：一般螢幕（1x）上 0.5pt 會淡到看不見
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

/// 滑鼠停在哪顆星（筆記 key、宮名、在盤面上的位置）
/// 雜曜也能 hover 出說明卡（主星在 StarColumn 裡自己處理）
private struct StarHoverArea: ViewModifier {
    let key: String
    let palace: String
    @Environment(\.starHover) private var starHover
    func body(content: Content) -> some View {
        if let starHover {
            content
                .contentShape(Rectangle())
                .onContinuousHover(coordinateSpace: .named("board")) { phase in
                    switch phase {
                    case .active(let p): starHover(StarHoverInfo(key: key, palace: palace, rect: CGRect(x: p.x, y: p.y - 8, width: 0, height: 16)))
                    case .ended: starHover(nil)
                    }
                }
        } else {
            content
        }
    }
}

extension View {
    func starHoverArea(_ key: String, palace: String) -> some View { modifier(StarHoverArea(key: key, palace: palace)) }
}

struct StarHoverInfo: Equatable {
    let key: String
    let palace: String
    let rect: CGRect
}

private struct StarHoverKey: EnvironmentKey { static let defaultValue: ((StarHoverInfo?) -> Void)? = nil }
extension EnvironmentValues {
    var starHover: ((StarHoverInfo?) -> Void)? {
        get { self[StarHoverKey.self] }
        set { self[StarHoverKey.self] = newValue }
    }
}

/// 文字實際排出來的大小：用 CoreText 量（跟 SwiftUI 的 Text 一樣會自動用蘋方補中文字），量過的有快取
enum TextMeasure {
    nonisolated(unsafe) private static var cache: [String: CGSize] = [:]
    static func size(_ s: String, _ pt: CGFloat, bold: Bool = false) -> CGSize {
        let key = "\(s)|\(pt)|\(bold)"
        if let v = cache[key] { return v }
        // 跟 ChartType.font 一樣的粗細（粗體實際用 medium）
        let font = PlatformFont.systemFont(ofSize: pt, weight: bold ? .medium : .regular)
        let r = (s as NSString).boundingRect(with: CGSize(width: 10_000, height: 10_000),
                                             options: [.usesLineFragmentOrigin, .usesFontLeading], attributes: [.font: font], context: nil)
        let v = CGSize(width: ceil(r.width), height: ceil(r.height))
        cache[key] = v
        return v
    }
}

/// 夾宮的「撞一下」：兩個鄰宮往被夾的宮位撞進來 20pt 再彈回；被夾的宮位本身不動
private struct ClampSqueeze: ViewModifier {
    let on: Bool
    let index: Int
    let selected: Int
    let amount: CGFloat
    // 每一格都套同一個 offset（不是鄰宮就是 0）：用 if 分支的話，格子變成鄰宮那一刻會被當成新 view 重建，動畫就被吃掉
    func body(content: Content) -> some View {
        let isNeighbor = on && (index == (selected + 11) % 12 || index == (selected + 1) % 12)
        let d = isNeighbor ? ClampOverlay.side(selected: selected, neighbor: index) : (dx: 0, dy: 0)
        return content.offset(x: -d.dx * 20 * amount, y: -d.dy * 20 * amount)
    }
}

/// 宮格四個角：整個矩形挖掉一個圓角矩形（even-odd 填色），用頁面底色蓋住方格露出的角
private struct GridCorners: Shape {
    let radius: CGFloat
    func path(in r: CGRect) -> Path {
        var p = Path(r)
        p.addRoundedRect(in: r, cornerSize: CGSize(width: radius, height: radius), style: .continuous)
        return p
    }
}

/// 星曜一欄的寬度與欄距：Mac 每欄多留一點（1.18 倍字寬、欄距 1）；
/// iPhone 照文墨天機一欄剛好一個字寬、欄距 0，雜曜跟主星同一個字級
enum StarLayout {
    #if os(iOS)
    /// iPhone：照文墨天機的精簡版面
    static let compact = true
    static let gap: CGFloat = 0
    static func columnWidth(_ f: CGFloat) -> CGFloat { f }   // 一欄剛好一個字寬，主星跟雜曜之間沒有空隙
    static func adjBase(_ fs: CGFloat) -> CGFloat { ChartType.star(fs) }
    #else
    static let compact = false
    static let gap: CGFloat = 1
    static func columnWidth(_ f: CGFloat) -> CGFloat { f * 1.18 }
    static func adjBase(_ fs: CGFloat) -> CGFloat { ChartType.adj(fs) }
    #endif
    /// 四化方塊相對字級的大小（n＝這顆星有幾個方塊）
    static func boxScale(_ n: Int) -> CGFloat {
        #if os(iOS)
        1.0
        #else
        n > 3 ? 1.06 : 1.22
        #endif
    }
    /// 雜曜量出來的大小換成一欄的寬度（跟畫出來的 frame 一致，量和畫才不會差一點）
    static func column(_ s: CGSize, _ f: CGFloat) -> CGSize { CGSize(width: max(s.width, columnWidth(f)), height: s.height) }
}
