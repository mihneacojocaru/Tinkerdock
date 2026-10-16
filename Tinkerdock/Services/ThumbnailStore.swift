import AppKit
import Observation
import WebKit

@MainActor @Observable
final class ThumbnailStore {
    private(set) var images: [Tool.ID: NSImage] = [:]

    @ObservationIgnored private var requested: Set<Tool.ID> = []
    @ObservationIgnored private var renderers: [Tool.ID: SnapshotRenderer] = [:]
    @ObservationIgnored private let folder = AppPaths.thumbnails
    @ObservationIgnored private let server: ToolServer

    init(server: ToolServer) {
        self.server = server
    }

    func ensure(_ tool: Tool) {
        guard !requested.contains(tool.id) else { return }
        requested.insert(tool.id)

        if tool.kind == .app, let path = tool.fileURL?.path, !tool.isMissing {
            images[tool.id] = NSWorkspace.shared.icon(forFile: path)
        } else if let image = NSImage(contentsOf: file(for: tool)) {
            images[tool.id] = image
        } else {
            render(tool)
        }
    }

    /// Captures a dev project once its server runs, unless it already has a preview.
    func captureIfMissing(_ tool: Tool, at url: URL) {
        guard images[tool.id] == nil, renderers[tool.id] == nil,
              !FileManager.default.fileExists(atPath: file(for: tool).path) else { return }
        let renderer = SnapshotRenderer()
        renderers[tool.id] = renderer
        capture(tool, url: url, with: renderer, to: file(for: tool), settle: .seconds(3))
    }

    /// Drops the stored preview; pages render a new one now, dev projects on their next server start.
    func reset(_ tool: Tool, devServerURL: URL?) {
        images[tool.id] = nil
        try? FileManager.default.removeItem(at: file(for: tool))
        if let devServerURL {
            captureIfMissing(tool, at: devServerURL)
        } else {
            render(tool)
        }
    }

    private func file(for tool: Tool) -> URL {
        folder.appendingPathComponent("\(tool.id.uuidString).png")
    }

    private func render(_ tool: Tool) {
        guard tool.entryURL != nil, !tool.isMissing, renderers[tool.id] == nil else { return }
        let target = file(for: tool)
        let renderer = SnapshotRenderer()
        renderers[tool.id] = renderer
        Task {
            guard let url = await server.pageURL(for: tool) else {
                renderers[tool.id] = nil
                return
            }
            capture(tool, url: url, with: renderer, to: target)
        }
    }

    private func capture(_ tool: Tool, url: URL, with renderer: SnapshotRenderer, to target: URL, settle: Duration = .milliseconds(1200)) {
        renderer.capture(url: url, readAccess: tool.folderURL, settle: settle) { [weak self] image in
            guard let self else { return }
            renderers[tool.id] = nil
            guard let image else { return }
            images[tool.id] = image
            if let tiff = image.tiffRepresentation,
               let png = NSBitmapImageRep(data: tiff)?.representation(using: .png, properties: [:]) {
                try? png.write(to: target, options: .atomic)
            }
        }
    }
}

/// Loads a page in an invisible window and takes one snapshot of it.
@MainActor
private final class SnapshotRenderer: NSObject, WKNavigationDelegate {
    private let window: NSWindow
    private let webView: WKWebView
    private var completion: ((NSImage?) -> Void)?
    private var settle: Duration = .milliseconds(1200)

    override init() {
        let frame = NSRect(x: 0, y: 0, width: 1280, height: 960)
        webView = WKWebView(frame: frame)
        // WebKit only paints views that live in a window, so the renderer keeps an off-screen one.
        window = NSWindow(contentRect: frame.offsetBy(dx: -20000, dy: -20000), styleMask: .borderless, backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        window.ignoresMouseEvents = true
        window.contentView = webView
        super.init()
        webView.navigationDelegate = self
    }

    func capture(url: URL, readAccess: URL?, settle: Duration, completion: @escaping (NSImage?) -> Void) {
        self.completion = completion
        self.settle = settle
        window.orderBack(nil)
        if url.isFileURL {
            webView.loadFileURL(url, allowingReadAccessTo: readAccess ?? url.deletingLastPathComponent())
        } else {
            webView.load(URLRequest(url: url))
        }
        Task {
            try? await Task.sleep(for: .seconds(20))
            finish(nil)
        }
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        Task {
            try? await Task.sleep(for: settle)
            let config = WKSnapshotConfiguration()
            config.snapshotWidth = 640
            webView.takeSnapshot(with: config) { [weak self] image, _ in
                self?.finish(image)
            }
        }
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        finish(nil)
    }

    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        finish(nil)
    }

    private func finish(_ image: NSImage?) {
        guard let completion else { return }
        self.completion = nil
        window.orderOut(nil)
        completion(image)
    }
}
