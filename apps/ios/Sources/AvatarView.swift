import SwiftUI
import PhotosUI

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

/// 可以點的頭貼：點了從相簿選一張，裁成正中間的正方形、縮成 256×256 JPEG，存進資料夾的 media/（跟 Mac 同一個地方）
struct AvatarPicker: View {
    @Binding var name: String?
    var size: CGFloat = 68
    @State private var item: PhotosPickerItem?

    var body: some View {
        PhotosPicker(selection: $item, matching: .images) {
            AvatarView(name: name, size: size)
                .overlay(alignment: .bottomTrailing) {
                    Image(systemName: "camera.fill")
                        .font(.system(size: size * 0.16, weight: .semibold))
                        .foregroundStyle(Color.zText)
                        .frame(width: size * 0.34, height: size * 0.34)
                        .background(Circle().fill(Color.zCard))
                        .overlay(Circle().stroke(Color.zLine))
                }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("更換頭貼")
        .onChange(of: item) { _, it in
            Task {
                guard let data = try? await it?.loadTransferable(type: Data.self), let saved = Self.save(data) else { return }
                name = saved
                item = nil
            }
        }
    }

    static func save(_ data: Data) -> String? {
        guard let img = UIImage(data: data) else { return nil }
        let side = min(img.size.width, img.size.height)
        let crop = CGRect(x: (img.size.width - side) / 2, y: (img.size.height - side) / 2, width: side, height: side)
        let out = UIGraphicsImageRenderer(size: CGSize(width: 256, height: 256)).image { _ in
            img.draw(in: CGRect(x: -crop.minX * 256 / side, y: -crop.minY * 256 / side,
                                width: img.size.width * 256 / side, height: img.size.height * 256 / side))
        }
        guard let jpg = out.jpegData(compressionQuality: 0.85) else { return nil }
        let dir = Store.dataDir.appendingPathComponent("media", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let file = "avatar-" + UUID().uuidString + ".jpg"
        guard (try? jpg.write(to: dir.appendingPathComponent(file))) != nil else { return nil }
        return file
    }
}
