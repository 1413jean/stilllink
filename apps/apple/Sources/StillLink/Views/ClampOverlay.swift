import SwiftUI

/// 夾宮提示：選到被夾的宮位時，它跟左右鄰宮的交界線正中間各壓一個雙箭頭（»），尖端指向被夾的宮位
/// 箭頭底下墊一顆跟盤面同色的小膠囊，蓋住底下的字和格線，箭頭才看得清楚；出現時從鄰宮那側滑進來，之後靜止
/// 點的那一下，鄰宮往中間擠、被夾的宮位微縮一下（在 ChartBoard 做，見 squeeze）
/// 吉夾綠、凶夾紅；文字說明寫在右側星曜筆記
struct ClampOverlay: View {
    let clamps: [Clamp]
    let selected: Int
    let m: CGFloat, cw: CGFloat, ch: CGFloat
    let boardSize: CGSize
    let fs: CGFloat

    @State private var shown = false

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
            withAnimation(Motion.reduce ? nil : .spring(response: 0.32, dampingFraction: 0.8).delay(0.05)) { shown = true }
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
        let slide: CGFloat = Motion.reduce || shown ? 0 : 8
        return Image(systemName: "chevron.right.2")
            .font(.system(size: h * 0.55, weight: .bold))
            .foregroundStyle(color)
            .frame(width: w, height: h)
            .background(Capsule().fill(Color.zCard))
            .overlay(Capsule().stroke(color.opacity(0.35), lineWidth: 1))
            .rotationEffect(.degrees(angle))
            .opacity(shown ? 1 : 0)
            .offset(x: cx - w / 2 + d.dx * slide, y: cy - h / 2 + d.dy * slide)
    }
}
