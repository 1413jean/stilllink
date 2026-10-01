import SwiftUI

/// 首頁：照 Claude 的「Let's noodle」——大標題＋一張可點的輸入卡（點了開新增彈窗）＋最近的人
struct HomeView: View {
    @EnvironmentObject var store: Store
    @Binding var route: Route?
    var onNew: () -> Void
    @State private var hover = false

    var body: some View {
        VStack(spacing: 26) {
            Spacer()
            HStack(spacing: 12) {
                Image(systemName: "sparkle")
                    .font(Font.zIconHero)
                    .foregroundStyle(Color.zAccent)
                Text("今天想幫誰排盤？").font(.zDisplay)
            }

            Button(action: onNew) {
                VStack(alignment: .leading, spacing: 18) {
                    Text("輸入姓名、生辰與出生地…")
                        .font(Font.zBody)
                        .foregroundStyle(Color.zText3)
                    HStack(spacing: 8) {
                        chip("calendar", "國曆／農曆")
                        chip("clock", "出生時間")
                        chip("mappin.and.ellipse", "出生地・真太陽時")
                        Spacer()
                        Image(systemName: "arrow.up")
                            .font(Font.zIconBold)
                            .foregroundStyle(Color.zOnColor)
                            .frame(width: 30, height: 30)
                            .background(Circle().fill(Color.zAccent))
                    }
                }
                .padding(18)
                .frame(maxWidth: 660, alignment: .leading)
                .background(RoundedRectangle(cornerRadius: 18).fill(Color.zCard))
                .overlay(RoundedRectangle(cornerRadius: 18).stroke(hover ? Color.zGrid : Color.zLine))
                .shadow(color: Color.zShadow.opacity(hover ? 1 : 0.6), radius: 14, y: 4)
                .contentShape(RoundedRectangle(cornerRadius: 18))
            }
            .buttonStyle(.plain)
            .onHover { hover = $0 }

            let recent = Array(store.people.prefix(5))
            if !recent.isEmpty {
                HStack(spacing: 8) {
                    ForEach(recent) { p in
                        Button { route = .person(p.id) } label: {
                            Label(p.name, systemImage: "person.crop.circle")
                                .font(Font.zCallout)
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
    }

    private func chip(_ icon: String, _ text: String) -> some View {
        Label(text, systemImage: icon)
            .font(Font.zCallout)
            .foregroundStyle(Color.zText2)
            .padding(.horizontal, 9).padding(.vertical, 5)
            .background(RoundedRectangle(cornerRadius: 8).fill(Color.zHover))
    }
}
