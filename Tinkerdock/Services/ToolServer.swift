import Foundation
import Observation

/// Resolves the address a tool's page is shown at, serving local pages over http://127.0.0.1.
@MainActor @Observable
final class ToolServer {
    @ObservationIgnored private var servers: [Tool.ID: StaticServer] = [:]
    @ObservationIgnored private var ports: [Tool.ID: Task<UInt16?, Never>] = [:]

    func pageURL(for tool: Tool) async -> URL? {
        switch tool.kind {
        case .url:
            return tool.remoteURL
        case .htmlFile, .staticFolder:
            guard let root = tool.folderURL, let entry = tool.entryURL, !tool.isMissing else { return nil }
            guard let port = await port(for: tool, root: root) else { return entry }
            let rootPath = root.resolvingSymlinksInPath().path
            let entryPath = entry.resolvingSymlinksInPath().path
            guard entryPath.hasPrefix(rootPath) else { return entry }
            var components = URLComponents()
            components.scheme = "http"
            components.host = "127.0.0.1"
            components.port = Int(port)
            components.path = String(entryPath.dropFirst(rootPath.count))
            return components.url ?? entry
        default:
            return nil
        }
    }

    func stop(_ id: Tool.ID) {
        servers[id]?.stop()
        servers[id] = nil
        ports[id] = nil
    }

    private func port(for tool: Tool, root: URL) async -> UInt16? {
        if let task = ports[tool.id] { return await task.value }
        let server = StaticServer(root: root)
        servers[tool.id] = server
        let preferred = Self.preferredPort(for: tool.id)
        let task = Task { await server.start(preferredPort: preferred) }
        ports[tool.id] = task
        return await task.value
    }

    private static func preferredPort(for id: UUID) -> UInt16 {
        let bytes = id.uuid
        return 49_152 + (UInt16(bytes.0) << 8 | UInt16(bytes.1)) % 16_000
    }
}
