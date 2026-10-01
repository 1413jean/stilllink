import SwiftUI

/// 右側筆記／對話面板：先存筆記，AI 解盤之後接上
struct NotesPanel: View {
    @EnvironmentObject var store: Store
    let person: Person
    @State private var text = ""

    private var notes: [Note] { store.people.first { $0.id == person.id }?.notes ?? [] }

    var body: some View {
        VStack(spacing: 0) {
            if notes.isEmpty {
                VStack(spacing: 10) {
                    Spacer()
                    Image(systemName: "sparkle").font(.system(size: 26, weight: .light)).foregroundStyle(Color.zAccent)
                    (Text("這張盤想看什麼").font(.serif(19, .medium)) + Text("?").font(.system(size: 17, weight: .light)))
                    Text("先把客人的問題和你的觀察記在這裡。\nAI 解盤之後會接上，直接讀這張盤回答。")
                        .font(.system(size: 12)).foregroundStyle(.secondary).multilineTextAlignment(.center)
                    HStack(spacing: 6) {
                        ForEach(["今年感情", "事業轉換時機", "大限走勢"], id: \.self) { s in
                            Button(s) { text = s }
                                .buttonStyle(.plain)
                                .font(.system(size: 12))
                                .padding(.horizontal, 10).padding(.vertical, 5)
                                .background(RoundedRectangle(cornerRadius: 8).fill(Color.zCard))
                                .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.zLine))
                        }
                    }
                    .padding(.top, 4)
                    Spacer()
                }
                .padding(16)
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 14) {
                        ForEach(notes) { n in
                            VStack(alignment: .leading, spacing: 3) {
                                Text(n.at.formatted(date: .abbreviated, time: .shortened))
                                    .font(.system(size: 10.5)).foregroundStyle(.tertiary)
                                Text(n.text).font(.system(size: 13)).textSelection(.enabled)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                    .padding(16)
                }
            }

            // Codex 式輸入框
            VStack(alignment: .leading, spacing: 8) {
                TextField("記下問題或觀察…", text: $text, axis: .vertical)
                    .textFieldStyle(.plain)
                    .lineLimit(2...6)
                    .font(.system(size: 13))
                    .onSubmit(send)
                HStack(spacing: 8) {
                    Text("筆記")
                        .font(.system(size: 11.5, weight: .medium))
                        .padding(.horizontal, 8).padding(.vertical, 3)
                        .background(RoundedRectangle(cornerRadius: 6).fill(Color.zSel))
                    Text("AI 解盤 · 即將推出").font(.system(size: 11.5)).foregroundStyle(.tertiary)
                    Spacer()
                    Button(action: send) {
                        Image(systemName: "arrow.up")
                            .font(.system(size: 12, weight: .bold)).foregroundStyle(.white)
                            .frame(width: 26, height: 26)
                            .background(Circle().fill(text.isEmpty ? Color.zText3.opacity(0.5) : Color.zAccent))
                    }
                    .buttonStyle(.plain)
                    .disabled(text.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .padding(12)
            .background(RoundedRectangle(cornerRadius: 14).fill(Color.zCard))
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.zLine))
            .padding(12)
        }
        .background(Color.zBg)
    }

    private func send() {
        let t = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !t.isEmpty, var p = store.people.first(where: { $0.id == person.id }) else { return }
        p.notes.append(Note(text: t))
        store.update(p)
        text = ""
    }
}
