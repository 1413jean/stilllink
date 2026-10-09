import SwiftUI

/// 夾宮提示（雙箭頭樣式，預設）：選到被夾的宮位時，它跟左右鄰宮的交界線正中間各壓一個雙箭頭（»），尖端指向被夾的宮位
/// 「吸附變色」：箭頭先是灰的、從鄰宮那側衝過來，跟鄰宮撞進來（ChartBoard 的 squeeze）同一拍「啪」地吸到交界線上，
/// 這一刻變成吉綠／凶紅、彈一下，並冒出一圈淡淡的震波；之後靜止
/// 箭頭底下墊一顆跟盤面同色的小膠囊，蓋住底下的字和格線；文字說明寫在右側星曜筆記
struct ClampOverlay: View {
    let clamps: [Clamp]
    let selected: Int
    let m: CGFloat, cw: CGFloat, ch: CGFloat
    let boardSize: CGSize
    let fs: CGFloat

    @State private var shown = false     // 衝到交界線上了
    @State private var snapped = false   // 吸附：變色、彈一下、震波
    @State private var ring = false      // 震波擴散

    private var color: Color { clamps.contains { !$0.good } ? Color.mJi : Color.mLu }

    var body: some View {
        ZStack(alignment: .topLeading) {
            ForEach([(selected + 11) % 12, (selected + 1) % 12], id: \.self) { n in
                badge(n)
            }
        }
        .frame(width: boardSize.width, height: boardSize.height, alignment: .topLeading)
        .allowsHitTesting(false)
        .onAppear {
            if Motion.reduce { shown = true; snapped = true; ring = true; return }
            // 跟鄰宮撞進來同一拍：0.09 秒加速衝到交界線 → 吸附
            withAnimation(.easeIn(duration: 0.09)) { shown = true }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.09) {
                withAnimation(.spring(response: 0.28, dampingFraction: 0.75)) { snapped = true }   // 阻尼高：吸附時只輕輕一彈，不晃
                withAnimation(.easeOut(duration: 0.55)) { ring = true }
            }
        }
    }

    /// 鄰宮 n 在被選宮位的哪一邊（-1／0／1）
    static func side(selected: Int, neighbor n: Int) -> (dx: CGFloat, dy: CGFloat) {
        let (r, c) = ZW.grid[selected], (rn, cn) = ZW.grid[n]
        return (CGFloat(cn - c), CGFloat(rn - r))
    }

    /// 交界線正中間的雙箭頭膠囊
    private func badge(_ n: Int) -> some View {
        let d = Self.side(selected: selected, neighbor: n)
        let (r, c) = ZW.grid[selected]
        let s = CGRect(x: m + CGFloat(c) * cw, y: m + CGFloat(r) * ch, width: cw, height: ch)
        let cx = d.dx < 0 ? s.minX : d.dx > 0 ? s.maxX : s.midX
        let cy = d.dy < 0 ? s.minY : d.dy > 0 ? s.maxY : s.midY
        // 箭頭方向：從鄰宮指向被夾的宮位（右＝0°）
        let angle = atan2(-d.dy, -d.dx) * 180 / .pi
        let h = max(16, fs * 1.2), w = h * 1.55
        let slide: CGFloat = shown ? 0 : (d.dx != 0 ? cw : ch) * 0.18    // 從鄰宮裡面衝過來
        let tint = snapped ? color : Color.zText3                          // 吸附前是灰的
        return ZStack {
            // 震波：吸附那一刻從箭頭往外擴散一圈
            Capsule().stroke(color, lineWidth: 1.5)
                .frame(width: w, height: h)
                .scaleEffect(ring ? 2.1 : 1)
                .opacity(snapped && !ring ? 0.7 : 0)
            Image(systemName: "chevron.right.2")
                .font(.system(size: h * 0.55, weight: .bold))
                .foregroundStyle(tint)
                .frame(width: w, height: h)
                .background(Capsule().fill(Color.zCard))
                .overlay(Capsule().stroke(tint.opacity(0.35), lineWidth: 1))
                .scaleEffect(snapped ? 1 : 0.94)
        }
        .rotationEffect(.degrees(angle))
        .opacity(shown ? 1 : 0)
        .offset(x: cx - w / 2 + d.dx * slide, y: cy - h / 2 + d.dy * slide)
    }
}

/// 夾宮提示（框線樣式）：選到被夾的宮位時，「左鄰宮＋被選宮位＋右鄰宮」三宮的外框（角落宮位是 L 形）上跑一段能量流：
/// 從被夾的宮位那一側出發，兩道光像彗星一樣沿外框往兩邊跑（前端亮、尾巴淡、光往內暈一點），在對面會合後淡掉，
/// 最後只留一條淡淡的靜止框線。只在開頭約 1 秒重畫，跑完就停（不一直動、不耗電）；「減少動態效果」時直接顯示框線
struct ClampFrameOverlay: View {
    let clamps: [Clamp]
    let selected: Int
    let m: CGFloat, cw: CGFloat, ch: CGFloat
    let boardSize: CGSize
    let fs: CGFloat

    // 動態參數
    static let duration: Double = 0.95       // 兩道光跑到對面會合的秒數
    static let tail: CGFloat = 0.2           // 彗星尾巴長度（外框周長的比例）
    static let strength: Double = 0.55       // 整體濃淡（越小越淡）

    @State private var start = Date()
    @State private var done = false

    private var color: Color { clamps.contains { !$0.good } ? Color.mJi : Color.mLu }

    var body: some View {
        let poly = Self.outline(selected: selected, m: m, cw: cw, ch: ch)
        let (r, c) = ZW.grid[selected]
        let center = CGPoint(x: m + (CGFloat(c) + 0.5) * cw, y: m + (CGFloat(r) + 0.5) * ch)
        TimelineView(.animation(minimumInterval: 1 / 60, paused: done)) { tl in
            Canvas { ctx, _ in
                let freeze = ProcessInfo.processInfo.environment["ZIWEI_CLAMP_T"].flatMap(Double.init)   // 驗證用：定格在第幾秒
                let t = freeze ?? (done || Motion.reduce ? Self.duration : tl.date.timeIntervalSince(start))
                let p = min(1, max(0, t / Self.duration))
                let k = Self.strength
                // 光跑完留下的靜止框：光跑過去之後才慢慢浮出來，要看得出來（比一般格線粗、深）
                var frame = Path(); frame.addLines(poly); frame.closeSubpath()
                ctx.stroke(frame, with: .color(color.opacity(0.9 * k * min(1, p * 1.4))), style: StrokeStyle(lineWidth: 1.8, lineJoin: .miter))
                guard p < 1 else { return }
                let track = Track(poly)
                let s0 = track.nearest(to: center)                       // 從被夾的宮位那一側出發
                let eased = 1 - pow(1 - p, 2.4)                           // 先快後慢
                let fade = p < 0.7 ? 1 : (1 - p) / 0.3                    // 快會合時淡掉
                for dir in [CGFloat(1), -1] {
                    let head = s0 + dir * eased * track.length / 2
                    let tailLen = Self.tail * track.length * CGFloat(0.4 + 0.6 * eased)
                    let n = 18
                    for q in 0..<n {
                        let a = head - dir * tailLen * CGFloat(n - q) / CGFloat(n)
                        let b = head - dir * tailLen * CGFloat(n - q - 1) / CGFloat(n)
                        let seg = track.segment(from: a, to: b)
                        let w = pow(Double(q + 1) / Double(n), 1.6)       // 越靠近前端越亮
                        // 光比靜止框亮很多：外層寬光暈往兩側暈開，內層亮線
                        var glow = ctx
                        glow.addFilter(.blur(radius: 6))
                        glow.stroke(seg, with: .color(color.opacity(0.7 * w * fade)), style: StrokeStyle(lineWidth: 12, lineCap: .round))
                        ctx.stroke(seg, with: .color(color.opacity(w * fade)), style: StrokeStyle(lineWidth: 2.2, lineCap: .round))
                    }
                }
            }
        }
        .frame(width: boardSize.width, height: boardSize.height, alignment: .topLeading)
        .allowsHitTesting(false)
        .onAppear {
            start = Date()
            if Motion.reduce { done = true; return }
            DispatchQueue.main.asyncAfter(deadline: .now() + Self.duration + 0.05) { done = true }
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
}

/// 沿著多邊形外框量長度：給一個「走了多遠」就能拿到位置，或取出一段路徑（會繞圈）
private struct Track {
    let pts: [CGPoint]
    let cum: [CGFloat]      // 每個頂點從起點走過來的距離
    let length: CGFloat

    init(_ poly: [CGPoint]) {
        pts = poly
        var c: [CGFloat] = [0]
        for i in poly.indices { let a = poly[i], b = poly[(i + 1) % poly.count]; c.append(c.last! + hypot(b.x - a.x, b.y - a.y)) }
        cum = c; length = c.last!
    }

    func point(at s0: CGFloat) -> CGPoint {
        var s = s0.truncatingRemainder(dividingBy: length); if s < 0 { s += length }
        var i = 0
        while i < pts.count - 1 && cum[i + 1] < s { i += 1 }
        let a = pts[i], b = pts[(i + 1) % pts.count]
        let f = (s - cum[i]) / max(0.001, cum[i + 1] - cum[i])
        return CGPoint(x: a.x + (b.x - a.x) * f, y: a.y + (b.y - a.y) * f)
    }

    /// a → b 的一段（中間經過的頂點也要加進去，轉角才會跟著轉）
    func segment(from a: CGFloat, to b: CGFloat) -> Path {
        var p = Path()
        let steps = max(2, Int(abs(b - a) / 3))
        p.move(to: point(at: a))
        for i in 1...steps { p.addLine(to: point(at: a + (b - a) * CGFloat(i) / CGFloat(steps))) }
        return p
    }

    /// 外框上離某點最近的位置（回傳走過的距離）
    func nearest(to q: CGPoint) -> CGFloat {
        var best: (CGFloat, CGFloat) = (0, .infinity)
        for i in pts.indices {
            let a = pts[i], b = pts[(i + 1) % pts.count]
            let ab = CGPoint(x: b.x - a.x, y: b.y - a.y)
            let len2 = max(0.001, ab.x * ab.x + ab.y * ab.y)
            let f = min(1, max(0, ((q.x - a.x) * ab.x + (q.y - a.y) * ab.y) / len2))
            let pnt = CGPoint(x: a.x + ab.x * f, y: a.y + ab.y * f)
            let d = hypot(pnt.x - q.x, pnt.y - q.y)
            if d < best.1 { best = (cum[i] + sqrt(len2) * f, d) }
        }
        return best.0
    }
}
