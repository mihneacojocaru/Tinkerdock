import Observation

/// Web tools opened inside the main window, kept alive while switching between them.
@MainActor @Observable
final class BrowserSessions {
    private(set) var openIDs: [Tool.ID] = []
    @ObservationIgnored private var models: [Tool.ID: BrowserModel] = [:]

    func open(_ tool: Tool) {
        if !openIDs.contains(tool.id) {
            openIDs.append(tool.id)
        }
    }

    func model(for tool: Tool) -> BrowserModel {
        if let model = models[tool.id] { return model }
        let model = BrowserModel()
        if let url = tool.entryURL {
            model.load(url, readAccess: tool.folderURL)
        }
        models[tool.id] = model
        return model
    }

    func close(_ id: Tool.ID) {
        openIDs.removeAll { $0 == id }
        models[id] = nil
    }
}
