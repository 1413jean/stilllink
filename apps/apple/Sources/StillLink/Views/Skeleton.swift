import SwiftUI

// MARK: - 載入骨架（Mac、iOS 共用）：資料還沒算好時先排出跟真內容一樣的形狀，算好再淡入

/// 載入中的盤面骨架
struct BoardSkeleton: View {
    var body: some View {
        GeometryReader { geo in
            let m: CGFloat = 18
            let cw = (geo.size.width - m * 2) / 4
            let ch = (geo.size.height - m * 2) / 4
            ZStack(alignment: .topLeading) {
                ForEach(0..<12, id: \.self) { i in
                    let (r, c) = ZW.grid[i]
                    VStack(alignment: .leading, spacing: 6) {
                        HStack(spacing: 4) {
                            ForEach(0..<4, id: \.self) { _ in RoundedRectangle(cornerRadius: 3).fill(Color.zHover).frame(width: cw * 0.09, height: ch * 0.28) }
                        }
                        Spacer()
                        RoundedRectangle(cornerRadius: 3).fill(Color.zHover).frame(width: cw * 0.55, height: 8)
                        HStack {
                            RoundedRectangle(cornerRadius: 3).fill(Color.zHover).frame(width: cw * 0.22, height: ch * 0.18)
                            Spacer()
                            RoundedRectangle(cornerRadius: 3).fill(Color.zHover).frame(width: cw * 0.12, height: ch * 0.24)
                        }
                    }
                    .padding(8)
                    .frame(width: cw, height: ch)
                    .overlay(Rectangle().stroke(Color.zLine, lineWidth: 0.5))
                    .offset(x: m + CGFloat(c) * cw, y: m + CGFloat(r) * ch)
                }
                VStack(spacing: 10) {
                    RoundedRectangle(cornerRadius: 4).fill(Color.zHover).frame(width: cw * 0.7, height: 16)
                    ForEach(0..<4, id: \.self) { _ in RoundedRectangle(cornerRadius: 3).fill(Color.zHover).frame(width: cw * 1.2, height: 9) }
                }
                .frame(width: cw * 2, height: ch * 2)
                .offset(x: m + cw, y: m + ch)
            }
        }
        .shimmer()
        .background(RoundedRectangle(cornerRadius: 12).fill(Color.zCard))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.zLine))
    }
}

extension View {
    /// 骨架的呼吸動畫
    func shimmer() -> some View { modifier(Shimmer()) }
}

private struct Shimmer: ViewModifier {
    @State private var on = false
    func body(content: Content) -> some View {
        content
            .opacity(on ? 0.55 : 1)
            .animation(Motion.reduce ? nil : .easeInOut(duration: 0.8).repeatForever(autoreverses: true), value: on)
            .onAppear { on = true }
    }
}

/// 運限表的骨架：大限、流年、流月、流日、流時五列，每列左邊標題格＋右邊一排格子
struct PeriodTableSkeleton: View {
    var body: some View {
        VStack(spacing: 0) {
            ForEach(0..<5, id: \.self) { r in
                HStack(spacing: 0) {
                    Rectangle().fill(Color.zHover).frame(width: 52)
                    HStack(spacing: 12) {
                        ForEach(0..<6, id: \.self) { _ in
                            VStack(spacing: 4) {
                                RoundedRectangle(cornerRadius: 3).fill(Color.zHover).frame(width: 34, height: 9)
                                RoundedRectangle(cornerRadius: 3).fill(Color.zHover).frame(width: 24, height: 7)
                            }
                            .frame(maxWidth: .infinity)
                        }
                    }
                    .padding(.horizontal, 8)
                }
                .frame(height: r == 3 ? 96 : 40)
                if r < 4 { Divider() }
            }
        }
        .shimmer()
        .background(RoundedRectangle(cornerRadius: 12).fill(Color.zCard))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.zLine))
    }
}

/// 一小段文字的骨架（例：命宮主星還沒算出來）
struct SkeletonBar: View {
    var width: CGFloat = 48
    var height: CGFloat = 10
    var body: some View {
        RoundedRectangle(cornerRadius: height / 2).fill(Color.zLine)   // 放在淺灰卡片上，要比卡片深一階才看得到
            .frame(width: width, height: height)
            .shimmer()
    }
}

/// 列表一列的骨架（Mac 側欄、iPhone 所有命盤）：頭像圓點＋名字＋一行小字；寬度依序變化，看起來不像複製貼上
struct ListRowSkeleton: View {
    var index = 0
    var avatar: CGFloat = 22
    var body: some View {
        let widths: [CGFloat] = [0.55, 0.4, 0.62, 0.48, 0.35, 0.58]
        GeometryReader { g in
            HStack(spacing: 10) {
                Circle().fill(Color.zHover).frame(width: avatar, height: avatar)
                VStack(alignment: .leading, spacing: 5) {
                    RoundedRectangle(cornerRadius: 3).fill(Color.zHover)
                        .frame(width: (g.size.width - avatar - 10) * widths[index % widths.count], height: 9)
                    RoundedRectangle(cornerRadius: 3).fill(Color.zHover)
                        .frame(width: (g.size.width - avatar - 10) * widths[(index + 3) % widths.count] * 0.6, height: 7)
                }
                Spacer(minLength: 0)
            }
            .frame(maxHeight: .infinity)
        }
        .shimmer()
    }
}
