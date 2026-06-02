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

class WebViewStore {
    static let sharedWebView = FocusableWebView()
    static var coordinator: WebView.Coordinator?
}

struct WebView: NSViewRepresentable {
    let url: URL
    @Binding var isLoading: Bool

    class Coordinator: NSObject {
        var parent: WebView
        var observation: NSKeyValueObservation?

        init(_ parent: WebView) {
            self.parent = parent
        }

        func observeLoading(webView: WKWebView) {
            // Remove previous observation if any
            observation?.invalidate()
            observation = webView.observe(\.isLoading, options: [.new]) { [weak self] webView, change in
                guard let self = self else { return }
                DispatchQueue.main.async {
                    self.parent.isLoading = webView.isLoading
                }
            }
        }
        
        deinit {
            observation?.invalidate()
        }
    }

    func makeCoordinator() -> Coordinator {
        let coordinator = Coordinator(self)
        WebViewStore.coordinator = coordinator
        return coordinator
    }

    func makeNSView(context: Context) -> WKWebView {
        let webView = WebViewStore.sharedWebView
        context.coordinator.observeLoading(webView: webView)
        return webView
    }

    func updateNSView(_ nsView: WKWebView, context: Context) {
        context.coordinator.parent = self
        // Re-observe since parent binding might have updated
        context.coordinator.observeLoading(webView: nsView)
        
        if nsView.url == nil {
            let request = URLRequest(url: url)
            nsView.load(request)
        }
    }
}
