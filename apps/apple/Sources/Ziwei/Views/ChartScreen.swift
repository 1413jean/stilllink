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

struct ChartScreen: View {
    @EnvironmentObject var store: Store
    let person: Person
    @State private var pick = Pick.today()
    @State private var showInfo = true
    @State private var model: ChartModel?

    private var notes: [Note] { store.people.first { $0.id == person.id }?.notes ?? [] }

    var body: some View {
        HStack(spacing: 0) {
            // 中間：命盤＋運限表＋筆記串，最下面浮著輸入框（Codex 式）
            GeometryReader { geo in
                let boardW = min(geo.size.width - 48, boardMaxWidth, max(460, geo.size.height - 180))
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

                            NoteThread(notes: notes)
                        }
                        .frame(width: boardW)
                        .padding(.top, 14)
                        .padding(.bottom, 150)
                        .frame(maxWidth: .infinity)
                    }
                    .defaultScrollAnchor(.top)

                    Composer(person: person)
                        .frame(width: min(boardW, 720))
                        .padding(.top, 28)
                        .padding(.bottom, 16)
                        .frame(maxWidth: .infinity)
                        .background(
                            LinearGradient(colors: [Color.zBg.opacity(0), Color.zBg, Color.zBg], startPoint: .top, endPoint: .bottom)
                                .allowsHitTesting(false)
                        )
                }
            }

            if showInfo {
                InfoPanel(person: person, chart: model?.chart)
                    .transition(.move(edge: .trailing).combined(with: .opacity))
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

/// 筆記串：像 Codex 的對話，自己的筆記靠右
private struct NoteThread: View {
    let notes: [Note]
    var body: some View {
        if !notes.isEmpty {
            VStack(alignment: .trailing, spacing: 14) {
                ForEach(notes) { n in
                    VStack(alignment: .trailing, spacing: 4) {
                        Text(n.text)
                            .font(.system(size: 13))
                            .textSelection(.enabled)
                            .padding(.horizontal, 14).padding(.vertical, 9)
                            .background(RoundedRectangle(cornerRadius: 16).fill(Color.zSel))
                        Text(n.at.formatted(date: .abbreviated, time: .shortened))
                            .font(.system(size: 10.5)).foregroundStyle(Color.zText3)
                    }
                    .frame(maxWidth: .infinity, alignment: .trailing)
                }
            }
            .padding(.top, 18)
        }
    }
}

/// 下方輸入框（Codex 式）：先存筆記，AI 解盤之後接上
private struct Composer: View {
    @EnvironmentObject var store: Store
    let person: Person
    @State private var text = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            TextField("記下客人的問題或你的觀察…", text: $text, axis: .vertical)
                .textFieldStyle(.plain)
                .lineLimit(1...6)
                .font(.system(size: 13.5))
                .onSubmit(send)
            HStack(spacing: 10) {
                Image(systemName: "plus").font(.system(size: 13)).foregroundStyle(Color.zText2)
                Text("筆記")
                    .font(.system(size: 11.5, weight: .medium))
                    .padding(.horizontal, 8).padding(.vertical, 3)
                    .background(RoundedRectangle(cornerRadius: 6).fill(Color.zSel))
                Text("AI 解盤 · 即將推出").font(.system(size: 11.5)).foregroundStyle(Color.zText3)
                Spacer()
                Button(action: send) {
                    Image(systemName: "arrow.up")
                        .font(.system(size: 12, weight: .bold)).foregroundStyle(.white)
                        .frame(width: 28, height: 28)
                        .background(Circle().fill(text.trimmingCharacters(in: .whitespaces).isEmpty ? Color.zText3.opacity(0.5) : Color.zAccent))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 16).padding(.vertical, 12)
        .background(RoundedRectangle(cornerRadius: 18).fill(Color.zCard))
        .overlay(RoundedRectangle(cornerRadius: 18).stroke(Color.zLine))
        .shadow(color: .black.opacity(0.08), radius: 18, y: 6)
    }

    private func send() {
        let t = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !t.isEmpty, var p = store.people.first(where: { $0.id == person.id }) else { return }
        p.notes.append(Note(text: t))
        store.update(p)
        text = ""
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
