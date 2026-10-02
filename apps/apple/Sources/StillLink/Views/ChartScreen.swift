import SwiftUI

/// 運限選擇（預設大限）：level 0 本命、1 大限、2 流年、3 流月、4 流日、5 流時；年月日都是農曆
struct Pick: Equatable, Hashable {
    var level = 1
    var year: Int
    var lm: Int
    var ld: Int
    var hour: Int

    static func today() -> Pick {
        let c = Calendar.current.dateComponents([.year, .month, .day, .hour], from: Date())
        let l = Lunar.toLunar(c.year!, c.month!, c.day!)
        return Pick(year: l.year, lm: l.month, ld: l.day, hour: SolarTime.shichen(c.hour!) % 12)
    }
}

/// 首頁：以當下時間排盤（不存檔）
struct NowChart: View {
    @AppStorage("nowGender") private var gender: Gender = .male
    @State private var now = Date()

    var body: some View {
        let c = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: now)
        let p = Person(id: NowChart.id, name: "此刻", gender: gender, solar: "\(c.year!)-\(c.month!)-\(c.day!)",
                       hour: SolarTime.shichen(c.hour!), group: "此刻",
                       clock: String(format: "%d-%d-%d %02d:%02d", c.year!, c.month!, c.day!, c.hour!, c.minute!))
        ChartPager(primary: p)
            .id(p.chartKey)
            .onReceive(Timer.publish(every: 60, on: .main, in: .common).autoconnect()) { now = $0 }
    }

    static let id = UUID(uuidString: "00000000-0000-0000-0000-00000000A0A0")!
}

/// 盤面寬度上限（約文墨天機的比例）
let boardMaxWidth: CGFloat = 780
let infoPanelWidth: CGFloat = 300
/// 盤面高寬比：略高於正方形，宮位底部（歲數、運限宮名、宮名）才放得下又不擠星曜
let boardAspect: CGFloat = 1.06

struct ChartScreen: View {
    @EnvironmentObject var store: Store
    let person: Person
    /// false：標題和工具列交給外層（ChartPager 多頁時統一管理）
    var chrome = true
    /// 盤面旁邊的「＋」：加第二張盤
    var onAdd: (() -> Void)? = nil
    @State private var pick: Pick
    @AppStorage("showInfoPanel") private var showInfo = true
    @State private var model: ChartModel?
    @State private var shownLevel = 1           // 盤面用的層級：跟著 model 一起更新，避免先用舊資料畫一次
    @State private var zoom: CGFloat = 1       // 觸控板捏合縮放（1～2.5）
    @State private var zoomBase: CGFloat = 1
    /// 盤面實際排版用的倍率：捏合中先用 scaleEffect（順），放手後用這個倍率重排，字才清楚
    @State private var sharpZoom: CGFloat = 1

    /// level 沒指定時照設定「打開命盤時預設顯示大限」（預設關閉＝本命）
    init(person: Person, level: Int? = nil, chrome: Bool = true, onAdd: (() -> Void)? = nil) {
        self.person = person
        self.chrome = chrome
        self.onAdd = onAdd
        // 驗證用：ZIWEI_LEVEL=2 直接開到流年
        let lv = ProcessInfo.processInfo.environment["ZIWEI_LEVEL"].flatMap(Int.init) ?? level ?? ZSettings.stored().openLevel
        var p = Pick.today(); p.level = lv
        _pick = State(initialValue: p)
        _shownLevel = State(initialValue: lv)
        // 驗證用：ZIWEI_ZOOM=2 直接以放大倍率開啟
        if let z = ProcessInfo.processInfo.environment["ZIWEI_ZOOM"].flatMap(Double.init) {
            _zoom = State(initialValue: z); _zoomBase = State(initialValue: z); _sharpZoom = State(initialValue: z)
        }
    }

    private var magnify: some Gesture {
        MagnificationGesture()   // macOS 13 也能用（14 的 MagnifyGesture 不行）
            .onChanged { v in zoom = min(2.5, max(1, zoomBase * v)) }
            .onEnded { _ in
                if zoom < 1.05 { withAnimation(Motion.snap) { zoom = 1 } }
                zoomBase = zoom
                var t = Transaction(); t.disablesAnimations = true
                withTransaction(t) { sharpZoom = zoom }
            }
    }

    var body: some View {
        // 捲動區佔滿整個寬度（捲軸貼在視窗最右邊）；右側資訊卡固定浮在右上角，不跟著捲
        GeometryReader { geo in
            let panelSpace: CGFloat = showInfo ? infoPanelWidth + 24 : 0
            let usable = geo.size.width - panelSpace
            let boardW = min(usable - 48, boardMaxWidth, max(460, geo.size.height - 180))
            ZStack(alignment: .bottom) {
                ScrollView(zoom > 1 ? [.vertical, .horizontal] : .vertical) {
                    VStack(spacing: 12) {
                        Group {
                            if let model {
                                ChartBoard(person: person, model: model, level: shownLevel, zoom: sharpZoom) { pick.level = 0 }
                                    .equatable()
                                    .animation(nil, value: pick)
                                    .transition(.opacity)
                            } else {
                                BoardSkeleton().transition(.opacity)
                            }
                        }
                        .frame(width: boardW * sharpZoom, height: boardW * boardAspect * sharpZoom)
                        .scaleEffect(zoom / sharpZoom, anchor: .top)
                        .frame(width: boardW * zoom, height: boardW * boardAspect * zoom, alignment: .top)
                        .gesture(magnify)
                        // 盤面右邊的「＋」：加一張盤，左右滑動切換
                        .overlay(alignment: .trailing) {
                            if let onAdd, zoom == 1 { AddBoardButton(action: onAdd).offset(x: 40) }
                        }

                        if let model {
                            PeriodTable(chart: model.chart, birthYear: person.birthYear, pick: $pick)
                                .transition(.opacity.combined(with: .offset(y: 8)))
                        } else {
                            RoundedRectangle(cornerRadius: 12).fill(Color.zHover).frame(height: 210).shimmer()
                        }

                    }
                    .frame(width: boardW * zoom)
                    .padding(.top, 14)
                    .padding(.bottom, store.settings.showComposer ? 150 : 40)
                    .frame(width: max(usable, boardW * zoom + 48))
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .defaultScrollAnchorTop()

                if store.settings.showComposer {
                AIComposer()
                    .frame(width: min(boardW, 720))
                    .padding(.top, 28)
                    .padding(.bottom, 16)
                    .frame(width: usable)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(
                        LinearGradient(colors: [Color.zBg.opacity(0), Color.zBg, Color.zBg], startPoint: .top, endPoint: .bottom)
                            .padding(.trailing, 16) // 不蓋到捲軸
                            .allowsHitTesting(false)
                    )
                }
            }
            .dimmedBlur()
            .overlay(alignment: .topTrailing) {
                if showInfo {
                    ScrollView(showsIndicators: false) {
                        InfoPanel(person: person, chart: model?.chart)
                            .padding(.top, 12)
                            .padding(.bottom, 96) // 底部留給右下角的快捷鈕
                            .padding(.horizontal, 16) // 留空間給卡片陰影
                    }
                    .scrollClipDisabledCompat()
                    .frame(width: infoPanelWidth + 32)
                    .padding(.trailing, 4)
                    .dimmedBlur()
                    .transition(.move(edge: .trailing).combined(with: .opacity))
                }
            }
            .overlay(alignment: .bottomTrailing) {
                VStack(alignment: .trailing, spacing: 10) {
                    if zoom > 1 {
                        Button { withAnimation(Motion.snap) { zoom = 1; zoomBase = 1 }; sharpZoom = 1 } label: {
                            Label("\(Int(zoom * 100))%", systemImage: "arrow.down.right.and.arrow.up.left")
                                .font(Font.zCaptionStrong).foregroundStyle(Color.zText)
                                .padding(.horizontal, 10).frame(height: 30)
                                .background(Capsule().fill(Color.zCard).shadow(color: Color.zShadow, radius: 6, y: 2))
                        }
                        .buttonStyle(PressStyle())
                        .help("還原大小")
                        .transition(.opacity.combined(with: .scale(scale: 0.9)))
                    }
                    QuickMenu(pick: $pick)
                }
                .padding(.trailing, 24)
                .padding(.bottom, 24)
                .animation(Motion.base, value: zoom > 1)
            }
        }
        .background(Color.zBg)
        .modifier(ChartChrome(enabled: chrome, title: ChartScreen.title(person), showInfo: $showInfo))
        .task(id: TaskKey(person: person.chartKey + store.settings.calcKey, pick: pick)) {
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

    private struct TaskKey: Equatable { let person: String; let pick: Pick }

    static func title(_ p: Person) -> String { p.id == NowChart.id ? "此刻 · \(p.clock ?? "")" : p.name }
}

/// 下方 AI 解盤輸入框（Codex 式）：先留位置，功能之後接上
private struct AIComposer: View {
    @State private var text = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            TextField("AI 解盤未來推出，敬請期待…", text: $text, axis: .vertical)
                .textFieldStyle(.plain)
                .lineLimit(1...6)
                .font(Font.zBody)
            HStack(spacing: 10) {
                Image(systemName: "plus").font(Font.zBody).foregroundStyle(Color.zText2)
                Label("AI 解盤 · 未來推出", systemImage: "sparkle")
                    .font(Font.zCaption)
                    .foregroundStyle(Color.zText3)
                Spacer()
                Image(systemName: "arrow.up")
                    .font(Font.zIconBold).foregroundStyle(Color.zOnColor)
                    .frame(width: 28, height: 28)
                    .background(Circle().fill(Color.zText3.opacity(0.45)))
                    .help("AI 解盤未來推出")
            }
        }
        .padding(.horizontal, 16).padding(.vertical, 12)
        .background(RoundedRectangle(cornerRadius: 18).fill(Color.zCard))
        .overlay(RoundedRectangle(cornerRadius: 18).stroke(Color.zLine))
        .shadow(color: Color.zShadow, radius: 18, y: 6)
    }
}

/// 載入中的盤面骨架
struct BoardSkeleton: View {
    var body: some View {
        GeometryReader { geo in
            let m: CGFloat = 18
            let cw = (geo.size.width - m * 2) / 4
            let ch = (geo.size.height - m * 2) / 4
            ZStack(alignment: .topLeading) {
                ForEach(0..<12, id: \.self) { i in
                    let (r, c) = ZW.grid[i]
                    VStack(alignment: .leading, spacing: 6) {
                        HStack(spacing: 4) {
                            ForEach(0..<4, id: \.self) { _ in RoundedRectangle(cornerRadius: 3).fill(Color.zHover).frame(width: cw * 0.09, height: ch * 0.28) }
                        }
                        Spacer()
                        RoundedRectangle(cornerRadius: 3).fill(Color.zHover).frame(width: cw * 0.55, height: 8)
                        HStack {
                            RoundedRectangle(cornerRadius: 3).fill(Color.zHover).frame(width: cw * 0.22, height: ch * 0.18)
                            Spacer()
                            RoundedRectangle(cornerRadius: 3).fill(Color.zHover).frame(width: cw * 0.12, height: ch * 0.24)
                        }
                    }
                    .padding(8)
                    .frame(width: cw, height: ch)
                    .overlay(Rectangle().stroke(Color.zLine, lineWidth: 0.5))
                    .offset(x: m + CGFloat(c) * cw, y: m + CGFloat(r) * ch)
                }
                VStack(spacing: 10) {
                    RoundedRectangle(cornerRadius: 4).fill(Color.zHover).frame(width: cw * 0.7, height: 16)
                    ForEach(0..<4, id: \.self) { _ in RoundedRectangle(cornerRadius: 3).fill(Color.zHover).frame(width: cw * 1.2, height: 9) }
                }
                .frame(width: cw * 2, height: ch * 2)
                .offset(x: m + cw, y: m + ch)
            }
        }
        .shimmer()
        .background(RoundedRectangle(cornerRadius: 12).fill(Color.zCard))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.zLine))
    }
}

extension View {
    /// 骨架的呼吸動畫
    func shimmer() -> some View { modifier(Shimmer()) }
}

private struct Shimmer: ViewModifier {
    @State private var on = false
    func body(content: Content) -> some View {
        content
            .opacity(on ? 0.55 : 1)
            .animation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true), value: on)
            .onAppear { on = true }
    }
}

/// 命盤頁的標題＋「客人資料」開關；多頁時由 ChartPager 統一放，不在每一頁重複
struct ChartChrome: ViewModifier {
    let enabled: Bool
    let title: String
    @Binding var showInfo: Bool
    func body(content: Content) -> some View {
        if enabled {
            content
                .navigationTitle(title)
                .toolbar {
                    ToolbarItem(placement: .primaryAction) {
                        Button { withAnimation(Motion.enter) { showInfo.toggle() } } label: { Image(systemName: "sidebar.right") }
                            .help("客人資料")
                    }
                }
        } else {
            content
        }
    }
}

/// 盤面右邊的圓形「＋」
struct AddBoardButton: View {
    let action: () -> Void
    @State private var hover = false
    var body: some View {
        Button(action: action) {
            Image(systemName: "plus").font(Font.zCalloutStrong).foregroundStyle(hover ? Color.zText : Color.zText2)
                .frame(width: 30, height: 30)
                .background(Circle().fill(hover ? Color.zHover : Color.zCard))
                .overlay(Circle().stroke(Color.zLine))
                .contentShape(Circle())
        }
        .buttonStyle(PressStyle())
        .onHover { hover = $0 }
        .help("加一張盤（左右滑動切換）")
    }
}
