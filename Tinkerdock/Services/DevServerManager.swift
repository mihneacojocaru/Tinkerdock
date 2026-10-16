import AppKit
import Observation

/// Starts dev commands like `npm run dev` and watches their output for the local address.
@MainActor @Observable
final class DevServerManager {
    enum State: Equatable {
        case stopped
        case starting
        case running(URL)
        case failed(String)
    }

    private(set) var states: [Tool.ID: State] = [:]
    private(set) var logs: [Tool.ID: String] = [:]

    @ObservationIgnored private var processes: [Tool.ID: Process] = [:]
    @ObservationIgnored private var stopping: Set<Tool.ID> = []

    init() {
        NotificationCenter.default.addObserver(forName: NSApplication.willTerminateNotification, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.stopAll() }
        }
    }

    var runningIDs: [Tool.ID] {
        states.compactMap { id, state in
            if case .running = state { return id }
            return nil
        }
    }

    func state(_ id: Tool.ID) -> State {
        states[id] ?? .stopped
    }

    func url(for id: Tool.ID) -> URL? {
        if case .running(let url) = state(id) { return url }
        return nil
    }

    func isActive(_ id: Tool.ID) -> Bool {
        processes[id] != nil
    }

    func start(_ tool: Tool) {
        guard processes[tool.id] == nil, let folder = tool.folderURL else { return }
        let command = tool.command ?? "npm run dev"
        let id = tool.id

        let process = Process()
        process.executableURL = URL(fileURLWithPath: ProcessInfo.processInfo.environment["SHELL"] ?? "/bin/zsh")
        process.arguments = ["-l", "-c", command]
        process.currentDirectoryURL = folder
        var environment = ProcessInfo.processInfo.environment
        environment["BROWSER"] = "none"
        environment["FORCE_COLOR"] = "0"
        environment["NO_COLOR"] = "1"
        process.environment = environment

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe
        process.standardInput = FileHandle.nullDevice
        pipe.fileHandleForReading.readabilityHandler = { [weak self] handle in
            let data = handle.availableData
            guard !data.isEmpty else {
                handle.readabilityHandler = nil
                return
            }
            let text = String(decoding: data, as: UTF8.self)
            Task { @MainActor in self?.append(text, to: id) }
        }
        process.terminationHandler = { [weak self] process in
            let status = process.terminationStatus
            Task { @MainActor in self?.didTerminate(id, status: status) }
        }

        logs[id] = "$ \(command)\n"
        do {
            try process.run()
            processes[id] = process
            states[id] = .starting
        } catch {
            states[id] = .failed(error.localizedDescription)
        }
    }

    func stop(_ id: Tool.ID) {
        guard let process = processes[id] else { return }
        stopping.insert(id)
        Self.terminateTree(process.processIdentifier)
    }

    func restart(_ tool: Tool) {
        guard let process = processes[tool.id] else { return start(tool) }
        stop(tool.id)
        Task {
            while process.isRunning { try? await Task.sleep(for: .milliseconds(100)) }
            start(tool)
        }
    }

    func stopAll() {
        for process in processes.values {
            Self.terminateTree(process.processIdentifier)
        }
    }

    private func append(_ text: String, to id: Tool.ID) {
        let clean = text.replacingOccurrences(of: #"\u001B\[[0-9;?]*[ -/]*[@-~]"#, with: "", options: .regularExpression)
        var log = (logs[id] ?? "") + clean
        if log.count > 100_000 { log = String(log.suffix(80_000)) }
        logs[id] = log
        if state(id) == .starting, let url = Self.localURL(in: clean) {
            states[id] = .running(url)
        }
    }

    private func didTerminate(_ id: Tool.ID, status: Int32) {
        processes[id] = nil
        if stopping.remove(id) != nil || status == 0 {
            states[id] = .stopped
        } else {
            states[id] = .failed("The command exited with status \(status).")
        }
        logs[id, default: ""] += "\n[exited with status \(status)]\n"
    }

    nonisolated static func localURL(in text: String) -> URL? {
        let pattern = #"https?://(localhost|127\.0\.0\.1|0\.0\.0\.0|\[::1\]):\d+[^\s'"]*"#
        guard let range = text.range(of: pattern, options: .regularExpression) else { return nil }
        let address = String(text[range]).replacingOccurrences(of: "0.0.0.0", with: "localhost")
        return URL(string: address)
    }

    // npm and friends spawn children that ignore the parent's signal, so stop the whole tree.
    nonisolated private static func terminateTree(_ pid: pid_t) {
        for child in children(of: pid) {
            terminateTree(child)
        }
        kill(pid, SIGTERM)
    }

    nonisolated private static func children(of pid: pid_t) -> [pid_t] {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/pgrep")
        process.arguments = ["-P", String(pid)]
        let pipe = Pipe()
        process.standardOutput = pipe
        guard (try? process.run()) != nil else { return [] }
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        return String(decoding: data, as: UTF8.self).split(separator: "\n").compactMap { pid_t($0) }
    }
}
