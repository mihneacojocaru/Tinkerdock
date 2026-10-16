import Foundation

enum AppPaths {
    static let bundleID = "com.mihneacojocaru.tinkerdock"

    static let support: URL = directory(
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Tinkerdock", isDirectory: true)
    )
    static let tools = support.appendingPathComponent("tools.json")
    static let thumbnails = directory(support.appendingPathComponent("Thumbnails", isDirectory: true))
    static let inbox = directory(support.appendingPathComponent("Inbox", isDirectory: true))

    private static func directory(_ url: URL) -> URL {
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }
}
