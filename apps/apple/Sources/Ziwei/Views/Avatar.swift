import SwiftUI
import AppKit
import UniformTypeIdentifiers

/// 頭貼：存在 media 資料夾，裁成圓形、縮到 256×256、JPEG 壓縮後才存（每張約 20KB）
enum AvatarStore {
    static let size: CGFloat = 256

    /// 依裁切參數輸出壓縮後的 JPEG，回傳檔名
    static func save(_ image: NSImage, crop: CropState, viewport: CGFloat) -> String? {
        guard let cg = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else { return nil }
        let w = CGFloat(cg.width), h = CGFloat(cg.height)
        // 圖片在裁切框中顯示的大小：先等比填滿框，再乘上縮放
        let fill = max(viewport / w, viewport / h) * crop.scale
        let shownW = w * fill, shownH = h * fill
        // 框在圖片座標中的位置
        let originX = (shownW - viewport) / 2 - crop.offset.width
        let originY = (shownH - viewport) / 2 - crop.offset.height
        let src = CGRect(x: originX / fill, y: originY / fill, width: viewport / fill, height: viewport / fill)

        let out = Int(size)
        guard let ctx = CGContext(data: nil, width: out, height: out, bitsPerComponent: 8, bytesPerRow: 0,
                                  space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue) else { return nil }
        ctx.interpolationQuality = .high
        ctx.setFillColor(NSColor.white.cgColor)
        ctx.fill(CGRect(x: 0, y: 0, width: out, height: out))
        // CGImage 原點在左下；src 是以左上為原點算的
        let scale = CGFloat(out) / src.width
        ctx.translateBy(x: -src.minX * scale, y: -(h - src.maxY) * scale)
        ctx.scaleBy(x: scale, y: scale)
        ctx.draw(cg, in: CGRect(x: 0, y: 0, width: w, height: h))
        guard let result = ctx.makeImage(),
              let data = NSBitmapImageRep(cgImage: result).representation(using: .jpeg, properties: [.compressionFactor: 0.8]) else { return nil }
        let name = "avatar-\(UUID().uuidString).jpg"
        do { try data.write(to: Media.url(name)) } catch { return nil }
        return name
    }

    static func remove(_ name: String?) {
        guard let name else { return }
        try? FileManager.default.removeItem(at: Media.url(name))
    }

    /// 選一張照片
    @MainActor static func pick() -> NSImage? {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.image]
        panel.allowsMultipleSelection = false
        guard panel.runModal() == .OK, let url = panel.url else { return nil }
        return NSImage(contentsOf: url)
    }
}

struct CropState: Equatable {
    var scale: CGFloat = 1
    var offset: CGSize = .zero
}

/// 頭貼圓圖；沒有頭貼時顯示預設人像
struct AvatarView: View {
    let name: String?
    let size: CGFloat

    var body: some View {
        Group {
            if let name, let img = NSImage(contentsOf: Media.url(name)) {
                Image(nsImage: img).resizable().scaledToFill()
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

/// 裁切頭貼（原生 sheet）：拖曳移動、滑桿或捏合縮放，圓形框預覽
struct AvatarCropSheet: View {
    let image: NSImage
    var onDone: (String?) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var crop = CropState()
    @State private var dragStart: CGSize = .zero
    @State private var pinchStart: CGFloat = 1
    private let viewport: CGFloat = 280

    var body: some View {
        VStack(spacing: 18) {
            Text("裁切頭貼").font(.zTitle).foregroundStyle(Color.zText)
            ZStack {
                Image(nsImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(width: viewport, height: viewport)
                    .scaleEffect(crop.scale)
                    .offset(crop.offset)
                    .frame(width: viewport, height: viewport)
                    .clipped()
                // 圓形框外變暗
                Rectangle().fill(Color.black.opacity(0.45))
                    .mask(Rectangle().overlay(Circle().blendMode(.destinationOut)).compositingGroup())
                    .allowsHitTesting(false)
                Circle().stroke(Color.white.opacity(0.9), lineWidth: 2).allowsHitTesting(false)
            }
            .frame(width: viewport, height: viewport)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .contentShape(Rectangle())
            .gesture(DragGesture()
                .onChanged { v in crop.offset = clamp(CGSize(width: dragStart.width + v.translation.width, height: dragStart.height + v.translation.height)) }
                .onEnded { _ in dragStart = crop.offset })
            .simultaneousGesture(MagnifyGesture()
                .onChanged { v in crop.scale = min(4, max(1, pinchStart * v.magnification)); crop.offset = clamp(crop.offset) }
                .onEnded { _ in pinchStart = crop.scale; dragStart = crop.offset })

            HStack(spacing: 10) {
                Image(systemName: "minus.magnifyingglass").foregroundStyle(Color.zText3)
                Slider(value: Binding(get: { crop.scale }, set: { crop.scale = $0; pinchStart = $0; crop.offset = clamp(crop.offset); dragStart = crop.offset }), in: 1...4)
                Image(systemName: "plus.magnifyingglass").foregroundStyle(Color.zText3)
            }
            .frame(width: viewport)
            Text("拖曳移動位置，捏合或滑桿縮放").font(Font.zCaption).foregroundStyle(Color.zText3)

            HStack(spacing: 10) {
                Button("取消") { dismiss() }.buttonStyle(ZSecondaryButton())
                Button("套用") {
                    onDone(AvatarStore.save(image, crop: crop, viewport: viewport))
                    dismiss()
                }
                .buttonStyle(ZPrimaryButton())
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(28)
        .background(Color.zBg)
    }

    /// 不讓圖片拖出圓框外露出空白
    private func clamp(_ o: CGSize) -> CGSize {
        let px = image.size.width, py = image.size.height
        guard px > 0, py > 0 else { return o }
        let fill = max(viewport / px, viewport / py) * crop.scale
        let maxX = max(0, (px * fill - viewport) / 2), maxY = max(0, (py * fill - viewport) / 2)
        return CGSize(width: min(maxX, max(-maxX, o.width)), height: min(maxY, max(-maxY, o.height)))
    }
}

/// 表單用的「頭貼」控制：預覽＋上傳／更換＋移除
struct AvatarField: View {
    @Binding var name: String?
    @State private var picked: NSImage?

    var body: some View {
        HStack(spacing: 12) {
            AvatarView(name: name, size: 44)
            Spacer()
            if name != nil {
                Button("移除") { AvatarStore.remove(name); name = nil }.buttonStyle(ZSecondaryButton(small: true))
            }
            Button(name == nil ? "上傳頭貼" : "更換") { picked = AvatarStore.pick() }
                .buttonStyle(ZPrimaryButton(small: true))
        }
        .sheet(item: Binding(get: { picked.map(PickedImage.init) }, set: { picked = $0?.image })) { p in
            AvatarCropSheet(image: p.image) { saved in
                if let saved { AvatarStore.remove(name); name = saved }
                picked = nil
            }
        }
    }

    private struct PickedImage: Identifiable { let image: NSImage; var id: ObjectIdentifier { ObjectIdentifier(image) } }
}
