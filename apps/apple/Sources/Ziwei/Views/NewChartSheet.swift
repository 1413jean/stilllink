import SwiftUI

/// 新增命盤彈窗：照 Claude 設定頁——分區標題，每列左邊標題＋說明、右邊控制項，列之間細線
struct NewChartSheet: View {
    @EnvironmentObject var store: Store
    var editing: Person? = nil      // 有值＝編輯既有命盤
    var onClose: () -> Void
    var onCreated: (Person) -> Void

    @State private var name = ""
    @State private var gender: Gender = .female
    @State private var group = "客人"
    @State private var calendar = 0 // 0 國曆、1 農曆
    @State private var y = 1995
    @State private var m = 1
    @State private var d = 1
    @State private var leap = false
    @State private var hh = 12
    @State private var mi = 0
    @State private var unknownTime = false
    @State private var region: PlaceRegion = Places.taiwan
    @State private var city: PlaceCity? = Places.taiwan.cities.first
    @State private var loaded = false
    @State private var placeQuery = ""
    @FocusState private var nameFocused: Bool
    @State private var addingGroup = false
    @State private var newGroup = ""
    @State private var extraGroups: [String] = []
    @FocusState private var groupFocused: Bool
    private static let addGroupLabel = "＋ 新增分組…"

    private let controlWidth: CGFloat = 340
    private var canSubmit: Bool { !name.trimmingCharacters(in: .whitespaces).isEmpty }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(editing == nil ? "新增命盤" : "編輯命主資料").font(.zTitle).foregroundStyle(Color.zText)
                .padding(.horizontal, 32)
                .padding(.top, 20)
                .padding(.bottom, 4)

            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    sectionTitle("基本資料")
                    row("姓名", "客人的名字或代稱") {
                        TextField("例如：林小姐", text: $name).textFieldStyle(.plain)
                            .focused($nameFocused)
                            .inputBox()
                    }
                    row("性別", "影響大限順逆") {
                        ZSegmented(options: Gender.allCases.map { ($0, $0.rawValue) }, selection: $gender)
                    }
                    row("分組", "顯示在側欄的資料夾，可自己新增", last: true) {
                        if addingGroup {
                            HStack(spacing: 8) {
                                TextField("新分組名稱，例如：VIP", text: $newGroup).textFieldStyle(.plain)
                                    .focused($groupFocused)
                                    .onSubmit(commitGroup)
                                    .inputBox()
                                Button("完成", action: commitGroup).buttonStyle(ZSecondaryButton())
                                    .disabled(newGroup.trimmingCharacters(in: .whitespaces).isEmpty)
                            }
                            .transition(.opacity)
                        } else {
                            ZMenuField(options: groupOptions + [Self.addGroupLabel], selection: Binding(
                                get: { group },
                                set: { v in
                                    if v == Self.addGroupLabel {
                                        withAnimation(Motion.base) { addingGroup = true }
                                        DispatchQueue.main.async { groupFocused = true }
                                    } else { group = v }
                                }))
                        }
                    }

                    sectionTitle("出生時間")
                    row("曆法", "輸入的日期是國曆還是農曆") {
                        ZSegmented(options: [(0, "國曆"), (1, "農曆")], selection: $calendar)
                    }
                    row("出生日期", calendar == 0 ? "國曆年月日" : "農曆年月日") {
                        HStack(spacing: 10) {
                            HStack(spacing: 2) {
                                NumberField(value: $y, range: 1900...2100, width: 50)
                                unit("年")
                                NumberField(value: $m, range: 1...12, width: 30)
                                unit("月")
                                NumberField(value: $d, range: 1...31, width: 30)
                                unit("日")
                                Spacer(minLength: 0)
                            }
                            .inputBox()
                            if calendar == 1 {
                                Toggle("閏月", isOn: $leap).toggleStyle(.checkbox).font(Font.zBody)
                            }
                        }
                    }
                    row("出生時間", "24 小時制，以出生地鐘錶時間為準") {
                        HStack(spacing: 2) {
                            NumberField(value: $hh, range: 0...23, width: 30, pad: true)
                            unit(":")
                            NumberField(value: $mi, range: 0...59, width: 30, pad: true)
                            Spacer(minLength: 0)
                            Text(ZW.hours[SolarTime.shichen(hh)] + "時").font(Font.zCallout).foregroundStyle(Color.zText3)
                        }
                        .inputBox()
                        .disabled(unknownTime)
                        .opacity(unknownTime ? 0.4 : 1)
                    }
                    row("時間不確定", "不知道出生時間時，以午時排盤", last: true) {
                        HStack { Spacer(); Toggle("", isOn: $unknownTime).toggleStyle(.switch).labelsHidden() }
                    }

                    sectionTitle("出生地")
                    VStack(alignment: .leading, spacing: 10) {
                        Text("用經緯度換算真太陽時。上下捲動選擇國家／地區與城市。")
                            .font(Font.zCallout).foregroundStyle(Color.zText3)
                        HStack(spacing: 8) {
                            Image(systemName: "magnifyingglass").font(Font.zIcon).foregroundStyle(Color.zText3)
                            TextField("搜尋國家或城市，例如：高雄、東京、New York", text: $placeQuery).textFieldStyle(.plain)
                            if !placeQuery.isEmpty {
                                Button { placeQuery = "" } label: { Image(systemName: "xmark.circle.fill").foregroundStyle(Color.zText3) }
                                    .buttonStyle(.plain)
                            }
                        }
                        .inputBox()
                        Group {
                            if placeHits.isEmpty && !placeQuery.isEmpty {
                                Text("找不到「\(placeQuery)」，試試其他寫法或改用下方清單。")
                                    .font(Font.zCallout).foregroundStyle(Color.zText3)
                                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                                    .background(RoundedRectangle(cornerRadius: 9).fill(Color.zCard))
                                    .overlay(RoundedRectangle(cornerRadius: 9).stroke(Color.zLine))
                            } else if !placeQuery.isEmpty {
                                ZColumnList(items: placeHits, id: \.city.id, label: { "\($0.region.name) · \($0.city.name)" }, selected: city?.id) { h in
                                    region = h.region; city = h.city
                                    placeQuery = ""
                                }
                            } else {
                                HStack(spacing: 10) {
                                    ZColumnList(items: Places.all, id: \.id, label: \.name, selected: region.id) { r in
                                        region = r
                                        city = r.cities.first
                                    }
                                    .frame(width: 220)
                                    ZColumnList(items: region.cities, id: \.id, label: \.name, selected: city?.id) { c in city = c }
                                }
                            }
                        }
                        .frame(height: 220)
                        if let city {
                            Text(String(format: "%@ · %@　經度 %.4f°%@　緯度 %.4f°%@　%@", region.name, city.name,
                                        abs(city.lon), city.lon >= 0 ? "E" : "W", abs(city.lat), city.lat >= 0 ? "N" : "S", city.tz))
                                .font(Font.zCaption.monospacedDigit()).foregroundStyle(Color.zText2)
                        }
                    }
                    .padding(.vertical, 12)
                    .overlay(alignment: .bottom) { Rectangle().fill(Color.zLine).frame(height: 0.5) }
                    row("排盤時間", "實際用來排盤的時間與時辰", last: true) {
                        Text(previewText)
                            .font(Font.zBody.monospacedDigit())
                            .foregroundStyle(Color.zText)
                            .frame(maxWidth: .infinity, alignment: .trailing)
                    }
                }
                .padding(.horizontal, 32)
                .padding(.bottom, 8)
            }
            .scrollIndicators(.automatic)

            HStack(spacing: 10) {
                Spacer()
                Button("取消", action: onClose).buttonStyle(ZSecondaryButton())
                Button(editing == nil ? "排盤" : "儲存", action: submit)
                    .keyboardShortcut(.defaultAction)
                    .buttonStyle(ZPrimaryButton())
                    .disabled(!canSubmit)
            }
            .padding(.horizontal, 32)
            .padding(.vertical, 18)
            .overlay(alignment: .top) { Rectangle().fill(Color.zLine).frame(height: 0.5) }
        }
        .frame(maxWidth: 760)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.zBg)
        .navigationTitle("")
        .onAppear { load(); nameFocused = true }
    }

    /// 編輯時把原本的資料帶進表單
    private func load() {
        guard !loaded, let p = editing else { return }
        loaded = true
        name = p.name; gender = p.gender; group = p.group
        let src = p.clock ?? "\(p.solar) \(String(format: "%02d", max(0, p.hour * 2 - (p.hour == 12 ? 1 : 0))) ):00"
        let parts = src.split(whereSeparator: { $0 == " " || $0 == "-" || $0 == ":" }).compactMap { Int($0) }
        if parts.count >= 5 { (y, m, d, hh, mi) = (parts[0], parts[1], parts[2], parts[3], parts[4]) }
        calendar = 0
        if let pl = p.place {
            // 先比名字，再找最近的城市
            let best = Places.all.flatMap { r in r.cities.map { (r, $0) } }
                .min { a, b in dist(a.1, pl) < dist(b.1, pl) }
            if let best { region = best.0; city = best.1 }
        } else {
            city = nil
        }
    }

    private func dist(_ c: PlaceCity, _ p: BirthPlace) -> Double {
        (c.lat - p.latitude) * (c.lat - p.latitude) + (c.lon - p.longitude) * (c.lon - p.longitude)
    }

    // MARK: 版面元件

    private func sectionTitle(_ t: String) -> some View {
        Text(t).font(Font.zHeadline).foregroundStyle(Color.zText)
            .padding(.top, 22).padding(.bottom, 4)
    }

    private func unit(_ t: String) -> some View {
        Text(t).font(Font.zInput).foregroundStyle(Color.zText3)
    }

    /// 設定列：左邊標題＋說明，右邊固定寬度的控制項欄；列之間細線
    private func row<C: View>(_ title: String, _ note: String, last: Bool = false, @ViewBuilder _ control: () -> C) -> some View {
        HStack(alignment: .center, spacing: 24) {
            VStack(alignment: .leading, spacing: 3) {
                Text(title).font(Font.zBody).foregroundStyle(Color.zText)
                Text(note).font(Font.zCallout).foregroundStyle(Color.zText3)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            control()
                .frame(width: controlWidth)
        }
        .padding(.vertical, 12)
        .overlay(alignment: .bottom) { if !last { Rectangle().fill(Color.zLine).frame(height: 0.5) } }
    }

    // MARK: 資料

    struct PlaceHit: Hashable { let region: PlaceRegion; let city: PlaceCity }

    /// 出生地搜尋：比對國家名、城市名、時區（不分大小寫）
    private var placeHits: [PlaceHit] {
        let q = placeQuery.trimmingCharacters(in: .whitespaces).lowercased()
        guard !q.isEmpty else { return [] }
        var out: [PlaceHit] = []
        for r in Places.all {
            let regionHit = r.name.lowercased().contains(q)
            for c in r.cities where regionHit || c.name.lowercased().contains(q) || c.tz.lowercased().contains(q) {
                out.append(PlaceHit(region: r, city: c))
            }
        }
        return Array(out.prefix(80))
    }

    private var groupOptions: [String] {
        var g = ["客人", "家人", "朋友"]
        for p in store.people where !g.contains(p.group) { g.append(p.group) }
        for x in extraGroups where !g.contains(x) { g.append(x) }
        if !g.contains(group) { g.append(group) }
        return g
    }

    private func commitGroup() {
        let t = newGroup.trimmingCharacters(in: .whitespaces)
        if !t.isEmpty { extraGroups.append(t); group = t }
        newGroup = ""
        withAnimation(Motion.base) { addingGroup = false }
    }

    private var place: BirthPlace? {
        city.map { BirthPlace(name: region.name == $0.name ? $0.name : "\(region.name)\($0.name)", latitude: $0.lat, longitude: $0.lon, timeZoneID: $0.tz) }
    }

    /// 算出排盤用的國曆日期、時辰與真太陽時
    private func resolved() -> (solar: String, hour: Int, clock: String, trueSolar: String?) {
        let (sy, sm, sd): (Int, Int, Int) = {
            if calendar == 0 { return (y, m, d) }
            let s = Engine.shared.lunarToSolar(y, m, d, leap: leap).split(separator: "-").compactMap { Int($0) }
            return s.count == 3 ? (s[0], s[1], s[2]) : (y, m, d)
        }()
        let (h, mm) = unknownTime ? (12, 0) : (hh, mi)
        let clock = String(format: "%d-%d-%d %02d:%02d", sy, sm, sd, h, mm)
        guard let place, !unknownTime, let tz = TimeZone(identifier: place.timeZoneID) else {
            return ("\(sy)-\(sm)-\(sd)", SolarTime.shichen(h), clock, nil)
        }
        let r = SolarTime.compute(year: sy, month: sm, day: sd, hour: h, minute: mm, longitude: place.longitude, tz: tz)
        let ts = String(format: "%d-%d-%d %02d:%02d", r.ymd.0, r.ymd.1, r.ymd.2, r.hm.0, r.hm.1)
        return ("\(r.ymd.0)-\(r.ymd.1)-\(r.ymd.2)", r.shichen, clock, ts)
    }

    private var previewText: String {
        let r = resolved()
        let sc = ZW.hours[r.hour] + "時"
        if unknownTime { return "以午時排盤" }
        if let ts = r.trueSolar { return "真太陽時 \(ts) · \(sc)" }
        return "\(r.clock) · \(sc)"
    }

    private func submit() {
        guard canSubmit else { return }
        let r = resolved()
        if var p = editing {
            p.name = name.trimmingCharacters(in: .whitespaces); p.gender = gender; p.group = group
            p.solar = r.solar; p.hour = r.hour; p.clock = r.clock; p.trueSolar = r.trueSolar; p.place = place
            store.update(p)
            onClose()
            onCreated(p)
            return
        }
        let p = Person(name: name.trimmingCharacters(in: .whitespaces), gender: gender, solar: r.solar, hour: r.hour,
                       group: group, clock: r.clock, trueSolar: r.trueSolar, place: place)
        store.add(p)
        onClose()
        onCreated(p)
    }
}

/// 數字輸入欄：無邊框，放在 inputBox 裡；只收數字，超出範圍不採用
private struct NumberField: View {
    @Binding var value: Int
    let range: ClosedRange<Int>
    let width: CGFloat
    var pad = false
    @State private var text = ""

    var body: some View {
        TextField("", text: $text)
            .textFieldStyle(.plain)
            .multilineTextAlignment(.center)
            .font(Font.zInput.monospacedDigit())
            .frame(width: width)
            .onAppear { text = format(value) }
            .onChange(of: value) { _, v in if Int(text) != v { text = format(v) } }
            .onChange(of: text) { _, t in
                let digits = t.filter(\.isNumber)
                if digits != t { text = digits }
                if let v = Int(digits), range.contains(v) { value = v }
            }
            .onSubmit { text = format(value) }
    }

    private func format(_ v: Int) -> String { pad ? String(format: "%02d", v) : String(v) }
}

extension View {
    /// 設計系統的輸入框：38 高、14pt、淺底細框
    func inputBox() -> some View {
        self.font(Font.zInput)
            .padding(.horizontal, 12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .frame(height: 38)
            .background(RoundedRectangle(cornerRadius: 9).fill(Color.zCard))
            .overlay(RoundedRectangle(cornerRadius: 9).stroke(Color.zLine))
    }
}
