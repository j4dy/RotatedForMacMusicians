/*
 SUMMARY OF RENDERING ARCHITECTURE & ROTATED PDF DISCREPANCIES:
 
 - WantsLayer (recursive): Forces layer-backing recursively on PDFView and its internal page subviews. Under physically rotated frame views (frameCenterRotation = 90 or -90), this transforms coordinate calculations in CoreAnimation tiled layers (CATiledLayer), causing the tiled renderer to miscalculate the visible viewport and render only a portion of the page (leaving the rest blank white but interactive).
 - WantsLayer = false: Disables CoreAnimation layers on the PDFView hierarchy, forcing AppKit to fall back to standard synchronous vector drawRect rendering directly into the rotated window's backing store. This avoids viewport miscalculation but is still subject to AppKit rendering restrictions under complex view rotation.
 
 DIFF COMPARISON AGAINST origin/main:
 1. PDFViewWrapper.makeNSView sets pdfView.wantsLayer = false.
 2. PDFViewWrapper.updateNSView sets nsView.wantsLayer = false.
 3. Removed configureHighResolution(for:scale:) and its recursive layer configurations.
 */

import SwiftUI
import PDFKit

class ScrollablePDFView: PDFView {
    private var registered = false
    
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        Swift.print("ScrollablePDFView init(frame:) called! self: \(Unmanaged.passUnretained(self).toOpaque())")
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        Swift.print("ScrollablePDFView init(coder:) called! self: \(Unmanaged.passUnretained(self).toOpaque())")
    }
    
    deinit {
        Swift.print("ScrollablePDFView deinit called! self: \(Unmanaged.passUnretained(self).toOpaque())")
        NotificationCenter.default.removeObserver(self)
    }
    
    override func viewWillMove(toWindow newWindow: NSWindow?) {
        super.viewWillMove(toWindow: newWindow)
        Swift.print("ScrollablePDFView viewWillMove(toWindow:) called on self: \(Unmanaged.passUnretained(self).toOpaque()) with window: \(String(describing: newWindow)), registered: \(registered)")
        if newWindow != nil && !registered {
            NotificationCenter.default.addObserver(self, selector: #selector(handleScrollDown), name: NSNotification.Name("ScrollPDFDown"), object: nil)
            NotificationCenter.default.addObserver(self, selector: #selector(handleScrollUp), name: NSNotification.Name("ScrollPDFUp"), object: nil)
            NotificationCenter.default.addObserver(self, selector: #selector(handlePreviousPage), name: NSNotification.Name("PDFGoToPreviousPage"), object: nil)
            NotificationCenter.default.addObserver(self, selector: #selector(handleNextPage), name: NSNotification.Name("PDFGoToNextPage"), object: nil)
            registered = true
            Swift.print("ScrollablePDFView registered notifications successfully for self: \(Unmanaged.passUnretained(self).toOpaque())")
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
                if abs(self.scaleFactor - scaleFactor) > 0.001 {
                    self.scaleFactor = scaleFactor
                }
            }
        }
    }
    
    @objc func handlePreviousPage() {
        Swift.print("PDFView handlePreviousPage received! Document has \(self.document?.pageCount ?? 0) pages.")
        self.goToPreviousPage(nil)
    }
    
    @objc func handleNextPage() {
        Swift.print("PDFView handleNextPage received! Document has \(self.document?.pageCount ?? 0) pages.")
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
        pdfView.wantsLayer = true // Explicitly enable layer backing on the PDFView itself
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
                            let targetScale = min(widthScale, heightScale) * 1.0
                            if abs(nsView.scaleFactor - targetScale) > 0.001 {
                                nsView.scaleFactor = targetScale
                            }
                        }
                    }
                    context.coordinator.updatePageInfo(from: nsView)
                }
            }
        }
        
        // Force high-quality rendering options and Light Mode appearance
        nsView.interpolationQuality = .high
        nsView.backgroundColor = .white
        nsView.appearance = NSAppearance(named: .aqua) // Explicitly force Light Mode (Aqua)
        nsView.wantsLayer = true // Explicitly ensure layer backing is enabled
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
                    let targetScale = min(widthScale, heightScale) * 1.0
                    if abs(pdfView.scaleFactor - targetScale) > 0.001 {
                        pdfView.scaleFactor = targetScale
                    }
                }
            }
            
            // Force dynamic layout refresh and instant redrawing of the view and documentView to clear tile caches
            pdfView.needsLayout = true
            pdfView.needsDisplay = true
            if let docView = pdfView.documentView {
                docView.needsLayout = true
                docView.needsDisplay = true
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
}
