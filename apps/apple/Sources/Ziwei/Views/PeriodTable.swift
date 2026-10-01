import SwiftUI

/// 文墨天機下方的運限表：大限／流年小限／流月／流日／流時
struct PeriodTable: View {
    let chart: Chart
    let birthYear: Int
    @Binding var pick: Pick

    var body: some View {
        let decades = chart.palaces.map { ($0.range, $0.stem + $0.branch) }.sorted { $0.0[0] < $1.0[0] }
        let age = pick.year - birthYear + 1
        let cur = decades.firstIndex { age >= $0.0[0] && age <= $0.0[1] }
        let start = cur.map { birthYear + decades[$0].0[0] - 1 } ?? birthYear

        VStack(spacing: 0) {
            row("大限") {
                cell("起限前", "(童限)", on: cur == nil && pick.level >= 1) { pick.level = 2; pick.year = birthYear }
                ForEach(Array(decades.enumerated()), id: \.offset) { k, d in
                    cell("\(d.0[0])~\(d.0[1])", d.1 + "限", on: cur == k && pick.level >= 1) {
                        if cur == k && pick.level == 1 { pick.level = 0 } else { pick.level = 1; pick.year = birthYear + d.0[0] - 1 }
                    }
                }
            }
            row("流年\n小限") {
                ForEach(0..<10, id: \.self) { k in
                    let y = start + k
                    cell("\(y)年", "\(ZW.yearGanzhi(y))\(y - birthYear + 1)歲", on: y == pick.year && pick.level >= 2) {
                        pick.level = (y == pick.year && pick.level == 2) ? 1 : 2; pick.year = y
                    }
                }
            }
            row("流月") {
                ForEach(1...12, id: \.self) { m in
                    cell(ZW.lunarMonths[m - 1], on: m == pick.lm && pick.level >= 3) {
                        pick.level = (m == pick.lm && pick.level == 3) ? 2 : 3; pick.lm = m
                    }
                }
            }
            HStack(spacing: 0) {
                head("流日")
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 0), count: 10), spacing: 0) {
                    ForEach(1...30, id: \.self) { d in
                        cell(ZW.lunarDays[d - 1], on: d == pick.ld && pick.level >= 4, minW: 0) {
                            pick.level = (d == pick.ld && pick.level == 4) ? 3 : 4; pick.ld = d
                        }
                    }
                }
            }
            Divider()
            row("流時", divider: false) {
                ForEach(0..<12, id: \.self) { h in
                    cell(ZW.branches[h] + "時", on: h == pick.hour && pick.level >= 5) {
                        pick.level = (h == pick.hour && pick.level == 5) ? 4 : 5; pick.hour = h
                    }
                }
            }
        }
        .background(RoundedRectangle(cornerRadius: 12).fill(Color.zCard))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.zLine))
    }

    private func head(_ t: String) -> some View {
        Text(t)
            .font(.system(size: 12, weight: .medium))
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

    private func cell(_ main: String, _ sub: String? = nil, on: Bool, minW: CGFloat = 64, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 1) {
                Text(main).font(.system(size: 11.5))
                if let sub { Text(sub).font(.system(size: 9.5)).opacity(0.7) }
            }
            .foregroundStyle(on ? Color.zBg : Color.zText)
            .frame(minWidth: minW, maxWidth: minW == 0 ? .infinity : nil, minHeight: sub == nil ? 28 : 36)
            .padding(.horizontal, 4)
            .background(on ? Color.zText : Color.clear)
            .overlay(alignment: .trailing) { Rectangle().fill(Color.zLine).frame(width: 0.5) }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
