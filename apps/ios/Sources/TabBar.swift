import SwiftUI

/// 底部分頁列（照 Instagram）：只有圖示、垂直置中；選到的那格墊一塊淺灰膠囊，切換時滑過去。
/// 系統 TabView 不寫文字也會保留文字的位置，圖示會偏上，所以自己排；材質用 iOS 26 的 Liquid Glass
struct GlassTabBar: View {
    @Binding var tab: RootView.Tab
    @Namespace private var ns

    var body: some View {
        HStack(spacing: 0) {
            item(.home, label: "首頁") { HomeGlyph(filled: $0) }
            item(.people, label: "命盤") { Image(systemName: $0 ? "person.2.fill" : "person.2").font(.system(size: 22)) }
            item(.settings, label: "設定") { Image(systemName: $0 ? "gearshape.fill" : "gearshape").font(.system(size: 23)) }
        }
        .padding(5)
        .modifier(GlassCapsule())
        .padding(.horizontal, 24)
    }

    private func item<I: View>(_ t: RootView.Tab, label: String, @ViewBuilder icon: (Bool) -> I) -> some View {
        let on = tab == t
        return Button {
            if !on { Platform.haptic(.alignment) }
            withAnimation(.spring(response: 0.32, dampingFraction: 0.82)) { tab = t }
        } label: {
            icon(on)
                .foregroundStyle(Color.zText)
                .frame(maxWidth: .infinity)
                .frame(height: 54)
                .background {
                    if on {
                        Capsule().fill(Color.zText.opacity(0.08))
                            .matchedGeometryEffect(id: "pill", in: ns)
                    }
                }
                .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
        .accessibilityAddTraits(on ? .isSelected : [])
    }
}

/// iOS 26 用 Liquid Glass；舊系統退回毛玻璃＋細框
private struct GlassCapsule: ViewModifier {
    func body(content: Content) -> some View {
        // 26.1 起：26.0 測試版（模擬器）缺 Liquid Glass 的型別，一用就閃退
        if #available(iOS 26.1, *) {
            content.glassEffect(.regular.interactive(), in: Capsule())
        } else {
            content
                .background(.regularMaterial, in: Capsule())
                .overlay(Capsule().stroke(Color.zLine.opacity(0.6), lineWidth: 0.5))
                .shadow(color: .black.opacity(0.1), radius: 16, y: 4)
        }
    }
}

/// 側欄按鈕（照 Claude）：三條由長到短的細線
struct SidebarGlyph: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            ForEach([20.0, 15, 9], id: \.self) { w in
                Capsule().frame(width: w, height: 1.8)
            }
        }
        .frame(width: 22, height: 22, alignment: .leading)
    }
}

/// 首頁圖示：圓角五邊形的房子（沒有門），選到實心、沒選到空心
struct HomeGlyph: View {
    var filled: Bool
    var body: some View {
        Group {
            if filled {
                HouseShape().fill(style: FillStyle())
            } else {
                HouseShape().stroke(style: StrokeStyle(lineWidth: 2.1, lineCap: .round, lineJoin: .round))
            }
        }
        .frame(width: 24, height: 24)
    }
}

struct HouseShape: Shape {
    func path(in r: CGRect) -> Path {
        let w = r.width, h = r.height
        func p(_ x: CGFloat, _ y: CGFloat) -> CGPoint { CGPoint(x: r.minX + x * w, y: r.minY + y * h) }
        // 屋頂尖、屋簷、牆角：每個轉角都用切線圓弧修圓
        let apex = p(0.5, 0.08), rightEave = p(0.92, 0.42), br = p(0.92, 0.92), bl = p(0.08, 0.92), leftEave = p(0.08, 0.42)
        let start = CGPoint(x: (bl.x + br.x) / 2, y: br.y)
        var path = Path()
        path.move(to: start)
        path.addArc(tangent1End: br, tangent2End: rightEave, radius: w * 0.16)
        path.addArc(tangent1End: rightEave, tangent2End: apex, radius: w * 0.1)
        path.addArc(tangent1End: apex, tangent2End: leftEave, radius: w * 0.12)
        path.addArc(tangent1End: leftEave, tangent2End: bl, radius: w * 0.1)
        path.addArc(tangent1End: bl, tangent2End: br, radius: w * 0.16)
        path.closeSubpath()
        return path
    }
}
