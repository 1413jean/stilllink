import SwiftUI

/// 首頁：照 Claude 的「Let's noodle」——大標題＋一張輸入卡，直接輸入生辰就排盤
struct HomeView: View {
    @EnvironmentObject var store: Store
    @Binding var route: Route?

    @State private var name = ""
    @State private var gender: Gender = .female
    @State private var date = Calendar.current.date(from: DateComponents(year: 1995, month: 1, day: 1))!
    @State private var hour = 6
    @State private var group = "客人"
    @FocusState private var focused: Bool

    private var canSubmit: Bool { !name.trimmingCharacters(in: .whitespaces).isEmpty }

    var body: some View {
        VStack(spacing: 28) {
            Spacer()
            HStack(spacing: 12) {
                Image(systemName: "sparkle")
                    .font(.system(size: 30, weight: .light))
                    .foregroundStyle(Color.zAccent)
                (Text("今天想幫誰排盤").font(.serif(36, .medium)) + Text("?").font(.system(size: 32, weight: .light)))
            }

            VStack(alignment: .leading, spacing: 14) {
                TextField("輸入姓名，例如：林小姐", text: $name)
                    .textFieldStyle(.plain)
                    .font(.system(size: 15))
                    .focused($focused)
                    .onSubmit(submit)

                HStack(spacing: 10) {
                    Picker("", selection: $gender) {
                        ForEach(Gender.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                    .fixedSize()

                    DatePicker("", selection: $date, displayedComponents: .date)
                        .datePickerStyle(.compact)
                        .labelsHidden()
                        .environment(\.locale, Locale(identifier: "zh_TW"))

                    Picker("", selection: $hour) {
                        ForEach(0..<13, id: \.self) { Text(ZW.hours[$0] + "時").tag($0) }
                    }
                    .labelsHidden()
                    .fixedSize()

                    Picker("", selection: $group) {
                        ForEach(groupOptions, id: \.self) { Text($0).tag($0) }
                    }
                    .labelsHidden()
                    .fixedSize()

                    Spacer()

                    Button(action: submit) {
                        Image(systemName: "arrow.up")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(.white)
                            .frame(width: 30, height: 30)
                            .background(Circle().fill(canSubmit ? Color.zAccent : Color.zText3.opacity(0.5)))
                    }
                    .buttonStyle(.plain)
                    .disabled(!canSubmit)
                    .keyboardShortcut(.return, modifiers: .command)
                }
            }
            .padding(.horizontal, 18)
            .padding(.top, 18)
            .padding(.bottom, 12)
            .frame(maxWidth: 660)
            .background(RoundedRectangle(cornerRadius: 18).fill(Color.zCard))
            .overlay(RoundedRectangle(cornerRadius: 18).stroke(Color.zLine))
            .shadow(color: .black.opacity(0.04), radius: 12, y: 4)

            let recent = Array(store.people.prefix(5))
            if !recent.isEmpty {
                HStack(spacing: 8) {
                    ForEach(recent) { p in
                        Button { route = .person(p.id) } label: {
                            Label(p.name, systemImage: "person.crop.circle")
                                .font(.system(size: 12.5))
                                .padding(.horizontal, 11)
                                .padding(.vertical, 6)
                                .background(RoundedRectangle(cornerRadius: 9).fill(Color.zCard))
                                .overlay(RoundedRectangle(cornerRadius: 9).stroke(Color.zLine))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            Spacer()
            Spacer()
        }
        .padding(.horizontal, 24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.zBg)
        .navigationTitle("")
        .onAppear { focused = true }
    }

    private var groupOptions: [String] {
        var g = ["客人", "家人", "朋友"]
        for p in store.people where !g.contains(p.group) { g.append(p.group) }
        return g
    }

    private func submit() {
        guard canSubmit else { return }
        let c = Calendar.current.dateComponents([.year, .month, .day], from: date)
        let p = Person(name: name.trimmingCharacters(in: .whitespaces), gender: gender,
                       solar: "\(c.year!)-\(c.month!)-\(c.day!)", hour: hour, group: group)
        store.add(p)
        name = ""
        route = .person(p.id)
    }
}
