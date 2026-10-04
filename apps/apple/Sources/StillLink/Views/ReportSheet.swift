import SwiftUI

/// 回報問題彈窗的開關（選單、帳號選單、說明鈕都從這裡打開）
@MainActor
final class ReportState: ObservableObject {
    static let shared = ReportState()
    @Published var open = false
    func show() { withAnimation(Motion.fast) { open = true } }
    func close() { withAnimation(Motion.fast) { open = false } }
}

/// 回報問題：寫下問題按「送出」就直接寄到 support@jeanui.com（經 report.jeanui.com 轉寄），不用開郵件 App
/// 會一起送出版本、系統、螢幕和設定，不含任何命盤資料；送不出去時可以改用郵件寄
struct ReportSheet: View {
    @EnvironmentObject var store: Store
    let onClose: () -> Void

    private enum Phase: Equatable { case editing, sending, sent, failed(String) }
    @State private var message = ""
    @State private var contact = UserDefaults.standard.string(forKey: "reportContact") ?? ""
    @State private var phase: Phase = .editing
    @State private var showDetail = false
    @FocusState private var messageFocused: Bool

    private static let endpoint = URL(string: "https://report.jeanui.com/")!

    private var trimmed: String { message.trimmingCharacters(in: .whitespacesAndNewlines) }
    private var contactOK: Bool {
        let c = contact.trimmingCharacters(in: .whitespaces)
        return c.isEmpty || c.range(of: #"^[^\s@]+@[^\s@]+\.[^\s@]{2,}$"#, options: .regularExpression) != nil
    }
    private var canSend: Bool { !trimmed.isEmpty && contactOK && phase != .sending }

    var body: some View {
        // 外框跟「新功能」彈窗同一款：title1 標題＋右上 ×、左右 32、zBg 底
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("回報問題").zText(.title1).foregroundStyle(Color.zText)
                Spacer()
                Button(action: onClose) {
                    Image(systemName: "xmark").font(.system(size: 13, weight: .semibold)).foregroundStyle(Color.zText2)
                        .frame(width: 30, height: 30).contentShape(Circle())
                }
                .buttonStyle(PressStyle())
                .keyboardShortcut(.cancelAction)
                .help("關閉（Esc）")
            }
            .padding(.horizontal, 32).padding(.top, 26).padding(.bottom, 16)

            Group { if phase == .sent { sent } else { form } }
                .padding(.horizontal, 32).padding(.bottom, 32)
        }
        .background(Color.zBg)
        .onAppear { messageFocused = true }
    }

    // MARK: 填寫

    private var form: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 6) {
                Text("發生什麼事？").zText(.calloutStrong).foregroundStyle(Color.zText)
                TextField("例如：打開某張命盤時，格線沒有顯示", text: $message, axis: .vertical)
                    .lineLimit(4...10)
                    .focused($messageFocused)
                    .zInput(.medium, multiline: true)
            }
            VStack(alignment: .leading, spacing: 6) {
                Text("你的 email（選填）").zText(.calloutStrong).foregroundStyle(Color.zText)
                TextField("想收到回覆的話留一下", text: $contact)
                    .zInput(.medium)
                if !contactOK {
                    Text("email 格式好像不太對").zText(.footnote).foregroundStyle(Color.mJi)
                }
            }

            // 會一起送出的內容：先講重點，想看再展開全文
            VStack(alignment: .leading, spacing: 6) {
                Text("會一起傳送給 \(BugReport.supportEmail)：").zText(.footnote).foregroundStyle(Color.zText2)
                Text("App 版本、macOS 版本、機型、螢幕與顯示設定。不含任何命盤資料。")
                    .zText(.footnote).foregroundStyle(Color.zText3)
                    .fixedSize(horizontal: false, vertical: true)
                Button { withAnimation(Motion.fast) { showDetail.toggle() } } label: {
                    Label(showDetail ? "收起完整內容" : "查看完整內容", systemImage: showDetail ? "chevron.up" : "chevron.down")
                        .zText(.footnote).foregroundStyle(Color.zAccent)
                }
                .buttonStyle(.plain)
                if showDetail {
                    ScrollView {
                        Text(BugReport.report(store: store))
                            .zText(.caption1).foregroundStyle(Color.zText2)
                            .textSelection(.enabled)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(10)
                    }
                    .frame(height: 120)
                    .background(RoundedRectangle(cornerRadius: 8).fill(Color.zHover))
                    .transition(.opacity)
                }
            }

            if case .failed(let why) = phase {
                VStack(alignment: .leading, spacing: 8) {
                    Text(why).zText(.footnote).foregroundStyle(Color.mJi)
                        .fixedSize(horizontal: false, vertical: true)
                    Button("改用郵件寄送") { BugReport.run(store: store, message: trimmed); onClose() }
                        .buttonStyle(ZSecondaryButton(small: true))
                }
            }

            HStack(spacing: 10) {
                Spacer()
                Button("取消", action: onClose).buttonStyle(ZSecondaryButton())
                Button(action: send) {
                    if phase == .sending { ProgressView().controlSize(.small).tint(Color.zOnColor) } else { Text("送出") }
                }
                .buttonStyle(ZPrimaryButton())
                .disabled(!canSend)
                .keyboardShortcut(.return, modifiers: .command)
            }
            .padding(.top, 4)
        }
    }

    // MARK: 送出成功

    private var sent: some View {
        VStack(spacing: 12) {
            Image(systemName: "checkmark.circle.fill").font(.system(size: 40)).foregroundStyle(Color.mLu)
            Text("已送出，謝謝你！").zText(.headline).foregroundStyle(Color.zText)
            Text(contact.isEmpty ? "我們會盡快看過、修正。" : "我們看過後會回信到 \(contact)。")
                .zText(.callout).foregroundStyle(Color.zText2)
                .multilineTextAlignment(.center)
            Button("關閉", action: onClose).buttonStyle(ZPrimaryButton()).padding(.top, 8)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
    }

    // MARK: 傳送

    private func send() {
        guard canSend else { return }
        let c = contact.trimmingCharacters(in: .whitespaces)
        UserDefaults.standard.set(c, forKey: "reportContact")
        phase = .sending
        let payload: [String: String] = [
            "message": trimmed, "contact": c,
            "diagnostics": BugReport.report(store: store), "version": AppInfo.version,
        ]
        Task {
            var req = URLRequest(url: Self.endpoint, timeoutInterval: 20)
            req.httpMethod = "POST"
            req.setValue("application/json", forHTTPHeaderField: "Content-Type")
            req.setValue("stilllink-report-v1", forHTTPHeaderField: "x-stilllink")
            req.httpBody = try? JSONSerialization.data(withJSONObject: payload)
            do {
                let (_, resp) = try await URLSession.shared.data(for: req)
                let code = (resp as? HTTPURLResponse)?.statusCode ?? 0
                withAnimation(Motion.fast) {
                    switch code {
                    case 200: phase = .sent
                    case 429: phase = .failed("送太多次了，請過一分鐘再試。")
                    default: phase = .failed("送出失敗（\(code)），可以稍後再試，或改用郵件寄送。")
                    }
                }
            } catch {
                withAnimation(Motion.fast) { phase = .failed("沒有連上網路，請確認網路後再試，或改用郵件寄送。") }
            }
        }
    }
}
