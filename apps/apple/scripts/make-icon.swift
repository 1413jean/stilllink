// 產生 App 圖示：swift scripts/make-icon.swift <輸出.png> [beta]（beta：右下角加 BETA 標籤）
// 夜空藍圓角方塊＋星橘四芒星，照 Figma「Stillink Design System」的 App Icon（node 81:792，300×300）等比放大到 macOS 圖示格
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
// Figma 的 300 單位 → 這裡的像素；Figma 的 y 往下，CG 的 y 往上
let k = body.width / 300
func fig(_ x: CGFloat, _ y: CGFloat) -> CGPoint { CGPoint(x: body.minX + x * k, y: body.maxY - y * k) }

/// 內陰影：只畫在 path 裡面。dy 用 Figma 的方向（正數往下）
func innerShadow(_ path: CGPath, color: CGColor, blur: CGFloat, dy: CGFloat) {
    ctx.saveGState()
    ctx.addPath(path); ctx.clip()
    ctx.setShadow(offset: CGSize(width: 0, height: -dy * k), blur: blur * k, color: color)
    // 外面一大圈實心、中間挖掉 path：陰影從邊緣往內滲
    let ring = CGMutablePath()
    ring.addRect(body.insetBy(dx: -400, dy: -400))
    ring.addPath(path)
    ctx.addPath(ring); ctx.setFillColor(rgb(0x000000)); ctx.fillPath(using: .evenOdd)
    ctx.restoreGState()
}

// 1. 底：外陰影＋夜空漸層（上 #1A2944 → 下 #0A111F）＋底邊一圈藍光
ctx.saveGState()
ctx.setShadow(offset: CGSize(width: 0, height: -12), blur: 28, color: rgb(0x000000, 0.28))
ctx.addPath(shape); ctx.setFillColor(rgb(0x0A111F)); ctx.fillPath()
ctx.restoreGState()

ctx.saveGState()
ctx.addPath(shape); ctx.clip()
let bg = CGGradient(colorsSpace: cs, colors: [rgb(0x1A2944), rgb(0x0A111F)] as CFArray, locations: [0, 1])!
ctx.drawLinearGradient(bg, start: CGPoint(x: 0, y: body.maxY), end: CGPoint(x: 0, y: body.minY), options: [])
ctx.restoreGState()
innerShadow(shape, color: rgb(0x4F8CFF, 0.55), blur: 17.58, dy: -5.27)

// 2. 四芒星：Figma STAR（4 角、內半徑 0.42、圓角 11.25），框 x 56.25 y 58.59 大小 187.5
func roundedStar(center c: CGPoint, r: CGFloat, inner: CGFloat, corner: CGFloat) -> CGPath {
    var pts: [CGPoint] = []
    for i in 0..<8 {
        let a = CGFloat.pi / 2 - CGFloat(i) * .pi / 4
        let rr = i % 2 == 0 ? r : r * inner
        pts.append(CGPoint(x: c.x + rr * cos(a), y: c.y + rr * sin(a)))
    }
    let p = CGMutablePath()
    let start = CGPoint(x: (pts[7].x + pts[0].x) / 2, y: (pts[7].y + pts[0].y) / 2)
    p.move(to: start)
    for i in 0..<8 { p.addArc(tangent1End: pts[i], tangent2End: pts[(i + 1) % 8], radius: corner) }
    p.closeSubpath()
    return p
}
let starBox = CGRect(origin: fig(56.25, 58.59 + 187.5), size: CGSize(width: 187.5 * k, height: 187.5 * k))
let star = roundedStar(center: CGPoint(x: starBox.midX, y: starBox.midY), r: starBox.width / 2, inner: 0.42, corner: 11.25 * k)

// 橘色光暈
ctx.saveGState()
ctx.addPath(shape); ctx.clip()
ctx.setShadow(offset: .zero, blur: 26.37 * k, color: rgb(0xF59457, 0.5))
ctx.addPath(star); ctx.setFillColor(rgb(0xF59457)); ctx.fillPath()
ctx.restoreGState()

// 星體漸層（上 #FFC88A → 中 #F59457 → 下 #DD5F31）
ctx.saveGState()
ctx.addPath(star); ctx.clip()
let sg = CGGradient(colorsSpace: cs, colors: [rgb(0xFFC88A), rgb(0xF59457), rgb(0xDD5F31)] as CFArray, locations: [0, 0.5, 1])!
ctx.drawLinearGradient(sg, start: CGPoint(x: 0, y: starBox.maxY), end: CGPoint(x: 0, y: starBox.minY), options: [])
ctx.restoreGState()
innerShadow(star, color: rgb(0xFFF0D8, 0.5), blur: 5.27, dy: 2.93)    // 上緣亮邊
innerShadow(star, color: rgb(0x9C3A18, 0.35), blur: 7.62, dy: -4.10)  // 下緣暗邊

// 測試版：右下角星橘膠囊＋夜空色字 BETA
if CommandLine.arguments.count > 2 && CommandLine.arguments[2] == "beta" {
    let pill = CGRect(x: body.maxX - 430, y: body.minY + 70, width: 380, height: 150)
    ctx.addPath(CGPath(roundedRect: pill, cornerWidth: 75, cornerHeight: 75, transform: nil))
    ctx.setFillColor(rgb(0xF59457)); ctx.fillPath()
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(cgContext: ctx, flipped: false)
    let para = NSMutableParagraphStyle(); para.alignment = .center
    let attrs: [NSAttributedString.Key: Any] = [.font: NSFont.systemFont(ofSize: 96, weight: .heavy),
                                                .foregroundColor: NSColor(cgColor: rgb(0x0B1220))!,
                                                .paragraphStyle: para, .kern: 6]
    let t = NSAttributedString(string: "BETA", attributes: attrs)
    let h = t.size().height
    t.draw(in: CGRect(x: pill.minX, y: pill.midY - h / 2, width: pill.width, height: h))
    NSGraphicsContext.restoreGraphicsState()
}

let img = ctx.makeImage()!
let rep = NSBitmapImageRep(cgImage: img)
try! rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: out))
print("wrote \(out)")
