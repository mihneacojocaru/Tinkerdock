import Foundation

@MainActor
final class InboxWatcher {
    private let store: ToolStore
    private let router: AppRouter
    private var source: DispatchSourceFileSystemObject?

    init(store: ToolStore, router: AppRouter) {
        self.store = store
        self.router = router
        let descriptor = open(AppPaths.inbox.path, O_EVTONLY)
        if descriptor >= 0 {
            let source = DispatchSource.makeFileSystemObjectSource(fileDescriptor: descriptor, eventMask: .write, queue: .main)
            source.setEventHandler { [weak self] in
                MainActor.assumeIsolated { self?.process() }
            }
            source.setCancelHandler { close(descriptor) }
            source.resume()
            self.source = source
        }
        process()
    }

    private func process() {
        let files = (try? FileManager.default.contentsOfDirectory(at: AppPaths.inbox, includingPropertiesForKeys: nil)) ?? []
        for file in files.sorted(by: { $0.lastPathComponent < $1.lastPathComponent }) where file.pathExtension == "json" {
            defer { try? FileManager.default.removeItem(at: file) }
            guard let data = try? Data(contentsOf: file),
                  let request = try? JSONDecoder().decode(InboxRequest.self, from: data),
                  let url = request.url else { continue }
            store.add([url])
            let location = url.isFileURL ? url.standardizedFileURL.path : url.absoluteString
            guard let tool = store.tool(atLocation: location) else { continue }
            store.update(tool.id) { tool in
                if let name = request.name { tool.name = name }
                if let description = request.description { tool.summary = description }
                if let tags = request.tags { tool.tags = tags }
                if let command = request.command { tool.command = command }
            }
            if request.open == true {
                router.open(tool.id)
            }
        }
    }
}
