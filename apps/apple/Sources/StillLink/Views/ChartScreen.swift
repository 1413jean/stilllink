import SwiftUI

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

    static let id = Person.nowID
}

/// 盤面寬度上限（約文墨天機的比例）
let boardMaxWidth: CGFloat = 920
let infoPanelWidth: CGFloat = 300
/// 右側面板可以拉的寬度範圍
let infoPanelRange: ClosedRange<CGFloat> = 260...560
/// 盤面高寬比：略高於正方形，宮位底部（歲數、運限宮名、宮名）才放得下又不擠星曜
let boardAspect: CGFloat = 1.12   // 高比寬多一點：四化方塊疊三層時宮格比較放得下

struct ChartScreen: View {
    @EnvironmentObject var store: Store
    @ObservedObject private var sync = CloudSync.shared   // 手動更新中：盤面、運限表換成骨架
    @AppStorage("hideBirth") private var hideBirth = false

    /// 右側星曜筆記的夾宮段落：跟盤面框線同一套判斷（設定關掉夾宮提示就不列）
    private var clampsForPanel: [Clamp] {
        guard store.settings.showClamp, let m = model, let i = selPalace else { return [] }
        return ZW.clamps(m.chart, horo: m.horo, center: i, level: store.settings.clampByScope ? shownLevel : 0, hepan: hepanYear.map(Hepan.init))
    }
    let person: Person
    /// false：標題和工具列交給外層（ChartPager 多頁時統一管理）
    var chrome = true
    /// 盤面旁邊的「＋」：加第二張盤
    var onAdd: (() -> Void)? = nil
    @State private var pick: Pick
    @State private var hepanYear: Int?          // 合盤：對方出生年
    @State private var selPalace: Int?          // 盤上點選的宮位（右側顯示星曜筆記）
    @AppStorage("showInfoPanel") private var showInfo = true
    @AppStorage("infoPanelW") private var panelW: Double = Double(infoPanelWidth)   // 右側面板寬度（左緣可拖拉，會記住）
    @State private var dragStartW: Double?
    @State private var lastNarrow: Bool?        // 上一次因為視窗窄收起側欄的狀態
    @State private var handleHover = false
    @State private var annoTool: AnnoTool = .select      // 底部工具列：目前的標註工具（選取＝一般看盤）
    @State private var annoColor: AnnoColor = .red
    @State private var annoSize: AnnoSize = .medium
    @State private var keyMonitor: Any?     // 標註工具快捷鍵（V P H R T E、Esc 回到選取）
    @State private var model: ChartModel?
    @State private var shownLevel = 1           // 盤面用的層級：跟著 model 一起更新，避免先用舊資料畫一次
    @State private var zoom: CGFloat = 1       // 觸控板捏合縮放（1～2.5）
    @State private var zoomBase: CGFloat = 1
    /// 盤面實際排版用的倍率：捏合中先用 scaleEffect（順），放手後用這個倍率重排，字才清楚
    @State private var sharpZoom: CGFloat = 1

    /// level 沒指定時照設定「打開命盤時預設顯示大限」（預設關閉＝本命）
    /// 多張盤左右並排時，只有正在看的那一頁回報工具列位置給提示條（不然會被畫面外那頁蓋掉，高度跑掉）
    var isCurrent = true
    @State private var toolbarFrame: CGRect?
    @State private var anchorID = UUID()

    init(person: Person, level: Int? = nil, chrome: Bool = true, isCurrent: Bool = true, onAdd: (() -> Void)? = nil) {
        self.person = person
        self.chrome = chrome
        self.isCurrent = isCurrent
        self.onAdd = onAdd
        // 驗證用：ZIWEI_LEVEL=2 直接開到流年
        let lv = ProcessInfo.processInfo.environment["ZIWEI_LEVEL"].flatMap(Int.init) ?? level ?? ZSettings.stored().openLevel
        var p = Pick.today(); p.level = lv
        _pick = State(initialValue: p)
        _shownLevel = State(initialValue: lv)
        // 驗證用：ZIWEI_HEPAN=1995 直接合盤
        _hepanYear = State(initialValue: ProcessInfo.processInfo.environment["ZIWEI_HEPAN"].flatMap(Int.init))
        // 驗證用：ZIWEI_ZOOM=2 直接以放大倍率開啟
        if let z = ProcessInfo.processInfo.environment["ZIWEI_ZOOM"].flatMap(Double.init) {
            _zoom = State(initialValue: z); _zoomBase = State(initialValue: z); _sharpZoom = State(initialValue: z)
        }
    }

    private var magnify: some Gesture {
        MagnifyGesture()
            .onChanged { v in zoom = min(2.5, max(1, zoomBase * v.magnification)) }
            .onEnded { _ in
                if zoom < 1.05 { withAnimation(Motion.snap) { zoom = 1 } }
                zoomBase = zoom
                var t = Transaction(); t.disablesAnimations = true
                withTransaction(t) { sharpZoom = zoom }
            }
    }

    /// 盤面上目前顯示的運限四化（跟盤面一樣最多三層）：給星曜筆記挑三方四正有四化的星
    private var activeScopes: [(String, [String])] {
        guard let model, shownLevel >= 1 else { return [] }
        let names = ["大限", "流年", "流月", "流日", "流時"]
        return (max(1, shownLevel - 2)...shownLevel).map { (names[$0 - 1], model.horo.scope($0).mutagen) }
    }

    var body: some View {
        // 捲動區佔滿整個寬度（捲軸貼在視窗最右邊）；右側資訊卡固定浮在右上角，不跟著捲
        GeometryReader { geo in
            // 視窗太窄：先收左側欄（見下方 onChange），還是太窄才暫時藏右側面板，命盤不被犧牲
            let showInfo = self.showInfo && geo.size.width - CGFloat(panelW) - 24 >= minBoardRoom
            let panelSpace: CGFloat = showInfo ? CGFloat(panelW) + 24 : 0
            let usable = geo.size.width - panelSpace
            // 盤面高度留出：上邊距＋運限表的大限、流年兩列（約 90）＋底部工具列（約 90），一打開就看得到大限流年
            let boardW = min(usable - 48, boardMaxWidth, max(460, (geo.size.height - 210) / boardAspect))
            let _ = autoSidebar(geo.size.width)
            ZStack(alignment: .bottom) {
                ScrollView(zoom > 1 ? [.vertical, .horizontal] : .vertical) {
                    VStack(spacing: 12) {
                        Group {
                            if let model, !sync.refreshing {
                                ChartBoard(person: person, model: model, level: shownLevel, zoom: sharpZoom, hepan: hepanYear.map(Hepan.init),
                                           onResetLevel: { pick.level = 0 }, onSelect: { selPalace = $0 })
                                    .equatable()
                                    .transaction(value: pick) { $0.animation = nil }
                                    .transition(.opacity)
                            } else {
                                BoardSkeleton().transition(.opacity)
                            }
                        }
                        .frame(width: boardW * sharpZoom, height: boardW * boardAspect * sharpZoom)
                        // 標註層：畫筆、螢光筆、框線、文字（座標跟著盤面大小）
                        .overlay { AnnotationLayer(chartID: person.id, tool: annoTool, color: annoColor, size: annoSize) }
                        // 備註圖釘（像 Figma 留言）：圖釘隨時可點；選到備註工具時點盤面新增
                        .overlay { CommentLayer(chartID: person.id, active: annoTool == .comment, tool: annoTool) }
                        // 游標在命盤上：換成目前工具的游標（選取＝一般箭頭）
                        .onContinuousHover { phase in
                            switch phase {
                            case .active: (ToolCursor.overComment ? NSCursor.arrow : ToolCursor.cursor(for: annoTool)).set()
                            case .ended: NSCursor.arrow.set()
                            }
                        }
                        .scaleEffect(zoom / sharpZoom, anchor: .top)
                        .frame(width: boardW * zoom, height: boardW * boardAspect * zoom, alignment: .top)
                        .gesture(magnify)
                        // 盤面右邊的「＋」：加一張盤，左右滑動切換
                        .overlay(alignment: .trailing) {
                            if let onAdd, zoom == 1 { AddBoardButton(action: onAdd).offset(x: 40) }
                        }

                        if let model, !sync.refreshing {
                            PeriodTable(chart: model.chart, birthYear: person.birthYear, pick: $pick)
                                .transition(.opacity.combined(with: .offset(y: 8)))
                        } else {
                            PeriodTableSkeleton().transition(.opacity)
                        }

                    }
                    .frame(width: boardW * zoom)
                    .padding(.top, 14)
                    .padding(.bottom, store.settings.showComposer ? 210 : 100)   // 底部留給工具列
                    .frame(width: max(usable, boardW * zoom + 48))
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .defaultScrollAnchor(.top)
                .modifier(PullToRefresh())
                // 命盤也能捲到頂部工具列底下（跟右側面板一樣被漸層＋模糊蓋住），左右下照常裁切
                .scrollClipDisabled()
                .mask(Rectangle().padding(.top, -80))

                // 命盤區底部：跟頂部一樣的漸層＋背景模糊
                TopFade(color: .zBg, edge: .bottom, height: 90)
                    .frame(width: usable)
                    .frame(maxWidth: .infinity, alignment: .leading)

                // 底部浮動工具列（標註）：在命盤區正中間
                AnnotationToolbar(chartID: person.id, tool: $annoTool, color: $annoColor, size: $annoSize)
                    // 回報工具列的水平中心，提示條（snackbar）對齊它
                    .background(GeometryReader { tg in
                        Color.clear
                            .onAppear { reportToolbar(tg.frame(in: .global)) }
                            .onChange(of: tg.frame(in: .global)) { _, f in reportToolbar(f) }
                    })
                    .frame(width: usable)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.bottom, store.settings.showComposer ? 150 : 22)

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
                        InfoPanel(person: person, chart: model?.chart, hepanYear: $hepanYear, selectedPalace: selPalace, width: CGFloat(panelW),
                                  notesBirth: max(0, shownLevel - 2) == 0, notesScopes: activeScopes,
                                  notesClamps: clampsForPanel,
                                  notesNames: shownLevel >= 1 ? model?.horo.scope(shownLevel).palaceNames : nil,
                                  notesPrefix: shownLevel >= 1 ? ZW.scopeTags[shownLevel - 1] : "")
                            .padding(.top, 12)
                            .padding(.bottom, 96) // 底部留給右下角的快捷鈕
                            .padding(.horizontal, 16) // 留空間給卡片陰影
                    }
                    .scrollClipDisabled()
                    .frame(width: CGFloat(panelW) + 32)
                    // 左緣拖拉把手：左右拉調整面板寬度
                    .overlay(alignment: .leading) {
                        Capsule().fill(handleHover || dragStartW != nil ? Color.zGrid : .clear)
                            .frame(width: 3, height: 44)
                            .frame(width: 12).frame(maxHeight: .infinity)
                            .contentShape(Rectangle())
                            .onHover { h in
                                handleHover = h
                                if h { NSCursor.resizeLeftRight.push() } else { NSCursor.pop() }
                            }
                            // 用視窗座標算位移：把手會跟著面板移動，用自己的座標會一直抖
                            .gesture(DragGesture(minimumDistance: 1, coordinateSpace: .global)
                                .onChanged { v in
                                    let start = dragStartW ?? panelW
                                    if dragStartW == nil { dragStartW = start }
                                    let w = min(Double(infoPanelRange.upperBound), max(Double(infoPanelRange.lowerBound), start - Double(v.translation.width)))
                                    if abs(w - panelW) >= 1 { panelW = w.rounded() }
                                    // 拉寬超過 400：左側欄自動收起；拉回 360 以下再打開
                                    let wide = panelW > 400 ? true : panelW < 360 ? false : nil
                                    if let wide { NotificationCenter.default.post(name: .infoPanelWide, object: wide) }
                                }
                                .onEnded { _ in dragStartW = nil })
                            .help("左右拖拉調整寬度")
                    }
                    .padding(.trailing, 4)
                    .dimmedBlur()
                    .transition(.move(edge: .trailing).combined(with: .opacity))
                }
            }
            // 左下角「?」：看盤小提示（點開展開，點旁邊收起）
            .overlay(alignment: .bottomLeading) { TipsButton().padding(.leading, 20).padding(.bottom, 24) }
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
        .onAppear {
            // 標註工具快捷鍵：打字中（焦點在文字框）不攔；Esc 回到選取
            keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { e in
                if e.window?.firstResponder is NSText { return e }
                if !e.modifierFlags.intersection([.command, .control, .option]).isEmpty { return e }
                if e.keyCode == 53 {   // Esc
                    if annoTool != .select { withAnimation(Motion.fast) { annoTool = .select }; return nil }
                    return e
                }
                guard let ch = e.charactersIgnoringModifiers?.uppercased(),
                      let t = AnnoTool.visible.first(where: { $0.key == ch }) else { return e }
                withAnimation(Motion.fast) { annoTool = t }
                return nil
            }
        }
        .onChange(of: isCurrent) { _, now in if now, let f = toolbarFrame { reportToolbar(f) } }
        .onDisappear {
            if let m = keyMonitor { NSEvent.removeMonitor(m); keyMonitor = nil }
            // 只清自己報的：切換命盤時新頁會先報位置，舊頁才關掉
            if ToastAnchor.shared.owner == anchorID {
                ToastAnchor.shared.owner = nil
                ToastAnchor.shared.centerX = nil
                ToastAnchor.shared.top = nil
            }
        }
        // 驗證用：ZIWEI_CURSOR_DUMP=資料夾 把各工具游標存成 PNG
        .task {
            guard let dir = ProcessInfo.processInfo.environment["ZIWEI_CURSOR_DUMP"] else { return }
            for t in AnnoTool.allCases where t != .select {
                let img = ToolCursor.cursor(for: t).image
                if let tiff = img.tiffRepresentation, let rep = NSBitmapImageRep(data: tiff), let png = rep.representation(using: .png, properties: [:]) {
                    try? png.write(to: URL(fileURLWithPath: dir).appendingPathComponent("\(t.rawValue).png"))
                }
            }
        }
        .modifier(ChartChrome(enabled: chrome, title: ChartScreen.title(person, hide: hideBirth), showInfo: $showInfo))
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

    /// 命盤至少要留的寬度（扣掉右側面板後）
    private var minBoardRoom: CGFloat { 560 }

    /// 視窗變窄時自動收起左側欄；變寬到側欄放回去也夠用時再打開（中間留一段緩衝，避免一收一放來回跳）
    private func autoSidebar(_ width: CGFloat) {
        let room = width - (self.showInfo ? CGFloat(panelW) + 24 : 0)
        let narrow: Bool? = room < minBoardRoom + 40 ? true : room > minBoardRoom + 340 ? false : nil
        guard let narrow, narrow != lastNarrow else { return }
        DispatchQueue.main.async {
            lastNarrow = narrow
            NotificationCenter.default.post(name: .infoPanelWide, object: narrow)
        }
    }

    private struct TaskKey: Equatable { let person: String; let pick: Pick }

    /// 工具列位置：記下來；是目前這一頁才回報給提示條
    private func reportToolbar(_ f: CGRect) {
        toolbarFrame = f
        guard isCurrent else { return }
        ToastAnchor.shared.owner = anchorID
        ToastAnchor.shared.centerX = f.midX
        ToastAnchor.shared.top = f.minY
    }

    /// 視窗標題；隱藏生辰時姓名只留第一個字（此刻盤不用遮）
    static func title(_ p: Person, hide: Bool = false) -> String {
        p.id == NowChart.id ? "此刻 · \(p.clock ?? "")" : hide ? p.name.maskedName : p.name
    }
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

/// 命盤區左下角的「?」：點開是看盤小提示，點旁邊就收起來
struct TipsButton: View {
    @EnvironmentObject private var store: Store
    @State private var open = false
    @State private var hover = false

    var body: some View {
        Button { open.toggle() } label: {
            Image(systemName: "questionmark").font(.system(size: 13, weight: .semibold)).foregroundStyle(Color.zText2)
                .frame(width: 32, height: 32)
                .background(Circle().fill(hover || open ? Color.zHover : Color.zCard))
                .overlay(Circle().stroke(Color.zLine))
                .shadow(color: Color.zShadow, radius: 6, y: 2)
                .contentShape(Circle())
        }
        .buttonStyle(PressStyle())
        .onHover { hover = $0 }
        .help("看盤小提示")
        .popover(isPresented: $open, arrowEdge: .top) {
            VStack(alignment: .leading, spacing: 10) {
                Text("看盤小提示").zText(.calloutStrong).foregroundStyle(Color.zText)
                tip("hand.tap", "點宮位：看三方四正和宮干飛化；再點一次取消")
                tip("lock", "長按或點兩下宮位：鎖定這組三方四正，再點別的宮位就能兩組一起比較；再長按或點兩下解鎖")
                tip("arrow.triangle.2.circlepath", "右鍵宮位：以這一宮為命（轉宮）")
                tip("pencil.tip", "底部工具列可以畫線、框、箭頭和放備註；快捷鍵 V P H A R E C，Esc 回到選取")
                Divider().padding(.vertical, 2)
                // 畫面怪怪的：一鍵複製版本、系統、螢幕資訊，貼給 Jean
                Button { open = false; ReportState.shared.show() } label: {
                    Label("回報問題…", systemImage: "exclamationmark.bubble")
                        .zText(.footnote).foregroundStyle(Color.zText2)
                        .frame(maxWidth: .infinity, minHeight: 28, alignment: .leading)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .focusable(false)   // 彈窗打開時焦點會落在它身上，出現藍色框
            }
            .padding(16)
            .frame(width: 300)
        }
    }

    private func tip(_ icon: String, _ text: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Image(systemName: icon).font(Font.zCaption).foregroundStyle(Color.zText3).frame(width: 14)
            Text(text).zText(.subheadline).foregroundStyle(Color.zText2).fixedSize(horizontal: false, vertical: true)
        }
    }
}
