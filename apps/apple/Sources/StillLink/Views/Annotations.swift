import SwiftUI
import AppKit

/// 命盤上的標註：畫筆、螢光筆、框線、文字。座標存成 0～1（相對盤面大小），縮放、換視窗大小都對得上
struct Mark: Codable, Identifiable, Equatable {
    enum Kind: String, Codable { case pen, highlight, rect, text, arrow }
    var id = UUID()
    var kind: Kind
    var points: [CGPoint]          // 畫筆、螢光筆：路徑；框線：起點＋終點；文字：左上角
    var color: String              // AnnoColor 的 rawValue
    var text = ""
    var size: String? = nil        // AnnoSize 的 rawValue（舊標註沒有＝中）
}

/// 筆的粗細：畫筆、框線用前一個數字，螢光筆用後一個
enum AnnoSize: String, CaseIterable {
    case thin, medium, thick
    var pen: CGFloat { switch self { case .thin: 1.4; case .medium: 2.4; case .thick: 4.5 } }
    var highlight: CGFloat { switch self { case .thin: 9; case .medium: 16; case .thick: 26 } }
    var dot: CGFloat { switch self { case .thin: 4; case .medium: 7; case .thick: 11 } }
    var label: String { switch self { case .thin: "細"; case .medium: "中"; case .thick: "粗" } }
}

enum AnnoTool: String, CaseIterable {
    case select, pen, highlight, arrow, rect, text, eraser, comment
    var icon: String {
        switch self {
        case .select: "cursorarrow"
        case .pen: "pencil.tip"
        case .highlight: "highlighter"
        case .rect: "rectangle"
        case .text: "t.square"
        case .eraser: "eraser"
        case .comment: "bubble.left"
        case .arrow: "arrow.up.right"
        }
    }
    /// 工具列上顯示的工具（文字註解拿掉了）
    static var visible: [AnnoTool] { allCases.filter { $0 != .text } }

    /// 快捷鍵（單一字母；打字中不會觸發）
    var key: String {
        switch self { case .select: "V"; case .pen: "P"; case .highlight: "H"; case .rect: "R"; case .text: "T"; case .eraser: "E"; case .comment: "C"; case .arrow: "A" }
    }
    var help: String {
        switch self {
        case .select: "選取（一般看盤）"
        case .pen: "畫筆"
        case .highlight: "螢光筆"
        case .rect: "框線"
        case .text: "文字註解"
        case .eraser: "橡皮擦"
        case .comment: "備註"
        case .arrow: "箭頭直線"
        }
    }
}

enum AnnoColor: String, CaseIterable {
    case red, blue, green, orange, black
    var color: Color {
        switch self {
        case .red: .wmRed
        case .blue: .wmBlue
        case .green: .wmGreen
        case .orange: .zAccent
        case .black: .zText
        }
    }
}

/// 每張命盤的標註，存在資料夾的 annotations.json（命盤 id → 標註）
@MainActor
final class AnnotationStore: ObservableObject {
    static let shared = AnnotationStore()
    @Published private(set) var marks: [UUID: [Mark]] = [:]
    private var undo: [UUID: [[Mark]]] = [:]
    private let url = Store.dataDir.appendingPathComponent("annotations.json")

    private init() {
        if let d = try? Data(contentsOf: url), let v = try? JSONDecoder().decode([String: [Mark]].self, from: d) {
            marks = Dictionary(uniqueKeysWithValues: v.compactMap { k, m in UUID(uuidString: k).map { ($0, m) } })
        }
    }

    func list(_ id: UUID) -> [Mark] { marks[id] ?? [] }

    /// 改之前先記一份，給復原用
    func edit(_ id: UUID, _ change: (inout [Mark]) -> Void) {
        var m = list(id)
        let before = m
        change(&m)
        guard m != before else { return }
        undo[id, default: []].append(before)
        if undo[id]!.count > 50 { undo[id]!.removeFirst() }
        marks[id] = m.isEmpty ? nil : m
        save()
    }

    /// 打字中的文字：不記復原（不然每打一個字就一步）
    func setText(_ id: UUID, mark: UUID, _ text: String) {
        guard var m = marks[id], let i = m.firstIndex(where: { $0.id == mark }) else { return }
        m[i].text = text
        marks[id] = m
        save()
    }

    func canUndo(_ id: UUID) -> Bool { !(undo[id] ?? []).isEmpty }
    func undoLast(_ id: UUID) {
        guard let prev = undo[id]?.popLast() else { return }
        marks[id] = prev.isEmpty ? nil : prev
        save()
    }

    private func save() {
        let out = Dictionary(uniqueKeysWithValues: marks.map { ($0.key.uuidString, $0.value) })
        if let d = try? JSONEncoder().encode(out) { try? d.write(to: url, options: .atomic) }
    }
}

/// 疊在盤面上的標註層。選取工具時不攔滑鼠，盤面照常點；其他工具時攔下來畫
struct AnnotationLayer: View {
    let chartID: UUID
    let tool: AnnoTool
    let color: AnnoColor
    var size: AnnoSize = .medium
    @ObservedObject private var store = AnnotationStore.shared
    @State private var drawing: Mark?
    @State private var editingText: UUID?
    @FocusState private var textFocused: Bool

    init(chartID: UUID, tool: AnnoTool, color: AnnoColor, size: AnnoSize = .medium) {
        self.chartID = chartID; self.tool = tool; self.color = color; self.size = size
    }

    var body: some View {
        GeometryReader { g in
            let size = g.size
            let marks = store.list(chartID) + (drawing.map { [$0] } ?? [])
            ZStack(alignment: .topLeading) {
                Canvas { ctx, _ in
                    for m in marks where m.kind != .text { draw(m, in: &ctx, size: size) }
                }
                .allowsHitTesting(false)
                ForEach(marks.filter { $0.kind == .text }) { m in
                    textMark(m, size: size)
                }
            }
            .contentShape(Rectangle())
            .gesture(DragGesture(minimumDistance: 0)
                .onChanged { v in changed(v, size: size) }
                .onEnded { v in ended(v, size: size) })
            .allowsHitTesting(tool != .select && tool != .comment)
        }
        .onChange(of: tool) { _ in finishText() }
    }

    // MARK: 畫

    private func draw(_ m: Mark, in ctx: inout GraphicsContext, size: CGSize) {
        let c = (AnnoColor(rawValue: m.color) ?? .red).color
        let pts = m.points.map { CGPoint(x: $0.x * size.width, y: $0.y * size.height) }
        switch m.kind {
        case .pen, .highlight:
            guard let first = pts.first else { return }
            var p = Path()
            p.move(to: first)
            if pts.count == 1 { p.addLine(to: CGPoint(x: first.x + 0.1, y: first.y)) }
            for pt in pts.dropFirst() { p.addLine(to: pt) }
            let sz = AnnoSize(rawValue: m.size ?? "") ?? .medium
            let w: CGFloat = m.kind == .pen ? sz.pen : sz.highlight
            ctx.stroke(p, with: .color(m.kind == .pen ? c : c.opacity(0.28)),
                       style: StrokeStyle(lineWidth: w, lineCap: .round, lineJoin: .round))
        case .rect:
            guard pts.count == 2 else { return }
            let r = CGRect(x: min(pts[0].x, pts[1].x), y: min(pts[0].y, pts[1].y),
                           width: abs(pts[1].x - pts[0].x), height: abs(pts[1].y - pts[0].y))
            ctx.stroke(Path(roundedRect: r, cornerRadius: 4), with: .color(c), lineWidth: (AnnoSize(rawValue: m.size ?? "") ?? .medium).pen)
        case .arrow:
            // 直線＋箭頭（箭頭大小跟著粗細）
            guard pts.count == 2 else { return }
            let w = (AnnoSize(rawValue: m.size ?? "") ?? .medium).pen
            let a = pts[0], b = pts[1]
            let ang = atan2(b.y - a.y, b.x - a.x), head = max(9, w * 4)
            var line = Path(); line.move(to: a); line.addLine(to: CGPoint(x: b.x - cos(ang) * head * 0.6, y: b.y - sin(ang) * head * 0.6))
            ctx.stroke(line, with: .color(c), style: StrokeStyle(lineWidth: w, lineCap: .round))
            var tip = Path()
            tip.move(to: b)
            tip.addLine(to: CGPoint(x: b.x - cos(ang - .pi / 7) * head, y: b.y - sin(ang - .pi / 7) * head))
            tip.addLine(to: CGPoint(x: b.x - cos(ang + .pi / 7) * head, y: b.y - sin(ang + .pi / 7) * head))
            tip.closeSubpath()
            ctx.fill(tip, with: .color(c))
        case .text:
            break
        }
    }

    @ViewBuilder
    private func textMark(_ m: Mark, size: CGSize) -> some View {
        let c = (AnnoColor(rawValue: m.color) ?? .red).color
        let origin = CGPoint(x: (m.points.first?.x ?? 0) * size.width, y: (m.points.first?.y ?? 0) * size.height)
        Group {
            if editingText == m.id {
                TextField("輸入註解", text: Binding(get: { m.text }, set: { store.setText(chartID, mark: m.id, $0) }), axis: .vertical)
                    .textFieldStyle(.plain)
                    .focused($textFocused)
                    .onSubmit { finishText() }
                    .frame(minWidth: 120, maxWidth: 260, alignment: .leading)
            } else {
                Text(m.text)
                    .frame(maxWidth: 260, alignment: .leading)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .font(Font.zCalloutStrong)
        .foregroundStyle(c)
        .padding(.horizontal, 6).padding(.vertical, 3)
        .background(RoundedRectangle(cornerRadius: 6).fill(Color.zCard.opacity(0.92)))
        .overlay(RoundedRectangle(cornerRadius: 6).stroke(c.opacity(0.5)))
        .fixedSize()
        .offset(x: origin.x, y: origin.y)
        .allowsHitTesting(editingText == m.id)
    }

    // MARK: 手勢

    private func norm(_ p: CGPoint, _ size: CGSize) -> CGPoint {
        CGPoint(x: min(1, max(0, p.x / size.width)), y: min(1, max(0, p.y / size.height)))
    }

    private func changed(_ v: DragGesture.Value, size: CGSize) {
        let p = norm(v.location, size)
        switch tool {
        case .pen, .highlight:
            if drawing == nil { drawing = Mark(kind: tool == .pen ? .pen : .highlight, points: [norm(v.startLocation, size)], color: color.rawValue, size: self.size.rawValue) }
            drawing?.points.append(p)
        case .rect, .arrow:
            drawing = Mark(kind: tool == .rect ? .rect : .arrow, points: [norm(v.startLocation, size), p], color: color.rawValue, size: self.size.rawValue)
        case .eraser:
            erase(at: v.location, size: size)
        default:
            break
        }
    }

    private func ended(_ v: DragGesture.Value, size: CGSize) {
        switch tool {
        case .pen, .highlight, .rect, .arrow:
            // 箭頭太短（只是點一下）就不留
            if let m = drawing, m.kind != .arrow || hypot((m.points[1].x - m.points[0].x) * size.width, (m.points[1].y - m.points[0].y) * size.height) > 6 {
                store.edit(chartID) { $0.append(m) }
            }
            drawing = nil
        case .text:
            finishText()
            // 點到既有文字就改它，否則新增一則
            if let hit = textHit(v.location, size: size) {
                editingText = hit
            } else {
                let m = Mark(kind: .text, points: [norm(v.location, size)], color: color.rawValue)
                store.edit(chartID) { $0.append(m) }
                editingText = m.id
            }
            DispatchQueue.main.async { textFocused = true }
        case .eraser:
            erase(at: v.location, size: size)
        case .select, .comment:
            break
        }
    }

    /// 文字打完：空的就刪掉
    private func finishText() {
        guard let id = editingText else { return }
        editingText = nil
        if store.list(chartID).first(where: { $0.id == id })?.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? false {
            store.edit(chartID) { $0.removeAll { $0.id == id } }
        }
    }

    private func textHit(_ p: CGPoint, size: CGSize) -> UUID? {
        store.list(chartID).last { m in
            guard m.kind == .text, let o = m.points.first else { return false }
            let r = CGRect(x: o.x * size.width - 4, y: o.y * size.height - 4, width: 200, height: 30)
            return r.contains(p)
        }?.id
    }

    /// 橡皮擦：碰到的標註整筆刪掉
    private func erase(at p: CGPoint, size: CGSize) {
        let hit = store.list(chartID).filter { m in
            let pts = m.points.map { CGPoint(x: $0.x * size.width, y: $0.y * size.height) }
            switch m.kind {
            case .pen, .highlight:
                return pts.contains { hypot($0.x - p.x, $0.y - p.y) < 10 }
            case .rect:
                guard pts.count == 2 else { return false }
                let r = CGRect(x: min(pts[0].x, pts[1].x), y: min(pts[0].y, pts[1].y),
                               width: abs(pts[1].x - pts[0].x), height: abs(pts[1].y - pts[0].y))
                return r.insetBy(dx: -8, dy: -8).contains(p) && !r.insetBy(dx: 8, dy: 8).contains(p)
            case .arrow:
                guard pts.count == 2 else { return false }
                // 點到線段的距離
                let a = pts[0], b = pts[1], dx = b.x - a.x, dy = b.y - a.y
                let t = max(0, min(1, ((p.x - a.x) * dx + (p.y - a.y) * dy) / max(1, dx * dx + dy * dy)))
                return hypot(a.x + t * dx - p.x, a.y + t * dy - p.y) < 10
            case .text:
                guard let o = pts.first else { return false }
                return CGRect(x: o.x - 4, y: o.y - 4, width: 200, height: 30).contains(p)
            }
        }.map(\.id)
        if !hit.isEmpty { store.edit(chartID) { $0.removeAll { hit.contains($0.id) } } }
    }
}

/// 底部浮動工具列（像 Figma）：工具、顏色、復原、清除。淺色模式白底、深色模式深底（zCard）
struct AnnotationToolbar: View {
    let chartID: UUID
    @Binding var tool: AnnoTool
    @Binding var color: AnnoColor
    @Binding var size: AnnoSize
    @ObservedObject private var store = AnnotationStore.shared
    @State private var confirmClear = false
    @State private var hoverTool: AnnoTool?
    @State private var tipTool: AnnoTool?
    @State private var tipTask: Task<Void, Never>?

    var body: some View {
        HStack(spacing: 4) {
            ForEach(AnnoTool.visible, id: \.self) { t in
                Button { withAnimation(Motion.fast) { tool = t } } label: {
                    Image(systemName: t.icon)
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(tool == t ? Color.zOnColor : Color.zText)
                        .frame(width: 38, height: 38)
                        .background(RoundedRectangle(cornerRadius: 10).fill(tool == t ? Color.zAccent : hoverTool == t ? Color.zHover : .clear))
                        .contentShape(Rectangle())
                }
                .buttonStyle(PressStyle())
                // hover 停一下：上方出現深色小標籤「名稱  快捷鍵」（像 Figma）
                .onHover { inside in
                    tipTask?.cancel()
                    if inside {
                        hoverTool = t
                        tipTask = Task { @MainActor in
                            try? await Task.sleep(nanoseconds: 450_000_000)
                            if !Task.isCancelled, hoverTool == t { withAnimation(Motion.fast) { tipTool = t } }
                        }
                    } else if hoverTool == t {
                        hoverTool = nil
                        withAnimation(Motion.fast) { tipTool = nil }
                    }
                }
                .overlay(alignment: .top) {
                    if tipTool == t {
                        HStack(spacing: 8) {
                            Text(t.help.replacingOccurrences(of: "（一般看盤）", with: "")).font(Font.zCalloutStrong)
                            Text(t.key).font(Font.zCallout).opacity(0.6)
                        }
                        .foregroundStyle(Color.white)
                        .padding(.horizontal, 10).frame(height: 28)
                        .background(RoundedRectangle(cornerRadius: 7).fill(Color(white: 0.12)))
                        .fixedSize()
                        .offset(y: -40)
                        .allowsHitTesting(false)
                        .transition(.opacity)
                    }
                }
                if t == .select { divider }
            }
            // 顏色、粗細：選到畫筆、螢光筆、框線、文字時才展開
            if [.pen, .highlight, .arrow, .rect].contains(tool) {
            divider
            ForEach(AnnoColor.allCases, id: \.self) { c in
                Button { color = c; if tool == .select || tool == .eraser { tool = .pen } } label: {
                    Circle().fill(c.color)
                        .frame(width: 16, height: 16)
                        .overlay(Circle().stroke(Color.zText, lineWidth: color == c ? 2 : 0).padding(-3))
                        .frame(width: 26, height: 38)
                        .contentShape(Rectangle())
                }
                .buttonStyle(PressStyle())
                .help(["red": "紅", "blue": "藍", "green": "綠", "orange": "橘", "black": "黑"][c.rawValue] ?? "")
            }
            if true {
            divider
            // 粗細：細、中、粗（畫筆、螢光筆、框線）
            ForEach(AnnoSize.allCases, id: \.self) { z in
                Button { size = z; if tool == .select || tool == .eraser || tool == .text { tool = .pen } } label: {
                    Circle().fill(size == z ? Color.zText : Color.zText3)
                        .frame(width: z.dot, height: z.dot)
                        .frame(width: 26, height: 38)
                        .background(RoundedRectangle(cornerRadius: 8).fill(size == z ? Color.zHover : .clear).padding(.vertical, 6))
                        .contentShape(Rectangle())
                }
                .buttonStyle(PressStyle())
                .help(z.label)
            }
            }
            }
            divider
            Button { store.undoLast(chartID) } label: {
                Image(systemName: "arrow.uturn.backward").font(.system(size: 14, weight: .medium))
                    .foregroundStyle(store.canUndo(chartID) ? Color.zText : Color.zText3)
                    .frame(width: 34, height: 38).contentShape(Rectangle())
            }
            .buttonStyle(PressStyle()).disabled(!store.canUndo(chartID))
            .keyboardShortcut("z", modifiers: .command)
            .help("復原 ⌘Z")
            Button { confirmClear = true } label: {
                Image(systemName: "trash").font(.system(size: 14, weight: .medium))
                    .foregroundStyle(store.list(chartID).isEmpty ? Color.zText3 : Color.zText)
                    .frame(width: 34, height: 38).contentShape(Rectangle())
            }
            .buttonStyle(PressStyle()).disabled(store.list(chartID).isEmpty)
            .help("清除這張盤的全部標註")
            .confirmationDialog("清除這張盤的全部標註？", isPresented: $confirmClear) {
                Button("清除", role: .destructive) { store.edit(chartID) { $0.removeAll() } }
            } message: { Text("可以按復原（⌘Z）找回來。") }
        }
        .padding(.horizontal, 8).padding(.vertical, 6)
        .background(RoundedRectangle(cornerRadius: 16).fill(Color.zCard))   // 實心：淺色白底、深色深底
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.zLine))
        .shadow(color: Color.zShadow, radius: 14, y: 6)
        .animation(Motion.base, value: tool)
        .onExitCommand { tool = .select }   // Esc 回到選取
    }

    private var divider: some View {
        Rectangle().fill(Color.zLine).frame(width: 1, height: 26).padding(.horizontal, 4)
    }
}

/// 每個標註工具的游標：SF Symbol 圖示＋白色描邊＋陰影（游標在命盤上時才換）
enum ToolCursor {
    private static var cache: [AnnoTool: NSCursor] = [:]
    /// 滑鼠停在備註圖釘或對話串上：換回一般箭頭（盤面的游標會先看這個）
    static var overComment = false
    static func setOverComment(_ on: Bool, tool: AnnoTool) {
        overComment = on
        (on ? NSCursor.arrow : cursor(for: tool)).set()
    }

    static func cursor(for tool: AnnoTool) -> NSCursor {
        if tool == .select { return .arrow }
        if let c = cache[tool] { return c }
        let (symbol, hot): (String, CGPoint) = {
            switch tool {
            case .pen: return ("pencil.tip", CGPoint(x: 0.5, y: 0.92))
            case .highlight: return ("highlighter", CGPoint(x: 0.2, y: 0.85))
            case .arrow, .rect: return ("plus", CGPoint(x: 0.5, y: 0.5))
            case .text: return ("character.cursor.ibeam", CGPoint(x: 0.5, y: 0.5))
            case .eraser: return ("eraser", CGPoint(x: 0.3, y: 0.8))
            case .comment: return ("bubble.left.fill", CGPoint(x: 0.12, y: 0.88))
            case .select: return ("cursorarrow", .zero)
            }
        }()
        let size = NSSize(width: 30, height: 30)
        let img = NSImage(size: size, flipped: false) { r in
            let conf = NSImage.SymbolConfiguration(pointSize: 17, weight: .semibold)
            guard let base = NSImage(systemSymbolName: symbol, accessibilityDescription: nil)?.withSymbolConfiguration(conf) else { return false }
            let s = base.size
            let rect = NSRect(x: (r.width - s.width) / 2, y: (r.height - s.height) / 2, width: s.width, height: s.height)
            // 陰影
            let shadow = NSShadow()
            shadow.shadowColor = NSColor.black.withAlphaComponent(0.35)
            shadow.shadowBlurRadius = 3
            shadow.shadowOffset = NSSize(width: 0, height: -1.5)
            NSGraphicsContext.saveGraphicsState()
            shadow.set()
            // 白色描邊：往四周各畫一次白色版本
            let white = base.withSymbolConfiguration(conf.applying(.init(paletteColors: [.white])))!
            for (dx, dy) in [(-1.2, 0), (1.2, 0), (0, -1.2), (0, 1.2), (-0.9, -0.9), (0.9, 0.9), (-0.9, 0.9), (0.9, -0.9)] {
                white.draw(in: rect.offsetBy(dx: CGFloat(dx), dy: CGFloat(dy)))
            }
            NSGraphicsContext.restoreGraphicsState()
            if tool == .comment {
                // 備註：白底泡泡＋主色外框
                let outline = NSImage(systemSymbolName: "bubble.left", accessibilityDescription: nil)?
                    .withSymbolConfiguration(conf.applying(.init(paletteColors: [NSColor(Color.zAccent)])))
                white.draw(in: rect)
                outline?.draw(in: rect)
            } else {
                let ink = base.withSymbolConfiguration(conf.applying(.init(paletteColors: [.black])))!
                ink.draw(in: rect)
            }
            return true
        }
        let c = NSCursor(image: img, hotSpot: NSPoint(x: hot.x * size.width, y: hot.y * size.height))
        cache[tool] = c
        return c
    }
}
