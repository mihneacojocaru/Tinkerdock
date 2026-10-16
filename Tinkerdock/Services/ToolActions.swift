import AppKit
import UniformTypeIdentifiers

@MainActor
enum ToolActions {
    private static let iTermBundleID = "com.googlecode.iterm2"

    static func revealInFinder(_ tool: Tool) {
        guard let url = tool.fileURL else { return }
        NSWorkspace.shared.activateFileViewerSelecting([url])
    }

    static func openInBrowser(_ tool: Tool) {
        guard let url = tool.entryURL ?? tool.remoteURL else { return }
        NSWorkspace.shared.open(url)
    }

    static func launchApp(_ tool: Tool) {
        guard let url = tool.fileURL else { return }
        NSWorkspace.shared.openApplication(at: url, configuration: .init())
    }

    static func openTerminal(for tool: Tool, running command: String? = nil) {
        guard let folder = tool.folderURL else { return }
        var line = "cd \(shellQuoted(folder.path))"
        if let command { line += " && \(command)" }
        runInExternalTerminal(line)
    }

    static func runScript(_ tool: Tool) {
        guard let path = tool.fileURL?.path else { return }
        openTerminal(for: tool, running: tool.command ?? defaultCommand(forScript: path))
    }

    static func exportZip(_ tool: Tool) {
        guard let source = tool.fileURL else { return }
        let panel = NSSavePanel()
        panel.nameFieldStringValue = "\(tool.name).zip"
        panel.allowedContentTypes = [.zip]
        panel.message = "node_modules and .git are left out."
        guard panel.runModal() == .OK, let destination = panel.url else { return }
        try? FileManager.default.removeItem(at: destination)
        Task {
            let name = source.lastPathComponent
            let result = await Shell.run("/usr/bin/zip", ["-r", "-q", destination.path, name, "-x", "*/node_modules/*", "*/.git/*", "*.DS_Store"], in: source.deletingLastPathComponent())
            if result.status == 0 {
                NSWorkspace.shared.activateFileViewerSelecting([destination])
            } else {
                let alert = NSAlert()
                alert.messageText = "Couldn't create the ZIP file"
                alert.informativeText = result.output
                alert.runModal()
            }
        }
    }

    static var hasITerm: Bool {
        NSWorkspace.shared.urlForApplication(withBundleIdentifier: iTermBundleID) != nil
    }

    private static func defaultCommand(forScript path: String) -> String {
        let quoted = shellQuoted(path)
        switch (path as NSString).pathExtension.lowercased() {
        case "py": return "python3 \(quoted)"
        case "rb": return "ruby \(quoted)"
        case "js", "mjs": return "node \(quoted)"
        default: return "zsh \(quoted)"
        }
    }

    static func runInExternalTerminal(_ line: String) {
        let text = appleScriptQuoted(line)
        let source = hasITerm
            ? """
              tell application id "\(iTermBundleID)"
                  activate
                  set newWindow to (create window with default profile)
                  tell current session of newWindow to write text \(text)
              end tell
              """
            : """
              tell application "Terminal"
                  activate
                  do script \(text)
              end tell
              """
        var error: NSDictionary?
        NSAppleScript(source: source)?.executeAndReturnError(&error)
        if let error {
            let alert = NSAlert()
            alert.messageText = "Couldn't open the terminal"
            alert.informativeText = (error[NSAppleScript.errorMessage] as? String)
                ?? "Allow Tinkerdock to control your terminal in System Settings › Privacy & Security › Automation."
            alert.runModal()
        }
    }

    private static func shellQuoted(_ value: String) -> String {
        "'" + value.replacingOccurrences(of: "'", with: "'\\''") + "'"
    }

    private static func appleScriptQuoted(_ value: String) -> String {
        "\"" + value.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "\"", with: "\\\"") + "\""
    }
}
