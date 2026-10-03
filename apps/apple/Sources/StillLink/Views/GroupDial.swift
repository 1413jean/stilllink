import SwiftUI
import AppKit

/// 刻度尺式的選擇器：選項橫向排開，下面有刻度、正中間一條主色指示線；停下來自動對齊中間，每經過一根刻度震一下
/// 操作（不是每個人都會用觸控板左右滑）：
/// - 觸控板左右滑
/// - 滑鼠滾輪：滾一格換一個
/// - 滑鼠按住左右拖
/// - 直接點選項
/// 滾動的感應範圍比尺再大一圈，游標靠在邊邊也滑得動
struct GroupDial: View {
    let options: [String]
    @Binding var selection: String
    @Environment(\.zSettings) private var settings
    @State private var offset: CGFloat = 0          // 尺捲到哪：第 i 個選項在正中間時＝i × itemW
    @State private var dragStart: CGFloat?
    @State private var tick: Int?                   // 目前在中間線上的刻度編號（換刻度就震一下）
    @State private var frame: CGRect = .zero        // 尺在視窗裡的位置（判斷滾動是不是在尺附近）
    @State private var monitor: Any?
    @State private var settle: DispatchWorkItem?
    @State private var lastStep = Date.distantPast    // 滑鼠滾輪上一次換選項的時間（一格送好幾個事件時只算一次）
    @State private var owning: Bool?                // 這一次觸控板滑動歸尺管嗎（nil＝還沒判斷）
    private let itemW: CGFloat = 76
    private let reach: CGFloat = 18                 // 感應範圍往外多 18pt

    private var last: Int { max(0, options.count - 1) }
    private var current: Int { min(max(0, Int((offset / itemW).rounded())), last) }

    var body: some View {
        // macOS 13 沒有對齊捲動的 API：退回一般的下拉選單
        if #available(macOS 14, *) { dial } else { ZMenuField(options: options, selection: $selection) }
    }

    @available(macOS 14, *)
    private var dial: some View {
        GeometryReader { g in
            let mid = g.size.width / 2
            HStack(spacing: 0) {
                ForEach(Array(options.enumerated()), id: \.element) { i, o in
                    let on = i == current
                    VStack(spacing: 5) {
                        Text(o)
                            .font(on ? Font.zBodyStrong : Font.zCallout)
                            .foregroundStyle(on ? Color.zText : Color.zText3)
                            .lineLimit(1).minimumScaleFactor(0.7)
                            .frame(height: 18)
                        ticks(major: on)
                    }
                    .frame(width: itemW)
                    .contentShape(Rectangle())
                    .onTapGesture { snap(to: i) }
                }
            }
            .fixedSize()
            .offset(x: mid - itemW / 2 - offset)
            .frame(width: g.size.width, height: g.size.height, alignment: .leading)
            .contentShape(Rectangle())
            // 滑鼠按住左右拖：放開時照甩的力道多走幾格再對齊
            .gesture(DragGesture(minimumDistance: 3)
                .onChanged { v in
                    if dragStart == nil { dragStart = offset; settle?.cancel() }
                    move(to: (dragStart ?? offset) - v.translation.width)
                }
                .onEnded { v in
                    let end = (dragStart ?? offset) - v.predictedEndTranslation.width
                    dragStart = nil
                    snap(to: Int((end / itemW).rounded()))
                })
            // 正中間的指示線
            .overlay(alignment: .bottom) {
                Capsule().fill(Color.zAccent).frame(width: 2, height: 16).allowsHitTesting(false)
            }
            // 兩側淡出
            .mask(LinearGradient(stops: [.init(color: .clear, location: 0), .init(color: .black, location: 0.18),
                                         .init(color: .black, location: 0.82), .init(color: .clear, location: 1)],
                                 startPoint: .leading, endPoint: .trailing))
            .background(GeometryReader { fg in
                Color.clear
                    .onAppear { frame = fg.frame(in: .global) }
                    .onChange(of: fg.frame(in: .global)) { f in frame = f }
            })
        }
        .frame(height: 46)
        .clipped()
        .padding(.vertical, 2)
        .background(RoundedRectangle(cornerRadius: 10).fill(Color.zCard))
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.zLine))
        .onAppear {
            offset = CGFloat(options.firstIndex(of: selection) ?? 0) * itemW
            installScrollMonitor()
        }
        .onDisappear {
            if let monitor { NSEvent.removeMonitor(monitor) }
            monitor = nil
        }
        .onChange(of: selection) { s in
            guard let i = options.firstIndex(of: s), i != current else { return }
            withAnimation(Motion.snap) { offset = CGFloat(i) * itemW }
        }
    }

    /// 跟著手指／滑鼠走（超出頭尾時有一點阻力），每經過一根刻度震一下
    private func move(to x: CGFloat) {
        let lo: CGFloat = 0, hi = CGFloat(last) * itemW
        let v = x < lo ? lo + (x - lo) * 0.35 : x > hi ? hi + (x - hi) * 0.35 : x
        offset = v
        let t = Int((v / (itemW / 5)).rounded(.down))
        if t != tick {
            if tick != nil && settings.haptics { NSHapticFeedbackManager.defaultPerformer.perform(.alignment, performanceTime: .now) }
            tick = t
        }
    }

    /// 對齊到第 i 個並選它
    private func snap(to i: Int) {
        settle?.cancel()
        let i = min(max(0, i), last)
        withAnimation(Motion.snap) { offset = CGFloat(i) * itemW }
        tick = Int((CGFloat(i) * itemW / (itemW / 5)).rounded(.down))
        if options.indices.contains(i), options[i] != selection { selection = options[i] }
    }

    /// 滾動事件：游標在尺（含外圍一圈）上才接手
    /// - 觸控板：只接左右滑，上下滑照樣捲整頁
    /// - 滑鼠滾輪：上下滾一格＝換一個
    private func installScrollMonitor() {
        guard monitor == nil else { return }
        monitor = NSEvent.addLocalMonitorForEvents(matching: .scrollWheel) { e in
            guard let win = e.window, win.isKeyWindow, let content = win.contentView else { return e }
            let p = CGPoint(x: e.locationInWindow.x, y: content.bounds.height - e.locationInWindow.y)
            guard frame.insetBy(dx: -reach, dy: -reach).contains(p) else { return e }
            if e.hasPreciseScrollingDeltas {
                // 觸控板：上下為主的滑動不攔（讓整頁捲動）；動量結束或停手後對齊
                let dx = e.scrollingDeltaX, dy = e.scrollingDeltaY
                // 每次滑動開始時判斷一次方向：左右為主才歸尺管，之後的慣性也跟著同一個判斷
                if e.phase.contains(.began) { owning = nil }
                if owning == nil, e.momentumPhase == [], dx != 0 || dy != 0 { owning = abs(dx) > abs(dy) }
                guard owning == true else { return e }
                settle?.cancel()
                move(to: offset - dx)
                let w = DispatchWorkItem { snap(to: current) }
                settle = w
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.12, execute: w)
            } else {
                let d = e.scrollingDeltaY != 0 ? e.scrollingDeltaY : e.scrollingDeltaX
                guard d != 0, Date().timeIntervalSince(lastStep) > 0.09 else { return nil }
                lastStep = Date()
                snap(to: current + (d < 0 ? 1 : -1))
            }
            return nil
        }
    }

    /// 每個選項下面一組刻度：中間長、兩旁短
    private func ticks(major: Bool) -> some View {
        HStack(alignment: .bottom, spacing: 0) {
            ForEach(0..<5, id: \.self) { i in
                Capsule()
                    .fill(i == 2 ? (major ? Color.zText2 : Color.zText3) : Color.zLine)
                    .frame(width: 1, height: i == 2 ? 12 : 6)
                    .frame(maxWidth: .infinity)
            }
        }
        .frame(height: 12)
    }
}
