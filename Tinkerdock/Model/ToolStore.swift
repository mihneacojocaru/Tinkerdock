import Foundation
import Observation

@MainActor @Observable
final class ToolStore {
    static let supportURL: URL = {
        let url = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Tinkerdock", isDirectory: true)
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }()

    var tools: [Tool] = [] {
        didSet { scheduleSave() }
    }

    @ObservationIgnored private var saveTask: Task<Void, Never>?
    private let fileURL = ToolStore.supportURL.appendingPathComponent("tools.json")

    init() {
        load()
    }

    func tool(_ id: Tool.ID?) -> Tool? {
        guard let id else { return nil }
        return tools.first { $0.id == id }
    }

    /// Registers the given files, folders or links and returns the ones that were not recognized.
    @discardableResult
    func add(_ urls: [URL]) -> [URL] {
        var rejected: [URL] = []
        for url in urls {
            let location = url.isFileURL ? url.standardizedFileURL.path : url.absoluteString
            if tools.contains(where: { $0.location == location }) { continue }
            if var tool = ToolDetector.tool(for: url) {
                tool.location = location
                tools.append(tool)
            } else {
                rejected.append(url)
            }
        }
        return rejected
    }

    func update(_ id: Tool.ID, _ change: (inout Tool) -> Void) {
        guard let index = tools.firstIndex(where: { $0.id == id }) else { return }
        change(&tools[index])
    }

    func markOpened(_ id: Tool.ID) {
        update(id) { $0.lastOpenedAt = Date() }
    }

    func remove(_ ids: Set<Tool.ID>) {
        tools.removeAll { ids.contains($0.id) }
    }

    private func load() {
        guard let data = try? Data(contentsOf: fileURL) else { return }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        tools = (try? decoder.decode([Tool].self, from: data)) ?? []
    }

    private func scheduleSave() {
        saveTask?.cancel()
        let snapshot = tools
        let url = fileURL
        saveTask = Task {
            try? await Task.sleep(for: .milliseconds(400))
            guard !Task.isCancelled else { return }
            Self.write(snapshot, to: url)
        }
    }

    nonisolated private static func write(_ tools: [Tool], to url: URL) {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        guard let data = try? encoder.encode(tools) else { return }
        try? data.write(to: url, options: .atomic)
    }
}
