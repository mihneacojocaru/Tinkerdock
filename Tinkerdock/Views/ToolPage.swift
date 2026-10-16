import SwiftUI

/// Shows a tool's page, or the dev server status until the server reports its address.
struct ToolPage: View {
    let tool: Tool
    var browser: BrowserModel?
    var showsWindowButton = true

    @Environment(BrowserSessions.self) private var sessions
    @Environment(DevServerManager.self) private var devServers

    var body: some View {
        let browser = browser ?? sessions.model(for: tool)
        let devURL = devServers.url(for: tool.id)
        Group {
            if tool.kind == .devProject && devURL == nil {
                DevServerStatusView(tool: tool)
            } else {
                ToolBrowserView(tool: tool, browser: browser, showsWindowButton: showsWindowButton)
            }
        }
        .task(id: devURL) {
            guard let url = await sessions.pageURL(for: tool), browser.loadedURL != url else { return }
            browser.load(url, readAccess: tool.folderURL)
        }
    }
}

struct DevServerStatusView: View {
    let tool: Tool
    @Environment(DevServerManager.self) private var devServers

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                statusLabel
                Spacer()
                if devServers.isActive(tool.id) {
                    Button("Stop") { devServers.stop(tool.id) }
                } else {
                    Button("Start Dev Server") { devServers.start(tool) }
                        .buttonStyle(.borderedProminent)
                }
            }
            .padding(12)
            .background(.bar)
            Divider()
            ScrollViewReader { proxy in
                ScrollView {
                    Text(devServers.logs[tool.id] ?? "No output yet.")
                        .font(.system(.callout, design: .monospaced))
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(12)
                    Color.clear.frame(height: 1).id("end")
                }
                .onChange(of: devServers.logs[tool.id]) {
                    proxy.scrollTo("end", anchor: .bottom)
                }
            }
        }
    }

    @ViewBuilder
    private var statusLabel: some View {
        switch devServers.state(tool.id) {
        case .stopped:
            Label("Dev server is stopped", systemImage: "stop.circle")
        case .starting:
            HStack(spacing: 8) {
                ProgressView().controlSize(.small)
                Text("Starting \(tool.command ?? "npm run dev")… The page opens once the server prints its address.")
            }
        case .running(let url):
            Label("Running at \(url.absoluteString)", systemImage: "circle.fill").foregroundStyle(.green)
        case .failed(let message):
            Label(message, systemImage: "exclamationmark.triangle.fill").foregroundStyle(.orange)
        }
    }
}
