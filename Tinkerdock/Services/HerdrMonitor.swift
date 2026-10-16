import AppKit
import Observation
import UserNotifications

struct HerdrAgent: Decodable, Identifiable, Hashable {
    let agent: String?
    let agentStatus: String
    let cwd: String?
    let paneId: String
    let terminalId: String
    let workspaceId: String
    let focused: Bool

    var id: String { terminalId }
    var kind: String {
        switch agent {
        case "claude": "Claude Code"
        case let name?: name.prefix(1).uppercased() + name.dropFirst()
        case nil: "Agent"
        }
    }
    var folderName: String { cwd.map { ($0 as NSString).lastPathComponent } ?? paneId }
}

struct AgentEvent: Identifiable, Equatable {
    enum Kind {
        case finished
        case needsInput
    }

    let id = UUID()
    let agent: HerdrAgent
    let kind: Kind
    let date = Date()

    var title: String {
        kind == .finished ? "\(agent.kind) is done" : "\(agent.kind) needs you"
    }
}

/// Polls the local herdr server for coding agents and their state.
@MainActor @Observable
final class HerdrMonitor {
    private(set) var agents: [HerdrAgent] = []
    private(set) var workspaceLabels: [String: String] = [:]
    private(set) var errorMessage: String?
    private(set) var events: [AgentEvent] = []

    @ObservationIgnored let executable: String?
    @ObservationIgnored private var previousStatus: [String: String] = [:]

    private static let candidates = ["/opt/homebrew/bin/herdr", "/usr/local/bin/herdr", NSHomeDirectory() + "/.local/bin/herdr"]
    private static let statusOrder = ["blocked": 0, "working": 1, "done": 2, "idle": 3]

    init() {
        executable = Self.candidates.first { FileManager.default.isExecutableFile(atPath: $0) }
        guard executable != nil else { return }
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }
        Task {
            while !Task.isCancelled {
                await refresh()
                try? await Task.sleep(for: .seconds(3))
            }
        }
    }

    var isAvailable: Bool { executable != nil }

    var blockedCount: Int {
        agents.filter { $0.agentStatus == "blocked" }.count
    }

    var sortedAgents: [HerdrAgent] {
        agents.sorted {
            let left = Self.statusOrder[$0.agentStatus] ?? 9
            let right = Self.statusOrder[$1.agentStatus] ?? 9
            return left == right ? $0.folderName < $1.folderName : left < right
        }
    }

    func agents(in folder: URL) -> [HerdrAgent] {
        let path = folder.standardizedFileURL.path
        return sortedAgents.filter { agent in
            guard let cwd = agent.cwd else { return false }
            return cwd == path || cwd.hasPrefix(path + "/")
        }
    }

    func workspaceLabel(_ agent: HerdrAgent) -> String {
        workspaceLabels[agent.workspaceId] ?? agent.workspaceId
    }

    /// Switches herdr to the agent and brings the terminal app that shows herdr to the front.
    func show(_ agent: HerdrAgent) async -> String? {
        guard let result = await run(["agent", "focus", agent.terminalId]), result.status == 0 else {
            return "herdr couldn't switch to this agent."
        }
        guard let app = await Self.terminalAppShowingHerdr() else {
            return "herdr isn't open in a terminal window right now."
        }
        app.activate(from: .current, options: [])
        return nil
    }

    private static func terminalAppShowingHerdr() async -> NSRunningApplication? {
        let pids = await Shell.run("/usr/bin/pgrep", ["-x", "herdr"]).output.split(separator: "\n").compactMap { pid_t($0) }
        for pid in pids {
            var current = pid
            while let parent = parentPID(of: current), parent > 1 {
                if let app = NSRunningApplication(processIdentifier: parent), app.bundleURL != nil {
                    return app
                }
                current = parent
            }
        }
        return nil
    }

    nonisolated private static func parentPID(of pid: pid_t) -> pid_t? {
        var info = kinfo_proc()
        var size = MemoryLayout<kinfo_proc>.stride
        var mib: [Int32] = [CTL_KERN, KERN_PROC, KERN_PROC_PID, pid]
        guard sysctl(&mib, 4, &info, &size, nil, 0) == 0, size > 0 else { return nil }
        return info.kp_eproc.e_ppid
    }

    func recentOutput(_ agent: HerdrAgent) async -> String {
        let response: ReadResponse? = await decode(["agent", "read", agent.terminalId, "--source", "recent-unwrapped", "--lines", "80"])
        return response?.result.read.text ?? "No output available."
    }

    /// Starts Claude Code in a new herdr pane in the folder and returns an error message on failure.
    func startClaude(in folder: URL, name: String) async -> String? {
        let result = await run(["agent", "start", name, "--cwd", folder.path, "--no-focus", "--", "claude"])
        await refresh()
        return result?.status == 0 ? nil : (result?.output ?? "herdr is not installed.")
    }

    private func refresh() async {
        guard let response: AgentListResponse = await decode(["agent", "list"]) else {
            errorMessage = "herdr isn't running. Start it once with `herdr` in a terminal."
            agents = []
            return
        }
        errorMessage = nil
        if let workspaces: WorkspaceListResponse = await decode(["workspace", "list"]) {
            workspaceLabels = Dictionary(uniqueKeysWithValues: workspaces.result.workspaces.map { ($0.workspaceId, $0.label) })
        }
        recordTransitions(response.result.agents)
        agents = response.result.agents
    }

    func dismiss(_ id: AgentEvent.ID) {
        events.removeAll { $0.id == id }
    }

    func dismissAll() {
        events.removeAll()
    }

    private func recordTransitions(_ agents: [HerdrAgent]) {
        for agent in agents {
            guard let previous = previousStatus[agent.id], previous != agent.agentStatus else { continue }
            let kind: AgentEvent.Kind
            if agent.agentStatus == "blocked" {
                kind = .needsInput
            } else if previous == "working" && (agent.agentStatus == "idle" || agent.agentStatus == "done") {
                kind = .finished
            } else {
                continue
            }
            let event = AgentEvent(agent: agent, kind: kind)
            events.removeAll { $0.agent.id == agent.id }
            events.append(event)
            if events.count > 4 { events.removeFirst(events.count - 4) }
            if !NSApp.isActive { postSystemNotification(for: event) }
        }
        previousStatus = Dictionary(uniqueKeysWithValues: agents.map { ($0.id, $0.agentStatus) })
    }

    private func postSystemNotification(for event: AgentEvent) {
        let content = UNMutableNotificationContent()
        content.title = event.title
        content.body = "\(event.agent.folderName) · \(workspaceLabel(event.agent))"
        content.sound = .default
        UNUserNotificationCenter.current().add(UNNotificationRequest(identifier: event.id.uuidString, content: content, trigger: nil))
    }

    private func run(_ arguments: [String]) async -> Shell.Result? {
        guard let executable else { return nil }
        return await Shell.run(executable, arguments)
    }

    private func decode<T: Decodable>(_ arguments: [String]) async -> T? {
        guard let result = await run(arguments), result.status == 0 else { return nil }
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        return try? decoder.decode(T.self, from: Data(result.output.utf8))
    }
}

private struct AgentListResponse: Decodable {
    struct Result: Decodable { let agents: [HerdrAgent] }
    let result: Result
}

private struct WorkspaceListResponse: Decodable {
    struct Workspace: Decodable {
        let workspaceId: String
        let label: String
    }
    struct Result: Decodable { let workspaces: [Workspace] }
    let result: Result
}

private struct ReadResponse: Decodable {
    struct Read: Decodable { let text: String }
    struct Result: Decodable { let read: Read }
    let result: Result
}
