import Foundation

enum ToolKind: String, Codable, CaseIterable, Identifiable {
    case htmlFile = "html"
    case staticFolder = "static"
    case devProject = "dev"
    case url
    case script
    case app

    var id: String { rawValue }

    var title: String {
        switch self {
        case .htmlFile: "HTML File"
        case .staticFolder: "Static Site"
        case .devProject: "Dev Project"
        case .url: "Web Link"
        case .script: "Script"
        case .app: "App"
        }
    }

    var symbol: String {
        switch self {
        case .htmlFile: "doc.richtext"
        case .staticFolder: "folder"
        case .devProject: "hammer"
        case .url: "link"
        case .script: "terminal"
        case .app: "app"
        }
    }
}

struct Tool: Identifiable, Codable, Hashable {
    var id = UUID()
    var name: String
    var kind: ToolKind
    /// Absolute path, or the URL string for `.url` tools.
    var location: String
    var entry: String?
    var command: String?
    var summary = ""
    var tags: [String] = []
    var notes = ""
    var isFavorite = false
    var addedAt = Date()
    var lastOpenedAt: Date?
}

extension Tool {
    var fileURL: URL? {
        kind == .url ? nil : URL(fileURLWithPath: location)
    }

    var remoteURL: URL? {
        kind == .url ? URL(string: location) : nil
    }

    var isDirectory: Bool {
        guard let fileURL, kind != .app else { return false }
        var isDir: ObjCBool = false
        return FileManager.default.fileExists(atPath: fileURL.path, isDirectory: &isDir) && isDir.boolValue
    }

    /// Folder a terminal or Finder action should use.
    var folderURL: URL? {
        guard let fileURL else { return nil }
        return isDirectory ? fileURL : fileURL.deletingLastPathComponent()
    }

    /// Page shown in the tool window and used for thumbnails.
    var entryURL: URL? {
        switch kind {
        case .url: remoteURL
        case .htmlFile: fileURL
        case .staticFolder: fileURL?.appendingPathComponent(entry ?? "index.html")
        default: nil
        }
    }

    var opensInWebView: Bool {
        [.htmlFile, .staticFolder, .url].contains(kind)
    }

    var isMissing: Bool {
        guard let fileURL else { return false }
        return !FileManager.default.fileExists(atPath: fileURL.path)
    }

    var displayLocation: String {
        kind == .url ? location : (location as NSString).abbreviatingWithTildeInPath
    }
}

extension Tool {
    var kindTitle: String { kind.title }
    var lastOpenedSortKey: Date { lastOpenedAt ?? .distantPast }

    var quickLookURL: URL? {
        kind == .url ? nil : (entryURL ?? fileURL)
    }

    func matches(_ query: String) -> Bool {
        guard !query.isEmpty else { return true }
        return [name, summary, notes, location, tags.joined(separator: " ")]
            .contains { $0.localizedCaseInsensitiveContains(query) }
    }
}
