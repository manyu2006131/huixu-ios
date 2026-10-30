import SwiftUI
import PencilKit
import PhotosUI
import UniformTypeIdentifiers
import CoreImage
import ImageIO

// MARK: Portable document model
struct EditLayer: Codable, Identifiable, Equatable {
    var id = UUID()
    var name: String
    var image: Data? = nil
    var text = ""
    var x: Double = 512
    var y: Double = 512
    var width: Double = 500
    var height: Double = 500
    var scale: Double = 1
    var rotation: Double = 0
    var opacity: Double = 1
    var hidden = false
    var locked = false
    var flipX = false
    var brightness: Double = 0
    var contrast: Double = 1
    var saturation: Double = 1
    var textSize: Double = 64
    var textColor = "#171320"
}
struct ArtDocument: Codable, Equatable {
    var version = 1
    var width = 1024
    var height = 1024
    var transparent = false
    var layers: [EditLayer] = []
    var drawing = Data()
    func validate() throws {
        guard version == 1, (64...2048).contains(width), (64...2048).contains(height), layers.count <= 30,
              Set(layers.map(\.id)).count == layers.count,
              drawing.count <= 20_000_000,
              layers.reduce(0, { $0 + ($1.image?.count ?? 0) }) <= 60_000_000,
              layers.allSatisfy({ l in
                  [l.x,l.y,l.width,l.height,l.scale,l.rotation,l.opacity,l.brightness,l.contrast,l.saturation,l.textSize].allSatisfy(\.isFinite)
                  && abs(l.x) <= 10000 && abs(l.y) <= 10000 && l.width > 0 && l.width <= 10000 && l.height > 0 && l.height <= 10000
                  && (0.05...8).contains(l.scale) && abs(l.rotation) <= 10000 && (0...1).contains(l.opacity)
                  && (-1...1).contains(l.brightness) && (0...2).contains(l.contrast) && (0...2).contains(l.saturation)
                  && (12...240).contains(l.textSize) && l.text.count <= 2000
              }) else { throw CocoaError(.fileReadCorruptFile) }
    }
}

// MARK: Rendering. Preview and export use the same composition.
@MainActor enum ArtRender {
    static let context = CIContext(options: [.cacheIntermediates: false])
    static func ink(_ data: Data) -> PKDrawing { (try? PKDrawing(data: data)) ?? PKDrawing() }
    static func color(_ hex: String) -> UIColor {
        let n = UInt32(hex.replacingOccurrences(of: "#", with: ""), radix: 16) ?? 0x171320
        return UIColor(red: CGFloat((n >> 16) & 255) / 255, green: CGFloat((n >> 8) & 255) / 255, blue: CGFloat(n & 255) / 255, alpha: 1)
    }
    static func image(_ layer: EditLayer) -> UIImage? {
        guard let bytes = layer.image, let image = UIImage(data: bytes) else { return nil }
        guard layer.brightness != 0 || layer.contrast != 1 || layer.saturation != 1 else { return image }
        guard let source = CIImage(image: image) else { return image }
        let adjusted = source.applyingFilter("CIColorControls", parameters: [kCIInputBrightnessKey:layer.brightness, kCIInputContrastKey:layer.contrast, kCIInputSaturationKey:layer.saturation])
        guard let cg = context.createCGImage(adjusted, from: source.extent) else { return image }
        return UIImage(cgImage: cg, scale: image.scale, orientation: image.imageOrientation)
    }
    static func drawLayer(_ l: EditLayer, context: CGContext) {
        guard !l.hidden else { return }
        context.saveGState(); defer { context.restoreGState() }
        context.translateBy(x: l.x, y: l.y); context.rotate(by: l.rotation)
        context.scaleBy(x: l.scale * (l.flipX ? -1 : 1), y: l.scale); context.setAlpha(l.opacity)
        let rect = CGRect(x: -l.width / 2, y: -l.height / 2, width: l.width, height: l.height)
        if l.image != nil { image(l)?.draw(in: rect) }
        else {
            let paragraph = NSMutableParagraphStyle(); paragraph.alignment = .center
            (l.text as NSString).draw(in: rect, withAttributes: [.font:UIFont.systemFont(ofSize: l.textSize, weight: .semibold), .foregroundColor:color(l.textColor), .paragraphStyle:paragraph])
        }
    }
    static func render(_ doc: ArtDocument, jpeg: Bool = false) -> UIImage {
        let size = CGSize(width: doc.width, height: doc.height)
        let format = UIGraphicsImageRendererFormat(); format.scale = 1; format.opaque = jpeg || !doc.transparent
        return UIGraphicsImageRenderer(size: size, format: format).image { renderer in
            if jpeg || !doc.transparent { UIColor.white.setFill(); renderer.fill(CGRect(origin: .zero, size: size)) }
            for layer in doc.layers { drawLayer(layer, context: renderer.cgContext) }
            ink(doc.drawing).image(from: CGRect(origin: .zero, size: size), scale: 1).draw(at: .zero)
        }
    }
    static func thumbnail(_ data: Data) throws -> UIImage {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil),
              let cg = CGImageSourceCreateThumbnailAtIndex(source, 0, [kCGImageSourceCreateThumbnailFromImageAlways:true, kCGImageSourceThumbnailMaxPixelSize:2048, kCGImageSourceCreateThumbnailWithTransform:true] as CFDictionary) else { throw CocoaError(.fileReadCorruptFile) }
        return UIImage(cgImage: cg)
    }
    static func validatePixels(_ doc: ArtDocument) throws {
        try doc.validate()
        if !doc.drawing.isEmpty { _ = try PKDrawing(data: doc.drawing) }
        var pixels = 0
        for l in doc.layers where l.image != nil {
            guard let data = l.image, let src = CGImageSourceCreateWithData(data as CFData, nil),
                  let props = CGImageSourceCopyPropertiesAtIndex(src, 0, nil) as? [CFString: Any],
                  let w = props[kCGImagePropertyPixelWidth] as? Int, let h = props[kCGImagePropertyPixelHeight] as? Int,
                  w > 0, h > 0, w <= 2048, h <= 2048, UIImage(data: data) != nil else { throw CocoaError(.fileReadCorruptFile) }
            pixels += w * h; guard pixels <= 24_000_000 else { throw CocoaError(.fileReadTooLarge) }
        }
    }
}

@MainActor final class Editor: ObservableObject {
    @Published var document = ArtDocument()
    @Published var selected: UUID?
    @Published var mode = "移动"
    @Published var brush = "钢笔"
    @Published var color = Color.black
    @Published var brushWidth = 10.0
    @Published var error: String?
    @Published var undoStack: [ArtDocument] = []
    @Published var redoStack: [ArtDocument] = []
    @Published var importing = false
    private var writable = true
    private let file = URL.documentsDirectory.appending(path: "huixu-project.json")
    init() {
        if FileManager.default.fileExists(atPath: file.path) {
            do { let data = try Data(contentsOf: file); guard data.count <= 90_000_000 else { throw CocoaError(.fileReadTooLarge) }; document = try JSONDecoder().decode(ArtDocument.self, from: data); try ArtRender.validatePixels(document) }
            catch { writable = false; self.error = "上次工程无法读取，已阻止覆盖原文件。请导出或从有效工程恢复。\n" + error.localizedDescription }
        }
    }
    var layer: EditLayer? { document.layers.first { $0.id == selected } }
    func save() {
        guard writable else { error = "原工程读取失败，已阻止覆盖；请先导入有效工程。"; return }
        do { try JSONEncoder().encode(document).write(to: file, options: [.atomic, .completeFileProtection]) }
        catch { self.error = "保存失败：" + error.localizedDescription }
    }
    func commit(_ next: ArtDocument) {
        guard next != document else { return }
        undoStack.append(document); if undoStack.count > 20 { undoStack.removeFirst() }
        redoStack.removeAll(); document = next; save()
    }
    func undo() { guard let old = undoStack.popLast() else { return }; redoStack.append(document); document = old; selected = nil; save() }
    func redo() { guard let next = redoStack.popLast() else { return }; undoStack.append(document); document = next; selected = nil; save() }
    func update(_ change: (inout EditLayer) -> Void) {
        guard let i = document.layers.firstIndex(where: { $0.id == selected }), !document.layers[i].locked else { return }
        var next = document; change(&next.layers[i]); commit(next)
    }
    func addText(_ text: String) {
        guard document.layers.count < 30 else { error = "最多支持 30 个图片/文字图层"; return }
        let clean = String(text.prefix(2000)); guard !clean.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        var next = document
        let l = EditLayer(name: "文字 · " + String(clean.prefix(12)), text: clean, x: Double(next.width) / 2, y: Double(next.height) / 2, width: Double(next.width) * 0.8, height: 240)
        next.layers.append(l); commit(next); selected = l.id; mode = "移动"
    }
    func addImage(_ image: UIImage) {
        guard document.layers.count < 30, let data = image.pngData() else { error = "无法添加图片，或图层已达 30 个"; return }
        guard document.layers.compactMap(\.image).reduce(data.count, { $0 + $1.count }) <= 60_000_000 else { error = "工程图片数据已达 60 MB，请减少图层"; return }
        let factor = min(Double(document.width) * 0.8 / image.size.width, Double(document.height) * 0.8 / image.size.height)
        let l = EditLayer(name: "图片 \(document.layers.count + 1)", image: data, x: Double(document.width) / 2, y: Double(document.height) / 2, width: image.size.width * factor, height: image.size.height * factor)
        var next = document; next.layers.append(l)
        do { try ArtRender.validatePixels(next); commit(next); selected = l.id; mode = "移动" }
        catch { self.error = "图片总像素已达上限，请减少图层" }
    }
    func clearDrawing() { var next = document; next.drawing = Data(); commit(next) }
    func replace(_ doc: ArtDocument) { writable = true; selected = nil; commit(doc); save() }
}

// MARK: UIKit canvas with independent PencilKit overlay
final class LayerCanvas: UIView {
    var item: EditLayer
    init(_ layer: EditLayer) { self.item = layer; super.init(frame: .zero); isOpaque = false; backgroundColor = .clear; accessibilityLabel = layer.name }
    required init?(coder: NSCoder) { fatalError() }
    override func draw(_ rect: CGRect) {
        guard let context = UIGraphicsGetCurrentContext() else { return }
        var local = item; local.x = bounds.midX; local.y = bounds.midY; local.scale = 1; local.rotation = 0; local.flipX = false; local.opacity = 1
        ArtRender.drawLayer(local, context: context)
    }
}
@MainActor final class CanvasHost: UIView, UIScrollViewDelegate, PKCanvasViewDelegate, UIGestureRecognizerDelegate {
    let scroll = UIScrollView()
    let stage = UIView()
    let canvas = PKCanvasView()
    var editor: Editor?
    var views: [UUID:LayerCanvas] = [:]
    var lastBounds = CGSize.zero
    var lastSize = CGSize.zero
    var lastInk = Data()
    var syncing = false
    var transformStart: [ObjectIdentifier:CGAffineTransform] = [:]
    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = UIColor(red: 0.07, green: 0.06, blue: 0.12, alpha: 1)
        scroll.delegate = self; scroll.minimumZoomScale = 0.1; scroll.maximumZoomScale = 4
        scroll.panGestureRecognizer.minimumNumberOfTouches = 2
        addSubview(scroll); scroll.addSubview(stage)
        stage.clipsToBounds = true
        canvas.isOpaque = false; canvas.backgroundColor = .clear; canvas.isScrollEnabled = false; canvas.delegate = self
        canvas.drawingPolicy = .anyInput; canvas.overrideUserInterfaceStyle = .light
        canvas.accessibilityIdentifier = "drawingCanvas"
        stage.addSubview(canvas)
    }
    required init?(coder: NSCoder) { fatalError() }
    override func layoutSubviews() {
        super.layoutSubviews(); scroll.frame = bounds
        guard bounds.size != lastBounds || stage.bounds.size != lastSize else { centerStage(); return }
        lastBounds = bounds.size; lastSize = stage.bounds.size
        let fit = max(0.01, min((bounds.width - 24) / max(1, stage.bounds.width), (bounds.height - 24) / max(1, stage.bounds.height)))
        scroll.minimumZoomScale = fit; scroll.maximumZoomScale = fit * 6; scroll.setZoomScale(fit, animated: false)
        centerStage()
    }
    func centerStage() {
        scroll.contentInset = UIEdgeInsets(top: max(12, (bounds.height - scroll.contentSize.height) / 2), left: max(12, (bounds.width - scroll.contentSize.width) / 2), bottom: 12, right: 12)
    }
    func viewForZooming(in scrollView: UIScrollView) -> UIView? { stage }
    func scrollViewDidZoom(_ scrollView: UIScrollView) { centerStage() }
    func sync(_ editor: Editor) {
        self.editor = editor; syncing = true; defer { syncing = false }
        let doc = editor.document
        if stage.bounds.size != CGSize(width: doc.width, height: doc.height) {
            scroll.zoomScale = 1; stage.frame = CGRect(x: 0, y: 0, width: doc.width, height: doc.height); scroll.contentSize = stage.bounds.size; setNeedsLayout()
        }
        if doc.transparent {
            let tile = UIGraphicsImageRenderer(size: CGSize(width: 32, height: 32)).image { c in
                UIColor(white: 0.9, alpha: 1).setFill(); c.fill(CGRect(x: 0, y: 0, width: 32, height: 32))
                UIColor(white: 0.72, alpha: 1).setFill(); c.fill(CGRect(x: 0, y: 0, width: 16, height: 16)); c.fill(CGRect(x: 16, y: 16, width: 16, height: 16))
            }; stage.backgroundColor = UIColor(patternImage: tile)
        } else { stage.backgroundColor = .white }
        for (id, view) in views where !doc.layers.contains(where: { $0.id == id }) { view.removeFromSuperview(); views.removeValue(forKey: id) }
        for l in doc.layers {
            let view: LayerCanvas
            if let existing = views[l.id] { view = existing }
            else {
                view = LayerCanvas(l); views[l.id] = view
                let tap = UITapGestureRecognizer(target: self, action: #selector(tapped(_:))); view.addGestureRecognizer(tap)
                let pan = UIPanGestureRecognizer(target: self, action: #selector(moved(_:))); pan.maximumNumberOfTouches = 1; view.addGestureRecognizer(pan)
                let pinch = UIPinchGestureRecognizer(target: self, action: #selector(scaled(_:))); pinch.delegate = self; view.addGestureRecognizer(pinch)
                let rotation = UIRotationGestureRecognizer(target: self, action: #selector(rotated(_:))); rotation.delegate = self; view.addGestureRecognizer(rotation)
                stage.insertSubview(view, belowSubview: canvas)
            }
            view.transform = .identity; view.item = l; view.bounds = CGRect(x: 0, y: 0, width: l.width, height: l.height); view.center = CGPoint(x: l.x, y: l.y)
            view.transform = CGAffineTransform(rotationAngle: l.rotation).scaledBy(x: l.scale * (l.flipX ? -1 : 1), y: l.scale)
            view.alpha = l.opacity; view.isHidden = l.hidden; view.isUserInteractionEnabled = editor.mode == "移动" && !l.locked
            view.layer.borderColor = UIColor.systemPurple.cgColor; view.layer.borderWidth = editor.selected == l.id && editor.mode == "移动" ? 2 / l.scale : 0
            view.setNeedsDisplay(); stage.bringSubviewToFront(view)
            view.layer.borderColor = UIColor.systemPurple.cgColor; view.layer.borderWidth = editor.selected == l.id && editor.mode == "移动" ? 2 / l.scale : 0
        }
        stage.bringSubviewToFront(canvas); canvas.frame = stage.bounds
        canvas.isUserInteractionEnabled = editor.mode != "移动"
        if editor.mode == "橡皮" { canvas.tool = PKEraserTool(.vector) }
        else {
            let type: PKInkingTool.InkType = editor.brush == "铅笔" ? .pencil : editor.brush == "马克笔" ? .marker : .pen
            canvas.tool = PKInkingTool(type, color: UIColor(editor.color), width: editor.brushWidth)
        }
        if lastInk != doc.drawing { canvas.drawing = ArtRender.ink(doc.drawing); lastInk = doc.drawing; canvas.undoManager?.removeAllActions() }
    }
    func canvasViewDidEndUsingTool(_ canvasView: PKCanvasView) {
        guard !syncing, let editor else { return }
        let bytes = canvas.drawing.dataRepresentation(); guard bytes != editor.document.drawing else { return }
        guard bytes.count <= 20_000_000 else { editor.error = "笔迹数据超过上限，请简化工程"; canvas.drawing = ArtRender.ink(editor.document.drawing); return }
        lastInk = bytes; var next = editor.document; next.drawing = bytes; editor.commit(next)
    }
    @objc func tapped(_ gesture: UITapGestureRecognizer) { guard let v = gesture.view as? LayerCanvas else { return }; editor?.selected = v.item.id }
    @objc func moved(_ gesture: UIPanGestureRecognizer) {
        guard let v = gesture.view as? LayerCanvas, let editor else { return }
        if gesture.state == .began { editor.selected = v.item.id }
        let delta = gesture.translation(in: stage); v.center.x += delta.x; v.center.y += delta.y; gesture.setTranslation(.zero, in: stage)
        if gesture.state == .ended { editor.update { $0.x = max(-10000, min(10000, v.center.x)); $0.y = max(-10000, min(10000, v.center.y)) } }
        if gesture.state == .cancelled { sync(editor) }
    }
    @objc func scaled(_ gesture: UIPinchGestureRecognizer) {
        guard let v = gesture.view as? LayerCanvas, let editor else { return }; if gesture.state == .began { editor.selected = v.item.id }
        let key = ObjectIdentifier(gesture)
        if gesture.state == .began { transformStart[key] = v.transform }
        let base = transformStart[key] ?? v.transform
        let current = editor.layer?.scale ?? 1; let scale = max(0.05, min(8, current * gesture.scale)) / current
        v.transform = base.scaledBy(x: scale, y: scale)
        if gesture.state == .ended { editor.update { $0.scale = max(0.05, min(8, current * gesture.scale)) }; transformStart[key] = nil }
        if gesture.state == .cancelled { transformStart[key] = nil; sync(editor) }
    }
    @objc func rotated(_ gesture: UIRotationGestureRecognizer) {
        guard let v = gesture.view as? LayerCanvas, let editor else { return }; if gesture.state == .began { editor.selected = v.item.id }
        let key = ObjectIdentifier(gesture)
        if gesture.state == .began { transformStart[key] = v.transform }
        v.transform = (transformStart[key] ?? v.transform).rotated(by: gesture.rotation)
        if gesture.state == .ended { editor.update { $0.rotation += gesture.rotation }; transformStart[key] = nil }
        if gesture.state == .cancelled { transformStart[key] = nil; sync(editor) }
    }
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool { false }
}
struct CanvasSurface: UIViewRepresentable {
    @ObservedObject var editor: Editor
    func makeUIView(context: Context) -> CanvasHost { CanvasHost() }
    func updateUIView(_ uiView: CanvasHost, context: Context) { uiView.sync(editor) }
}

struct BinaryDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.json, .png, .jpeg] }
    var bytes: Data
    init(_ bytes: Data) { self.bytes = bytes }
    init(configuration: ReadConfiguration) throws { bytes = configuration.file.regularFileContents ?? Data() }
    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper { FileWrapper(regularFileWithContents: bytes) }
}
@main struct HuixuApp: App {
    @StateObject private var editor = Editor()
    var body: some Scene { WindowGroup { EditorScreen().environmentObject(editor).preferredColorScheme(.dark).tint(.purple) } }
}
struct EditorScreen: View {
    @EnvironmentObject var editor: Editor
    @State private var photo: PhotosPickerItem?
    @State private var panel = false
    @State private var textPrompt = false
    @State private var text = ""
    @State private var clearPrompt = false
    @State private var newPrompt = false
    @State private var importing = false
    @State private var incoming: ArtDocument?
    @State private var restorePrompt = false
    @State private var exporting = false
    @State private var export = BinaryDocument(Data())
    @State private var exportType = UTType.png
    @State private var filename = "绘序作品"
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                HStack {
                    Text("\(editor.document.width) × \(editor.document.height)").font(.caption.monospacedDigit())
                    Spacer(); Text(editor.importing ? "正在导入…" : "两指缩放画布 · 移动模式可拖图片").font(.caption2)
                }.foregroundStyle(.secondary).padding(12)
                CanvasSurface(editor: editor).accessibilityIdentifier("artboard")
                controls
            }.background(Color(red: 0.08, green: 0.06, blue: 0.13))
            .navigationTitle("绘序 · 魔女画室").navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Menu {
                        Button("新建画布") { newPrompt = true }
                        Button("导入工程") { importing = true }
                        Button("导出工程（可继续编辑）") { prepareExport(.json) }
                        Button("导出 PNG") { prepareExport(.png) }
                        Button("导出 JPEG（白底）") { prepareExport(.jpeg) }
                    } label: { Image(systemName: "doc.badge.gearshape") }.accessibilityLabel("文件")
                }
                ToolbarItemGroup(placement: .topBarTrailing) {
                    PhotosPicker(selection: $photo, matching: .images) { Image(systemName: "photo.badge.plus") }.accessibilityLabel("导入图片").disabled(editor.importing)
                    Button { text = ""; textPrompt = true } label: { Image(systemName: "textformat") }.accessibilityLabel("添加文字")
                    Button { panel = true } label: { Image(systemName: "square.3.layers.3d") }.accessibilityLabel("图层与调整")
                }
            }
            .alert("添加文字图层", isPresented: $textPrompt) {
                TextField("输入文字", text: $text)
                Button("添加") { editor.addText(text) }; Button("取消", role: .cancel) {}
            }
            .confirmationDialog("选择清理范围，图片会保留；两种操作都可撤销。", isPresented: $clearPrompt, titleVisibility: .visible) { Button("只清空手绘笔迹", role: .destructive) { editor.clearDrawing() }; Button("清空笔迹及文字", role: .destructive) { var next = editor.document; next.drawing = Data(); next.layers.removeAll { $0.image == nil }; editor.commit(next) } }
            .confirmationDialog("新建画布？当前内容会清空，可撤销；建议先导出工程。", isPresented: $newPrompt, titleVisibility: .visible) {
                Button("正方形 1024 × 1024") { editor.commit(ArtDocument()) }
                Button("竖版 1024 × 1536") { var d = ArtDocument(); d.height = 1536; editor.commit(d) }
                Button("横版 1536 × 1024") { var d = ArtDocument(); d.width = 1536; editor.commit(d) }
            }
            .alert("提示", isPresented: Binding(get: { editor.error != nil }, set: { if !$0 { editor.error = nil } })) { Button("知道了") { editor.error = nil } } message: { Text(editor.error ?? "") }
            .sheet(isPresented: $panel) { NavigationStack { LayersPanel() }.environmentObject(editor) }
            .fileExporter(isPresented: $exporting, document: export, contentType: exportType, defaultFilename: filename) { result in if case .failure(let e) = result { editor.error = e.localizedDescription } }
            .fileImporter(isPresented: $importing, allowedContentTypes: [.json]) { result in
                do {
                    let url = try result.get(); let access = url.startAccessingSecurityScopedResource(); defer { if access { url.stopAccessingSecurityScopedResource() } }
                    let bytes = try Data(contentsOf: url); guard bytes.count <= 90_000_000 else { throw CocoaError(.fileReadTooLarge) }
                    let doc = try JSONDecoder().decode(ArtDocument.self, from: bytes); try ArtRender.validatePixels(doc)
                    incoming = doc; restorePrompt = true
                } catch { editor.error = "工程导入失败：" + error.localizedDescription }
            }
            .confirmationDialog("用导入工程替换当前画布？可撤销。", isPresented: $restorePrompt, titleVisibility: .visible) { Button("替换工程") { if let doc = incoming { editor.replace(doc) }; incoming = nil }; Button("取消", role: .cancel) { incoming = nil } }
            .onChange(of: photo) { _, item in
                guard let item else { return }
                editor.importing = true
                Task { @MainActor in
                    defer { editor.importing = false; photo = nil }
                    do {
                        guard let bytes = try await item.loadTransferable(type: Data.self), bytes.count <= 60_000_000 else { throw CocoaError(.fileReadTooLarge) }
                        editor.addImage(try ArtRender.thumbnail(bytes))
                    } catch { editor.error = "图片导入失败：" + error.localizedDescription }
                }
            }
        }
    }
    var controls: some View {
        VStack(spacing: 10) {
            HStack {
                Picker("工具", selection: $editor.mode) { ForEach(["移动", "绘画", "橡皮"], id: \.self) { Text($0) } }.pickerStyle(.segmented)
                Button { editor.undo() } label: { Image(systemName: "arrow.uturn.backward") }.accessibilityLabel("撤销").disabled(editor.undoStack.isEmpty)
                Button { editor.redo() } label: { Image(systemName: "arrow.uturn.forward") }.accessibilityLabel("重做").disabled(editor.redoStack.isEmpty)
            }
            if editor.mode == "绘画" {
                HStack {
                    Picker("笔刷", selection: $editor.brush) { ForEach(["钢笔", "铅笔", "马克笔"], id: \.self) { Text($0) } }.pickerStyle(.menu)
                    ColorPicker("颜色", selection: $editor.color, supportsOpacity: true).labelsHidden()
                    Slider(value: $editor.brushWidth, in: 1...80).accessibilityLabel("笔刷大小")
                    Text("\(Int(editor.brushWidth))").font(.caption.monospacedDigit())
                }
            }
            HStack {
                Button("一键清空涂鸦", systemImage: "eraser.fill") { clearPrompt = true }.font(.caption).disabled(editor.document.drawing.isEmpty && !editor.document.layers.contains { $0.image == nil })
                Spacer()
                Button("导出 PNG", systemImage: "square.and.arrow.up") { prepareExport(.png) }.font(.caption).buttonStyle(.borderedProminent)
            }
        }.padding(12).background(.ultraThinMaterial)
    }
    func prepareExport(_ type: UTType) {
        do {
            exportType = type
            if type == .json { export = BinaryDocument(try JSONEncoder().encode(editor.document)); filename = "绘序工程" }
            else {
                let image = ArtRender.render(editor.document, jpeg: type == .jpeg)
                guard let bytes = type == .png ? image.pngData() : image.jpegData(compressionQuality: 0.92) else { throw CocoaError(.fileWriteUnknown) }
                export = BinaryDocument(bytes); filename = "绘序作品"
            }
            exporting = true
        } catch { editor.error = error.localizedDescription }
    }
}

struct LayersPanel: View {
    @EnvironmentObject var editor: Editor
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        List {
            Section("画布") {
                Toggle("透明背景（PNG 保留透明度）", isOn: Binding(get: { editor.document.transparent }, set: { v in var next = editor.document; next.transparent = v; editor.commit(next) }))
                Text("两指缩放和移动整个画布。移动模式下，单指拖动图层；在图层上双指缩放或旋转。画布边界外内容在导出时裁去。 ").font(.footnote).foregroundStyle(.secondary)
            }
            Section("顶部 · 手绘笔迹层") {
                Label("钢笔、铅笔、马克笔与橡皮", systemImage: "pencil.tip.crop.circle")
                Text("所有手绘笔迹统一位于图片和文字上方。橡皮仅擦除此层，按完整笔画擦除。 ").font(.footnote).foregroundStyle(.secondary)
            }
            Section("图层 · 从上往下排列") {
                if editor.document.layers.isEmpty { ContentUnavailableView("还没有图层", systemImage: "square.3.layers.3d", description: Text("用顶部按钮导入图片或添加文字。")) }
                ForEach(editor.document.layers.reversed()) { layer in
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Image(systemName: layer.image == nil ? "textformat" : "photo")
                            Button(layer.name) { editor.selected = layer.id; editor.mode = "移动" }.fontWeight(editor.selected == layer.id ? .bold : .regular)
                            Spacer()
                            Button { change(layer.id) { $0.hidden.toggle() } } label: { Image(systemName: layer.hidden ? "eye.slash" : "eye") }.accessibilityLabel("显示或隐藏图层")
                            Button { change(layer.id) { $0.locked.toggle() } } label: { Image(systemName: layer.locked ? "lock.fill" : "lock.open") }.accessibilityLabel("锁定或解锁图层")
                        }.buttonStyle(.borderless)
                        NavigationLink("调整 · " + layer.name) { LayerInspector(initial: layer) }
                        HStack {
                            Button("上移") { reorder(layer.id, offset: 1) }
                            Button("下移") { reorder(layer.id, offset: -1) }
                            Button("复制") { duplicate(layer) }.disabled(editor.document.layers.count >= 30)
                            Button("删除", role: .destructive) { var next = editor.document; next.layers.removeAll { $0.id == layer.id }; editor.commit(next) }.disabled(layer.locked)
                        }.font(.caption).buttonStyle(.bordered)
                    }.padding(.vertical, 6)
                }
            }
            Section {
                Text("最多 30 个图片/文字图层，单张导入图片会缩小到最长边 2048 像素。工程自动保存在本机，可导出 JSON 继续编辑；图片导出会合并图层。撤销历史最多 20 步，仅在当前启动期间保留。 ").font(.footnote).foregroundStyle(.secondary)
            }
        }.navigationTitle("图层与调整").toolbar { Button("完成") { dismiss() } }
    }
    func change(_ id: UUID, _ action: (inout EditLayer) -> Void) {
        guard let i = editor.document.layers.firstIndex(where: { $0.id == id }) else { return }
        var next = editor.document; action(&next.layers[i]); editor.commit(next)
    }
    func reorder(_ id: UUID, offset: Int) {
        guard let i = editor.document.layers.firstIndex(where: { $0.id == id }), !editor.document.layers[i].locked else { return }
        let j = i + offset; guard editor.document.layers.indices.contains(j) else { return }
        var next = editor.document; next.layers.swapAt(i, j); editor.commit(next)
    }
    func duplicate(_ layer: EditLayer) {
        guard editor.document.layers.count < 30 else { return }
        var copy = layer; copy.id = UUID(); copy.name += " 副本"; copy.x += 20; copy.y += 20; copy.locked = false
        var next = editor.document; next.layers.append(copy)
        do { try ArtRender.validatePixels(next); editor.commit(next); editor.selected = copy.id }
        catch { editor.error = "复制超出工程限制" }
    }
}
struct LayerInspector: View {
    @EnvironmentObject var editor: Editor
    @Environment(\.dismiss) private var dismiss
    @State var draft: EditLayer
    init(initial: EditLayer) { _draft = State(initialValue: initial) }
    var body: some View {
        Form {
            Section("图层名称") { TextField("名称", text: $draft.name) }
            if draft.image == nil {
                Section("文字内容") {
                    TextEditor(text: $draft.text).frame(minHeight: 100)
                    Slider(value: $draft.textSize, in: 12...240) { Text("字号") }
                    Text("字号 \(Int(draft.textSize))")
                    Picker("文字颜色", selection: $draft.textColor) { Text("墨黑").tag("#171320"); Text("纯白").tag("#FFFFFF"); Text("魔法紫").tag("#9555EE"); Text("冰蓝").tag("#33BBDD"); Text("红色").tag("#EE3355") }
                }
            }
            Section("位置与变换") {
                Stepper("水平位置 \(Int(draft.x))", value: $draft.x, in: -10000...10000, step: 10)
                Stepper("垂直位置 \(Int(draft.y))", value: $draft.y, in: -10000...10000, step: 10)
                Slider(value: $draft.scale, in: 0.05...8) { Text("缩放") }
                Text("缩放 \(draft.scale, specifier: "%.2f") 倍")
                Slider(value: $draft.rotation, in: -Double.pi...Double.pi) { Text("旋转") }
                Text("旋转 \(draft.rotation * 180 / .pi, specifier: "%.0f")°")
                Toggle("水平翻转", isOn: $draft.flipX)
                Button("居中") { draft.x = Double(editor.document.width) / 2; draft.y = Double(editor.document.height) / 2 }
            }
            Section("不透明度") { Slider(value: $draft.opacity, in: 0...1); Text("\(Int(draft.opacity * 100))%") }
            if draft.image != nil {
                Section("图片调色") {
                    Text("亮度 \(draft.brightness, specifier: "%.2f")"); Slider(value: $draft.brightness, in: -1...1)
                    Text("对比度 \(draft.contrast, specifier: "%.2f")"); Slider(value: $draft.contrast, in: 0...2)
                    Text("饱和度 \(draft.saturation, specifier: "%.2f")"); Slider(value: $draft.saturation, in: 0...2)
                    Button("黑白") { draft.saturation = 0 }
                    Button("恢复原色") { draft.brightness = 0; draft.contrast = 1; draft.saturation = 1 }
                }
            }
            Text("点击应用后更新画布，可撤销。锁定的图层需先在列表中解锁。 ").font(.footnote).foregroundStyle(.secondary)
            Button("应用调整") {
                guard let i = editor.document.layers.firstIndex(where: { $0.id == draft.id }), !editor.document.layers[i].locked else { return }
                draft.text = String(draft.text.prefix(2000)); var next = editor.document; next.layers[i] = draft
                do { try next.validate(); editor.commit(next); dismiss() } catch { editor.error = "调整参数无效" }
            }.disabled(draft.locked || draft.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }.navigationTitle("图层属性")
    }
}
