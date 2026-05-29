import SwiftUI
import PDFKit

class ScrollablePDFView: PDFView {
    private var registered = false
    override func viewWillMove(toWindow newWindow: NSWindow?) {
        super.viewWillMove(toWindow: newWindow)
        if newWindow != nil && !registered {
            NotificationCenter.default.addObserver(self, selector: #selector(handleScrollDown), name: NSNotification.Name("ScrollPDFDown"), object: nil)
            NotificationCenter.default.addObserver(self, selector: #selector(handleScrollUp), name: NSNotification.Name("ScrollPDFUp"), object: nil)
            registered = true
        }
    }
    
    @objc func handleScrollDown() {
        if let scrollView = self.subviews.first(where: { $0 is NSScrollView }) as? NSScrollView {
            let contentView = scrollView.contentView
            var newPoint = contentView.bounds.origin
            newPoint.y += 120 // Scroll down logically (AppKit coordinate moves up/down)
            contentView.scroll(to: newPoint)
        } else {
            self.scrollLineDown(nil)
        }
    }
    
    @objc func handleScrollUp() {
        if let scrollView = self.subviews.first(where: { $0 is NSScrollView }) as? NSScrollView {
            let contentView = scrollView.contentView
            var newPoint = contentView.bounds.origin
            newPoint.y -= 120 // Scroll up logically
            contentView.scroll(to: newPoint)
        } else {
            self.scrollLineUp(nil)
        }
    }
}

struct PDFViewWrapper: NSViewRepresentable {
    let url: URL?

    func makeNSView(context: Context) -> PDFView {
        let pdfView = ScrollablePDFView()
        pdfView.backgroundColor = .white
        pdfView.interpolationQuality = .high
        pdfView.appearance = NSAppearance(named: .aqua) // Explicitly force Light Mode (Aqua)
        return pdfView
    }

    func updateNSView(_ nsView: PDFView, context: Context) {
        if let url = url {
            if nsView.document?.documentURL != url {
                nsView.document = PDFDocument(url: url)
                nsView.autoScales = true
            }
        }
        
        // Dynamically ensure high resolution contentsScale matches current window DPI
        let scale = nsView.window?.backingScaleFactor ?? NSScreen.main?.backingScaleFactor ?? 2.0
        
        // Force high-quality rendering options and Light Mode appearance
        nsView.interpolationQuality = .high
        nsView.backgroundColor = .white
        nsView.appearance = NSAppearance(named: .aqua) // Explicitly force Light Mode (Aqua)
        
        // Recursively configure all subview layers for crisp Retina scaling under rotation
        configureHighResolution(for: nsView, scale: scale)
    }
    
    private func configureHighResolution(for view: NSView, scale: CGFloat) {
        view.wantsLayer = true
        if let layer = view.layer {
            layer.contentsScale = scale
            layer.rasterizationScale = scale
            layer.shouldRasterize = false
            layer.magnificationFilter = .linear
        }
        for subview in view.subviews {
            configureHighResolution(for: subview, scale: scale)
        }
    }
}
