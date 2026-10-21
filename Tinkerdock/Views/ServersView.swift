import SwiftUI

struct ServersView: View {
    @Environment(ServerMonitor.self) private var monitor

    @AppStorage("serversShowOther") private var showOther = false
    @AppStorage("serversShowStoppedDDEV") private var showStoppedDDEV = false

    private var devServers: [LocalServer] { monitor.servers.filter { $0.kind != .other } }
    private var otherServers: [LocalServer] { monitor.servers.filter { $0.kind == .other } }

    private var visibleDDEV: [DDEVProject] {
        (monitor.ddevProjects ?? []).filter { showStoppedDDEV || $0.isRunning }
    }

    var body: some View {
        @Bindable var monitor = monitor
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                header

                if monitor.ddevProjects != nil {
                    ServerSection(title: "DDEV", count: monitor.ddevProjects?.filter(\.isRunning).count ?? 0, color: .ddev) {
                        if monitor.ddevProjects?.contains(where: \.isRunning) == true {
                            Button("Power Off All") { monitor.stopAllDDEV() }
                                .disabled(monitor.busy.contains("ddev-all"))
                                .help("Stop all DDEV projects and the DDEV router (ddev poweroff)")
                        }
                    } content: {
                        if visibleDDEV.isEmpty {
                            EmptyCard(text: "No DDEV project is running.")
                        }
                        ForEach(visibleDDEV) { DDEVRow(project: $0, mappings: monitor.ddevPorts[$0.name] ?? []) }
                    }
                }

                ServerSection(title: "Dev Servers", count: devServers.count, color: .vite) {
                    if devServers.isEmpty {
                        EmptyCard(text: "No Vite, Node, Python or similar server is listening.")
                    }
                    ForEach(devServers) { ServerRow(server: $0) }
                }

                if !monitor.otherContainers.isEmpty {
                    ServerSection(title: "Docker", count: monitor.otherContainers.count, color: .docker) {
                        ForEach(monitor.otherContainers) { ContainerRow(container: $0) }
                    }
                }

                if showOther && !otherServers.isEmpty {
                    ServerSection(title: "Other Processes", count: otherServers.count, color: .other) {
                        ForEach(otherServers) { ServerRow(server: $0) }
                    }
                }
            }
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(.background)
        .onAppear { monitor.isVisible = true }
        .onDisappear { monitor.isVisible = false }
        .alert("Couldn't Stop the Server", isPresented: Binding(get: { monitor.errorMessage != nil }, set: { if !$0 { monitor.errorMessage = nil } })) {
            Button("OK") {}
        } message: {
            Text(monitor.errorMessage ?? "")
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Servers running on this Mac and the ports they listen on. Click a port to open it in the browser. Orange ports are reachable from your network.")
                .foregroundStyle(.secondary)
            HStack(spacing: 16) {
                Toggle("Show other processes", isOn: $showOther)
                if monitor.ddevProjects != nil {
                    Toggle("Show stopped DDEV projects", isOn: $showStoppedDDEV)
                }
                Spacer()
                Button("Refresh", systemImage: "arrow.clockwise") {
                    Task { await monitor.refresh() }
                }
            }
            .toggleStyle(.checkbox)
        }
    }
}

private extension Color {
    static let ddev = Color(red: 0x18 / 255, green: 0xC9 / 255, blue: 0xD2 / 255)
    static let vite = Color(red: 0x7B / 255, green: 0x57 / 255, blue: 0xFF / 255)
    static let node = Color(red: 0x2F / 255, green: 0xA3 / 255, blue: 0x9A / 255)
    static let python = Color(red: 0x2D / 255, green: 0x8C / 255, blue: 0xFF / 255)
    static let script = Color(red: 0x6A / 255, green: 0x5C / 255, blue: 0xFF / 255)
    static let database = Color(red: 0x00 / 255, green: 0xB8 / 255, blue: 0xFF / 255)
    static let docker = Color(red: 0x56 / 255, green: 0xB1 / 255, blue: 0xFF / 255)
    static let other = Color(red: 0x8A / 255, green: 0x8F / 255, blue: 0x98 / 255)
    static let localPort = Color(red: 0x2D / 255, green: 0x8C / 255, blue: 0xFF / 255)
    static let exposedPort = Color(red: 0xFF / 255, green: 0x8A / 255, blue: 0x2A / 255)
    static let running = Color(red: 0x2F / 255, green: 0xE6 / 255, blue: 0x7A / 255)
}

private extension LocalServer.Kind {
    var color: Color {
        switch self {
        case .vite, .next, .astro, .nuxt, .storybook, .webpack: .vite
        case .node, .bun, .deno: .node
        case .python: .python
        case .php, .ruby, .java: .script
        case .database: .database
        case .other: .other
        }
    }
}

private struct ServerSection<Actions: View, Content: View>: View {
    let title: String
    let count: Int
    let color: Color
    @ViewBuilder var actions: Actions
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Text(title).font(.title3.weight(.semibold))
                Text("\(count)")
                    .font(.caption.weight(.bold))
                    .padding(.horizontal, 7)
                    .padding(.vertical, 2)
                    .foregroundStyle(.white)
                    .background(color, in: Capsule())
                Spacer()
                actions
            }
            content
        }
    }
}

extension ServerSection where Actions == EmptyView {
    init(title: String, count: Int, color: Color, @ViewBuilder content: () -> Content) {
        self.init(title: title, count: count, color: color, actions: { EmptyView() }, content: content)
    }
}

private struct Card<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        HStack(spacing: 12) { content }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 10))
            .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(.quaternary))
    }
}

private struct EmptyCard: View {
    let text: String

    var body: some View {
        Card { Text(text).foregroundStyle(.secondary) }
    }
}

private struct ServerRow: View {
    let server: LocalServer

    @Environment(ServerMonitor.self) private var monitor
    @Environment(ToolStore.self) private var store

    private var detail: String {
        var parts = ["PID \(server.pid)"]
        if let tool = server.toolID.flatMap(store.tool) { parts.append("Started by Tinkerdock (\(tool.name))") }
        if let cwd = server.cwd { parts.append((cwd as NSString).abbreviatingWithTildeInPath) }
        return parts.joined(separator: " · ")
    }

    var body: some View {
        Card {
            KindBadge(title: server.kind == .other ? server.command : server.kind.title, symbol: server.kind.symbol, color: server.kind.color)
            VStack(alignment: .leading, spacing: 3) {
                Text(server.name).font(.body.weight(.semibold))
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
                Text(server.arguments)
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .help(server.arguments)
            }
            Spacer()
            ForEach(server.ports, id: \.self) { PortButton(number: $0.number, isExposed: $0.isExposed, url: $0.url) }
            Button("Stop") { monitor.stop(server) }
                .help(server.toolID == nil ? "Send the process a quit signal (SIGTERM)" : "Stop the dev server Tinkerdock started")
        }
        .contextMenu {
            ForEach(server.ports, id: \.self) { port in
                Button("Open localhost:\(port.number) in Browser") { NSWorkspace.shared.open(port.url) }
                Button("Copy localhost:\(port.number)") { copy(port.url.absoluteString) }
            }
            if let cwd = server.cwd {
                Divider()
                Button("Show Folder in Finder") { NSWorkspace.shared.selectFile(nil, inFileViewerRootedAtPath: cwd) }
            }
            Button("Copy Command") { copy(server.arguments) }
            Divider()
            Button("Force Quit", role: .destructive) { monitor.stop(server, force: true) }
        }
    }
}

private struct DDEVRow: View {
    let project: DDEVProject
    let mappings: [DockerContainer.Mapping]

    @Environment(ServerMonitor.self) private var monitor

    private var detail: String {
        [project.type?.uppercased(), project.approot.map { ($0 as NSString).abbreviatingWithTildeInPath }]
            .compactMap { $0 }
            .joined(separator: " · ")
    }

    var body: some View {
        Card {
            KindBadge(title: project.isRunning ? "Running" : project.status.capitalized, symbol: "shippingbox", color: project.isRunning ? .ddev : .other)
            VStack(alignment: .leading, spacing: 3) {
                Text(project.name).font(.body.weight(.semibold))
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
                if let url = project.url, project.isRunning {
                    Link(url.host() ?? url.absoluteString, destination: url).font(.caption)
                }
            }
            Spacer()
            if project.isRunning {
                ForEach(mappings, id: \.self) { mapping in
                    PortButton(number: mapping.host, isExposed: mapping.isExposed, url: URL(string: "http://localhost:\(mapping.host)")!, label: Self.label(for: mapping.container))
                }
            }
            if monitor.busy.contains(project.id) {
                ProgressView().controlSize(.small)
            }
            Button(project.isRunning ? "Stop" : "Start") { monitor.toggle(project) }
                .disabled(monitor.busy.contains(project.id))
        }
        .contextMenu {
            if let url = project.url { Button("Open \(url.host() ?? "Site")") { NSWorkspace.shared.open(url) } }
            if let mailpit = project.mailpitHttpsUrl.flatMap(URL.init(string:)) { Button("Open Mailpit") { NSWorkspace.shared.open(mailpit) } }
            if let root = project.approot {
                Divider()
                Button("Show Folder in Finder") { NSWorkspace.shared.selectFile(nil, inFileViewerRootedAtPath: root) }
            }
        }
    }

    private static func label(for containerPort: Int) -> String {
        switch containerPort {
        case 80: "HTTP"
        case 443: "HTTPS"
        case 3306, 5432: "DB"
        case 8025: "Mail"
        default: "\(containerPort)"
        }
    }
}

private struct ContainerRow: View {
    let container: DockerContainer

    @Environment(ServerMonitor.self) private var monitor

    var body: some View {
        Card {
            KindBadge(title: "Docker", symbol: "shippingbox", color: .docker)
            VStack(alignment: .leading, spacing: 3) {
                Text(container.name).font(.body.weight(.semibold))
                Text(container.image).font(.caption).foregroundStyle(.secondary).lineLimit(1)
            }
            Spacer()
            ForEach(container.mappings, id: \.self) { mapping in
                PortButton(number: mapping.host, isExposed: mapping.isExposed, url: URL(string: "http://localhost:\(mapping.host)")!, label: "→ \(mapping.container)")
            }
            if monitor.busy.contains(container.id) {
                ProgressView().controlSize(.small)
            }
            Button("Stop") { monitor.stop(container) }
                .disabled(monitor.busy.contains(container.id))
        }
    }
}

private struct PortButton: View {
    let number: Int
    let isExposed: Bool
    let url: URL
    var label: String?

    var body: some View {
        Button {
            NSWorkspace.shared.open(url)
        } label: {
            HStack(spacing: 3) {
                if isExposed { Image(systemName: "globe") }
                Text(label.map { "\($0) \(number)" } ?? ":\(number)")
            }
            .font(.system(.callout, design: .monospaced).weight(.semibold))
            .padding(.horizontal, 9)
            .padding(.vertical, 4)
            .foregroundStyle(.white)
            .background(isExposed ? Color.exposedPort : Color.localPort, in: Capsule())
        }
        .buttonStyle(.plain)
        .help(isExposed ? "Port \(number), reachable from your network. Click to open in the browser." : "Port \(number), only on this Mac. Click to open in the browser.")
    }
}

private struct KindBadge: View {
    let title: String
    let symbol: String
    let color: Color

    var body: some View {
        Label(title, systemImage: symbol)
            .font(.caption.weight(.semibold))
            .lineLimit(1)
            .frame(minWidth: 96, alignment: .leading)
            .padding(.vertical, 4)
            .padding(.horizontal, 8)
            .foregroundStyle(.white)
            .background(color, in: Capsule())
    }
}

private func copy(_ text: String) {
    NSPasteboard.general.clearContents()
    NSPasteboard.general.setString(text, forType: .string)
}
