import SwiftUI
import PDFKit

struct PDFViewWrapper: NSViewRepresentable {
    let url: URL?

    func makeNSView(context: Context) -> PDFView {
        let pdfView = PDFView()
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
