import SwiftUI
import PDFKit

struct PDFViewWrapper: NSViewRepresentable {
    let url: URL?

    func makeNSView(context: Context) -> PDFView {
        let pdfView = PDFView()
        pdfView.autoScales = true
        if let url = url {
            pdfView.document = PDFDocument(url: url)
        }
        return pdfView
    }

    func updateNSView(_ nsView: PDFView, context: Context) {
        if let url = url, nsView.document?.documentURL != url {
            nsView.document = PDFDocument(url: url)
        }
    }
}
