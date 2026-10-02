import SwiftUI

/// 文墨天機下方的運限表：大限／流年小限／流月／流日／流時
struct PeriodTable: View {
    let chart: Chart
    let birthYear: Int
    @Binding var pick: Pick
    @Environment(\.zSettings) private var settings
    @AppStorage("hideBirth") private var hideBirth = false   // 隱藏生辰時不顯示歲數（可推出生年）   // 每一列的選取底色共用一個 id，切換時會滑過去（類似 GSAP Flip）

    var body: some View {
        let decades = chart.palaces.map { ($0.range, $0.stem + $0.branch) }.sorted { $0.0[0] < $1.0[0] }
        let age = pick.year - birthYear + 1
        let cur = decades.firstIndex { age >= $0.0[0] && age <= $0.0[1] }
        let start = cur.map { birthYear + decades[$0].0[0] - 1 } ?? birthYear
        // 這個農曆月初一的儒略日，與月長（大月 30、小月 29）
        let j1 = jdnOf(pick.year, pick.lm)
        let jNext = pick.lm == 12 ? jdnOf(pick.year + 1, 1) : jdnOf(pick.year, pick.lm + 1)
        let monthLen = (j1 != nil && jNext != nil) ? max(29, min(30, jNext! - j1!)) : 30
        let dayStem = j1.map { ZW.dayIndex(jdn: $0 + min(pick.ld, monthLen) - 1) % 10 } ?? 0

        VStack(spacing: 0) {
            row("大限") {
                // 起限前（童限）：停在大限層級，不強制切到流年；再點一次回本命
                cell("起限前", "(童限)", group: "dec", on: cur == nil && pick.level >= 1) {
                    if cur == nil && pick.level == 1 { pick.level = 0 } else { pick.level = 1; pick.year = birthYear }
                }
                ForEach(Array(decades.enumerated()), id: \.offset) { k, d in
                    cell("\(d.0[0])~\(d.0[1])", d.1, group: "dec", on: cur == k && pick.level >= 1) {
                        if cur == k && pick.level == 1 { pick.level = 0 } else { pick.level = 1; pick.year = birthYear + d.0[0] - 1 }
                    }
                }
            }
            row("流年\n小限") {
                ForEach(0..<10, id: \.self) { k in
                    let y = start + k
                    cell("\(y)年", hideBirth ? ZW.yearGanzhi(y) : "\(ZW.yearGanzhi(y))\(y - birthYear + 1)歲",
                         extra: minorPalace(age: y - birthYear + 1), group: "year", on: y == pick.year && pick.level >= 2) {
                        pick.level = (y == pick.year && pick.level == 2) ? 1 : 2; pick.year = y
                    }
                }
            }
            row("流月") {
                ForEach(1...12, id: \.self) { m in
                    cell(ZW.lunarMonths[m - 1], ZW.monthGanzhi(lunarYear: pick.year, month: m), group: "month", on: m == pick.lm && pick.level >= 3) {
                        pick.level = (m == pick.lm && pick.level == 3) ? 2 : 3; pick.lm = m
                    }
                }
            }
            HStack(spacing: 0) {
                head("流日")
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 0), count: 10), spacing: 0) {
                    ForEach(1...30, id: \.self) { d in
                        cell(ZW.lunarDays[d - 1], j1.map { ZW.ganzhi(ZW.dayIndex(jdn: $0 + d - 1)) }, group: "day", on: d == pick.ld && pick.level >= 4, minW: 0) {
                            pick.level = (d == pick.ld && pick.level == 4) ? 3 : 4; pick.ld = d
                        }
                        .disabled(d > monthLen)
                        .opacity(d > monthLen ? 0.25 : 1)
                    }
                }
            }
            Divider()
            row("流時", divider: false) {
                ForEach(0..<12, id: \.self) { h in
                    cell(ZW.branches[h] + "時", ZW.hourGanzhi(dayStem: dayStem, hour: h), group: "hour", on: h == pick.hour && pick.level >= 5) {
                        pick.level = (h == pick.hour && pick.level == 5) ? 4 : 5; pick.hour = h
                    }
                }
            }
        }
        .background(RoundedRectangle(cornerRadius: 12).fill(Color.zCard))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.zLine))
    }

    private func jdnOf(_ y: Int, _ m: Int) -> Int? {
        Lunar.toSolar(y, m, 1).map { ZW.jdn($0.0, $0.1, $0.2) }
    }

    private func head(_ t: String) -> some View {
        Text(t)
            .font(Font.zCalloutStrong)
            .multilineTextAlignment(.center)
            .frame(width: 52)
            .frame(maxHeight: .infinity)
            .background(Color.zHover)
    }

    private func row<C: View>(_ title: String, divider: Bool = true, @ViewBuilder _ content: () -> C) -> some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                head(title)
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 0) { content() }
                }
            }
            .fixedSize(horizontal: false, vertical: true)
            if divider { Divider() }
        }
    }

    /// 那一歲的小限在哪一宮（小命、小兄…）
    private func minorPalace(age: Int) -> String? {
        chart.palaces.first { $0.ages.contains(age) }.map { "小" + String($0.name.prefix(1)) }
    }

    private func cell(_ main: String, _ sub: String? = nil, extra: String? = nil, group: String, on: Bool, minW: CGFloat = 64, action: @escaping () -> Void) -> some View {
        Button {
            Sound.tap(settings, ["dec": .decade, "year": .year, "month": .month, "day": .day, "hour": .hour][group] ?? .palace)
            action()   // 選取底色直接跳過去：盤面同時要重畫，滑動動畫會被卡住，看起來反而頓
        } label: {
            VStack(spacing: 1) {
                Text(main).font(Font.zCaption)
                if let sub { Text(sub).font(Font.zMicro).opacity(0.7) }
                if let extra { Text(extra).font(Font.zMicro).foregroundStyle(on ? Color.zBg : Color.minorColor) }
            }
            .foregroundStyle(on ? Color.zBg : Color.zText)
            .frame(minWidth: minW, maxWidth: minW == 0 ? .infinity : nil, minHeight: sub == nil ? 28 : 36)
            .padding(.horizontal, 4)
            .background {
                if on { Rectangle().fill(Color.zText) }
            }
            .overlay(alignment: .trailing) { Rectangle().fill(Color.zLine).frame(width: 0.5) }
            .contentShape(Rectangle())
        }
        .buttonStyle(PressStyle())
    }
}
