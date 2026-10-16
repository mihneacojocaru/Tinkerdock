import Foundation

enum Installer {
    static let commandLink = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".local/bin/tinkerdock")
    static let skillFile = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".claude/skills/tinkerdock/SKILL.md")

    static var executableURL: URL? {
        Bundle.main.executableURL?.resolvingSymlinksInPath()
    }

    static var appURL: URL? {
        executableURL?.deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
    }

    static var isCommandInstalled: Bool {
        guard let target = try? FileManager.default.destinationOfSymbolicLink(atPath: commandLink.path) else { return false }
        return URL(fileURLWithPath: target).resolvingSymlinksInPath() == executableURL
    }

    static var isSkillInstalled: Bool {
        (try? String(contentsOf: skillFile, encoding: .utf8)) == skillText
    }

    static func installCommand() throws {
        guard let executableURL else { throw CocoaError(.fileNoSuchFile) }
        let fm = FileManager.default
        try fm.createDirectory(at: commandLink.deletingLastPathComponent(), withIntermediateDirectories: true)
        if (try? fm.destinationOfSymbolicLink(atPath: commandLink.path)) != nil {
            try fm.removeItem(at: commandLink)
        }
        try fm.createSymbolicLink(at: commandLink, withDestinationURL: executableURL)
    }

    static func installSkill() throws {
        try FileManager.default.createDirectory(at: skillFile.deletingLastPathComponent(), withIntermediateDirectories: true)
        try skillText.write(to: skillFile, atomically: true, encoding: .utf8)
    }

    static let skillText = """
    ---
    name: tinkerdock
    description: Register a finished tool in Tinkerdock, the user's macOS library of self-built tools. Use after building a small standalone tool for the user (HTML page, static site, Vite/Node project, script) or when the user asks to add, register or list tools in Tinkerdock.
    ---

    # Tinkerdock

    Tinkerdock is a macOS app that collects the user's self-built tools and opens them with a preview. The `tinkerdock` command registers tools with the running app.

    ## When to register

    - After you finish a standalone tool the user will open again: an HTML page, a folder with `index.html`, a Vite/Node project, a script.
    - When the user asks to add something to Tinkerdock.
    - Skip throwaway files, tests and intermediate build output.

    ## How to register

    1. For a project folder, write `tinkerdock.json` in its root so the folder describes itself:

       ```json
       {
         "name": "Car Search",
         "type": "static",
         "entry": "index.html",
         "description": "Compares used car listings by price and distance",
         "tags": ["cars", "calculator"]
       }
       ```

       `type` is one of `html`, `static`, `dev`, `url`, `script`, `app`. For `dev` add `"command": "npm run dev"`. Leave out fields Tinkerdock can detect itself.

    2. Register it:

       ```sh
       tinkerdock add <path-or-url> --name "Car Search" --description "…" --tags cars,calculator
       ```

       Add `--open` to show it in Tinkerdock right away. For a single HTML file, pass the file path and skip the manifest.

    3. Check with `tinkerdock list`.

    If `tinkerdock` is not found, tell the user to choose Tinkerdock › Settings › Integrations › Install Command Line Tool.
    """
}
