import SwiftUI
import WebKit

struct WebView: NSViewRepresentable {
    let url: URL

    func makeNSView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        configuration.websiteDataStore = .default()

        // Inject JavaScript interceptor for notes capture
        let contentController = configuration.userContentController
        if let jsURL = Bundle.main.url(forResource: "intercept", withExtension: "js"),
           let jsSource = try? String(contentsOf: jsURL, encoding: .utf8) {
            let userScript = WKUserScript(
                source: jsSource,
                injectionTime: .atDocumentStart,
                forMainFrameOnly: false
            )
            contentController.addUserScript(userScript)
        }

        let captureService = NotesCaptureService()
        let captureHandler = NotesCaptureHandler(captureService: captureService)
        contentController.add(captureHandler, name: "notesCapture")
        context.coordinator.captureHandler = captureHandler

        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.navigationDelegate = context.coordinator
        webView.uiDelegate = context.coordinator
        webView.allowsBackForwardNavigationGestures = true

        let customUA = UserDefaults.standard.string(forKey: "customUserAgent") ?? ""
        if customUA.isEmpty {
            if let defaultUA = webView.value(forKey: "userAgent") as? String {
                webView.customUserAgent = defaultUA + " WeReadMac/1.0"
            }
        } else {
            webView.customUserAgent = customUA
        }

        webView.load(URLRequest(url: url))

        // Set window frame autosave name once the view is in the window
        DispatchQueue.main.async {
            webView.window?.setFrameAutosaveName("WeReadMainWindow")
        }

        context.coordinator.webView = webView
        context.coordinator.observeNavigationCommands()
        return webView
    }

    func updateNSView(_ nsView: WKWebView, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    static func dismantleNSView(_ nsView: WKWebView, coordinator: Coordinator) {
        nsView.configuration.userContentController.removeScriptMessageHandler(forName: "notesCapture")
        nsView.configuration.userContentController.removeAllUserScripts()
        coordinator.captureHandler = nil
    }

    class Coordinator: NSObject, WKNavigationDelegate, WKUIDelegate {
        weak var webView: WKWebView?
        var captureHandler: NotesCaptureHandler?

        // MARK: - WKNavigationDelegate

        func webView(
            _ webView: WKWebView,
            decidePolicyFor navigationAction: WKNavigationAction,
            decisionHandler: @escaping (WKNavigationActionPolicy) -> Void
        ) {
            guard let url = navigationAction.request.url else {
                decisionHandler(.allow)
                return
            }

            switch evaluateNavigationPolicy(for: url) {
            case .allow:
                decisionHandler(.allow)
            case .external:
                NSWorkspace.shared.open(url)
                decisionHandler(.cancel)
            }
        }

        func webView(
            _ webView: WKWebView,
            didFailProvisionalNavigation navigation: WKNavigation!,
            withError error: Error
        ) {
            let nsError = error as NSError
            // Ignore cancelled navigations
            if nsError.domain == NSURLErrorDomain && nsError.code == NSURLErrorCancelled {
                return
            }

            let html = """
                <html><body style="font-family: -apple-system; text-align: center; padding-top: 100px; color: #666;">
                <h2>无法连接到微信读书</h2>
                <p>\(nsError.localizedDescription)</p>
                <p><a href="https://weread.qq.com" style="color: #1890ff;">点击重试</a></p>
                </body></html>
                """
            webView.loadHTMLString(html, baseURL: nil)
        }

        // MARK: - WKUIDelegate

        func webView(
            _ webView: WKWebView,
            createWebViewWith configuration: WKWebViewConfiguration,
            for navigationAction: WKNavigationAction,
            windowFeatures: WKWindowFeatures
        ) -> WKWebView? {
            // Handle window.open() by loading in the current WebView
            if let url = navigationAction.request.url {
                webView.load(URLRequest(url: url))
            }
            return nil
        }

        func webView(
            _ webView: WKWebView,
            runJavaScriptAlertPanelWithMessage message: String,
            initiatedByFrame frame: WKFrameInfo,
            completionHandler: @escaping () -> Void
        ) {
            let alert = NSAlert()
            alert.messageText = message
            alert.addButton(withTitle: "确定")
            alert.runModal()
            completionHandler()
        }

        func webView(
            _ webView: WKWebView,
            runJavaScriptConfirmPanelWithMessage message: String,
            initiatedByFrame frame: WKFrameInfo,
            completionHandler: @escaping (Bool) -> Void
        ) {
            let alert = NSAlert()
            alert.messageText = message
            alert.addButton(withTitle: "确定")
            alert.addButton(withTitle: "取消")
            let response = alert.runModal()
            completionHandler(response == .alertFirstButtonReturn)
        }

        func webView(
            _ webView: WKWebView,
            runJavaScriptTextInputPanelWithPrompt prompt: String,
            defaultText: String?,
            initiatedByFrame frame: WKFrameInfo,
            completionHandler: @escaping (String?) -> Void
        ) {
            let alert = NSAlert()
            alert.messageText = prompt
            alert.addButton(withTitle: "确定")
            alert.addButton(withTitle: "取消")
            let textField = NSTextField(frame: NSRect(x: 0, y: 0, width: 300, height: 24))
            textField.stringValue = defaultText ?? ""
            alert.accessoryView = textField
            let response = alert.runModal()
            completionHandler(response == .alertFirstButtonReturn ? textField.stringValue : nil)
        }

        // MARK: - Navigation Commands

        func observeNavigationCommands() {
            NotificationCenter.default.addObserver(
                self, selector: #selector(reload),
                name: .webViewReload, object: nil
            )
            NotificationCenter.default.addObserver(
                self, selector: #selector(goBack),
                name: .webViewGoBack, object: nil
            )
            NotificationCenter.default.addObserver(
                self, selector: #selector(goForward),
                name: .webViewGoForward, object: nil
            )
            NotificationCenter.default.addObserver(
                self, selector: #selector(handleUserAgentChanged),
                name: .userAgentChanged, object: nil
            )
        }

        @objc func reload() {
            webView?.reload()
        }

        @objc func goBack() {
            webView?.goBack()
        }

        @objc func goForward() {
            webView?.goForward()
        }

        @objc func handleUserAgentChanged() {
            let customUA = UserDefaults.standard.string(forKey: "customUserAgent") ?? ""
            if customUA.isEmpty {
                if let defaultUA = webView?.value(forKey: "userAgent") as? String {
                    let base = defaultUA.replacingOccurrences(of: " WeReadMac/1.0", with: "")
                    webView?.customUserAgent = base + " WeReadMac/1.0"
                }
            } else {
                webView?.customUserAgent = customUA
            }
            webView?.reload()
        }
    }
}
