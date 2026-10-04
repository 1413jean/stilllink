import SwiftUI

/// 夾宮提示：選到被夾的宮位時，一條線把「左鄰宮＋被選宮位＋右鄰宮」整個圈起來（角落宮位是 L 形）
/// 一條淡淡的框線把三宮框起來，框線帶一點點波紋、慢慢沿著框流動；進場時沿著外框畫一圈
/// 顏色刻意淡：只是一點點提示，不搶盤面。夾宮的文字說明寫在右側星曜筆記裡，盤面上不跳卡片
/// 只有這一層的 Canvas 在重畫（每秒 24 格），不會牽動整張盤；「減少動態效果」時兩股線靜止
struct ClampOverlay: View {
    let clamps: [Clamp]
    let selected: Int
    let m: CGFloat, cw: CGFloat, ch: CGFloat
    let boardSize: CGSize
    let fs: CGFloat

    // 動態參數
    static let drawIn: Double = 0.3          // 進場畫一圈的秒數
    static let amplitude: CGFloat = 1.1      // 波紋高度（pt）：一點點就好
    static let wavelength: CGFloat = 26      // 一個波的長度（pt）
    static let flow: Double = 18             // 流動速度（pt／秒）
    static let step: CGFloat = 2             // 沿線取樣間距（pt）
    static let fps: Double = 24
    static let strength: Double = 0.55       // 整體濃淡（越小越淡）

    @State private var start = Date()

    private var color: Color { clamps.contains { !$0.good } ? Color.mJi : Color.mLu }

    var body: some View {
        let outline = Self.outline(selected: selected, m: m, cw: cw, ch: ch)
        ZStack(alignment: .topLeading) {
            TimelineView(.periodic(from: start, by: 1 / Self.fps)) { tl in
                Canvas { ctx, _ in
                    let t = tl.date.timeIntervalSince(start)
                    let progress = Motion.reduce ? 1 : min(1, max(0, t) / Self.drawIn)
                    let eased = 1 - pow(1 - progress, 3)
                    let phase = Motion.reduce ? 0 : CGFloat(t * Self.flow)
                    let k = Self.strength
                    // 底下一條淡淡的直框，上面一條帶波紋的線在流動
                    let frameLine = Self.helix(outline, phase: 0, strand: 0, upTo: eased, amplitude: 0)
                    let wave = Self.helix(outline, phase: phase, strand: 0, upTo: eased, amplitude: Self.amplitude)
                    ctx.stroke(frameLine, with: .color(color.opacity(0.35 * k)), style: StrokeStyle(lineWidth: 1, lineJoin: .miter))
                    var glow = ctx
                    glow.addFilter(.blur(radius: 2))
                    glow.stroke(wave, with: .color(color.opacity(0.25 * k)), style: StrokeStyle(lineWidth: 3, lineCap: .round))
                    ctx.stroke(wave, with: .color(color.opacity(0.85 * k)), style: StrokeStyle(lineWidth: 1.2, lineCap: .round, lineJoin: .round))
                }
            }
            .allowsHitTesting(false)

        }
        .frame(width: boardSize.width, height: boardSize.height, alignment: .topLeading)
        .allowsHitTesting(false)
        .onAppear { start = Date() }
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

    /// 沿著外框走，線在中心線兩側用正弦擺動（amplitude 0＝直框）；phase 往前推＝波紋流動
    static func helix(_ poly: [CGPoint], phase: CGFloat, strand: Int, upTo: Double, amplitude: CGFloat) -> Path {
        var samples: [CGPoint] = []
        var dist: CGFloat = 0
        for k in poly.indices {
            let a = poly[k], b = poly[(k + 1) % poly.count]
            let len = max(1, hypot(b.x - a.x, b.y - a.y))
            let n = max(1, Int(len / step))
            let nx = -(b.y - a.y) / len, ny = (b.x - a.x) / len
            for j in 0..<n {
                let f = CGFloat(j) / CGFloat(n)
                let s = dist + len * f
                let off = amplitude == 0 ? 0 : amplitude * sin((s - phase) / wavelength * 2 * .pi + (strand == 1 ? .pi : 0))
                samples.append(CGPoint(x: a.x + (b.x - a.x) * f + nx * off, y: a.y + (b.y - a.y) * f + ny * off))
            }
            dist += len
        }
        let count = max(2, Int(Double(samples.count) * upTo))
        var p = Path()
        p.move(to: samples[0])
        for q in samples.prefix(count).dropFirst() { p.addLine(to: q) }
        if upTo >= 1 { p.closeSubpath() }
        return p
    }
}
