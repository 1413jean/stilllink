import SwiftUI
import AppKit

/// 刻度尺式的選擇器：選項橫向排開，下面有刻度、正中間一條主色指示線；
/// 觸控板左右滑或直接點，停下來自動對齊中間。滑的過程中每經過一個選項就震一下
struct GroupDial: View {
    let options: [String]
    @Binding var selection: String
    @Environment(\.zSettings) private var settings
    @State private var pos: String?          // 停下來對齊的那一個（決定選擇）
    @State private var live: String?         // 滑動中目前在中間的那一個（震動、即時反白）
    @State private var tick: Int?            // 目前在中間線上的刻度編號（換刻度就震一下）
    private let itemW: CGFloat = 76

    var body: some View {
        GeometryReader { g in
            let mid = g.size.width / 2
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 0) {
                    ForEach(options, id: \.self) { o in
                        let on = o == (live ?? pos)
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
                        .onTapGesture { withAnimation(Motion.snap) { pos = o } }
                        // 回報每個選項在尺上的位置，算出誰在中間
                        .background(GeometryReader { ig in
                            Color.clear.preference(key: DialCenters.self, value: [o: ig.frame(in: .named("dial")).midX])
                        })
                        .id(o)
                    }
                }
                .scrollTargetLayout()
            }
            .coordinateSpace(name: "dial")
            .contentMargins(.horizontal, max(0, mid - itemW / 2), for: .scrollContent)
            .scrollTargetBehavior(.viewAligned)
            .scrollPosition(id: $pos, anchor: .center)
            .onPreferenceChange(DialCenters.self) { centers in
                guard let nearest = centers.min(by: { abs($0.value - mid) < abs($1.value - mid) })?.key else { return }
                // 每一根刻度經過中間指示線就輕震一下（像轉動實體刻度盤）
                if let first = options.first, let c0 = centers[first] {
                    let t = Int(((mid - c0) / (itemW / 5)).rounded(.down))
                    if t != tick {
                        if tick != nil && settings.haptics {
                            NSHapticFeedbackManager.defaultPerformer.perform(.alignment, performanceTime: .now)
                        }
                        tick = t
                    }
                }
                if nearest != live { live = nearest }
            }
            // 正中間的指示線
            .overlay(alignment: .bottom) {
                Capsule().fill(Color.zAccent).frame(width: 2, height: 16).allowsHitTesting(false)
            }
            // 兩側淡出
            .mask(LinearGradient(stops: [.init(color: .clear, location: 0), .init(color: .black, location: 0.18),
                                         .init(color: .black, location: 0.82), .init(color: .clear, location: 1)],
                                 startPoint: .leading, endPoint: .trailing))
        }
        .frame(height: 46)
        .padding(.vertical, 2)
        .background(RoundedRectangle(cornerRadius: 10).fill(Color.zCard))
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.zLine))
        .onAppear { pos = selection }
        .onChange(of: selection) { _, s in if pos != s { pos = s } }
        .onChange(of: pos) { _, p in
            guard let p, p != selection else { return }
            selection = p
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

/// 每個選項的中心位置（在尺上的 x）
private struct DialCenters: PreferenceKey {
    static let defaultValue: [String: CGFloat] = [:]
    static func reduce(value: inout [String: CGFloat], nextValue: () -> [String: CGFloat]) {
        value.merge(nextValue()) { _, n in n }
    }
}

