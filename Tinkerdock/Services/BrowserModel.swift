import Combine
import WebKit

@MainActor
final class BrowserModel: NSObject, ObservableObject, WKNavigationDelegate, WKUIDelegate {
    let webView: WKWebView
    @Published private(set) var pageTitle = ""
    @Published private(set) var canGoBack = false
    @Published private(set) var canGoForward = false
    @Published private(set) var isLoading = false
    @Published private(set) var errorMessage: String?
    private(set) var loadedURL: URL?
    private var setup: Task<Void, Never>?

    override init() {
        webView = WKWebView(frame: .zero, configuration: WKWebViewConfiguration())
        super.init()
        webView.isInspectable = true
        webView.navigationDelegate = self
        webView.uiDelegate = self
        setup = Task { [webView] in await ContentBlocker.install(on: webView) }
    }

    func load(_ url: URL, readAccess: URL? = nil) {
        loadedURL = url
        errorMessage = nil
        Task {
            await setup?.value
            guard loadedURL == url else { return }
            if url.isFileURL {
                webView.loadFileURL(url, allowingReadAccessTo: readAccess ?? url.deletingLastPathComponent())
            } else {
                webView.load(URLRequest(url: url))
            }
        }
    }

    func reload() {
        if webView.url != nil {
            errorMessage = nil
            webView.reload()
        } else if let loadedURL {
            load(loadedURL)
        }
    }

    func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
        isLoading = true
        sync()
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        isLoading = false
        sync()
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        fail(error)
    }

    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        fail(error)
    }

    // Links with target="_blank" would otherwise do nothing.
    func webView(_ webView: WKWebView, createWebViewWith configuration: WKWebViewConfiguration, for navigationAction: WKNavigationAction, windowFeatures: WKWindowFeatures) -> WKWebView? {
        if navigationAction.targetFrame == nil {
            webView.load(navigationAction.request)
        }
        return nil
    }

    private func fail(_ error: Error) {
        isLoading = false
        if (error as NSError).code != NSURLErrorCancelled {
            errorMessage = error.localizedDescription
        }
        sync()
    }

    private func sync() {
        pageTitle = webView.title ?? ""
        canGoBack = webView.canGoBack
        canGoForward = webView.canGoForward
    }
}
