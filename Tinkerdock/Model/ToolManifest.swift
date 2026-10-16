import Foundation

/// Optional `tinkerdock.json` inside a project folder that describes the tool.
struct ToolManifest: Codable {
    static let fileName = "tinkerdock.json"

    var name: String?
    var type: ToolKind?
    var entry: String?
    var command: String?
    var description: String?
    var tags: [String]?

    static func load(from folder: URL) -> ToolManifest? {
        let url = folder.appendingPathComponent(fileName)
        guard let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode(ToolManifest.self, from: data)
    }

    func apply(to tool: inout Tool) {
        if let name { tool.name = name }
        if let type { tool.kind = type }
        if let entry { tool.entry = entry }
        if let command { tool.command = command }
        if let description { tool.summary = description }
        if let tags { tool.tags = tags }
    }
}
