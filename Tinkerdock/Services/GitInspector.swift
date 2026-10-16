import Foundation

struct GitInfo: Equatable {
    var branch: String
    var changedFiles: Int
    var ahead: Int
    var lastCommit: String?
}

enum GitInspector {
    static func info(for folder: URL) async -> GitInfo? {
        let status = await Shell.run("/usr/bin/git", ["-C", folder.path, "status", "--porcelain=v1", "--branch"])
        guard status.status == 0 else { return nil }

        let lines = status.output.split(separator: "\n").map(String.init)
        let header = lines.first ?? ""
        var branch = header.replacingOccurrences(of: "## ", with: "")
        if let dots = branch.range(of: "...") { branch = String(branch[..<dots.lowerBound]) }
        if let space = branch.firstIndex(of: " ") { branch = String(branch[..<space]) }
        let ahead = header.range(of: #"ahead (\d+)"#, options: .regularExpression)
            .flatMap { Int(header[$0].split(separator: " ").last ?? "") } ?? 0

        let log = await Shell.run("/usr/bin/git", ["-C", folder.path, "log", "-1", "--format=%s · %cr"])
        let lastCommit = log.status == 0 ? log.output.trimmingCharacters(in: .whitespacesAndNewlines) : nil

        return GitInfo(branch: branch, changedFiles: max(0, lines.count - 1), ahead: ahead, lastCommit: lastCommit?.isEmpty == false ? lastCommit : nil)
    }
}
