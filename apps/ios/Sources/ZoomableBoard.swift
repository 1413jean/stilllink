import SwiftUI

/// 盤面縮放（照 Mac 的手感）：兩指捏合時先整張放大（順），放手後用放大後的尺寸重新排版（字是向量，清楚不糊）；
/// 放大後盤面自己可以上下左右捲動來看別的地方，捏的那一點會留在手指下面
struct ZoomableBoard<Content: View>: View {
    let size: CGSize                       // 不放大時盤面的大小（也是可視範圍）
    @Binding var zoom: CGFloat             // 目前排版用的倍率（1～3）
    @ViewBuilder var content: (CGFloat) -> Content   // 用這個倍率排出來的盤面

    @State private var live: CGFloat = 1                    // 捏合中、還沒放手的額外倍率
    @State private var anchor: UnitPoint = .center          // 捏的那一點（在目前盤面內容上的位置）
    @State private var offset: CGPoint = .zero              // 目前捲到哪
    @State private var position = ScrollPosition()

    var body: some View {
        ScrollView(zoom > 1 ? [.horizontal, .vertical] : [], showsIndicators: false) {
            content(zoom)
                .frame(width: size.width * zoom, height: size.height * zoom)
                .scaleEffect(live, anchor: anchor)
                .frame(width: size.width * zoom, height: size.height * zoom)
        }
        .scrollPosition($position)
        .scrollDisabled(zoom <= 1)
        .scrollBounceBehavior(.basedOnSize)
        .onScrollGeometryChange(for: CGPoint.self) { $0.contentOffset } action: { _, p in offset = p }
        .frame(width: size.width, height: size.height)
        .clipped()
        .gesture(MagnifyGesture()
            .onChanged { v in
                if live == 1 {
                    // 換算成在整個盤面內容上的位置：可視範圍裡的點＋目前捲動量
                    let p = CGPoint(x: v.startLocation.x + offset.x, y: v.startLocation.y + offset.y)
                    anchor = UnitPoint(x: p.x / (size.width * zoom), y: p.y / (size.height * zoom))
                }
                live = min(3 / zoom, max(1 / zoom, v.magnification))
            }
            .onEnded { _ in commit() })
    }

    /// 放手：倍率寫進排版，捲動位置調整成捏的那一點還在手指下面
    private func commit() {
        let old = zoom
        var z = old * live
        if z < 1.05 { z = 1 }
        let k = z / old
        // 捏的那一點在可視範圍裡的位置（放手前後要一樣）
        let ax = anchor.x * size.width * old, ay = anchor.y * size.height * old
        let screen = CGPoint(x: ax - offset.x, y: ay - offset.y)
        let nx = max(0, min(size.width * z - size.width, ax * k - screen.x))
        let ny = max(0, min(size.height * z - size.height, ay * k - screen.y))
        var t = Transaction(); t.disablesAnimations = true
        withTransaction(t) {
            zoom = z
            live = 1
            anchor = .center
        }
        DispatchQueue.main.async { position.scrollTo(x: z > 1 ? nx : 0, y: z > 1 ? ny : 0) }
    }
}
