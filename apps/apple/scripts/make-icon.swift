// 產生 App 圖示：swift scripts/make-icon.swift <輸出.png>
// 暖白圓角方塊＋淡淡的命盤十二宮格線＋中間赭紅四芒星（色票同 Theme.swift 的 zAccent）
import AppKit

let size: CGFloat = 1024
let out = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "icon.png"

func rgb(_ hex: UInt32, _ a: CGFloat = 1) -> CGColor {
    CGColor(srgbRed: CGFloat((hex >> 16) & 0xff) / 255, green: CGFloat((hex >> 8) & 0xff) / 255, blue: CGFloat(hex & 0xff) / 255, alpha: a)
}

let cs = CGColorSpace(name: CGColorSpace.sRGB)!
let ctx = CGContext(data: nil, width: Int(size), height: Int(size), bitsPerComponent: 8, bytesPerRow: 0, space: cs,
                    bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!

// macOS 圖示格：1024 畫布，主體 824、圓角約 185，留陰影空間
let body = CGRect(x: 100, y: 100, width: 824, height: 824)
let shape = CGPath(roundedRect: body, cornerWidth: 185, cornerHeight: 185, transform: nil)

ctx.saveGState()
ctx.setShadow(offset: CGSize(width: 0, height: -12), blur: 28, color: rgb(0x000000, 0.22))
ctx.addPath(shape); ctx.setFillColor(rgb(0xF5EFE6)); ctx.fillPath()
ctx.restoreGState()

ctx.saveGState()
ctx.addPath(shape); ctx.clip()
let grad = CGGradient(colorsSpace: cs, colors: [rgb(0xFBF8F3), rgb(0xEBDFD0)] as CFArray, locations: [0, 1])!
ctx.drawLinearGradient(grad, start: CGPoint(x: 0, y: body.maxY), end: CGPoint(x: 0, y: body.minY), options: [])

// 十二宮格：4×4 外圈，中間 2×2 留白
let inset: CGFloat = 150
let grid = body.insetBy(dx: inset, dy: inset)
let cell = grid.width / 4
ctx.setStrokeColor(rgb(0xD96B43, 0.28))
ctx.setLineWidth(5)
ctx.stroke(grid)
for k in 1..<4 {
    let x = grid.minX + CGFloat(k) * cell, y = grid.minY + CGFloat(k) * cell
    // 直線：中間那兩條只畫上下兩段（避開中宮）
    if k == 2 {
        ctx.strokeLineSegments(between: [CGPoint(x: x, y: grid.minY), CGPoint(x: x, y: grid.minY + cell),
                                         CGPoint(x: x, y: grid.maxY - cell), CGPoint(x: x, y: grid.maxY)])
        ctx.strokeLineSegments(between: [CGPoint(x: grid.minX, y: y), CGPoint(x: grid.minX + cell, y: y),
                                         CGPoint(x: grid.maxX - cell, y: y), CGPoint(x: grid.maxX, y: y)])
    } else {
        ctx.strokeLineSegments(between: [CGPoint(x: x, y: grid.minY), CGPoint(x: x, y: grid.maxY)])
        ctx.strokeLineSegments(between: [CGPoint(x: grid.minX, y: y), CGPoint(x: grid.maxX, y: y)])
    }
}

// 中宮四芒星
func sparkle(center c: CGPoint, r: CGFloat, waist: CGFloat) -> CGPath {
    let p = CGMutablePath()
    let pts: [CGPoint] = [
        CGPoint(x: c.x, y: c.y + r), CGPoint(x: c.x + waist, y: c.y + waist),
        CGPoint(x: c.x + r, y: c.y), CGPoint(x: c.x + waist, y: c.y - waist),
        CGPoint(x: c.x, y: c.y - r), CGPoint(x: c.x - waist, y: c.y - waist),
        CGPoint(x: c.x - r, y: c.y), CGPoint(x: c.x - waist, y: c.y + waist),
    ]
    p.move(to: pts[0])
    for i in 1...8 {
        let a = pts[(i - 1) % 8], b = pts[i % 8]
        // 弧邊讓星形更柔和
        let mid = CGPoint(x: (a.x + b.x) / 2 * 0.86 + c.x * 0.14, y: (a.y + b.y) / 2 * 0.86 + c.y * 0.14)
        p.addQuadCurve(to: b, control: mid)
    }
    p.closeSubpath()
    return p
}
let center = CGPoint(x: body.midX, y: body.midY)
ctx.addPath(sparkle(center: center, r: 210, waist: 34)); ctx.setFillColor(rgb(0xD96B43)); ctx.fillPath()
ctx.addPath(sparkle(center: CGPoint(x: center.x + 200, y: center.y + 190), r: 52, waist: 9)); ctx.setFillColor(rgb(0xD96B43, 0.85)); ctx.fillPath()
ctx.restoreGState()

let img = ctx.makeImage()!
let rep = NSBitmapImageRep(cgImage: img)
try! rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: out))
print("wrote \(out)")
