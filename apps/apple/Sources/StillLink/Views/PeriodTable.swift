import SwiftUI
import AppKit

/// 文墨天機下方的運限表：大限／流年小限／流月／流日／流時
struct PeriodTable: View {
    let chart: Chart
    let birthYear: Int
    @Binding var pick: Pick
    @Environment(\.zSettings) private var settings
    @State private var panning = false   // 正在拖曳捲動：放開那一下不要當成點格子
    @AppStorage("hideBirth") private var hideBirth = false   // 隱藏生辰時不顯示歲數（可推出生年）   // 每一列的選取底色共用一個 id，切換時會滑過去（類似 GSAP Flip）

    var body: some View {
        let decades = chart.palaces.map { ($0.range, $0.stem + $0.branch) }.sorted { $0.0[0] < $1.0[0] }
        let age = pick.year - birthYear + 1
        let cur = decades.firstIndex { age >= $0.0[0] && age <= $0.0[1] }
        let start = cur.map { birthYear + decades[$0].0[0] - 1 } ?? birthYear
        // 這個農曆月初一的儒略日，與月長（大月 30、小月 29）
        let j1 = jdnOf(pick.year, pick.lm)
        let jNext = pick.lm == 12 ? jdnOf(pick.year + 1, 1) : jdnOf(pick.year, pick.lm + 1)
        let monthLen = (j1 != nil && jNext != nil) ? max(29, min(30, jNext! - j1!)) : 30
        let dayStem = j1.map { ZW.dayIndex(jdn: $0 + min(pick.ld, monthLen) - 1) % 10 } ?? 0

        VStack(spacing: 0) {
            row("大限") {
                // 起限前（童限）：停在大限層級，不強制切到流年；再點一次回本命
                cell("起限前", "(童限)", group: "dec", on: cur == nil && pick.level >= 1) {
                    if cur == nil && pick.level == 1 { pick.level = 0 } else { pick.level = 1; pick.year = birthYear }
                }
                ForEach(Array(decades.enumerated()), id: \.offset) { k, d in
                    cell("\(d.0[0])~\(d.0[1])", d.1, group: "dec", on: cur == k && pick.level >= 1) {
                        if cur == k && pick.level == 1 { pick.level = 0 } else { pick.level = 1; pick.year = birthYear + d.0[0] - 1 }
                    }
                }
            }
            row("流年\n小限", enabled: pick.level >= 1) {
                ForEach(0..<10, id: \.self) { k in
                    let y = start + k
                    cell("\(y)年", hideBirth ? ZW.yearGanzhi(y) : "\(ZW.yearGanzhi(y))\(y - birthYear + 1)歲",
                         group: "year", on: y == pick.year && pick.level >= 2) {
                        pick.level = (y == pick.year && pick.level == 2) ? 1 : 2; pick.year = y
                    }
                }
            }
            row("流月", enabled: pick.level >= 2) {
                ForEach(1...12, id: \.self) { m in
                    cell(ZW.lunarMonths[m - 1], ZW.monthGanzhi(lunarYear: pick.year, month: m), group: "month", on: m == pick.lm && pick.level >= 3) {
                        pick.level = (m == pick.lm && pick.level == 3) ? 2 : 3; pick.lm = m
                    }
                }
            }
            HStack(spacing: 0) {
                head("流日")
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 0), count: 10), spacing: 0) {
                    ForEach(1...30, id: \.self) { d in
                        cell(ZW.lunarDays[d - 1], j1.map { ZW.ganzhi(ZW.dayIndex(jdn: $0 + d - 1)) }, group: "day", on: d == pick.ld && pick.level >= 4, minW: 0) {
                            pick.level = (d == pick.ld && pick.level == 4) ? 3 : 4; pick.ld = d
                        }
                        .disabled(d > monthLen)
                        .opacity(d > monthLen ? 0.25 : 1)
                    }
                }
                .disabled(pick.level < 3)
                .opacity(pick.level < 3 ? 0.35 : 1)
            }
            Divider()
            row("流時", divider: false, enabled: pick.level >= 4) {
                ForEach(0..<12, id: \.self) { h in
                    cell(ZW.branches[h] + "時", ZW.hourGanzhi(dayStem: dayStem, hour: h), group: "hour", on: h == pick.hour && pick.level >= 5) {
                        pick.level = (h == pick.hour && pick.level == 5) ? 4 : 5; pick.hour = h
                    }
                }
            }
        }
        .background(RoundedRectangle(cornerRadius: 12).fill(Color.zCard))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.zLine))
    }

    private func jdnOf(_ y: Int, _ m: Int) -> Int? {
        Lunar.toSolar(y, m, 1).map { ZW.jdn($0.0, $0.1, $0.2) }
    }

    private func head(_ t: String) -> some View {
        Text(t)
            .font(Font.zCalloutStrong)
            .multilineTextAlignment(.center)
            .frame(width: 52)
            .frame(maxHeight: .infinity)
            .background(Color.zHover)
    }

    /// enabled：要先點上一層（大限→流年→流月→流日→流時）才能點這一層
    private func row<C: View>(_ title: String, divider: Bool = true, enabled: Bool = true, @ViewBuilder _ content: () -> C) -> some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                head(title)
                PanRow(panning: $panning) {
                    HStack(spacing: 0) { content() }
                        .disabled(!enabled)
                        .opacity(enabled ? 1 : 0.35)
                }
            }
            .fixedSize(horizontal: false, vertical: true)
            if divider { Divider() }
        }
    }

    private func cell(_ main: String, _ sub: String? = nil, extra: String? = nil, group: String, on: Bool, minW: CGFloat = 64, action: @escaping () -> Void) -> some View {
        Button {
            guard !panning else { return }   // 剛拖完放開，不算點
            Sound.tap(settings, ["dec": .decade, "year": .year, "month": .month, "day": .day, "hour": .hour][group] ?? .palace)
            action()   // 選取底色直接跳過去：盤面同時要重畫，滑動動畫會被卡住，看起來反而頓
        } label: {
            VStack(spacing: 1) {
                Text(main).font(Font.zCaption)
                if let sub { Text(sub).font(Font.zMicro).opacity(0.7) }
                if let extra { Text(extra).font(Font.zMicro).foregroundStyle(on ? Color.zBg : Color.minorColor) }
            }
            .foregroundStyle(on ? Color.zBg : Color.zText)
            .frame(minWidth: minW, maxWidth: minW == 0 ? .infinity : nil, minHeight: sub == nil ? 28 : 36)
            .padding(.horizontal, 4)
            .background {
                if on { Rectangle().fill(Color.zText) }
            }
            .overlay(alignment: .trailing) { Rectangle().fill(Color.zLine).frame(width: 0.5) }
            .contentShape(Rectangle())
        }
        .buttonStyle(PressStyle())
    }
}

/// 可以左右捲的一列（運限表用）
/// - hover 到這一列時左右出現箭頭按鈕：點一下捲 6 成寬，長按持續捲
/// - 滑鼠按住左右拖；觸控板左右滑、Shift＋滾輪也可以
struct PanRow<Content: View>: View {
    @Binding var panning: Bool
    @ViewBuilder var content: Content
    @State private var offset: CGFloat = 0
    @State private var viewW: CGFloat = 0
    @State private var contentW: CGFloat = 0
    @State private var contentH: CGFloat = 36
    @State private var hover = ProcessInfo.processInfo.environment["ZIWEI_PAN_HOVER"] != nil   // 驗證用：不用 hover 也顯示箭頭
    @State private var dragStart: CGFloat?
    @State private var frame: CGRect = .zero
    @State private var monitor: Any?
    @State private var owning: Bool?
    @State private var hold: Timer?          // 長按箭頭：持續捲動
    @State private var holdDelay: DispatchWorkItem?
    @State private var held = false

    private var maxOff: CGFloat { max(0, contentW - viewW) }

    var body: some View {
        GeometryReader { g in
            content
                .fixedSize()
                .background(GeometryReader { cg in
                    Color.clear
                        .onAppear { contentW = cg.size.width; contentH = cg.size.height }
                        .onChange(of: cg.size) { _, z in contentW = z.width; contentH = z.height; clamp() }
                })
                .offset(x: -offset)
                .frame(width: g.size.width, alignment: .leading)
                .onAppear { viewW = g.size.width }
                .onChange(of: g.size.width) { _, w in viewW = w; clamp() }
        }
        .frame(height: contentH)   // GeometryReader 本身沒有高度，照內容撐
        .clipped()
        .contentShape(Rectangle())
        // 滑鼠按住左右拖（格子是按鈕，所以用 simultaneous；拖過就不算點）
        .simultaneousGesture(DragGesture(minimumDistance: 4)
            .onChanged { v in
                if dragStart == nil { dragStart = offset; panning = true }
                offset = rubber((dragStart ?? offset) - v.translation.width)
            }
            .onEnded { v in
                let end = (dragStart ?? offset) - v.predictedEndTranslation.width
                dragStart = nil
                withAnimation(Motion.base) { offset = min(max(0, end), maxOff) }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { panning = false }
            })
        .overlay(alignment: .leading) { arrow(-1) }
        .overlay(alignment: .trailing) { arrow(1) }
        .onHover { h in withAnimation(Motion.fast) { hover = h } }
        .background(GeometryReader { fg in
            Color.clear
                .onAppear { frame = fg.frame(in: .global) }
                .onChange(of: fg.frame(in: .global)) { _, f in frame = f }
        })
        .onAppear(perform: installScrollMonitor)
        .onDisappear {
            if let monitor { NSEvent.removeMonitor(monitor) }
            monitor = nil
            stopHold()
        }
    }

    /// 左右箭頭：只在 hover 這一列、而且那個方向還捲得動時出現
    @ViewBuilder
    private func arrow(_ dir: CGFloat) -> some View {
        let can = dir < 0 ? offset > 0.5 : offset < maxOff - 0.5
        if hover && can {
            Image(systemName: dir < 0 ? "chevron.left" : "chevron.right")
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(Color.zText2)
                .frame(width: 26, height: 26)
                .background(Circle().fill(Color.zRaised))
                .overlay(Circle().stroke(Color.zRaisedLine, lineWidth: 0.5))
                .shadow(color: .black.opacity(0.18), radius: 5, y: 2)
                .frame(width: 40)
                .frame(maxHeight: .infinity)
                .contentShape(Rectangle())
                // 點一下：捲 6 成寬；按住超過 0.3 秒：持續捲到放開
                .gesture(DragGesture(minimumDistance: 0)
                    .onChanged { _ in if holdDelay == nil && hold == nil { startHold(dir) } }
                    .onEnded { _ in
                        let wasHeld = held
                        stopHold()
                        if !wasHeld { step(dir) }
                    })
                .help(dir < 0 ? "往前（按住持續捲動）" : "往後（按住持續捲動）")
                .transition(.opacity)
        }
    }

    private func step(_ dir: CGFloat) {
        withAnimation(Motion.base) { offset = min(max(0, offset + dir * max(120, viewW * 0.6)), maxOff) }
    }

    private func startHold(_ dir: CGFloat) {
        held = false
        let w = DispatchWorkItem {
            held = true
            hold = Timer.scheduledTimer(withTimeInterval: 1.0 / 60, repeats: true) { _ in
                MainActor.assumeIsolated {
                    offset = min(max(0, offset + dir * 7), maxOff)
                    if offset <= 0 || offset >= maxOff { stopHold() }
                }
            }
        }
        holdDelay = w
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3, execute: w)
    }

    private func stopHold() {
        holdDelay?.cancel(); holdDelay = nil
        hold?.invalidate(); hold = nil
    }

    private func clamp() { if offset > maxOff { offset = maxOff } }

    /// 拖過頭尾時有一點阻力
    private func rubber(_ x: CGFloat) -> CGFloat {
        x < 0 ? x * 0.35 : x > maxOff ? maxOff + (x - maxOff) * 0.35 : x
    }

    /// 觸控板左右滑、Shift＋滾輪：游標在這一列上才接手；上下滑照樣捲整頁
    private func installScrollMonitor() {
        guard monitor == nil else { return }
        monitor = NSEvent.addLocalMonitorForEvents(matching: .scrollWheel) { e in
            guard maxOff > 0, !SettingsPage.isOpen, let win = e.window, win.isKeyWindow, let cv = win.contentView else { return e }
            let p = CGPoint(x: e.locationInWindow.x, y: cv.bounds.height - e.locationInWindow.y)
            guard frame.contains(p) else { return e }
            let dx = e.scrollingDeltaX, dy = e.scrollingDeltaY
            if e.hasPreciseScrollingDeltas {
                if e.phase.contains(.began) { owning = nil }
                if owning == nil, e.momentumPhase == [], dx != 0 || dy != 0 { owning = abs(dx) > abs(dy) }
                guard owning == true else { return e }
                offset = min(max(0, offset - dx), maxOff)
            } else {
                guard dx != 0 else { return e }   // 一般滾輪上下滾＝捲整頁；Shift＋滾輪才是左右
                offset = min(max(0, offset - dx * 8), maxOff)
            }
            return nil
        }
    }
}
