import SwiftUI

/// 右下角「快捷排盤」：點 ✦ 直接往上展開，每項都有圖示；紫占、報數在裡面再展開
struct QuickMenu: View {
    @Binding var pick: Pick
    @State private var open = false
    @State private var sub: Sub?
    @State private var num = ""
    @State private var hover = false
    @State private var frame: CGRect = .zero      // 選單＋按鈕在視窗裡的位置（點外面就關）
    @State private var monitor: Any?

    enum Sub { case zizhan, baoshu }

    var body: some View {
        VStack(alignment: .trailing, spacing: 10) {
            if open {
                VStack(alignment: .leading, spacing: 2) {
                    item("plus.circle", "新建命盤", 0) { close(); NotificationCenter.default.post(name: .newChart, object: nil) }
                    item("square.grid.2x2", "四柱反查", 1) { close(); NotificationCenter.default.post(name: .openPillars, object: nil) }
                    item("sparkles", "紫占排盤", 2, chevron: sub == .zizhan) { toggle(.zizhan) }
                    if sub == .zizhan {
                        subItem("clock", "當前時刻起盤（男）") { go(.now(.male)) }
                        subItem("clock", "當前時刻起盤（女）") { go(.now(.female)) }
                        subItem("shuffle", "系統亂序起盤（男）") { go(.random(.male)) }
                        subItem("shuffle", "系統亂序起盤（女）") { go(.random(.female)) }
                        subItem("square.stack.3d.up", "七層限流盤（男）") { go(.sevenLayer(.male)) }
                        subItem("square.stack.3d.up", "七層限流盤（女）") { go(.sevenLayer(.female)) }
                    }
                    item("number", "報數起卦", 3, chevron: sub == .baoshu) { toggle(.baoshu) }
                    if sub == .baoshu { baoshu }
                    Rectangle().fill(Color.zLine).frame(height: 0.5).padding(.vertical, 4)
                    item("calendar", "今年流盤", 4) { flow(2) }
                    item("calendar.day.timeline.left", "本月流盤", 5) { flow(3) }
                    item("sun.max", "今日流盤", 6) { flow(4) }
                    item("clock.badge", "此時流盤", 7) { flow(5) }
                }
                .padding(6)
                .frame(width: 236)
                .background(RoundedRectangle(cornerRadius: 14).fill(Color.zCard).shadow(color: Color.zShadow, radius: 18, y: 6))
                .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.zLine))
                .transition(.opacity.combined(with: .scale(scale: 0.95, anchor: .bottomTrailing)))
            }
            Button { withAnimation(Motion.snap) { open.toggle(); if !open { sub = nil } } } label: {
                Image(systemName: open ? "xmark" : "sparkles")
                    .font(Font.zHeadline)
                    .foregroundStyle(Color.zOnColor)
                    .frame(width: 44, height: 44)
                    .background(Circle().fill(Color.zAccent))
                    .shadow(color: Color.zShadow, radius: 10, y: 4)
                    .rotationEffect(.degrees(open && !Motion.reduce ? 90 : 0))
                    .contentShape(Circle())
            }
            .buttonStyle(PressStyle())
            .onHover { hover = $0 }
            .help("快捷排盤")
        }
        .background(GeometryReader { g in
            Color.clear
                .onAppear { frame = g.frame(in: .global) }
                .onChange(of: g.frame(in: .global)) { f in frame = f }
        })
        .onChange(of: open) { isOpen in isOpen ? watchOutsideClicks() : stopWatching() }
        .onDisappear(perform: stopWatching)
        .onExitCommand { if open { close() } }
    }

    /// 選單打開時：點到選單以外的地方（盤面、側欄…）就收起來，那一下點擊照常生效
    private func watchOutsideClicks() {
        stopWatching()
        monitor = NSEvent.addLocalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { e in
            guard let h = e.window?.contentView?.bounds.height else { return e }
            let p = CGPoint(x: e.locationInWindow.x, y: h - e.locationInWindow.y)
            if !frame.contains(p) { close() }
            return e
        }
    }

    private func stopWatching() {
        if let m = monitor { NSEvent.removeMonitor(m); monitor = nil }
    }

    private var baoshu: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("心裡想著問題，隨口報一個 0–9999 的數字").font(Font.zCaption).foregroundStyle(Color.zText3)
            TextField("例如：3721", text: $num)
                .textFieldStyle(.plain).multilineTextAlignment(.center)
                .font(Font.zBody.monospacedDigit())
                .frame(height: 32)
                .background(RoundedRectangle(cornerRadius: 7).fill(Color.zBg))
                .overlay(RoundedRectangle(cornerRadius: 7).stroke(Color.zLine))
                .onChange(of: num) { v in
                    let d = String(v.filter(\.isNumber).prefix(4))
                    if d != v { num = d }
                }
                .onSubmit(submitBaoshu)
            Button("起卦", action: submitBaoshu)
                .buttonStyle(ZPrimaryButton(small: true))
                .frame(maxWidth: .infinity, alignment: .trailing)
                .disabled(Int(num) == nil)
        }
        .padding(.horizontal, 10).padding(.vertical, 8)
        .background(RoundedRectangle(cornerRadius: 9).fill(Color.zHover))
        .transition(.opacity)
    }

    private func item(_ icon: String, _ title: String, _ i: Int, chevron: Bool? = nil, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: icon).font(Font.zIcon).foregroundStyle(Color.zText).frame(width: 18)
                Text(title).font(Font.zBody).foregroundStyle(Color.zText)
                Spacer()
                if let chevron {
                    Image(systemName: "chevron.right").font(Font.zCaption).foregroundStyle(Color.zText3)
                        .rotationEffect(.degrees(chevron ? 90 : 0))
                }
            }
            .padding(.horizontal, 10).frame(height: 34)
            .contentShape(Rectangle())
        }
        .buttonStyle(QuickRowStyle())
        .enterFromBelow(open, index: 7 - i, distance: 6)
    }

    private func subItem(_ icon: String, _ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: icon).font(Font.zCaption).foregroundStyle(Color.zText3).frame(width: 18)
                Text(title).font(Font.zCallout).foregroundStyle(Color.zText2)
                Spacer()
            }
            .padding(.leading, 24).padding(.trailing, 10).frame(height: 30)
            .contentShape(Rectangle())
        }
        .buttonStyle(QuickRowStyle())
        .transition(.opacity)
    }

    private func submitBaoshu() {
        guard let n = Int(num) else { return }
        close()
        TempChart.openBaoshu(n)
    }

    private func toggle(_ s: Sub) { withAnimation(Motion.base) { sub = sub == s ? nil : s } }
    private func close() { withAnimation(Motion.exit) { open = false; sub = nil } }
    private func go(_ k: TempChart.Kind) { close(); TempChart.open(k) }

    /// 回到今天的運限，並切到指定層級
    private func flow(_ level: Int) {
        close()
        var p = Pick.today()
        p.level = level
        pick = p
    }
}

/// 選單列的 hover／按下底色（快捷選單、帳號選單共用）
struct QuickRowStyle: ButtonStyle {
    @State private var hover = false
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background(RoundedRectangle(cornerRadius: 8).fill(configuration.isPressed ? Color.zSel : hover ? Color.zHover : .clear))
            .animation(Motion.fast, value: hover)
            .onHover { hover = $0 }
    }
}

/// 紫占用的暫時命盤（不存檔，可在右側「存入命盤」）
enum TempChart {
    enum Kind { case now(Gender), random(Gender), sevenLayer(Gender) }

    static func open(_ k: Kind) {
        let p: Person, level: Int
        switch k {
        case .now(let g): p = make(Date(), g, name: "紫占 · 此刻"); level = ZSettings.stored().openLevel
        case .sevenLayer(let g): p = make(Date(), g, name: "七層限流盤"); level = 5
        case .random(let g):
            // 亂序起盤：西元 1～9999 年任一刻
            p = make(Int.random(in: Self.years), Int.random(in: 1...12), Int.random(in: 1...28),
                     Int.random(in: 0...23), Int.random(in: 0...59), g, name: "匿名"); level = ZSettings.stored().openLevel
        }
        NotificationCenter.default.post(name: .openTemp, object: TempRequest(person: p, level: level))
    }

    /// 報數起卦：報的數字（0–9999）加上起卦當下的時間當種子，亂數產生年月日時與陰陽。
    /// 文墨天機沒有公開公式；這裡的做法是「數＋時」起卦——同一分鐘報同一個數會得到同一張盤，換個時間再報就不一定。
    static func openBaoshu(_ n: Int) {
        let minute = UInt64(Date().timeIntervalSince1970 / 60)
        var rng = SeededRandom(seed: UInt64(n) &* 0x9E3779B97F4A7C15 ^ minute)
        // 西元 1～9999 年都可能；直接抽國曆日期，不經農曆換算（Foundation 在極端年份不可靠）
        let year = Int.random(in: Self.years, using: &rng)
        let month = Int.random(in: 1...12, using: &rng)
        let day = Int.random(in: 1...28, using: &rng)
        let branch = Int.random(in: 0...11, using: &rng)
        let g: Gender = Bool.random(using: &rng) ? .male : .female
        let p = make(year, month, day, branch == 0 ? 0 : branch * 2, branch == 0 ? 30 : 0, g, name: "匿名")
        NotificationCenter.default.post(name: .openTemp, object: TempRequest(person: p, level: ZSettings.stored().openLevel))
        Toast.show("報數 \(n) → 西元\(year)年\(month)月\(day)日 \(ZW.branches[branch])時 · \(g.rawValue)")
    }

    /// 亂數起盤的年份範圍
    static let years = 1...9999

    static func make(_ d: Date, _ g: Gender, name: String) -> Person {
        let c = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: d)
        return make(c.year!, c.month!, c.day!, c.hour!, c.minute!, g, name: name)
    }

    static func make(_ y: Int, _ m: Int, _ d: Int, _ h: Int, _ min: Int, _ g: Gender, name: String) -> Person {
        // 1582-10-5～14 在格里曆改曆時被跳過，不存在（iztro 會報錯）→ 移到 10-15
        let d = (y == 1582 && m == 10 && (5...14).contains(d)) ? 15 : d
        return Person(name: name, gender: g, solar: "\(y)-\(m)-\(d)", hour: SolarTime.shichen(h),
               group: "占卜", clock: String(format: "%d-%d-%d %02d:%02d", y, m, d, h, min))
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

/// 可指定種子的亂數（SplitMix64）
struct SeededRandom: RandomNumberGenerator {
    private var state: UInt64
    init(seed: UInt64) { state = seed }
    mutating func next() -> UInt64 {
        state &+= 0x9E3779B97F4A7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58476D1CE4E5B9
        z = (z ^ (z >> 27)) &* 0x94D049BB133111EB
        return z ^ (z >> 31)
    }
}
