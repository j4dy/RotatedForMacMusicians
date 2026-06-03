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
            NotificationCenter.default.addObserver(self, selector: #selector(handleFocusRequest), name: NSNotification.Name("FocusBrowserWebView"), object: nil)
            registered = true
        }
    }
    
    @objc func handleFocusRequest() {
        print("FocusableWebView: forcing first responder window focus")
        let success = self.window?.makeFirstResponder(self) ?? false
        print("Focus request success: \(success)")
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
    
    static func updateAdBlockerState() {
        let isEnabled = UserDefaults.standard.bool(forKey: "isAdBlockerEnabled")
        let webView = sharedWebView
        let userContentController = webView.configuration.userContentController
        
        userContentController.removeAllContentRuleLists()
        
        if isEnabled {
            // WKContentRuleListStore does not support regex disjunctions (|) in url-filter.
            // Generate one rule per domain instead.
            let adDomains = [
                "googleads", "doubleclick", "adservice", "adsystem", "adnxs", "pagead",
                "googlesyndication", "quantserve", "scorecardresearch", "taboola",
                "outbrain", "adroll", "carbonads", "adzerk", "amazon-adsystem",
                "openx", "pubmatic", "casalemedia", "rubiconproject", "adcolony",
                "chartboost", "flurry", "mopub", "unityads", "ironsrc", "admob",
                "applovin", "adserver", "adtech", "advertising", "smartadserver"
            ]
            let rules: [[String: Any]] = adDomains.map { domain in
                ["trigger": ["url-filter": ".*\(domain).*"], "action": ["type": "block"]]
            }
            guard let jsonData = try? JSONSerialization.data(withJSONObject: rules),
                  let blockRules = String(data: jsonData, encoding: .utf8) else {
                print("Ad blocker: failed to serialize rules")
                return
            }
            WKContentRuleListStore.default().compileContentRuleList(
                forIdentifier: "AdBlockerRules",
                encodedContentRuleList: blockRules
            ) { (contentRuleList, error) in
                if let error = error {
                    print("Error compiling ad blocker rules: \(error.localizedDescription)")
                    return
                }
                if let contentRuleList = contentRuleList {
                    DispatchQueue.main.async {
                        userContentController.add(contentRuleList)
                        print("Ad Blocker applied successfully (\(adDomains.count) rules).")
                    }
                }
            }
        } else {
            print("Ad Blocker rules removed.")
        }
    }
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
