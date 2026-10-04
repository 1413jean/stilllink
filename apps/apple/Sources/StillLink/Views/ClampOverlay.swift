import SwiftUI

/// 夾宮提示：選到被夾的宮位時，一條線把「左鄰宮＋被選宮位＋右鄰宮」整個圈起來（角落宮位是 L 形）
/// 線像電流一樣微微跳動，讓人感覺三宮被鏈在一起；進場時沿著外框畫一圈；滑鼠停在線上才跳出說明卡
/// 只有這一層的 Canvas 在重畫（每秒 12 格），不會牽動整張盤；「減少動態效果」時是一條靜止的線
struct ClampOverlay: View {
    let clamps: [Clamp]
    let selected: Int
    let m: CGFloat, cw: CGFloat, ch: CGFloat
    let boardSize: CGSize
    let fs: CGFloat

    // 動態參數
    static let drawIn: Double = 0.55         // 進場畫一圈的秒數
    static let jitter: CGFloat = 1.3         // 平常的抖動幅度（pt）
    static let spark: CGFloat = 3.2          // 偶爾閃一下的幅度（pt）
    static let sparkChance: Double = 0.06    // 每個取樣點閃一下的機率
    static let step: CGFloat = 5             // 沿線取樣間距（pt）
    static let fps: Double = 12

    @State private var start = Date()
    @State private var hoverAt: CGPoint?

    private var color: Color { clamps.contains { !$0.good } ? Color.mJi : Color.mLu }

    var body: some View {
        let outline = Self.outline(selected: selected, m: m, cw: cw, ch: ch)
        ZStack(alignment: .topLeading) {
            TimelineView(.periodic(from: start, by: 1 / Self.fps)) { tl in
                Canvas { ctx, _ in
                    let t = tl.date.timeIntervalSince(start)
                    let progress = Motion.reduce ? 1 : min(1, max(0, t) / Self.drawIn)
                    let eased = 1 - pow(1 - progress, 3)
                    let frame = Motion.reduce ? -1 : Int(t * Self.fps)
                    let path = Self.electric(outline, frame: frame, upTo: eased)
                    // 外層光暈＋內層實線
                    var glow = ctx
                    glow.addFilter(.blur(radius: 3))
                    glow.stroke(path, with: .color(color.opacity(0.45)), style: StrokeStyle(lineWidth: 4, lineCap: .round, lineJoin: .round))
                    ctx.stroke(path, with: .color(color), style: StrokeStyle(lineWidth: 1.6, lineCap: .round, lineJoin: .round))
                }
            }
            .allowsHitTesting(false)

            // 滑鼠感應：只有線附近 14pt 一圈，不擋宮位點擊
            OutlineBand(points: outline, width: 14)
                .fill(Color.white.opacity(0.001))
                .onContinuousHover { phase in
                    switch phase {
                    case .active(let p): hoverAt = p
                    case .ended: withAnimation(Motion.fast) { hoverAt = nil }
                    }
                }

            if let p = hoverAt {
                card.offset(cardOrigin(near: p))
                    .transition(.opacity)
                    .allowsHitTesting(false)
            }
        }
        .frame(width: boardSize.width, height: boardSize.height, alignment: .topLeading)
        .onAppear {
            start = Date()
            if ProcessInfo.processInfo.environment["ZIWEI_CLAMP_HOVER"] != nil, let p = outline.first {   // 驗證用：直接顯示說明卡
                hoverAt = CGPoint(x: p.x + cw * 0.5, y: p.y)
            }
        }
    }

    /// 三格的外框（宮位依地支前後相鄰，一定連在一起：一直線或 L 形），順時針頂點
    static func outline(selected s: Int, m: CGFloat, cw: CGFloat, ch: CGFloat) -> [CGPoint] {
        let cells = [(s + 11) % 12, s, (s + 1) % 12].map { ZW.grid[$0] }
        let r0 = cells.map(\.0).min()!, r1 = cells.map(\.0).max()!
        let c0 = cells.map(\.1).min()!, c1 = cells.map(\.1).max()!
        func pts(_ g: [(Int, Int)]) -> [CGPoint] { g.map { CGPoint(x: m + CGFloat($0.0) * cw, y: m + CGFloat($0.1) * ch) } }
        // 一直線：外框就是包住三格的長方形
        if r0 == r1 || c0 == c1 {
            return pts([(c0, r0), (c1 + 1, r0), (c1 + 1, r1 + 1), (c0, r1 + 1)])
        }
        // L 形：2×2 少一格
        let x0 = c0, x1 = c0 + 1, x2 = c0 + 2, y0 = r0, y1 = r0 + 1, y2 = r0 + 2
        let has = { (r: Int, c: Int) in cells.contains { $0 == (r, c) } }
        if !has(r0, c0) { return pts([(x1, y0), (x2, y0), (x2, y2), (x0, y2), (x0, y1), (x1, y1)]) }
        if !has(r0, c1) { return pts([(x0, y0), (x1, y0), (x1, y1), (x2, y1), (x2, y2), (x0, y2)]) }
        if !has(r1, c1) { return pts([(x0, y0), (x2, y0), (x2, y1), (x1, y1), (x1, y2), (x0, y2)]) }
        return pts([(x0, y0), (x2, y0), (x2, y2), (x1, y2), (x1, y1), (x0, y1)])
    }

    /// 沿著外框每 step 取一點，往垂直方向抖一下（偶爾大一點的閃），畫到 upTo（0～1）為止；frame < 0 不抖
    static func electric(_ poly: [CGPoint], frame: Int, upTo: Double) -> Path {
        var samples: [CGPoint] = []
        var idx = 0
        for k in poly.indices {
            let a = poly[k], b = poly[(k + 1) % poly.count]
            let len = max(1, hypot(b.x - a.x, b.y - a.y))
            let n = max(1, Int(len / step))
            let nx = -(b.y - a.y) / len, ny = (b.x - a.x) / len
            for j in 0..<n {
                let f = CGFloat(j) / CGFloat(n)
                var off: CGFloat = 0
                if frame >= 0 && j > 0 {   // 轉角那一點不抖，外框的角才會利落
                    let h1 = hash(idx, frame), h2 = hash(idx &* 7 &+ 3, frame)
                    off = (CGFloat(h1) * 2 - 1) * jitter
                    if h2 < sparkChance { off += (h1 < 0.5 ? -1 : 1) * spark }
                }
                samples.append(CGPoint(x: a.x + (b.x - a.x) * f + nx * off, y: a.y + (b.y - a.y) * f + ny * off))
                idx += 1
            }
        }
        let count = max(2, Int(Double(samples.count) * upTo))
        var p = Path()
        p.move(to: samples[0])
        for q in samples.prefix(count).dropFirst() { p.addLine(to: q) }
        if upTo >= 1 { p.closeSubpath() }
        return p
    }

    /// 0～1 的偽亂數（同一格同一點固定，換格才變）
    private static func hash(_ i: Int, _ frame: Int) -> Double {
        let v = sin(Double(i) * 12.9898 + Double(frame) * 78.233) * 43758.5453
        return v - floor(v)
    }

    /// 說明卡（樣式同星曜說明卡）
    private var card: some View {
        VStack(alignment: .leading, spacing: 6) {
            ForEach(clamps, id: \.self) { c in
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Circle().fill(c.good ? Color.mLu : Color.mJi).frame(width: 7, height: 7)
                        Text(c.name).font(Font.zBodyStrong).foregroundStyle(Color.white)
                    }
                    Text(c.meaning).font(Font.zCallout).foregroundStyle(Color.white.opacity(0.85))
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .padding(.horizontal, 12).padding(.vertical, 9)
        .frame(width: 240, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 12).fill(Color(white: 0.16)))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.white.opacity(0.08)))
        .shadow(color: Color.black.opacity(0.25), radius: 12, y: 5)
    }

    /// 說明卡跳在滑鼠右下方；放不下就往左、往上，不超出盤面
    private func cardOrigin(near p: CGPoint) -> CGSize {
        let h = CGFloat(clamps.count) * 60 + 10
        var x = p.x + 14, y = p.y + 14
        if x + 240 > boardSize.width - 4 { x = p.x - 254 }
        if y + h > boardSize.height - 4 { y = p.y - h - 10 }
        return CGSize(width: max(4, x), height: max(4, y))
    }
}

/// 沿著外框的一圈帶狀區域（滑鼠感應用）
private struct OutlineBand: Shape {
    let points: [CGPoint]
    let width: CGFloat
    func path(in _: CGRect) -> Path {
        var p = Path()
        p.addLines(points)
        p.closeSubpath()
        return p.strokedPath(StrokeStyle(lineWidth: width, lineJoin: .miter))
    }
}
