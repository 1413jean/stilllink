// DMG 視窗背景：暖白底、圓潤的主色箭頭、幾顆小星星、底下一行提示
// 用法：swift scripts/make-dmg-background.swift <輸出資料夾>  → background.png（660×540）＋ background@2x.png
import AppKit

let W: CGFloat = 660, H: CGFloat = 540
let out = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "."

func rgb(_ hex: UInt32, _ a: CGFloat = 1) -> NSColor {
    NSColor(srgbRed: CGFloat((hex >> 16) & 0xff) / 255, green: CGFloat((hex >> 8) & 0xff) / 255, blue: CGFloat(hex & 0xff) / 255, alpha: a)
}

/// 四角星（跟 App 圖示同一個形狀）
func sparkle(_ c: CGPoint, _ r: CGFloat, _ waist: CGFloat) -> NSBezierPath {
    let p = NSBezierPath()
    p.move(to: CGPoint(x: c.x, y: c.y + r))
    p.curve(to: CGPoint(x: c.x + r, y: c.y), controlPoint1: CGPoint(x: c.x + waist, y: c.y + waist), controlPoint2: CGPoint(x: c.x + waist, y: c.y + waist))
    p.curve(to: CGPoint(x: c.x, y: c.y - r), controlPoint1: CGPoint(x: c.x + waist, y: c.y - waist), controlPoint2: CGPoint(x: c.x + waist, y: c.y - waist))
    p.curve(to: CGPoint(x: c.x - r, y: c.y), controlPoint1: CGPoint(x: c.x - waist, y: c.y - waist), controlPoint2: CGPoint(x: c.x - waist, y: c.y - waist))
    p.curve(to: CGPoint(x: c.x, y: c.y + r), controlPoint1: CGPoint(x: c.x - waist, y: c.y + waist), controlPoint2: CGPoint(x: c.x - waist, y: c.y + waist))
    p.close()
    return p
}

func render(scale: CGFloat, to path: String) {
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: Int(W * scale), pixelsHigh: Int(H * scale), bitsPerSample: 8,
                               samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    rep.size = NSSize(width: W, height: H)
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)

    // 底色
    rgb(0xF5F1EA).setFill()
    NSRect(x: 0, y: 0, width: W, height: H).fill()

    // 箭頭：兩個圖示中間（Finder 座標 y 由上往下，這裡由下往上）
    let midY = H - 170
    let arrow = NSBezierPath()
    arrow.move(to: CGPoint(x: 290, y: midY))
    arrow.line(to: CGPoint(x: 362, y: midY))
    arrow.move(to: CGPoint(x: 340, y: midY + 20))
    arrow.line(to: CGPoint(x: 364, y: midY))
    arrow.line(to: CGPoint(x: 340, y: midY - 20))
    arrow.lineWidth = 9
    arrow.lineCapStyle = .round
    arrow.lineJoinStyle = .round
    rgb(0xD96B43).setStroke()
    arrow.stroke()

    // 小星星點綴
    rgb(0xD96B43, 0.55).setFill()
    sparkle(CGPoint(x: 326, y: midY + 52), 9, 1.6).fill()
    rgb(0xD96B43, 0.35).setFill()
    sparkle(CGPoint(x: 350, y: midY + 40), 5, 1).fill()
    sparkle(CGPoint(x: 304, y: midY - 46), 6, 1.1).fill()

    // 提示文字
    let para = NSMutableParagraphStyle(); para.alignment = .center
    let attrs: [NSAttributedString.Key: Any] = [
        .font: NSFont.systemFont(ofSize: 13, weight: .regular),
        .foregroundColor: rgb(0x9C9A93),
        .paragraphStyle: para,
    ]
    NSString(string: "把 StillLink 拖到 Applications 就安裝好了").draw(in: NSRect(x: 0, y: H - 290, width: W, height: 20), withAttributes: attrs)
    // 分隔線＋安裝說明提示（說明檔放在下面）
    rgb(0xE4DED3).setFill()
    NSRect(x: 60, y: H - 305, width: W - 120, height: 1).fill()
    NSString(string: "第一次打開被擋下？請看這份說明").draw(in: NSRect(x: 0, y: H - 340, width: W, height: 20), withAttributes: attrs)

    NSGraphicsContext.restoreGraphicsState()
    try! rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: path))
}

render(scale: 1, to: out + "/background.png")
render(scale: 2, to: out + "/background@2x.png")
print("wrote \(out)/background.png")
