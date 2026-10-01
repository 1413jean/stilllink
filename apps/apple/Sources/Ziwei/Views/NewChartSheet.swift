import SwiftUI
import MapKit

/// 地址自動完成：MKLocalSearchCompleter → 選定後用 MKLocalSearch 取得經緯度與時區
@MainActor
final class PlaceSearch: NSObject, ObservableObject, MKLocalSearchCompleterDelegate {
    @Published var query = "" { didSet { if query != oldValue && !suppress { completer.queryFragment = query } } }
    @Published var results: [MKLocalSearchCompletion] = []
    @Published var resolving = false
    private let completer = MKLocalSearchCompleter()
    private var suppress = false

    override init() {
        super.init()
        completer.delegate = self
        completer.resultTypes = [.address, .pointOfInterest]
    }

    nonisolated func completerDidUpdateResults(_ c: MKLocalSearchCompleter) {
        let r = Array(c.results.prefix(6))
        Task { @MainActor in self.results = r }
    }
    nonisolated func completer(_ c: MKLocalSearchCompleter, didFailWithError error: Error) {}

    func resolve(_ item: MKLocalSearchCompletion) async -> BirthPlace? {
        resolving = true
        defer { resolving = false }
        let res = try? await MKLocalSearch(request: MKLocalSearch.Request(completion: item)).start()
        guard let m = res?.mapItems.first else { return nil }
        let name = [item.title, item.subtitle].filter { !$0.isEmpty }.joined(separator: "，")
        set(name)
        results = []
        let coord = m.placemark.coordinate
        return BirthPlace(name: name, latitude: coord.latitude, longitude: coord.longitude,
                          timeZoneID: (m.timeZone ?? TimeZone(identifier: "Asia/Taipei")!).identifier)
    }

    func set(_ text: String) { suppress = true; query = text; suppress = false }
}

/// 新增命盤彈窗
struct NewChartSheet: View {
    @EnvironmentObject var store: Store
    @Environment(\.dismiss) private var dismiss
    var onCreated: (Person) -> Void

    @State private var name = ""
    @State private var gender: Gender = .female
    @State private var calendar = 0 // 0 國曆、1 農曆
    @State private var date = Calendar.current.date(from: DateComponents(year: 1995, month: 1, day: 1, hour: 12))!
    @State private var ly = 1995
    @State private var lm = 1
    @State private var ld = 1
    @State private var leap = false
    @State private var time = Calendar.current.date(from: DateComponents(year: 2000, month: 1, day: 1, hour: 12, minute: 0))!
    @State private var unknownTime = false
    @State private var group = "客人"
    @State private var place: BirthPlace?
    @StateObject private var search = PlaceSearch()
    @FocusState private var focus: Field?
    enum Field { case name, place }

    private var canSubmit: Bool { !name.trimmingCharacters(in: .whitespaces).isEmpty }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("新增命盤").font(.zTitle)
                Spacer()
                Button { dismiss() } label: {
                    Image(systemName: "xmark").font(Font.zCaptionStrong).foregroundStyle(Color.zText2)
                        .frame(width: 24, height: 24).background(Circle().fill(Color.zHover))
                }
                .buttonStyle(.plain)
            }
            .padding(.bottom, 18)

            VStack(alignment: .leading, spacing: 14) {
                field("姓名") {
                    TextField("例如：林小姐", text: $name).textFieldStyle(.plain).focused($focus, equals: .name)
                        .inputBox()
                }
                HStack(spacing: 14) {
                    field("性別") {
                        Picker("", selection: $gender) { ForEach(Gender.allCases, id: \.self) { Text($0.rawValue).tag($0) } }
                            .pickerStyle(.segmented).labelsHidden().frame(width: 110)
                    }
                    field("分組") {
                        Picker("", selection: $group) { ForEach(groupOptions, id: \.self) { Text($0).tag($0) } }
                            .labelsHidden().frame(width: 120)
                    }
                    Spacer()
                }

                field("出生日期") {
                    HStack(spacing: 10) {
                        Picker("", selection: $calendar) { Text("國曆").tag(0); Text("農曆").tag(1) }
                            .pickerStyle(.segmented).labelsHidden().frame(width: 110)
                        if calendar == 0 {
                            DatePicker("", selection: $date, displayedComponents: .date)
                                .datePickerStyle(.field).labelsHidden()
                        } else {
                            Picker("", selection: $ly) { ForEach(1900...2100, id: \.self) { Text(String($0) + "年").tag($0) } }.labelsHidden().frame(width: 90)
                            Picker("", selection: $lm) { ForEach(1...12, id: \.self) { Text(ZW.lunarMonths[$0 - 1]).tag($0) } }.labelsHidden().frame(width: 76)
                            Picker("", selection: $ld) { ForEach(1...30, id: \.self) { Text(ZW.lunarDays[$0 - 1]).tag($0) } }.labelsHidden().frame(width: 76)
                            Toggle("閏月", isOn: $leap).toggleStyle(.checkbox)
                        }
                    }
                }

                field("出生時間") {
                    HStack(spacing: 10) {
                        DatePicker("", selection: $time, displayedComponents: .hourAndMinute)
                            .datePickerStyle(.field).labelsHidden().disabled(unknownTime)
                        Toggle("時間不確定（以午時排）", isOn: $unknownTime).toggleStyle(.checkbox)
                            .font(Font.zCallout)
                    }
                }

                field("出生地") {
                    VStack(alignment: .leading, spacing: 0) {
                        HStack(spacing: 6) {
                            Image(systemName: "mappin.and.ellipse").foregroundStyle(Color.zText3)
                            TextField("輸入城市或地址，例如：台北市大安區", text: $search.query)
                                .textFieldStyle(.plain)
                                .focused($focus, equals: .place)
                                .onChange(of: search.query) { _, v in if v != place?.name { place = nil } }
                            if search.resolving { ProgressView().controlSize(.small) }
                        }
                        .inputBox()
                        if focus == .place && !search.results.isEmpty && place == nil {
                            VStack(alignment: .leading, spacing: 0) {
                                ForEach(search.results, id: \.self) { r in
                                    Button {
                                        Task { place = await search.resolve(r) }
                                    } label: {
                                        VStack(alignment: .leading, spacing: 1) {
                                            Text(r.title).font(Font.zCallout).foregroundStyle(Color.zText)
                                            if !r.subtitle.isEmpty { Text(r.subtitle).font(Font.zCaption).foregroundStyle(Color.zText3) }
                                        }
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .padding(.horizontal, 10).padding(.vertical, 6)
                                        .contentShape(Rectangle())
                                    }
                                    .buttonStyle(HoverRowStyle())
                                }
                            }
                            .padding(4)
                            .background(RoundedRectangle(cornerRadius: 10).fill(Color.zCard))
                            .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.zLine))
                            .padding(.top, 4)
                        }
                        if let place {
                            Text(String(format: "經度 %.4f°%@　緯度 %.4f°%@　%@", abs(place.longitude), place.longitude >= 0 ? "E" : "W",
                                        abs(place.latitude), place.latitude >= 0 ? "N" : "S", place.timeZoneID))
                                .font(Font.zCaption.monospacedDigit()).foregroundStyle(Color.zText2)
                                .padding(.top, 6)
                        }
                    }
                }

                // 結果預覽：真太陽時與時辰
                HStack(spacing: 8) {
                    Image(systemName: "sun.max").foregroundStyle(Color.zAccent)
                    Text(previewText).font(Font.zCallout.monospacedDigit()).foregroundStyle(Color.zText2)
                }
                .padding(.horizontal, 12).padding(.vertical, 10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(RoundedRectangle(cornerRadius: 10).fill(Color.zHover))
            }

            HStack {
                Spacer()
                Button("取消") { dismiss() }.keyboardShortcut(.cancelAction)
                Button("排盤") { submit() }
                    .keyboardShortcut(.defaultAction)
                    .buttonStyle(.borderedProminent)
                    .tint(Color.zAccent)
                    .disabled(!canSubmit)
            }
            .controlSize(.large)
            .padding(.top, 22)
        }
        .padding(24)
        .frame(width: 560)
        .background(Color.zBg)
        .environment(\.locale, Locale(identifier: "zh_TW"))
        .onAppear { focus = .name }
    }

    private var groupOptions: [String] {
        var g = ["客人", "家人", "朋友"]
        for p in store.people where !g.contains(p.group) { g.append(p.group) }
        return g
    }

    /// 算出排盤用的國曆日期、時辰與真太陽時
    private func resolved() -> (solar: String, hour: Int, clock: String, trueSolar: String?) {
        let (y, m, d): (Int, Int, Int) = {
            if calendar == 0 {
                let c = Calendar.current.dateComponents([.year, .month, .day], from: date)
                return (c.year!, c.month!, c.day!)
            }
            let s = Engine.shared.lunarToSolar(ly, lm, ld, leap: leap).split(separator: "-").compactMap { Int($0) }
            return s.count == 3 ? (s[0], s[1], s[2]) : (ly, lm, ld)
        }()
        let t = Calendar.current.dateComponents([.hour, .minute], from: time)
        let (hh, mm) = unknownTime ? (12, 0) : (t.hour!, t.minute!)
        let clock = String(format: "%d-%d-%d %02d:%02d", y, m, d, hh, mm)
        guard let place, !unknownTime, let tz = TimeZone(identifier: place.timeZoneID) else {
            return ("\(y)-\(m)-\(d)", SolarTime.shichen(hh), clock, nil)
        }
        let r = SolarTime.compute(year: y, month: m, day: d, hour: hh, minute: mm, longitude: place.longitude, tz: tz)
        let ts = String(format: "%d-%d-%d %02d:%02d", r.ymd.0, r.ymd.1, r.ymd.2, r.hm.0, r.hm.1)
        return ("\(r.ymd.0)-\(r.ymd.1)-\(r.ymd.2)", r.shichen, clock, ts)
    }

    private var previewText: String {
        let r = resolved()
        let sc = ZW.hours[r.hour] + "時"
        if let ts = r.trueSolar { return "鐘錶 \(r.clock)　→　真太陽時 \(ts)　→　\(sc)" }
        if unknownTime { return "時間不確定，以午時排盤" }
        return "鐘錶 \(r.clock)　→　\(sc)（填出生地可換算真太陽時）"
    }

    private func submit() {
        guard canSubmit else { return }
        let r = resolved()
        let p = Person(name: name.trimmingCharacters(in: .whitespaces), gender: gender, solar: r.solar, hour: r.hour,
                       group: group, clock: r.clock, trueSolar: r.trueSolar, place: place)
        store.add(p)
        dismiss()
        onCreated(p)
    }

    private func field<C: View>(_ label: String, @ViewBuilder _ content: () -> C) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label).font(Font.zCaptionStrong).foregroundStyle(Color.zText2)
            content()
        }
    }
}

private struct HoverRowStyle: ButtonStyle {
    @State private var hover = false
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background(RoundedRectangle(cornerRadius: 7).fill(hover ? Color.zHover : .clear))
            .onHover { hover = $0 }
    }
}

extension View {
    func inputBox() -> some View {
        self.font(Font.zBody)
            .padding(.horizontal, 10)
            .frame(height: 32)
            .background(RoundedRectangle(cornerRadius: 8).fill(Color.zCard))
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.zLine))
    }
}
