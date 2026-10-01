import SwiftUI

/// 運限選擇：level 0 本命、1 大限、2 流年、3 流月、4 流日、5 流時；年月日都是農曆
struct Pick: Equatable, Hashable {
    var level = 2
    var year: Int
    var lm: Int
    var ld: Int
    var hour: Int

    static func today() -> Pick {
        let c = Calendar.current.dateComponents([.year, .month, .day, .hour], from: Date())
        let l = Engine.shared.solarToLunar("\(c.year!)-\(c.month!)-\(c.day!)")
        return Pick(year: l.year, lm: l.month, ld: l.day, hour: SolarTime.shichen(c.hour!) % 12)
    }
}

/// 盤面寬度上限（約文墨天機的比例）
let boardMaxWidth: CGFloat = 700
let infoPanelWidth: CGFloat = 300

struct ChartScreen: View {
    @EnvironmentObject var store: Store
    let person: Person
    @State private var pick = Pick.today()
    @State private var showInfo = true
    @State private var model: ChartModel?

    var body: some View {
        // 捲動區佔滿整個寬度（捲軸貼在視窗最右邊）；右側資訊卡固定浮在右上角，不跟著捲
        GeometryReader { geo in
            let panelSpace: CGFloat = showInfo ? infoPanelWidth + 24 : 0
            let usable = geo.size.width - panelSpace
            let boardW = min(usable - 48, boardMaxWidth, max(460, geo.size.height - 180))
            ZStack(alignment: .bottom) {
                ScrollView {
                    VStack(spacing: 12) {
                        Group {
                            if let model {
                                ChartBoard(person: person, model: model, level: pick.level) { pick.level = 0 }
                                    .transition(.opacity)
                            } else {
                                BoardSkeleton().transition(.opacity)
                            }
                        }
                        .frame(width: boardW, height: boardW)

                        if let model {
                            PeriodTable(chart: model.chart, birthYear: person.birthYear, pick: $pick)
                        } else {
                            RoundedRectangle(cornerRadius: 12).fill(Color.zHover).frame(height: 210).shimmer()
                        }

                    }
                    .frame(width: boardW)
                    .padding(.top, 14)
                    .padding(.bottom, 150)
                    .frame(width: usable)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .defaultScrollAnchor(.top)

                AIComposer()
                    .frame(width: min(boardW, 720))
                    .padding(.top, 28)
                    .padding(.bottom, 16)
                    .frame(width: usable)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(
                        LinearGradient(colors: [Color.zBg.opacity(0), Color.zBg, Color.zBg], startPoint: .top, endPoint: .bottom)
                            .padding(.trailing, 16) // 不蓋到捲軸
                            .allowsHitTesting(false)
                    )
            }
            .overlay(alignment: .topTrailing) {
                if showInfo {
                    ScrollView(showsIndicators: false) {
                        InfoPanel(person: person, chart: model?.chart)
                            .padding(.top, 12)
                            .padding(.bottom, 16)
                            .padding(.horizontal, 4)
                    }
                    .frame(width: infoPanelWidth + 8)
                    .padding(.trailing, 16)
                    .transition(.move(edge: .trailing).combined(with: .opacity))
                }
            }
        }
        .background(Color.zBg)
        .navigationTitle(person.name)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button { withAnimation(.easeOut(duration: 0.2)) { showInfo.toggle() } } label: { Image(systemName: "sidebar.right") }
                    .help("客人資料")
            }
        }
        .task(id: TaskKey(person: person.chartKey, pick: pick)) {
            let m = await Engine.shared.model(for: person, pick: pick)
            withAnimation(.easeOut(duration: model == nil ? 0.18 : 0)) { model = m }
        }
    }

    private struct TaskKey: Equatable { let person: String; let pick: Pick }
}

/// 下方 AI 解盤輸入框（Codex 式）：先留位置，功能之後接上
private struct AIComposer: View {
    @State private var text = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            TextField("問問這張盤…", text: $text, axis: .vertical)
                .textFieldStyle(.plain)
                .lineLimit(1...6)
                .font(.system(size: 13.5))
            HStack(spacing: 10) {
                Image(systemName: "plus").font(.system(size: 13)).foregroundStyle(Color.zText2)
                Label("AI 解盤 · 即將推出", systemImage: "sparkle")
                    .font(.system(size: 11.5))
                    .foregroundStyle(Color.zText3)
                Spacer()
                Image(systemName: "arrow.up")
                    .font(.system(size: 12, weight: .bold)).foregroundStyle(.white)
                    .frame(width: 28, height: 28)
                    .background(Circle().fill(Color.zText3.opacity(0.45)))
                    .help("AI 解盤即將推出")
            }
        }
        .padding(.horizontal, 16).padding(.vertical, 12)
        .background(RoundedRectangle(cornerRadius: 18).fill(Color.zCard))
        .overlay(RoundedRectangle(cornerRadius: 18).stroke(Color.zLine))
        .shadow(color: .black.opacity(0.08), radius: 18, y: 6)
    }
}

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
            .animation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true), value: on)
            .onAppear { on = true }
    }
}
