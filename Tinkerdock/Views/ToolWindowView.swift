import SwiftUI
import WebKit

struct ToolBrowserView: View {
    let tool: Tool
    @ObservedObject var browser: BrowserModel
    var showsWindowButton = false

    @Environment(\.openWindow) private var openWindow

    var body: some View {
        WebViewHost(webView: browser.webView)
            .overlay {
                if let message = browser.errorMessage {
                    ContentUnavailableView("Couldn't Load the Page", systemImage: "exclamationmark.triangle", description: Text(message))
                        .background(.background)
                }
            }
            .toolbar {
                ToolbarItemGroup(placement: .navigation) {
                    Button { browser.webView.goBack() } label: { Label("Back", systemImage: "chevron.left") }
                        .disabled(!browser.canGoBack)
                        .keyboardShortcut("[")
                    Button { browser.webView.goForward() } label: { Label("Forward", systemImage: "chevron.right") }
                        .disabled(!browser.canGoForward)
                        .keyboardShortcut("]")
                }
                ToolbarItemGroup(placement: .primaryAction) {
                    if browser.isLoading {
                        ProgressView().controlSize(.small)
                    }
                    Button { browser.reload() } label: { Label("Reload", systemImage: "arrow.clockwise") }
                        .keyboardShortcut("r")
                    if showsWindowButton {
                        Button { openWindow(id: "tool", value: tool.id) } label: { Label("Open in New Window", systemImage: "macwindow.badge.plus") }
                    }
                    Button { ToolActions.openInBrowser(tool) } label: { Label("Open in Browser", systemImage: "safari") }
                }
            }
    }

}

struct ToolWindowView: View {
    let toolID: Tool.ID?

    @Environment(ToolStore.self) private var store
    @StateObject private var browser = BrowserModel()

    var body: some View {
        if let tool = store.tool(toolID), tool.opensInWebView || tool.kind == .devProject {
            ToolPage(tool: tool, browser: browser, showsWindowButton: false)
                .navigationTitle(tool.name)
                .navigationSubtitle(browser.pageTitle)
        } else {
            ContentUnavailableView("Tool Not Available", systemImage: "questionmark.square.dashed", description: Text("This tool was removed or can't be shown in a window."))
                .frame(minWidth: 400, minHeight: 300)
        }
    }
}

private struct WebViewHost: NSViewRepresentable {
    let webView: WKWebView

    func makeNSView(context: Context) -> WKWebView { webView }
    func updateNSView(_ nsView: WKWebView, context: Context) {}
}
