import SwiftUI
import WebKit

class FocusableWebView: WKWebView {
    override var acceptsFirstResponder: Bool { true }
    
    override func becomeFirstResponder() -> Bool {
        print("WebView becoming first responder")
        return super.becomeFirstResponder()
    }
    
    override func mouseDown(with event: NSEvent) {
        print("WebView clicked - forcing focus")
        self.window?.makeKeyAndOrderFront(nil)
        let success = self.window?.makeFirstResponder(self) ?? false
        print("Focus success: \(success)")
        super.mouseDown(with: event)
    }
    
    // Explicitly allow key events
    override func keyDown(with event: NSEvent) {
        print("WebView key down: \(event.characters ?? "")")
        super.keyDown(with: event)
    }
}

struct WebView: NSViewRepresentable {
    let url: URL

    func makeNSView(context: Context) -> WKWebView {
        return FocusableWebView()
    }

    func updateNSView(_ nsView: WKWebView, context: Context) {
        if nsView.url == nil {
            let request = URLRequest(url: url)
            nsView.load(request)
        }
    }
}
