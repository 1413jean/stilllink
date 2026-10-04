import SwiftUI

/// 命盤反推生辰：只拿到一張盤（沒有出生資料）時，依幾顆星的位置倒推出生年月日時
/// 1. 生年化祿星 → 年干　2. 紅鸞：卯宮逆數到紅鸞 → 年支　3. 左輔：辰宮順數 → 月
/// 4. 三台：左輔順數 → 日（每 12 天一輪，會有 2～3 個候選）　5. 紫微位置＋五行局確認日期　6. 命宮 → 時辰
/// 公式只用來縮小範圍，最後每個候選都真的排一次盤比對（閏月、晚子時這類例外才不會漏）
struct ReverseChartPage: View {
    var onClose: () -> Void
    @State private var stem = Self.unknown
    @State private var hongluan = Self.unknown
    @State private var zuofu = Self.unknown
    @State private var santai = Self.unknown
    @State private var ming = Self.unknown
    @State private var ziwei = Self.unknown
    @State private var range = "1920–2030"
    @State private var gender: Gender = .male
    @State private var results: [Match] = []
    @State private var searching = false
    @State private var searched = false
    @State private var note = ""

    static let unknown = "不確定"
    private static let ranges = ["1900–1960", "1920–2030", "1950–2030", "1900–2100"]
    private var palaceOptions: [String] { [Self.unknown] + ZW.branches.map { $0 + "宮" } }
    /// 化祿星 → 年干（照目前設定的四化表）
    private var stemOptions: [String] {
        [Self.unknown] + ZW.stems.map { s in "\(s)年（\(ZW.stemMutagen[s]?.first ?? "")化祿）" }
    }

    struct Match: Identifiable {
        let id = UUID()
        let lunar: (y: Int, m: Int, d: Int)
        let hour: Int          // 0 早子 … 12 晚子
        var leap = false       // 閏月
        let solar: (Int, Int, Int)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                Text("命盤反推").font(.zTitle).foregroundStyle(Color.zText).padding(.bottom, 4)
                Text("只有一張盤、沒有出生資料時，照星曜位置倒推出生年月日時。條件給越多，結果越少；不確定的選「不確定」。")
                    .font(Font.zCallout).foregroundStyle(Color.zText3).padding(.bottom, 12)
                row("生年化祿", "哪一顆星帶生年化祿 → 年干") { ZMenuField(options: stemOptions, selection: $stem) }
                row("紅鸞在", "卯宮逆數到紅鸞 → 年支") { ZMenuField(options: palaceOptions, selection: $hongluan) }
                row("左輔在", "辰宮順數到左輔 → 農曆月") { ZMenuField(options: palaceOptions, selection: $zuofu) }
                row("三台在", "左輔順數到三台 → 農曆日") { ZMenuField(options: palaceOptions, selection: $santai) }
                row("紫微在", "配合五行局確認是哪一天") { ZMenuField(options: palaceOptions, selection: $ziwei) }
                row("命宮在", "寅宮順數月份、再逆數到命宮 → 時辰") { ZMenuField(options: palaceOptions, selection: $ming) }
                row("年份範圍", "同樣的干支每 60 年會重複一次") { ZMenuField(options: Self.ranges, selection: $range) }
                row("性別", "只影響打開後的盤，不影響反推", last: true) { ZSegmented(options: Gender.allCases.map { ($0, $0.rawValue) }, selection: $gender) }
                HStack {
                    Spacer()
                    Button { Task { await search() } } label: {
                        if searching { ProgressView().controlSize(.small).frame(width: 60) } else { Text("反推") }
                    }
                    .buttonStyle(ZPrimaryButton())
                    .keyboardShortcut(.defaultAction)
                    .disabled(searching)
                }
                .padding(.vertical, 16)

                if searched {
                    Text(note).font(Font.zCalloutStrong).foregroundStyle(Color.zText2).padding(.bottom, 8)
                    ForEach(Array(results.enumerated()), id: \.element.id) { i, r in
                        Button { open(r) } label: {
                            HStack(spacing: 10) {
                                Text("\(String(r.lunar.y)) \(ZW.yearGanzhi(r.lunar.y))年 \(r.leap ? "閏" : "")\(ZW.lunarMonths[r.lunar.m - 1]) \(ZW.lunarDays[r.lunar.d - 1])")
                                    .font(Font.zBody.monospacedDigit())
                                Text(r.hour == 12 ? "晚子時" : r.hour == 0 ? "早子時" : ZW.branches[r.hour] + "時")
                                    .font(Font.zBody).foregroundStyle(Color.zText2)
                                Spacer()
                                Text("國曆 " + String(format: "%d-%d-%d", r.solar.0, r.solar.1, r.solar.2)).font(Font.zCallout.monospacedDigit()).foregroundStyle(Color.zText3)
                                Image(systemName: "chevron.right").font(Font.zCaption).foregroundStyle(Color.zText3)
                            }
                            .padding(.horizontal, 12).frame(height: 40)
                            .background(RoundedRectangle(cornerRadius: 9).fill(Color.zCard))
                            .overlay(RoundedRectangle(cornerRadius: 9).stroke(Color.zLine))
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(PressStyle())
                        .padding(.bottom, 6)
                        .enterFromBelow(searched, index: min(i, 12))
                    }
                }
            }
            .frame(maxWidth: 680, alignment: .leading)
            .padding(.horizontal, 32).padding(.vertical, 20)
            .frame(maxWidth: .infinity)
        }
        .background(Color.zBg)
        .navigationTitle("")
        // 驗證用：ZIWEI_REVERSE=甲,巳,酉,未,寅,亥（年干,紅鸞,左輔,三台,紫微,命宮）自動填好並反推
        .task {
            guard let v = ProcessInfo.processInfo.environment["ZIWEI_REVERSE"], v.contains(",") else { return }
            let f = v.split(separator: ",").map(String.init)
            if let s = stemOptions.first(where: { $0.hasPrefix(f[0]) }) { stem = s }
            hongluan = f[1] + "宮"; zuofu = f[2] + "宮"; santai = f[3] + "宮"; ziwei = f[4] + "宮"; ming = f[5] + "宮"
            await search()
        }
    }

    private func row<C: View>(_ t: String, _ n: String, last: Bool = false, @ViewBuilder _ c: () -> C) -> some View {
        HStack(spacing: 24) {
            VStack(alignment: .leading, spacing: 3) {
                Text(t).font(Font.zBody).foregroundStyle(Color.zText)
                Text(n).font(Font.zCallout).foregroundStyle(Color.zText3)
            }
            Spacer()
            c().frame(width: 300)
        }
        .padding(.vertical, 12)
        .overlay(alignment: .bottom) { if !last { Rectangle().fill(Color.zLine).frame(height: 0.5) } }
    }

    /// 「子宮」→ 0；不確定 → nil
    private func idx(_ s: String) -> Int? { ZW.branches.firstIndex(of: String(s.prefix(1))).flatMap { s == Self.unknown ? nil : $0 } }

    private func search() async {
        searching = true
        defer { searching = false }
        let stemIdx = stem == Self.unknown ? nil : ZW.stems.firstIndex(of: String(stem.prefix(1)))
        let hl = idx(hongluan), zf = idx(zuofu), st = idx(santai), mg = idx(ming), zw = idx(ziwei)
        let bounds = range.split(separator: "–").compactMap { Int($0) }
        let years = (bounds.first ?? 1920)...(bounds.last ?? 2030)

        // 年：年干看化祿星、年支看紅鸞（紅鸞＝卯宮逆數到年支）
        let yearBranch = hl.map { ((3 - $0) % 12 + 12) % 12 }
        let ys = years.filter { y in
            let gz = ZW.yearGanzhi(y)
            if let s = stemIdx, gz.prefix(1) != ZW.stems[s] { return false }
            if let b = yearBranch, String(gz.suffix(1)) != ZW.branches[b] { return false }
            return true
        }
        // 月：左輔＝辰宮順數到月份
        let ms: [Int] = zf.map { [((($0 - 4) % 12) + 12) % 12 + 1] } ?? Array(1...12)
        // 日：三台＝左輔順數到日期（每 12 天一輪）
        func days(_ m: Int) -> [Int] {
            guard let st else { return Array(1...30) }
            let zfPos = zf ?? (4 + m - 1) % 12
            let first = ((st - zfPos) % 12 + 12) % 12 + 1
            return [first, first + 12, first + 24].filter { $0 <= 30 }
        }
        // 時：寅宮順數月份、再逆數到命宮
        func hours(_ m: Int) -> [Int] {
            guard let mg else { return Array(0...12) }
            let h = ((2 + m - 1 - mg) % 12 + 12) % 12
            return h == 0 ? [0, 12] : [h]
        }
        var candidates: [(Int, Int, Int, Int)] = []
        for y in ys { for m in ms { for d in days(m) { for h in hours(m) { candidates.append((y, m, d, h)) } } } }
        guard candidates.count <= 6000 else {
            results = []; note = "條件太少，可能的生日超過 \(candidates.count) 筆；多填幾項再試。"
            withAnimation(Motion.base) { searched = true }
            return
        }

        // 每個候選都真的排一次盤，所有填了的位置都要對得上
        var found: [Match] = []
        // 閏月：同一個月份數字再試一次閏月（左輔、三台的算法跟一般月份一樣）
        var tries: [(Int, Int, Int, Int, Bool)] = []
        for (y, m, d, h) in candidates {
            tries.append((y, m, d, h, false))
            if let a = Lunar.toSolar(y, m, d, leap: true), let b = Lunar.toSolar(y, m, d), a != b { tries.append((y, m, d, h, true)) }
        }
        for (y, m, d, h, leap) in tries {
            guard let s = Lunar.toSolar(y, m, d, leap: leap) else { continue }
            let p = Person(name: "反推", gender: gender, solar: "\(s.0)-\(s.1)-\(s.2)", hour: h, group: "占卜")
            let c = await Engine.shared.chart(for: p)
            func at(_ star: String) -> Int? {
                c.palaces.first { ($0.major + $0.minor + $0.adj).contains { $0.name == star } }.flatMap { ZW.branches.firstIndex(of: $0.branch) }
            }
            if let hl, at("紅鸞") != hl { continue }
            if let zf, at("左輔") != zf { continue }
            if let st, at("三台") != st { continue }
            if let zw, at("紫微") != zw { continue }
            if let mg, ZW.branches.firstIndex(of: c.palaces[c.soulIndex].branch) != mg { continue }
            if let si = stemIdx, !c.palaces.contains(where: { ($0.major + $0.minor).contains { $0.name == ZW.stemMutagen[ZW.stems[si]]?.first && $0.mutagen == "祿" } }) { continue }
            found.append(Match(lunar: (y, m, d), hour: h, leap: leap, solar: s))
        }
        results = found
        note = found.isEmpty ? "沒有符合的生日：檢查星的位置，或把年份範圍放寬。" : "找到 \(found.count) 個可能的生日（點一筆直接排盤）"
        withAnimation(Motion.base) { searched = true }
    }

    private func open(_ r: Match) {
        let h24 = r.hour == 12 ? 23 : r.hour * 2
        let p = TempChart.make(r.solar.0, r.solar.1, r.solar.2, h24, r.hour == 0 ? 30 : 0, gender, name: "反推 · \(ZW.yearGanzhi(r.lunar.y))年\(ZW.lunarMonths[r.lunar.m - 1])\(ZW.lunarDays[r.lunar.d - 1])")
        NotificationCenter.default.post(name: .openTemp, object: TempRequest(person: p, level: 0))
    }
}
