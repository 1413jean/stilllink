import SwiftUI

/// 命盤頁：上面十二宮盤面、下面運限表（兩個都跟 Mac 版共用），外框是系統導覽列
struct ChartView: View {
    let person: Person
    /// 暫時命盤（紫占、報數、四柱反查）：不存檔，右上角改成「存入命盤」
    var temporary = false
    @EnvironmentObject private var store: Store
    @Environment(\.zSettings) private var settings
    @State private var pick: Pick
    @State private var model: ChartModel?
    @State private var shownLevel: Int
    @State private var editing = false
    @State private var confirmDelete = false
    @State private var showSettings = false
    @Environment(\.dismiss) private var dismiss
    // 盤面縮放（照 Mac）：整張盤在頁面裡變大，頁面上下左右捲；捏合中先整張放大，放手後用新尺寸重排（字清楚）
    @State private var zoom: CGFloat = 1        // 排版用的倍率（1～3）
    @State private var live: CGFloat = 1        // 捏合中、還沒放手的額外倍率
    @State private var pinchAt: CGPoint = .zero // 捏的那一點（盤面上的位置，放手前的倍率）
    @State private var scrollOffset: CGPoint = .zero
    @State private var scrollPos = ScrollPosition()
    @State private var adding = false
    @State private var showPillars = false
    @State private var tempChart: TempItem?
    @State private var savedTemp = false
    @State private var selPalace: Int?      // 盤上點選的宮位（底部星曜筆記用）
    @State private var showNotes = false
    @AppStorage("hideBirth") private var hideBirth = false
    @State private var hepanYear: Int?        // 合盤：對方出生年
    @State private var hepanName: String?     // 合盤對象的名字（從命盤選時）
    @State private var showHepan = false

    /// 推到下一頁的暫時命盤
    struct TempItem: Identifiable, Hashable { let id = UUID(); let person: Person; let level: Int }

    init(person: Person, level: Int? = nil, temporary: Bool = false) {
        self.person = person
        self.temporary = temporary
        // 驗證用：ZIWEI_LEVEL=2 直接開到流年
        let lv = ProcessInfo.processInfo.environment["ZIWEI_LEVEL"].flatMap(Int.init) ?? level ?? ZSettings.stored().openLevel
        var p = Pick.today(); p.level = lv
        _pick = State(initialValue: p)
        _shownLevel = State(initialValue: lv)
        // 驗證用：ZIWEI_HEPAN=1995 直接合盤
        _hepanYear = State(initialValue: ProcessInfo.processInfo.environment["ZIWEI_HEPAN"].flatMap(Int.init))
    }

    /// 釘選狀態要看 store 裡最新的那份
    private var current: Person { store.people.first { $0.id == person.id } ?? person }
    private var isNow: Bool { person.id == Person.nowID }

    var body: some View {
        // 外層先量導覽列＋狀態列的高度（內層延伸到導覽列底下後就量不到了）
        GeometryReader { outer in
        let topInset = outer.safeAreaInsets.top
        GeometryReader { geo in
            // 手機直拿：盤面左右只留一點邊；iPad／橫放：寬度上限跟 Mac 一樣
            let phone = geo.size.width < 600
            // iPhone：宮格離螢幕左右各 16（外圈 4 放自化箭頭，盤面本身左右各留 12）
            let boardW = min(geo.size.width - (phone ? 24 : 8), 920)
            // iPhone 直拿：盤面拉長一點，宮格裡疊三層四化、流年歲數才不擠（iPad 照 Mac 比例）
            let aspect: CGFloat = geo.size.width < 600 ? 1.45 : 1.12
            ScrollView(zoom > 1 ? [.vertical, .horizontal] : .vertical, showsIndicators: false) {
                VStack(spacing: 14) {
                    if let y = hepanYear { hepanChip(y) }
                    Group {
                        if let model {
                            ChartBoard(person: person, model: model, level: shownLevel, zoom: zoom, hepan: hepanYear.map(Hepan.init),
                                       onResetLevel: { pick.level = 0 },
                                       onSelect: { selPalace = $0 },
                                       margin: phone ? 4 : 14, outerCard: !phone)
                                .equatable()
                                .transaction(value: pick) { $0.animation = nil }
                                .transition(.opacity)
                        } else {
                            BoardSkeleton().transition(.opacity)
                        }
                    }
                    .frame(width: boardW * zoom, height: boardW * aspect * zoom)
                    .scaleEffect(live, anchor: UnitPoint(x: pinchAt.x / (boardW * zoom), y: pinchAt.y / (boardW * aspect * zoom)))
                    .zIndex(1)   // 捏合中放大的盤面蓋在運限表上面
                    .gesture(MagnifyGesture()
                        .onChanged { v in
                            if live == 1 { pinchAt = v.startLocation }
                            live = min(3 / zoom, max(1 / zoom, v.magnification))
                        }
                        .onEnded { _ in commitZoom() })

                    if model == nil {
                        PeriodTableSkeleton()
                            .padding(.horizontal, phone ? 16 : 4)   // 跟宮格同一條邊
                            .frame(width: geo.size.width)
                            .transition(.opacity)
                    }
                    if let model {
                        PeriodTable(chart: model.chart, birthYear: person.birthYear, pick: $pick)
                            .padding(.horizontal, phone ? 16 : 4)   // 跟宮格同一條邊
                            .frame(width: geo.size.width)
                            .transition(.opacity.combined(with: .offset(y: 8)))
                    }
                    // 運限表底下：這位命主的備註、照片（暫時命盤、此刻盤沒有）
                    if model != nil && !temporary && !isNow && store.people.contains(where: { $0.id == person.id }) {
                        ChartRecords(personID: person.id)
                            .padding(.horizontal, phone ? 16 : 4)
                            .padding(.top, 14)
                    }
                }
                // 放大時內容比螢幕寬：寬度跟著盤面撐開，左右留一樣的邊（盤面左上角位置不變，縮放後捲動才算得準）
                .frame(width: max(geo.size.width, boardW * zoom + (geo.size.width - boardW)))
                .padding(.top, topInset + 16)   // 整頁延伸到導覽列底下，內容自己往下讓
                .padding(.bottom, 24)
            }
            // 驗證用：ZIWEI_SCROLL=1 一打開就捲到底（看捲上去之後頂端的樣子）
            // 內容可以捲到導覽列底下（被漸層＋模糊蓋住），不要在導覽列下緣硬切一條線
            .scrollClipDisabled()
            .scrollPosition($scrollPos)
            .onScrollGeometryChange(for: CGPoint.self) { $0.contentOffset } action: { _, p in scrollOffset = p }
            .defaultScrollAnchor(ProcessInfo.processInfo.environment["ZIWEI_SCROLL"] != nil ? .bottom : .top)
            // 打備註時：捲動或點盤面其他地方就收鍵盤
            .scrollDismissesKeyboard(.interactively)
            .simultaneousGesture(TapGesture().onEnded {
                UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
            })
        }
        // 捲動區延伸到導覽列底下：內容捲上去時從漸層＋模糊底下穿過，不會在導覽列下緣硬切一條線
        .ignoresSafeArea(edges: .top)
        }
        .background(Color.zBg)
        .zEdgeFades()
        // 底部浮著選到宮位的摘要：點了拉出星曜筆記
        .safeAreaInset(edge: .bottom, spacing: 0) {
            if let model, let i = selPalace, StarNotes.enabled {
                NotesBar(title: palaceTitle(model, i), stars: model.chart.palaces[i].major.map(\.name).joined()) { showNotes = true }
                    .padding(.bottom, 4)
                    .transition(.opacity.combined(with: .offset(y: 8)))
            }
        }
        .onAppear {
            // 驗證用：ZIWEI_NOTES_SHEET=1 一打開就拉出星曜筆記
            if ProcessInfo.processInfo.environment["ZIWEI_NOTES_SHEET"] != nil {
                DispatchQueue.main.asyncAfter(deadline: .now() + 2) { showNotes = true }
            }
        }
        .sheet(isPresented: $showNotes) {
            if let model, let i = selPalace {
                NotesSheet(chart: model.chart, index: i, includeBirth: max(0, shownLevel - 2) == 0, scopes: activeScopes(model),
                           clamps: notesClamps(model, i),
                           names: shownLevel >= 1 ? model.horo.scope(shownLevel).palaceNames : nil,
                           prefix: shownLevel >= 1 ? ZW.scopeTags[shownLevel - 1] : "")
                    .presentationDetents([.fraction(0.5), .large])
                    // 半頁時還能點盤面上半部換宮位，筆記跟著換（像 Apple 地圖）
                    .presentationBackgroundInteraction(.enabled(upThrough: .fraction(0.5)))
                    .presentationBackground(Color.zBg)
            }
        }
        .navigationTitle(isNow ? "此刻" : hideBirth ? person.name.maskedName : person.name)   // 隱藏生辰時標題也遮名字
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if zoom > 1 {
                ToolbarItem(placement: .topBarLeading) {
                    Button { setZoom(1) } label: { Image(systemName: "arrow.down.right.and.arrow.up.left") }
                        .accessibilityLabel("還原大小")
                }
            }
            ToolbarItem(placement: .topBarTrailing) {
                QuickMenu(pick: $pick, onNew: { adding = true }, onPillars: { showPillars = true },
                          onTemp: { tempChart = TempItem(person: $0, level: $1) }, onHepan: { showHepan = true })
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button { showSettings = true } label: { Image(systemName: "slider.horizontal.3").frame(width: 22, height: 22) }
                    .accessibilityLabel("命盤設定")
            }
            if temporary {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { saveTemp() } label: {
                        Image(systemName: savedTemp ? "checkmark" : "tray.and.arrow.down").frame(width: 22, height: 22)
                    }
                    .disabled(savedTemp)
                    .accessibilityLabel(savedTemp ? "已存入命盤" : "存入命盤")
                }
            }   // 編輯、釘選、刪除改在側欄長按命主做，這裡只留快捷排盤、設定兩顆
        }
        .confirmationDialog("刪除「\(person.name)」的命盤？", isPresented: $confirmDelete, titleVisibility: .visible) {
            Button("刪除", role: .destructive) { store.delete(person.id); dismiss() }
        } message: { Text("刪除後無法復原") }
        .sheet(isPresented: $showSettings) {
            NavigationStack {
                DisplaySettingsView(showRulesLink: true)
                    .toolbar { ToolbarItem(placement: .confirmationAction) { Button("完成") { showSettings = false } } }
            }
            .presentationDetents([.medium, .large])
        }
        .sheet(isPresented: $adding) { PersonForm() }
        .sheet(isPresented: $showHepan) {
            HepanSheet(current: person.id) { y, name in withAnimation(Motion.base) { hepanYear = y; hepanName = name } }
        }
        .sheet(isPresented: $showPillars) {
            PillarSearchSheet { tempChart = TempItem(person: $0, level: 0) }
        }
        .navigationDestination(item: $tempChart) { t in
            ChartView(person: t.person, level: t.level, temporary: true)
        }
        .sheet(isPresented: $editing) {
            PersonForm(editing: person)
        }
        .task(id: LoadKey(chart: person.chartKey + settings.calcKey, pick: pick)) {
            let target = pick, p = person
            let m = await Task.detached { await Engine.shared.model(for: p, pick: target) }.value
            guard !Task.isCancelled else { return }
            // 第一次淡入；之後換運限直接換，不讓整張盤一起動畫
            if model == nil {
                shownLevel = target.level
                withAnimation(Motion.enter) { model = m }
            } else {
                var t = Transaction(); t.disablesAnimations = true
                withTransaction(t) { model = m; shownLevel = target.level }
            }
            Engine.shared.prefetch(p, around: target)
        }
    }

    /// 暫時命盤存進命盤列表（分組「占卜」），之後在所有命盤裡找得到
    private func saveTemp() {
        store.add(person)
        Platform.haptic(.success)
        withAnimation(Motion.base) { savedTemp = true }
    }

    private func setZoom(_ z: CGFloat) {
        var t = Transaction(); t.disablesAnimations = true
        withTransaction(t) { zoom = z; live = 1 }
        if z == 1 { scrollPos.scrollTo(x: 0, y: scrollOffset.y) }
    }

    /// 放手：倍率寫進排版；捲動位置調成捏的那一點還留在手指下面
    /// （盤面在內容裡的左上角固定，所以只要把那一點放大後多出來的距離加到捲動量上）
    private func commitZoom() {
        let old = zoom
        var z = old * live
        if z < 1.05 { z = 1 }
        let k = z / old
        let target = CGPoint(x: max(0, scrollOffset.x + pinchAt.x * (k - 1)), y: max(0, scrollOffset.y + pinchAt.y * (k - 1)))
        var t = Transaction(); t.disablesAnimations = true
        withTransaction(t) { zoom = z; live = 1 }
        DispatchQueue.main.async { scrollPos.scrollTo(x: z > 1 ? target.x : 0, y: target.y) }
    }


    /// 合盤中：盤面上方一顆膠囊（對象、年干支），× 取消
    private func hepanChip(_ y: Int) -> some View {
        HStack(spacing: 8) {
            Text("合盤").zText(.footnoteStrong).foregroundStyle(Color.zOnColor)
                .padding(.horizontal, 6).padding(.vertical, 2)
                .background(RoundedRectangle(cornerRadius: 4).fill(Color.fHepan))
            Text([hepanName, "\(String(y)) \(ZW.yearGanzhi(y))年"].compactMap { $0 }.joined(separator: " · "))
                .zText(.footnote).foregroundStyle(Color.zText)
            Button { withAnimation(Motion.base) { hepanYear = nil; hepanName = nil } } label: {
                Image(systemName: "xmark").font(.system(size: 11, weight: .semibold)).foregroundStyle(Color.zText3)
                    .frame(width: 28, height: 28)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("取消合盤")
        }
        .padding(.leading, 10)
        .background(Capsule().fill(Color.zHover))
    }

    /// 宮位名稱：選到運限時用那一層的宮名（年疾厄…），跟盤面一樣
    private func palaceTitle(_ m: ChartModel, _ i: Int) -> String {
        shownLevel >= 1 ? ZW.scopeTags[shownLevel - 1] + m.horo.scope(shownLevel).palaceNames[i] : m.chart.palaces[i].name
    }

    /// 盤面上目前顯示的運限四化（跟盤面一樣最多三層）：星曜筆記挑三方四正有四化的星
    private func activeScopes(_ m: ChartModel) -> [(String, [String])] {
        guard shownLevel >= 1 else { return [] }
        let names = ["大限", "流年", "流月", "流日", "流時"]
        return (max(1, shownLevel - 2)...shownLevel).map { (names[$0 - 1], m.horo.scope($0).mutagen) }
    }

    /// 筆記的夾宮段落：跟盤面框線同一套判斷（設定關掉夾宮提示就不列）
    private func notesClamps(_ m: ChartModel, _ i: Int) -> [Clamp] {
        guard settings.showClamp else { return [] }
        return ZW.clamps(m.chart, horo: m.horo, center: i, level: settings.clampByScope ? shownLevel : 0, hepan: hepanYear.map(Hepan.init))
    }

    private struct LoadKey: Equatable { let chart: String; let pick: Pick }
}
