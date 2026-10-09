import SwiftUI

/// 隱私權政策／使用條款／刪除資料／開源授權（內容跟 Mac 版共用 LegalText.swift）
struct LegalView: View {
    let doc: LegalDoc
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    Text(LegalDoc.updated).zText(.footnote).foregroundStyle(Color.zText3).padding(.bottom, 12)
                    Text(doc.summary).zText(.bodyStrong).foregroundStyle(Color.zText).padding(.bottom, 24)
                    ForEach(doc.sections, id: \.0) { title, body in
                        VStack(alignment: .leading, spacing: 6) {
                            Text(title).zText(.headline).foregroundStyle(Color.zText)
                            Text(body).zText(.body).foregroundStyle(Color.zText2)
                                .fixedSize(horizontal: false, vertical: true)
                                .textSelection(.enabled)
                        }
                        .padding(.bottom, 20)
                    }
                    Text(LegalDoc.contact).zText(.footnote).foregroundStyle(Color.zText3).padding(.top, 4)
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 16)
            }
            .background(Color.zBg)
            .zEdgeFades()
            .navigationTitle(doc.rawValue)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button("完成") { dismiss() } }
            }
        }
        .tint(Color.zText)
    }
}
