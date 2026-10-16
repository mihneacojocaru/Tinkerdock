import Foundation

enum ToolDetector {
    private static let scriptExtensions: Set<String> = ["sh", "zsh", "command", "py", "rb", "js", "mjs"]
    private static let entryCandidates = ["index.html", "dist/index.html", "public/index.html", "build/index.html"]

    static func tool(for url: URL) -> Tool? {
        guard url.isFileURL else { return webLink(url) }

        let fm = FileManager.default
        var isDir: ObjCBool = false
        guard fm.fileExists(atPath: url.path, isDirectory: &isDir) else { return nil }

        let ext = url.pathExtension.lowercased()
        let baseName = url.deletingPathExtension().lastPathComponent

        if ext == "app" {
            return Tool(name: baseName, kind: .app, location: url.path)
        }
        if !isDir.boolValue {
            if ["html", "htm"].contains(ext) {
                return Tool(name: baseName, kind: .htmlFile, location: url.path)
            }
            if scriptExtensions.contains(ext) {
                return Tool(name: baseName, kind: .script, location: url.path)
            }
            return nil
        }

        let manifest = ToolManifest.load(from: url)
        var tool: Tool?
        if fm.fileExists(atPath: url.appendingPathComponent("package.json").path) {
            tool = Tool(name: url.lastPathComponent, kind: .devProject, location: url.path, command: "npm run dev")
        } else if let entry = entryCandidates.first(where: { fm.fileExists(atPath: url.appendingPathComponent($0).path) }) {
            tool = Tool(name: url.lastPathComponent, kind: .staticFolder, location: url.path, entry: entry)
        } else if let kind = manifest?.type {
            tool = Tool(name: url.lastPathComponent, kind: kind, location: url.path)
        }

        guard var tool else { return nil }
        manifest?.apply(to: &tool)
        return tool
    }

    static func webLink(_ url: URL) -> Tool? {
        guard let scheme = url.scheme?.lowercased(), ["http", "https"].contains(scheme) else { return nil }
        return Tool(name: url.host() ?? url.absoluteString, kind: .url, location: url.absoluteString)
    }
}
