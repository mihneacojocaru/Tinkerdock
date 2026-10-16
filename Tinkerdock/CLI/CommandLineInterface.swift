import AppKit

enum CommandLineInterface {
    private static let usage = """
    Usage:
      tinkerdock add <path-or-url> [--name NAME] [--description TEXT] [--tags a,b] [--command CMD] [--open]
      tinkerdock list
      tinkerdock install-cli
      tinkerdock install-skill
      tinkerdock help
    """

    static func run(_ arguments: [String]) -> Int32 {
        var arguments = arguments
        let command = arguments.removeFirst()
        switch command {
        case "add": return add(arguments)
        case "list": return list()
        case "install-cli": return install("Command line tool", at: Installer.commandLink, using: Installer.installCommand)
        case "install-skill": return install("Claude Code skill", at: Installer.skillFile, using: Installer.installSkill)
        case "help", "--help", "-h":
            print(usage)
            return 0
        default:
            printError("Unknown command \"\(command)\".\n\n\(usage)")
            return 64
        }
    }

    private static func add(_ arguments: [String]) -> Int32 {
        var target: String?
        var request = InboxRequest(location: "")
        var index = 0
        while index < arguments.count {
            let argument = arguments[index]
            let value = index + 1 < arguments.count ? arguments[index + 1] : nil
            switch argument {
            case "--name": request.name = value; index += 1
            case "--description": request.description = value; index += 1
            case "--command": request.command = value; index += 1
            case "--tags":
                request.tags = value?.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
                index += 1
            case "--open": request.open = true
            default:
                guard target == nil, !argument.hasPrefix("--") else {
                    printError("Unexpected argument \"\(argument)\".\n\n\(usage)")
                    return 64
                }
                target = argument
            }
            index += 1
        }

        let url: URL
        if let target, let remote = URL(string: target), ["http", "https"].contains(remote.scheme?.lowercased() ?? "") {
            url = remote
        } else {
            let path = target ?? FileManager.default.currentDirectoryPath
            url = URL(fileURLWithPath: path, relativeTo: URL(fileURLWithPath: FileManager.default.currentDirectoryPath)).standardizedFileURL
        }
        guard let tool = ToolDetector.tool(for: url) else {
            printError("Tinkerdock doesn't recognize \(url.isFileURL ? url.path : url.absoluteString). Use an HTML file, a folder with index.html, package.json or tinkerdock.json, a script, an app or a web link.")
            return 65
        }
        request.location = url.isFileURL ? url.path : url.absoluteString

        do {
            let data = try JSONEncoder().encode(request)
            let file = AppPaths.inbox.appendingPathComponent("\(Date().timeIntervalSince1970)-\(UUID().uuidString).json")
            try data.write(to: file, options: .atomic)
        } catch {
            printError("Couldn't hand the tool to Tinkerdock: \(error.localizedDescription)")
            return 73
        }
        launchAppInBackground()
        print("Added \"\(request.name ?? tool.name)\" (\(tool.kind.title)) to Tinkerdock.")
        return 0
    }

    private static func list() -> Int32 {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        guard let data = try? Data(contentsOf: AppPaths.tools),
              let tools = try? decoder.decode([Tool].self, from: data), !tools.isEmpty else {
            print("No tools registered yet.")
            return 0
        }
        let width = min(40, tools.map(\.name.count).max() ?? 0)
        for tool in tools.sorted(by: { $0.name.localizedStandardCompare($1.name) == .orderedAscending }) {
            let name = tool.name.padding(toLength: width, withPad: " ", startingAt: 0)
            let kind = tool.kind.title.padding(toLength: 12, withPad: " ", startingAt: 0)
            print("\(name)  \(kind)  \(tool.displayLocation)")
        }
        return 0
    }

    private static func install(_ label: String, at location: URL, using action: () throws -> Void) -> Int32 {
        do {
            try action()
            print("\(label) installed at \((location.path as NSString).abbreviatingWithTildeInPath).")
            return 0
        } catch {
            printError("Couldn't install the \(label.lowercased()): \(error.localizedDescription)")
            return 73
        }
    }

    private static func launchAppInBackground() {
        let running = NSRunningApplication.runningApplications(withBundleIdentifier: AppPaths.bundleID)
        guard running.isEmpty, let appURL = Installer.appURL else { return }
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/open")
        process.arguments = ["-g", appURL.path]
        try? process.run()
        process.waitUntilExit()
    }

    private static func printError(_ message: String) {
        FileHandle.standardError.write(Data((message + "\n").utf8))
    }
}
