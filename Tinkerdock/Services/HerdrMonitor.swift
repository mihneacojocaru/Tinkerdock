import Foundation
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
    var kind: String { agent ?? "agent" }
    var folderName: String { cwd.map { ($0 as NSString).lastPathComponent } ?? paneId }
}

/// Polls the local herdr server for coding agents and their state.
@MainActor @Observable
final class HerdrMonitor {
    private(set) var agents: [HerdrAgent] = []
    private(set) var workspaceLabels: [String: String] = [:]
    private(set) var errorMessage: String?

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

    func focus(_ agent: HerdrAgent) async {
        _ = await run(["agent", "focus", agent.terminalId])
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
        notifyNewlyBlocked(response.result.agents)
        agents = response.result.agents
    }

    private func notifyNewlyBlocked(_ agents: [HerdrAgent]) {
        for agent in agents where agent.agentStatus == "blocked" && previousStatus[agent.id] != nil && previousStatus[agent.id] != "blocked" {
            let content = UNMutableNotificationContent()
            content.title = "\(agent.kind) needs your input"
            content.body = "\(agent.folderName) · \(workspaceLabel(agent))"
            content.sound = .default
            UNUserNotificationCenter.current().add(UNNotificationRequest(identifier: agent.id, content: content, trigger: nil))
        }
        previousStatus = Dictionary(uniqueKeysWithValues: agents.map { ($0.id, $0.agentStatus) })
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
