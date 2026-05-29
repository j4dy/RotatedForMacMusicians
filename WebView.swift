import SwiftUI
import WebKit

class FocusableWebView: WKWebView {
    override var acceptsFirstResponder: Bool { true }
    
    private var registered = false
    override func viewWillMove(toWindow newWindow: NSWindow?) {
        super.viewWillMove(toWindow: newWindow)
        if newWindow != nil && !registered {
            NotificationCenter.default.addObserver(self, selector: #selector(handleScrollDown), name: NSNotification.Name("ScrollBrowserDown"), object: nil)
            NotificationCenter.default.addObserver(self, selector: #selector(handleScrollUp), name: NSNotification.Name("ScrollBrowserUp"), object: nil)
            registered = true
        }
    }
    
    @objc func handleScrollDown() {
        self.evaluateJavaScript("window.scrollBy({ top: 300, behavior: 'smooth' })", completionHandler: nil)
    }
    
    @objc func handleScrollUp() {
        self.evaluateJavaScript("window.scrollBy({ top: -300, behavior: 'smooth' })", completionHandler: nil)
    }
    
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
