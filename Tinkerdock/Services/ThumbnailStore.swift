import AppKit
import Observation
import WebKit

@MainActor @Observable
final class ThumbnailStore {
    private(set) var images: [Tool.ID: NSImage] = [:]

    @ObservationIgnored private var requested: Set<Tool.ID> = []
    @ObservationIgnored private var renderers: [Tool.ID: SnapshotRenderer] = [:]
    @ObservationIgnored private let folder: URL = {
        let url = ToolStore.supportURL.appendingPathComponent("Thumbnails", isDirectory: true)
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }()

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

    func refresh(_ tool: Tool) {
        render(tool)
    }

    private func file(for tool: Tool) -> URL {
        folder.appendingPathComponent("\(tool.id.uuidString).png")
    }

    private func render(_ tool: Tool) {
        guard let url = tool.entryURL, !tool.isMissing, renderers[tool.id] == nil else { return }
        let target = file(for: tool)
        let renderer = SnapshotRenderer()
        renderers[tool.id] = renderer
        renderer.capture(url: url, readAccess: tool.folderURL) { [weak self] image in
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

    func capture(url: URL, readAccess: URL?, completion: @escaping (NSImage?) -> Void) {
        self.completion = completion
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
            try? await Task.sleep(for: .milliseconds(1200))
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
