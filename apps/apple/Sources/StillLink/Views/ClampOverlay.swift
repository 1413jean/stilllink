import SwiftUI

/// 夾宮提示：選到被夾的宮位時，它跟左右鄰宮的交界各扣上一個鏈結（🔗）；滑鼠停在鏈結上才跳出說明卡
/// 鏈結從鄰宮那側滑到交界、轉正，最後輕輕彈一下「扣上」；每次換選取宮位用 .id 重建、重播一次
struct ClampOverlay: View {
    let clamps: [Clamp]
    let selected: Int
    let m: CGFloat, cw: CGFloat, ch: CGFloat
    let boardSize: CGSize
    let fs: CGFloat                     // 盤面基準字級：鏈結大小跟著盤面縮放

    // 動態參數：鏈結從鄰宮往交界滑的距離（宮格寬高的比例）、徽章大小、進場前的旋轉角度
    static let travel: CGFloat = 0.28
    static let badgeScale: CGFloat = 1.5   // 徽章直徑＝盤面字級 × 這個倍數（一般大小約 20pt）
    static let spin: Double = -70

    private var badge: CGFloat { max(16, fs * Self.badgeScale) }
    @State private var shown = false
    @State private var locked = false   // 滑到定位後的「扣上」彈一下
    @State private var pulse = false
    @State private var hover: Int?      // 滑鼠停在哪一道括號（0／1）

    private var color: Color { clamps.contains { !$0.good } ? Color.mJi : Color.mLu }
    private var neighbors: [Int] { [(selected + 11) % 12, (selected + 1) % 12] }

    private func rect(_ i: Int) -> CGRect {
        let (r, c) = ZW.grid[i]
        return CGRect(x: m + CGFloat(c) * cw, y: m + CGFloat(r) * ch, width: cw, height: ch)
    }

    /// 鄰宮在被選宮位的哪一邊（-1／0／1）
    private func side(_ n: Int) -> (dx: CGFloat, dy: CGFloat) {
        let (r, c) = ZW.grid[selected], (rn, cn) = ZW.grid[n]
        return (CGFloat(cn - c), CGFloat(rn - r))
    }

    var body: some View {
        let s = rect(selected)
        ZStack(alignment: .topLeading) {
            ForEach(Array(neighbors.enumerated()), id: \.offset) { k, n in
                let d = side(n)
                // 鄰宮淡淡亮一下再退掉：告訴人「是這兩宮在夾」
                Rectangle().fill(color.opacity(pulse ? 0 : 0.14))
                    .frame(width: cw, height: ch)
                    .offset(x: rect(n).minX, y: rect(n).minY)
                    .allowsHitTesting(false)
                link(d, in: s, index: k)
            }
            if let k = hover {
                card.offset(cardOrigin(for: neighbors[k], in: s))
                    .transition(.opacity)
                    .allowsHitTesting(false)
            }
        }
        .frame(width: boardSize.width, height: boardSize.height, alignment: .topLeading)
        .onAppear {
            withAnimation(Motion.reduce ? nil : .spring(response: 0.42, dampingFraction: 0.78)) { shown = true }
            withAnimation(Motion.reduce ? nil : .spring(response: 0.22, dampingFraction: 0.45).delay(0.32)) { locked = true }
            withAnimation(Motion.reduce ? nil : .easeOut(duration: 0.9).delay(0.15)) { pulse = true }
            if ProcessInfo.processInfo.environment["ZIWEI_CLAMP_HOVER"] != nil { hover = 0 }   // 驗證用：直接顯示說明卡
        }
    }

    /// 交界上的鏈結徽章：圓形底＋鏈結圖示；左右鄰宮用橫的鏈、上下鄰宮用直的鏈
    private func link(_ d: (dx: CGFloat, dy: CGFloat), in s: CGRect, index k: Int) -> some View {
        let size = badge
        // 交界中點
        let cx = d.dx < 0 ? s.minX : d.dx > 0 ? s.maxX : s.midX
        let cy = d.dy < 0 ? s.minY : d.dy > 0 ? s.maxY : s.midY
        let travelX = Motion.reduce || shown ? 0 : d.dx * cw * Self.travel
        let travelY = Motion.reduce || shown ? 0 : d.dy * ch * Self.travel
        let angle: Double = d.dx != 0 ? 45 : -45     // SF 的 link 是斜的：轉成橫的或直的
        let pop: CGFloat = locked ? (hover == k ? 1.12 : 1) : 0.86
        return Image(systemName: "link")
            .font(.system(size: size * 0.52, weight: .semibold))
            .foregroundStyle(color)
            .rotationEffect(.degrees(angle + (shown || Motion.reduce ? 0 : Self.spin)))
            .frame(width: size, height: size)
            .background(Circle().fill(Color.zCard))
            .overlay(Circle().stroke(color.opacity(0.55), lineWidth: 1))
            .shadow(color: Color.black.opacity(0.15), radius: 3, y: 1)
            .scaleEffect(Motion.reduce ? 1 : pop)
            .contentShape(Circle())
            .onHover { inside in withAnimation(Motion.fast) { hover = inside ? k : (hover == k ? nil : hover) } }
            .opacity(shown ? 1 : 0)
            .offset(x: cx - size / 2 + travelX, y: cy - size / 2 + travelY)
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

    /// 說明卡跳在鏈結右下方；右邊放不下就放左邊，不超出盤面
    private func cardOrigin(for n: Int, in s: CGRect) -> CGSize {
        let d = side(n)
        let cx = d.dx < 0 ? s.minX : d.dx > 0 ? s.maxX : s.midX
        let cy = d.dy < 0 ? s.minY : d.dy > 0 ? s.maxY : s.midY
        let h = CGFloat(clamps.count) * 52 + 10
        var x = cx + badge / 2 + 6
        if x + 240 > boardSize.width - 4 { x = cx - badge / 2 - 246 }
        let y = min(max(4, cy + badge / 2 + 4), boardSize.height - h - 4)
        return CGSize(width: max(4, x), height: y)
    }
}
