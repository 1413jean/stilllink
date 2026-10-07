import SwiftUI

/// 命盤頁：上面十二宮盤面、下面運限表（兩個都跟 Mac 版共用），外框是系統導覽列
struct ChartView: View {
    let person: Person
    @EnvironmentObject private var store: Store
    @Environment(\.zSettings) private var settings
    @State private var pick: Pick
    @State private var model: ChartModel?
    @State private var shownLevel: Int
    @State private var editing = false
    @State private var confirmDelete = false
    @State private var showSettings = false
    @Environment(\.dismiss) private var dismiss
    @State private var zoom: CGFloat = 1        // 兩指捏合縮放（1～2.5）
    @State private var zoomBase: CGFloat = 1
    /// 盤面實際排版用的倍率：捏合中先用 scaleEffect（順），放手後用這個倍率重排，字才清楚
    @State private var sharpZoom: CGFloat = 1

    init(person: Person) {
        self.person = person
        // 驗證用：ZIWEI_LEVEL=2 直接開到流年
        let lv = ProcessInfo.processInfo.environment["ZIWEI_LEVEL"].flatMap(Int.init) ?? ZSettings.stored().openLevel
        var p = Pick.today(); p.level = lv
        _pick = State(initialValue: p)
        _shownLevel = State(initialValue: lv)
    }

    /// 釘選狀態要看 store 裡最新的那份
    private var current: Person { store.people.first { $0.id == person.id } ?? person }
    private var isNow: Bool { person.id == Person.nowID }

    var body: some View {
        GeometryReader { geo in
            // 手機直拿：盤面左右只留一點邊；iPad／橫放：寬度上限跟 Mac 一樣
            let boardW = min(geo.size.width - 8, 920)
            // iPhone 直拿：盤面拉長一點，宮格裡疊三層四化、流年歲數才不擠（iPad 照 Mac 比例）
            let aspect: CGFloat = geo.size.width < 600 ? 1.3 : 1.12
            ScrollView(zoom > 1 ? [.vertical, .horizontal] : .vertical) {
                VStack(spacing: 14) {
                    Group {
                        if let model {
                            ChartBoard(person: person, model: model, level: shownLevel, zoom: sharpZoom, onResetLevel: { pick.level = 0 })
                                .equatable()
                                .transaction(value: pick) { $0.animation = nil }
                                .transition(.opacity)
                        } else {
                            ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
                        }
                    }
                    .frame(width: boardW * sharpZoom, height: boardW * aspect * sharpZoom)
                    .scaleEffect(zoom / sharpZoom, anchor: .top)
                    .frame(width: boardW * zoom, height: boardW * aspect * zoom, alignment: .top)
                    .gesture(magnify)

                    if let model {
                        PeriodTable(chart: model.chart, birthYear: person.birthYear, pick: $pick)
                            .padding(.horizontal, 12)
                            .frame(width: geo.size.width)
                            .transition(.opacity.combined(with: .offset(y: 8)))
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.top, 16)
                .padding(.bottom, 24)
            }
            // 驗證用：ZIWEI_SCROLL=1 一打開就捲到底（看捲上去之後頂端的樣子）
            .defaultScrollAnchor(ProcessInfo.processInfo.environment["ZIWEI_SCROLL"] != nil ? .bottom : .top)
        }
        .background(Color.zBg)
        .zEdgeFades()
        .navigationTitle(isNow ? "此刻" : person.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if zoom > 1 {
                ToolbarItem(placement: .topBarLeading) {
                    Button { setZoom(1) } label: { Image(systemName: "arrow.down.right.and.arrow.up.left") }
                        .accessibilityLabel("還原大小")
                }
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button { showSettings = true } label: { Image(systemName: "slider.horizontal.3").frame(width: 22, height: 22) }
                    .accessibilityLabel("命盤設定")
            }
            if !isNow {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button("編輯命主資料", systemImage: "person.text.rectangle") { editing = true }
                        Button(current.pinned ? "取消釘選" : "釘選", systemImage: current.pinned ? "pin.slash" : "pin") {
                            var q = current; q.pinned.toggle(); store.update(q)
                        }
                        Divider()
                        Button("刪除命盤", systemImage: "trash", role: .destructive) { confirmDelete = true }
                    } label: {
                        Image(systemName: "ellipsis").frame(width: 22, height: 22)   // 給固定的框，圓按鈕裡才會置中
                    }
                    .accessibilityLabel("更多")
                }
            }
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
        .sheet(isPresented: $editing) {
            PersonForm(editing: person)
        }
        .task(id: LoadKey(chart: person.chartKey + settings.calcKey, pick: pick)) {
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

    private var magnify: some Gesture {
        MagnifyGesture()
            .onChanged { v in zoom = min(2.5, max(1, zoomBase * v.magnification)) }
            .onEnded { _ in setZoom(zoom < 1.05 ? 1 : zoom) }
    }

    private func setZoom(_ z: CGFloat) {
        withAnimation(Motion.snap) { zoom = z }
        zoomBase = z
        var t = Transaction(); t.disablesAnimations = true
        withTransaction(t) { sharpZoom = z }
    }

    private struct LoadKey: Equatable { let chart: String; let pick: Pick }
}

/// 此刻：用現在的時間排盤（不存檔），每分鐘更新；性別可切換
struct NowChartView: View {
    @AppStorage("nowGender") private var gender: Gender = .male
    @State private var now = Date()

    var body: some View {
        let c = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: now)
        let p = Person(id: Person.nowID, name: "此刻", gender: gender, solar: "\(c.year!)-\(c.month!)-\(c.day!)",
                       hour: SolarTime.shichen(c.hour!), group: "此刻",
                       clock: String(format: "%d-%d-%d %02d:%02d", c.year!, c.month!, c.day!, c.hour!, c.minute!))
        ChartView(person: p)
            .id(p.chartKey)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Picker("性別", selection: $gender) {
                        ForEach(Gender.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                    }
                    .pickerStyle(.segmented)
                    .fixedSize()
                }
            }
            .onReceive(Timer.publish(every: 60, on: .main, in: .common).autoconnect()) { now = $0 }
    }
}
