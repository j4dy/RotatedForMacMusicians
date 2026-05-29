import SwiftUI
import PDFKit

class ScrollablePDFView: PDFView {
    private var registered = false
    override func viewWillMove(toWindow newWindow: NSWindow?) {
        super.viewWillMove(toWindow: newWindow)
        if newWindow != nil && !registered {
            NotificationCenter.default.addObserver(self, selector: #selector(handleScrollDown), name: NSNotification.Name("ScrollPDFDown"), object: nil)
            NotificationCenter.default.addObserver(self, selector: #selector(handleScrollUp), name: NSNotification.Name("ScrollPDFUp"), object: nil)
            NotificationCenter.default.addObserver(self, selector: #selector(handlePreviousPage), name: NSNotification.Name("PDFGoToPreviousPage"), object: nil)
            NotificationCenter.default.addObserver(self, selector: #selector(handleNextPage), name: NSNotification.Name("PDFGoToNextPage"), object: nil)
            registered = true
        }
    }
    
    override func layout() {
        super.layout()
        // Manually calculate and enforce scale factor to fit the entire page within the view bounds (page fit view)
        if let page = self.currentPage {
            let pageBounds = page.bounds(for: self.displayBox)
            let viewBounds = self.bounds
            if pageBounds.width > 0 && pageBounds.height > 0 && viewBounds.width > 0 && viewBounds.height > 0 {
                self.autoScales = false
                
                let widthScale = viewBounds.width / pageBounds.width
                let heightScale = viewBounds.height / pageBounds.height
                
                // Use the smaller scale factor to ensure the entire page fits in view bounds cleanly (Page Fit, zoom 1.0)
                let scaleFactor = min(widthScale, heightScale) * 1.0
                self.scaleFactor = scaleFactor
            }
        }
    }
    
    @objc func handlePreviousPage() {
        self.goToPreviousPage(nil)
    }
    
    @objc func handleNextPage() {
        self.goToNextPage(nil)
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
    @Binding var currentPageIndex: Int
    @Binding var totalPageCount: Int

    func makeNSView(context: Context) -> PDFView {
        let pdfView = ScrollablePDFView()
        pdfView.backgroundColor = .white
        pdfView.interpolationQuality = .high
        pdfView.displayMode = .singlePage // Show only 1 page at a time
        pdfView.displaysPageBreaks = false // Remove all default shadows/margins/borders
        pdfView.autoScales = false // We handle width scaling manually!
        pdfView.appearance = NSAppearance(named: .aqua) // Explicitly force Light Mode (Aqua)
        
        context.coordinator.setupNotificationObserver(for: pdfView)
        return pdfView
    }

    func updateNSView(_ nsView: PDFView, context: Context) {
        context.coordinator.parent = self
        
        if let url = url {
            if nsView.document?.documentURL != url {
                nsView.document = PDFDocument(url: url)
                nsView.displayMode = .singlePage
                nsView.displaysPageBreaks = false
                nsView.autoScales = false
                
                // Let the view obtain its layout and non-zero bounds first, then fit width
                DispatchQueue.main.async {
                    if let page = nsView.currentPage {
                        let pageBounds = page.bounds(for: nsView.displayBox)
                        let viewBounds = nsView.bounds
                        if pageBounds.width > 0 && pageBounds.height > 0 && viewBounds.width > 0 && viewBounds.height > 0 {
                            let widthScale = viewBounds.width / pageBounds.width
                            let heightScale = viewBounds.height / pageBounds.height
                            nsView.scaleFactor = min(widthScale, heightScale) * 1.0
                        }
                    }
                    context.coordinator.updatePageInfo(from: nsView)
                }
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
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject {
        var parent: PDFViewWrapper
        
        init(_ parent: PDFViewWrapper) {
            self.parent = parent
        }
        
        func setupNotificationObserver(for pdfView: PDFView) {
            NotificationCenter.default.addObserver(
                self,
                selector: #selector(pageChangedNotification(_:)),
                name: .PDFViewPageChanged,
                object: pdfView
            )
        }
        
        @objc private func pageChangedNotification(_ notification: Notification) {
            guard let pdfView = notification.object as? PDFView else { return }
            
            // Adjust zoom factor to perfectly fit width on page change
            if let page = pdfView.currentPage {
                let pageBounds = page.bounds(for: pdfView.displayBox)
                let viewBounds = pdfView.bounds
                if pageBounds.width > 0 && pageBounds.height > 0 && viewBounds.width > 0 && viewBounds.height > 0 {
                    pdfView.autoScales = false
                    let widthScale = viewBounds.width / pageBounds.width
                    let heightScale = viewBounds.height / pageBounds.height
                    pdfView.scaleFactor = min(widthScale, heightScale) * 1.0
                }
            }
            
            updatePageInfo(from: pdfView)
        }
        
        func updatePageInfo(from pdfView: PDFView) {
            guard let document = pdfView.document else {
                DispatchQueue.main.async {
                    self.parent.currentPageIndex = 0
                    self.parent.totalPageCount = 0
                }
                return
            }
            let total = document.pageCount
            let current = pdfView.currentPage
            let index = current != nil ? document.index(for: current!) : 0
            
            DispatchQueue.main.async {
                self.parent.currentPageIndex = index
                self.parent.totalPageCount = total
            }
        }
        
        deinit {
            NotificationCenter.default.removeObserver(self)
        }
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
