import AppKit
import Observation

struct ListeningPort: Hashable, Comparable {
    let number: Int
    let isExposed: Bool

    var url: URL { URL(string: "http://localhost:\(number)")! }

    static func < (lhs: ListeningPort, rhs: ListeningPort) -> Bool { lhs.number < rhs.number }
}

struct LocalServer: Identifiable, Hashable {
    enum Kind: String {
        case vite, next, astro, nuxt, storybook, webpack, node, bun, deno, python, php, ruby, java, database, other

        var title: String {
            switch self {
            case .vite: "Vite"
            case .next: "Next.js"
            case .astro: "Astro"
            case .nuxt: "Nuxt"
            case .storybook: "Storybook"
            case .webpack: "webpack"
            case .node: "Node"
            case .bun: "Bun"
            case .deno: "Deno"
            case .python: "Python"
            case .php: "PHP"
            case .ruby: "Ruby"
            case .java: "Java"
            case .database: "Database"
            case .other: "Other"
            }
        }

        var symbol: String {
            switch self {
            case .vite, .next, .astro, .nuxt, .storybook, .webpack: "bolt.horizontal"
            case .node, .bun, .deno: "hexagon"
            case .python: "chevron.left.forwardslash.chevron.right"
            case .php, .ruby, .java: "curlybraces"
            case .database: "cylinder"
            case .other: "gearshape"
            }
        }
    }

    let pid: pid_t
    let command: String
    let arguments: String
    let cwd: String?
    let ports: [ListeningPort]
    let kind: Kind
    let toolID: Tool.ID?

    var id: pid_t { pid }

    var name: String {
        guard let cwd, cwd != "/", cwd != NSHomeDirectory() else { return command }
        return (cwd as NSString).lastPathComponent
    }

    static func kind(command: String, arguments: String) -> Kind {
        let command = command.lowercased()
        let arguments = arguments.lowercased()
        if arguments.contains("vite") { return .vite }
        if arguments.contains("next dev") || arguments.contains("next-server") || arguments.contains("/next/") { return .next }
        if arguments.contains("astro") { return .astro }
        if arguments.contains("nuxt") { return .nuxt }
        if arguments.contains("storybook") { return .storybook }
        if arguments.contains("webpack") { return .webpack }
        if command.hasPrefix("node") { return .node }
        if command.hasPrefix("bun") { return .bun }
        if command.hasPrefix("deno") { return .deno }
        if command.hasPrefix("python") || ["uvicorn", "gunicorn", "flask"].contains(command) { return .python }
        if command.hasPrefix("php") { return .php }
        if command.hasPrefix("ruby") || ["puma", "rails"].contains(command) { return .ruby }
        if command.hasPrefix("java") { return .java }
        if ["postgres", "mysqld", "mariadbd", "redis-server", "mongod"].contains(command) { return .database }
        return .other
    }
}

struct DDEVProject: Decodable, Identifiable, Hashable {
    let name: String
    let status: String
    let type: String?
    let approot: String?
    let primaryUrl: String?
    let mailpitHttpsUrl: String?

    var id: String { name }
    var isRunning: Bool { status == "running" }
    var url: URL? { primaryUrl.flatMap(URL.init(string:)) }
}

struct DockerContainer: Identifiable, Hashable {
    struct Mapping: Hashable {
        let host: Int
        let container: Int
        let isExposed: Bool
    }

    let name: String
    let image: String
    let mappings: [Mapping]

    var id: String { name }

    static func mappings(in ports: String) -> [Mapping] {
        var seen: Set<Int> = []
        return ports.split(separator: ",").compactMap { entry in
            let parts = entry.trimmingCharacters(in: .whitespaces).components(separatedBy: "->")
            guard parts.count == 2,
                  let colon = parts[0].lastIndex(of: ":"),
                  let host = Int(parts[0][parts[0].index(after: colon)...].prefix { $0.isNumber }),
                  let container = Int(parts[1].prefix { $0.isNumber }),
                  seen.insert(host).inserted
            else { return nil }
            let address = parts[0][..<colon]
            return Mapping(host: host, container: container, isExposed: address == "0.0.0.0" || address == "[::]")
        }
    }
}

/// Lists local servers: processes listening on TCP ports, DDEV projects and Docker containers.
@MainActor @Observable
final class ServerMonitor {
    private(set) var servers: [LocalServer] = []
    private(set) var ddevProjects: [DDEVProject]?
    private(set) var containers: [DockerContainer] = []
    private(set) var busy: Set<String> = []
    var errorMessage: String?

    var isVisible = false {
        didSet { if isVisible && !oldValue { Task { await refresh() } } }
    }

    @ObservationIgnored private let devServers: DevServerManager
    @ObservationIgnored private var isRefreshing = false

    private static let toolEnvironment: [String: String] = {
        var environment = ProcessInfo.processInfo.environment
        let extra = ["/opt/homebrew/bin", "/usr/local/bin", NSHomeDirectory() + "/.orbstack/bin", "/Applications/Docker.app/Contents/Resources/bin"]
        environment["PATH"] = (extra + [environment["PATH"] ?? "/usr/bin:/bin"]).joined(separator: ":")
        return environment
    }()

    init(devServers: DevServerManager) {
        self.devServers = devServers
        Task {
            while !Task.isCancelled {
                await refresh()
                try? await Task.sleep(for: .seconds(isVisible ? 3 : 15))
            }
        }
    }

    var devServerCount: Int {
        servers.filter { $0.kind != .other }.count + (ddevProjects?.filter(\.isRunning).count ?? 0)
    }

    var ddevPorts: [String: [DockerContainer.Mapping]] {
        var result: [String: [DockerContainer.Mapping]] = [:]
        for container in containers where container.name.hasPrefix("ddev-") {
            for project in ddevProjects ?? [] where container.name.hasPrefix("ddev-\(project.name)-") {
                result[project.name, default: []] += container.mappings
            }
        }
        return result
    }

    var otherContainers: [DockerContainer] {
        containers.filter { !$0.name.hasPrefix("ddev-") && !$0.mappings.isEmpty }
    }

    func refresh() async {
        guard !isRefreshing else { return }
        isRefreshing = true
        defer { isRefreshing = false }
        servers = await Self.listeningServers(managed: devServers.processIDs)
        guard isVisible || ddevProjects == nil else { return }
        containers = await Self.dockerContainers()
        ddevProjects = await Self.ddevProjects()
    }

    func stop(_ server: LocalServer, force: Bool = false) {
        if let id = server.toolID, !force {
            devServers.stop(id)
        } else if kill(server.pid, force ? SIGKILL : SIGTERM) != 0 {
            errorMessage = "Tinkerdock couldn't stop \(server.command) (PID \(server.pid))."
        }
        Task {
            try? await Task.sleep(for: .milliseconds(600))
            await refresh()
        }
    }

    func stop(_ container: DockerContainer) {
        perform(container.id, "docker", ["stop", container.name])
    }

    func toggle(_ project: DDEVProject) {
        perform(project.id, "ddev", [project.isRunning ? "stop" : "start", project.name])
    }

    func stopAllDDEV() {
        perform("ddev-all", "ddev", ["poweroff"])
    }

    private func perform(_ key: String, _ tool: String, _ arguments: [String]) {
        guard !busy.contains(key) else { return }
        busy.insert(key)
        Task {
            let result = await Shell.run("/usr/bin/env", [tool] + arguments, environment: Self.toolEnvironment)
            busy.remove(key)
            if result.status != 0 {
                errorMessage = result.output.split(separator: "\n").suffix(3).joined(separator: "\n")
            }
            containers = await Self.dockerContainers()
            ddevProjects = await Self.ddevProjects()
        }
    }

    private static func listeningServers(managed: [Tool.ID: pid_t]) async -> [LocalServer] {
        let own = ProcessInfo.processInfo.processIdentifier
        var commands: [pid_t: String] = [:]
        var ports: [pid_t: Set<ListeningPort>] = [:]
        var current: pid_t?
        for line in await Shell.run("/usr/sbin/lsof", ["-nP", "+c", "0", "-iTCP", "-sTCP:LISTEN", "-F", "pcn"]).output.split(separator: "\n") {
            let value = String(line.dropFirst())
            switch line.first {
            case "p": current = pid_t(value)
            case "c": if let current { commands[current] = value }
            case "n":
                guard let current, let colon = value.lastIndex(of: ":"), let number = Int(value[value.index(after: colon)...]) else { continue }
                let host = value[..<colon]
                ports[current, default: []].insert(ListeningPort(number: number, isExposed: host == "*" || host == "0.0.0.0" || host == "[::]"))
            default: break
            }
        }
        let pids = ports.keys.filter { $0 != own && commands[$0] != "com.docker.backend" }
        guard !pids.isEmpty else { return [] }

        var parents: [pid_t: pid_t] = [:]
        var arguments: [pid_t: String] = [:]
        for line in await Shell.run("/bin/ps", ["-axo", "pid=,ppid=,args="]).output.split(separator: "\n") {
            let fields = line.split(separator: " ", maxSplits: 2, omittingEmptySubsequences: true)
            guard fields.count >= 2, let pid = pid_t(fields[0]), let parent = pid_t(fields[1]) else { continue }
            parents[pid] = parent
            if fields.count == 3 { arguments[pid] = String(fields[2]) }
        }

        var directories: [pid_t: String] = [:]
        current = nil
        let list = pids.map(String.init).joined(separator: ",")
        for line in await Shell.run("/usr/sbin/lsof", ["-a", "-d", "cwd", "-p", list, "-F", "pn"]).output.split(separator: "\n") {
            let value = String(line.dropFirst())
            if line.first == "p" { current = pid_t(value) }
            if line.first == "n", let current { directories[current] = value }
        }

        let owners = Dictionary(managed.map { ($1, $0) }, uniquingKeysWith: { first, _ in first })
        return pids.map { pid in
            let command = commands[pid] ?? "PID \(pid)"
            let args = arguments[pid] ?? command
            var ancestor: pid_t? = pid
            var toolID: Tool.ID?
            while let candidate = ancestor, candidate > 1, toolID == nil {
                toolID = owners[candidate]
                ancestor = parents[candidate]
            }
            return LocalServer(
                pid: pid,
                command: command,
                arguments: args,
                cwd: directories[pid],
                ports: ports[pid, default: []].sorted(),
                kind: LocalServer.kind(command: command, arguments: args),
                toolID: toolID
            )
        }
        .sorted { ($0.ports.first?.number ?? 0) < ($1.ports.first?.number ?? 0) }
    }

    private static func dockerContainers() async -> [DockerContainer] {
        let result = await Shell.run("/usr/bin/env", ["docker", "ps", "--format", "{{.Names}}\t{{.Image}}\t{{.Ports}}"], environment: toolEnvironment)
        guard result.status == 0 else { return [] }
        return result.output.split(separator: "\n").compactMap { line in
            let fields = line.split(separator: "\t", omittingEmptySubsequences: false).map(String.init)
            guard fields.count == 3 else { return nil }
            return DockerContainer(name: fields[0], image: fields[1], mappings: DockerContainer.mappings(in: fields[2]))
        }
        .sorted { $0.name < $1.name }
    }

    private struct DDEVList: Decodable {
        let raw: [DDEVProject]
    }

    private static func ddevProjects() async -> [DDEVProject]? {
        let result = await Shell.run("/usr/bin/env", ["ddev", "list", "--json-output"], environment: toolEnvironment)
        guard result.status == 0 else { return nil }
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        // ddev prints one JSON object per line, the list is the one with "raw".
        for line in result.output.split(separator: "\n").reversed() {
            if let list = try? decoder.decode(DDEVList.self, from: Data(line.utf8)) {
                return list.raw.sorted { $0.isRunning == $1.isRunning ? $0.name < $1.name : $0.isRunning }
            }
        }
        return []
    }
}
