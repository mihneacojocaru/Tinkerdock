import SwiftUI

struct AgentsView: View {
    @Environment(HerdrMonitor.self) private var herdr

    private static let groups: [(title: String, statuses: Set<String>)] = [
        ("Needs You", ["blocked"]),
        ("Working", ["working"]),
        ("Done", ["done"]),
        ("Ready", ["idle"]),
        ("Unknown", ["unknown"]),
    ]

    var body: some View {
        if !herdr.isAvailable {
            ContentUnavailableView {
                Label("herdr Not Found", systemImage: "person.2.slash")
            } description: {
                Text("Install herdr from herdr.dev to see your coding agents here.")
            } actions: {
                Link("Open herdr.dev", destination: URL(string: "https://herdr.dev")!)
            }
        } else if let message = herdr.errorMessage {
            ContentUnavailableView {
                Label("herdr Isn't Running", systemImage: "bolt.horizontal.circle")
            } description: {
                Text(message)
            } actions: {
                OpenHerdrButton()
            }
        } else if herdr.agents.isEmpty {
            ContentUnavailableView("No Agents", systemImage: "person.2", description: Text("Start Claude Code in herdr and it shows up here with its status."))
        } else {
            List {
                Section {
                    Text("Your coding agents running in herdr. Agents that wait for you come first and send a notification. Double-click an agent to jump to it.")
                        .foregroundStyle(.secondary)
                }
                ForEach(Self.groups, id: \.title) { group in
                    let agents = herdr.sortedAgents.filter { group.statuses.contains($0.agentStatus) || (group.title == "Unknown" && !Self.known.contains($0.agentStatus)) }
                    if !agents.isEmpty {
                        Section("\(group.title) · \(agents.count)") {
                            ForEach(agents) { AgentRow(agent: $0, showsWorkspace: true) }
                        }
                    }
                }
            }
        }
    }

    private static let known: Set<String> = ["blocked", "working", "done", "idle"]
}

struct AgentRow: View {
    let agent: HerdrAgent
    var showsWorkspace = false

    @Environment(HerdrMonitor.self) private var herdr
    @State private var output: String?
    @State private var errorMessage: String?

    private var location: String {
        let path = (agent.cwd.map { ($0 as NSString).abbreviatingWithTildeInPath }) ?? ""
        return showsWorkspace ? "Workspace \(herdr.workspaceLabel(agent)) · \(path)" : "Workspace \(herdr.workspaceLabel(agent))"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .center, spacing: 10) {
                AgentStatusBadge(status: agent.agentStatus)
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(agent.kind) in \(agent.folderName)").font(.headline)
                    Text(location)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
                Spacer()
                Button("Output") {
                    Task { output = await herdr.recentOutput(agent) }
                }
                .help("Show what the agent printed last, without leaving Tinkerdock")
                Button("Show in herdr", action: show)
                    .help("Bring the herdr terminal to the front and switch to this agent")
            }
            if let errorMessage {
                HStack(spacing: 8) {
                    Label(errorMessage, systemImage: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                        .font(.callout)
                    OpenHerdrButton().controlSize(.small)
                }
            }
        }
        .padding(.vertical, 3)
        .contentShape(Rectangle())
        .onTapGesture(count: 2, perform: show)
        .popover(isPresented: Binding(get: { output != nil }, set: { if !$0 { output = nil } })) {
            VStack(alignment: .leading, spacing: 0) {
                Text("Output · \(agent.kind) in \(agent.folderName)")
                    .font(.headline)
                    .padding(12)
                Divider()
                ScrollView {
                    Text(output ?? "")
                        .font(.system(.caption, design: .monospaced))
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(12)
                }
                .defaultScrollAnchor(.bottom)
            }
            .frame(width: 640, height: 420)
        }
    }

    private func show() {
        Task { errorMessage = await herdr.show(agent) }
    }
}

private struct OpenHerdrButton: View {
    var body: some View {
        Button(ToolActions.hasITerm ? "Open herdr in iTerm" : "Open herdr in Terminal") {
            ToolActions.runInExternalTerminal("herdr")
        }
    }
}

struct AgentStatusBadge: View {
    let status: String

    private var label: String {
        switch status {
        case "blocked": "Needs you"
        case "working": "Working"
        case "done": "Done"
        case "idle": "Ready"
        default: "Unknown"
        }
    }

    private var color: Color {
        switch status {
        case "blocked": .orange
        case "working": .blue
        case "done": .green
        default: .secondary
        }
    }

    var body: some View {
        Text(label)
            .font(.caption.weight(.semibold))
            .frame(minWidth: 70)
            .padding(.vertical, 3)
            .foregroundStyle(color)
            .background(color.opacity(0.15), in: Capsule())
    }
}
