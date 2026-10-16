import Foundation
import Observation

/// Web tools opened inside the main window, kept alive while switching between them.
@MainActor @Observable
final class BrowserSessions {
    private(set) var openIDs: [Tool.ID] = []
    @ObservationIgnored private var models: [Tool.ID: BrowserModel] = [:]
    @ObservationIgnored private let server: ToolServer
    @ObservationIgnored private let devServers: DevServerManager

    init(server: ToolServer, devServers: DevServerManager) {
        self.server = server
        self.devServers = devServers
    }

    func open(_ tool: Tool) {
        if !openIDs.contains(tool.id) {
            openIDs.append(tool.id)
        }
    }

    func model(for tool: Tool) -> BrowserModel {
        if let model = models[tool.id] { return model }
        let model = BrowserModel()
        models[tool.id] = model
        return model
    }

    func pageURL(for tool: Tool) async -> URL? {
        tool.kind == .devProject ? devServers.url(for: tool.id) : await server.pageURL(for: tool)
    }

    func close(_ id: Tool.ID) {
        openIDs.removeAll { $0 == id }
        models[id] = nil
    }
}
