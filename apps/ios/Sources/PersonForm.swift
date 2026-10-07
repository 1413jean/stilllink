import SwiftUI

/// 新增／編輯命盤：系統 Form。換算邏輯跟 Mac 版 NewChartSheet 一樣（照鐘錶時間排盤，有出生地另算真太陽時）
struct PersonForm: View {
    var editing: Person? = nil
    /// 填自己的命盤（個人檔案）：分組固定「自己」，存完設成我的命盤
    var asSelf = false
    /// 新增完成（例：側欄新增後直接在首頁打開）
    var onCreated: ((Person) -> Void)? = nil
    @EnvironmentObject private var store: Store
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var gender: Gender = .female
    @State private var group = "客人"
    @State private var lunar = false
    @State private var solarDate = PersonForm.defaultDate
    @State private var ly = 1995
    @State private var lm = 1
    @State private var ld = 1
    @State private var leap = false
    @State private var time = PersonForm.defaultDate
    @State private var unknownTime = false
    @State private var region: PlaceRegion? = Places.taiwan
    @State private var city: PlaceCity? = Places.taiwan.cities.first
    @State private var loaded = false
    @State private var addingGroup = false
    @State private var newGroup = ""
    @State private var extraGroups: [String] = []
    @State private var confirmDelete = false
    @FocusState private var nameFocused: Bool

    private static let cal: Calendar = {
        var c = Calendar(identifier: .gregorian); c.timeZone = .current; return c
    }()
    private static var defaultDate: Date { cal.date(from: DateComponents(year: 1995, month: 1, day: 1, hour: 12, minute: 0))! }
    private static var dateRange: ClosedRange<Date> {
        cal.date(from: DateComponents(year: 1900, month: 1, day: 1))!...cal.date(from: DateComponents(year: 2100, month: 12, day: 31))!
    }

    private var canSubmit: Bool { !name.trimmingCharacters(in: .whitespaces).isEmpty }

    var body: some View {
        NavigationStack {
            Form {
                Section("基本資料") {
                    TextField("姓名", text: $name, prompt: Text(asSelf ? "你的名字" : "客人的名字或代稱"))
                        .focused($nameFocused)
                        .textContentType(.name)
                    Picker("性別", selection: $gender) {
                        ForEach(Gender.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                    }
                    .pickerStyle(.segmented)
                    if !asSelf && editing?.id != store.selfID {
                        Picker("分組", selection: $group) {
                            ForEach(groupOptions, id: \.self) { Text($0).tag($0) }
                        }
                        Button("新增分組…", systemImage: "folder.badge.plus") { addingGroup = true }
                    }
                }

                Section {
                    Picker("曆法", selection: $lunar) {
                        Text("國曆").tag(false)
                        Text("農曆").tag(true)
                    }
                    .pickerStyle(.segmented)
                    if lunar {
                        Picker("年", selection: $ly) {
                            ForEach((1900...2100).reversed(), id: \.self) { Text(String($0) + "年（\(ZW.yearGanzhi($0))）").tag($0) }
                        }
                        Picker("月", selection: $lm) {
                            ForEach(1...12, id: \.self) { Text(ZW.lunarMonths[$0 - 1]).tag($0) }
                        }
                        Picker("日", selection: $ld) {
                            ForEach(1...30, id: \.self) { Text(ZW.lunarDays[$0 - 1]).tag($0) }
                        }
                        Toggle("閏月", isOn: $leap)
                    } else {
                        DatePicker("出生日期", selection: $solarDate, in: PersonForm.dateRange, displayedComponents: .date)
                            .environment(\.calendar, PersonForm.cal)
                    }
                    if !unknownTime {
                        DatePicker("出生時間", selection: $time, displayedComponents: .hourAndMinute)
                            .environment(\.locale, Locale(identifier: "zh_TW"))
                    }
                    Toggle("時間不確定", isOn: $unknownTime.animation())
                } header: {
                    Text("出生時間")
                } footer: {
                    Text(unknownTime ? "不知道出生時間時，以午時排盤" : "以出生地的鐘錶時間為準")
                }

                Section {
                    NavigationLink {
                        PlacePicker(region: $region, city: $city)
                    } label: {
                        LabeledContent("出生地", value: city.map { c in region.map { $0.name == c.name ? c.name : "\($0.name) · \(c.name)" } ?? c.name } ?? "不指定")
                    }
                } header: {
                    Text("出生地")
                } footer: {
                    Text("用經緯度換算真太陽時，只拿來顯示；排盤一律照鐘錶時間（跟文墨天機一樣）")
                }

                Section("排盤時間") {
                    Text(previewText).foregroundStyle(Color.zText2)
                }

                if editing != nil {
                    Section {
                        Button("刪除命盤", role: .destructive) { confirmDelete = true }
                    }
                }
            }
            .navigationTitle(asSelf ? "我的命盤" : editing == nil ? "新增命盤" : "編輯命主資料")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("取消") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button(editing == nil ? "排盤" : "儲存", action: submit).disabled(!canSubmit)
                }
            }
            .alert("新增分組", isPresented: $addingGroup) {
                TextField("例如：VIP", text: $newGroup)
                Button("取消", role: .cancel) { newGroup = "" }
                Button("新增") {
                    let t = newGroup.trimmingCharacters(in: .whitespaces)
                    if !t.isEmpty { extraGroups.append(t); group = t }
                    newGroup = ""
                }
            }
            .confirmationDialog("刪除「\(name)」的命盤？", isPresented: $confirmDelete, titleVisibility: .visible) {
                Button("刪除", role: .destructive) {
                    if let p = editing { store.delete(p.id) }
                    dismiss()
                }
            } message: { Text("刪除後無法復原") }
            .onAppear {
                load()
                if asSelf && name.isEmpty { name = store.userName == "我" ? "" : store.userName }
                if editing == nil { nameFocused = true }
            }
        }
    }

    private var groupOptions: [String] {
        var g = ["客人", "家人", "朋友"]
        for p in store.people where !g.contains(p.group) && p.group != "自己" { g.append(p.group) }
        for x in extraGroups where !g.contains(x) { g.append(x) }
        if !g.contains(group) { g.append(group) }
        return g
    }

    /// 編輯時把原本的資料帶進表單
    private func load() {
        guard !loaded else { return }
        loaded = true
        guard let p = editing else { return }
        name = p.name; gender = p.gender; group = p.group
        let src = p.clock ?? "\(p.solar) \(String(format: "%02d", max(0, p.hour * 2 - (p.hour == 12 ? 1 : 0)))):00"
        let n = src.split(whereSeparator: { " -:".contains($0) }).compactMap { Int($0) }
        if n.count >= 5 {
            solarDate = PersonForm.cal.date(from: DateComponents(year: n[0], month: n[1], day: n[2])) ?? solarDate
            time = PersonForm.cal.date(from: DateComponents(year: 2000, month: 1, day: 1, hour: n[3], minute: n[4])) ?? time
        }
        if let pl = p.place {
            let best = Places.all.flatMap { r in r.cities.map { (r, $0) } }
                .min { a, b in dist(a.1, pl) < dist(b.1, pl) }
            region = best?.0; city = best?.1
        } else {
            region = nil; city = nil
        }
    }

    private func dist(_ c: PlaceCity, _ p: BirthPlace) -> Double {
        (c.lat - p.latitude) * (c.lat - p.latitude) + (c.lon - p.longitude) * (c.lon - p.longitude)
    }

    private var place: BirthPlace? {
        guard let city, let region else { return nil }
        return BirthPlace(name: region.name == city.name ? city.name : "\(region.name)\(city.name)",
                          latitude: city.lat, longitude: city.lon, timeZoneID: city.tz)
    }

    /// 算出排盤用的國曆日期、時辰與真太陽時
    private func resolved() -> (solar: String, hour: Int, clock: String, trueSolar: String?) {
        let (sy, sm, sd): (Int, Int, Int) = {
            if lunar { return Lunar.toSolar(ly, lm, ld, leap: leap) ?? Lunar.toSolar(ly, lm, min(ld, 29), leap: leap) ?? (ly, lm, ld) }
            let c = PersonForm.cal.dateComponents([.year, .month, .day], from: solarDate)
            return (c.year!, c.month!, c.day!)
        }()
        let t = PersonForm.cal.dateComponents([.hour, .minute], from: time)
        let (h, mm) = unknownTime ? (12, 0) : (t.hour!, t.minute!)
        let clock = String(format: "%d-%d-%d %02d:%02d", sy, sm, sd, h, mm)
        guard let place, !unknownTime, let tz = TimeZone(identifier: place.timeZoneID) else {
            return ("\(sy)-\(sm)-\(sd)", SolarTime.shichen(h), clock, nil)
        }
        let r = SolarTime.compute(year: sy, month: sm, day: sd, hour: h, minute: mm, longitude: place.longitude, tz: tz)
        let ts = String(format: "%d-%d-%d %02d:%02d", r.ymd.0, r.ymd.1, r.ymd.2, r.hm.0, r.hm.1)
        return ("\(sy)-\(sm)-\(sd)", SolarTime.shichen(h), clock, ts)
    }

    private var previewText: String {
        let r = resolved()
        let sc = ZW.hours[r.hour] + "時"
        if unknownTime { return "\(r.solar) · 以午時排盤" }
        if let ts = r.trueSolar { return "\(r.clock) · \(sc)\n真太陽時 \(ts)" }
        return "\(r.clock) · \(sc)"
    }

    private func submit() {
        guard canSubmit else { return }
        let r = resolved()
        let n = name.trimmingCharacters(in: .whitespaces)
        if var p = editing {
            p.name = n; p.gender = gender; p.group = group
            p.solar = r.solar; p.hour = r.hour; p.clock = r.clock; p.trueSolar = r.trueSolar; p.place = place
            store.update(p)
            if p.id == store.selfID { store.userName = p.name }
        } else {
            let p = Person(name: n, gender: gender, solar: r.solar, hour: r.hour, group: asSelf ? "自己" : group,
                           clock: r.clock, trueSolar: r.trueSolar, place: place)
            store.add(p)
            if asSelf { store.selfIDString = p.id.uuidString; store.userName = p.name }
            onCreated?(p)
        }
        dismiss()
    }
}

/// 出生地：先選國家／地區，再選城市；兩層都能搜尋
struct PlacePicker: View {
    @Binding var region: PlaceRegion?
    @Binding var city: PlaceCity?
    @State private var query = ""
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        List {
            if query.isEmpty {
                Button {
                    region = nil; city = nil; dismiss()
                } label: {
                    HStack {
                        Text("不指定").foregroundStyle(Color.zText)
                        Spacer()
                        if city == nil { Image(systemName: "checkmark").foregroundStyle(Color.zAccent) }
                    }
                }
            }
            ForEach(hits) { r in
                NavigationLink {
                    CityPicker(region: r, selectedRegion: $region, city: $city, onDone: { dismiss() })
                } label: {
                    LabeledContent(r.name, value: region?.id == r.id ? (city?.name ?? "") : "")
                }
            }
        }
        .navigationTitle("國家／地區")
        .navigationBarTitleDisplayMode(.inline)
        .searchable(text: $query, placement: .navigationBarDrawer(displayMode: .always), prompt: "搜尋國家或城市")
    }

    /// 國家名或底下任一城市符合都列出（例：打「東京」會留下日本）
    private var hits: [PlaceRegion] {
        let q = query.trimmingCharacters(in: .whitespaces).lowercased()
        guard !q.isEmpty else { return Places.all }
        return Places.all.filter { r in r.name.lowercased().contains(q) || r.cities.contains { $0.name.lowercased().contains(q) } }
    }
}

private struct CityPicker: View {
    let region: PlaceRegion
    @Binding var selectedRegion: PlaceRegion?
    @Binding var city: PlaceCity?
    var onDone: () -> Void
    @State private var query = ""

    var body: some View {
        List(hits) { c in
            Button {
                selectedRegion = region; city = c; onDone()
            } label: {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(c.name).foregroundStyle(Color.zText)
                        Text(String(format: "經度 %.2f°%@　%@", abs(c.lon), c.lon >= 0 ? "E" : "W", c.tz))
                            .zText(.footnote).foregroundStyle(Color.zText3)
                    }
                    Spacer()
                    if city?.id == c.id { Image(systemName: "checkmark").foregroundStyle(Color.zAccent) }
                }
            }
        }
        .navigationTitle(region.name)
        .navigationBarTitleDisplayMode(.inline)
        .searchable(text: $query, placement: .navigationBarDrawer(displayMode: .always), prompt: "搜尋城市")
    }

    private var hits: [PlaceCity] {
        let q = query.trimmingCharacters(in: .whitespaces).lowercased()
        guard !q.isEmpty else { return region.cities }
        return region.cities.filter { $0.name.lowercased().contains(q) || $0.tz.lowercased().contains(q) }
    }
}
