import AppKit
import Observation
import SwiftTerm

/// Keeps one embedded shell per tool alive while the app runs.
@MainActor @Observable
final class TerminalManager {
    @ObservationIgnored private var sessions: [Tool.ID: LocalProcessTerminalView] = [:]

    func session(for tool: Tool) -> LocalProcessTerminalView {
        if let view = sessions[tool.id] { return view }

        let view = LocalProcessTerminalView(frame: NSRect(x: 0, y: 0, width: 800, height: 260))
        view.font = .monospacedSystemFont(ofSize: 12, weight: .regular)

        let shell = ProcessInfo.processInfo.environment["SHELL"] ?? "/bin/zsh"
        var environment = Terminal.getEnvironmentVariables(termName: "xterm-256color")
        environment.append("SHELL=\(shell)")
        view.startProcess(
            executable: shell,
            environment: environment,
            execName: "-" + (shell as NSString).lastPathComponent,
            currentDirectory: tool.folderURL?.path ?? NSHomeDirectory()
        )
        sessions[tool.id] = view
        return view
    }

    func run(_ command: String, in tool: Tool) {
        session(for: tool).send(txt: command + "\r")
    }
}
