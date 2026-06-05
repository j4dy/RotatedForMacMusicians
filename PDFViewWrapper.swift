/*
 RENDERING ARCHITECTURE — Custom Rasterizing PDF Renderer
 
 WHY WE ABANDONED PDFView:
 PDFView uses CATiledLayer internally for page rendering. When the hosting NSView has
 frameCenterRotation = ±90°, CATiledLayer's tile math uses the rotated coordinate system
 to compute which tiles are "visible" — causing it to render only a partial strip of the
 page, leaving the rest blank (but still interactive). This is a fundamental AppKit/PDFKit
 bug with no known workaround short of bypassing the tiled renderer entirely.
 
 OUR SOLUTION — NSImageView + PDFPage.draw():
 1. Load the PDFDocument normally.
 2. When the page changes (or the view is sized), rasterize the current PDFPage into
    an NSImage using PDFPage.draw(with:to:) at 2× Retina scale.
 3. Display the resulting NSImage in a plain NSImageView with no layers or tiling.
 4. All page navigation is managed by a simple integer index — no PDFView state machine.
 
 This approach is immune to the rotation coordinate miscalculation because NSImageView
 renders a pre-rasterized bitmap directly into the window backing store.
*/

import SwiftUI
import PDFKit
import AppKit

// MARK: - Coordinator / ViewModel

final class PDFRenderCoordinator: NSObject {
    var document: PDFDocument?
    var currentIndex: Int = 0

    // Render the page at `index` into an NSImage sized to fill `targetSize`.
    // Runs on a background thread; safe to call from any thread.
    func renderPage(at index: Int, targetSize: CGSize, scale: CGFloat = 2.0) -> NSImage? {
        guard let doc = document,
              index >= 0, index < doc.pageCount,
              let page = doc.page(at: index) else { return nil }

        let pageBounds = page.bounds(for: .mediaBox)
        guard pageBounds.width > 0, pageBounds.height > 0,
              targetSize.width > 0, targetSize.height > 0 else { return nil }

        // Fit the page proportionally into targetSize
        let scaleW = targetSize.width / pageBounds.width
        let scaleH = targetSize.height / pageBounds.height
        let fitScale = min(scaleW, scaleH)

        let renderW = pageBounds.width  * fitScale * scale
        let renderH = pageBounds.height * fitScale * scale

        let bitmapSize = CGSize(width: renderW, height: renderH)
        guard let rep = NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: Int(renderW),
            pixelsHigh: Int(renderH),
            bitsPerSample: 8,
            samplesPerPixel: 4,
            hasAlpha: true,
            isPlanar: false,
            colorSpaceName: .deviceRGB,
            bytesPerRow: 0,
            bitsPerPixel: 0
        ) else { return nil }

        guard let ctx = NSGraphicsContext(bitmapImageRep: rep) else { return nil }

        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = ctx

        let cgCtx = ctx.cgContext
        // White background
        cgCtx.setFillColor(NSColor.white.cgColor)
        cgCtx.fill(CGRect(origin: .zero, size: bitmapSize))

        // Scale and draw the page
        cgCtx.scaleBy(x: fitScale * scale, y: fitScale * scale)
        page.draw(with: .mediaBox, to: cgCtx)

        NSGraphicsContext.restoreGraphicsState()

        let img = NSImage(size: NSSize(width: renderW / scale, height: renderH / scale))
        img.addRepresentation(rep)
        return img
    }
}

// MARK: - NSView subclass: displays a single pre-rendered PDF page

class PDFPageImageView: NSView {
    private let imageView = NSImageView()
    let coordinator = PDFRenderCoordinator()

    // Bindings piped in from the SwiftUI coordinator
    var onPageChanged: ((Int, Int) -> Void)?

    private var renderWorkItem: DispatchWorkItem?
    private var lastRenderedIndex: Int = -1
    private var lastRenderedSize: CGSize = .zero

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setup()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }

    private func setup() {
        wantsLayer = false          // plain drawRect rendering — no CoreAnimation
        imageView.imageScaling = .scaleProportionallyUpOrDown
        imageView.imageAlignment = .alignCenter
        imageView.wantsLayer = false
        addSubview(imageView)

        // Register page-navigation notifications
        NotificationCenter.default.addObserver(self, selector: #selector(handlePreviousPage),
                                               name: NSNotification.Name("PDFGoToPreviousPage"), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(handleNextPage),
                                               name: NSNotification.Name("PDFGoToNextPage"), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(handleScrollDown),
                                               name: NSNotification.Name("ScrollPDFDown"), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(handleScrollUp),
                                               name: NSNotification.Name("ScrollPDFUp"), object: nil)
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    // Called by the SwiftUI wrapper when the URL changes
    func load(url: URL) {
        let ext = url.pathExtension.lowercased()
        let isImage = ["png", "jpg", "jpeg", "gif", "tiff", "bmp", "heic", "webp"].contains(ext)
        
        if isImage {
            coordinator.document = nil
            coordinator.currentIndex = 0
            lastRenderedIndex = -1
            let img = NSImage(contentsOf: url)
            imageView.image = img
            onPageChanged?(0, 1)
        } else {
            let newDoc = PDFDocument(url: url)
            coordinator.document = newDoc
            coordinator.currentIndex = 0
            lastRenderedIndex = -1      // force re-render
            scheduleRender()
        }
    }

    // MARK: Layout

    override func layout() {
        super.layout()
        imageView.frame = bounds
        // Re-render if size changed meaningfully and it's a PDF
        if coordinator.document != nil {
            if abs(bounds.width - lastRenderedSize.width) > 1 ||
               abs(bounds.height - lastRenderedSize.height) > 1 {
                scheduleRender()
            }
        }
    }

    // MARK: Rendering

    private func scheduleRender() {
        renderWorkItem?.cancel()
        if coordinator.document == nil {
            return
        }
        let idx = coordinator.currentIndex
        let size = bounds.size
        guard size.width > 0, size.height > 0 else { return }

        let workItem = DispatchWorkItem { [weak self] in
            guard let self else { return }
            let img = self.coordinator.renderPage(at: idx, targetSize: size)
            DispatchQueue.main.async {
                self.imageView.image = img
                self.lastRenderedIndex = idx
                self.lastRenderedSize = size
                // Notify bindings
                let total = self.coordinator.document?.pageCount ?? 0
                self.onPageChanged?(idx, total)
            }
        }
        renderWorkItem = workItem
        DispatchQueue.global(qos: .userInitiated).async(execute: workItem)
    }

    // MARK: Navigation

    @objc private func handlePreviousPage() {
        guard let doc = coordinator.document, doc.pageCount > 0 else { return }
        if coordinator.currentIndex > 0 {
            coordinator.currentIndex -= 1
            scheduleRender()
        }
    }

    @objc private func handleNextPage() {
        guard let doc = coordinator.document, doc.pageCount > 0 else { return }
        if coordinator.currentIndex < doc.pageCount - 1 {
            coordinator.currentIndex += 1
            scheduleRender()
        }
    }

    @objc private func handleScrollDown() {
        handleNextPage()
    }

    @objc private func handleScrollUp() {
        handlePreviousPage()
    }
}

// MARK: - SwiftUI wrapper

struct PDFViewWrapper: NSViewRepresentable {
    let url: URL?
    @Binding var currentPageIndex: Int
    @Binding var totalPageCount: Int

    func makeNSView(context: Context) -> PDFPageImageView {
        let view = PDFPageImageView()
        view.onPageChanged = { idx, total in
            DispatchQueue.main.async {
                context.coordinator.parent.currentPageIndex = idx
                context.coordinator.parent.totalPageCount = total
            }
        }
        if let url = url {
            view.load(url: url)
        }
        return view
    }

    func updateNSView(_ nsView: PDFPageImageView, context: Context) {
        context.coordinator.parent = self
        // Reload document only when the URL actually changes
        if let url = url {
            if nsView.coordinator.document?.documentURL != url {
                nsView.load(url: url)
            }
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject {
        var parent: PDFViewWrapper
        init(_ parent: PDFViewWrapper) { self.parent = parent }
    }
}
