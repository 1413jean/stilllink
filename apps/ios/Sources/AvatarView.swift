import SwiftUI

/// 頭貼圓圖；沒有頭貼時顯示預設人像（跟 Mac 版 AvatarView 一樣：zSel 底、zText3 人像）
struct AvatarView: View {
    let name: String?
    let size: CGFloat

    var body: some View {
        Group {
            if let name, let img = UIImage(contentsOfFile: Store.dataDir.appendingPathComponent("media").appendingPathComponent(name).path) {
                Image(uiImage: img).resizable().scaledToFill()
            } else {
                Image(systemName: "person.fill")
                    .font(.system(size: size * 0.47))
                    .foregroundStyle(Color.zText3)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color.zSel)
            }
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
    }
}
