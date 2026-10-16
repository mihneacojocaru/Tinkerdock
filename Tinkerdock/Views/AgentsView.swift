import SwiftUI

struct AgentsView: View {
    @Environment(HerdrMonitor.self) private var herdr

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
            ContentUnavailableView("herdr Isn't Running", systemImage: "bolt.horizontal.circle", description: Text(message))
        } else if herdr.agents.isEmpty {
            ContentUnavailableView("No Agents", systemImage: "person.2", description: Text("Agents you start in herdr show up here with their status."))
        } else {
            List(herdr.sortedAgents) { agent in
                AgentRow(agent: agent, showsWorkspace: true)
            }
        }
    }
}

struct AgentRow: View {
    let agent: HerdrAgent
    var showsWorkspace = false

    @Environment(HerdrMonitor.self) private var herdr
    @State private var output: String?

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            AgentStatusBadge(status: agent.agentStatus)
            VStack(alignment: .leading, spacing: 2) {
                Text("\(agent.kind) · \(agent.folderName)").font(.headline)
                Text(showsWorkspace ? "\(herdr.workspaceLabel(agent)) · \(agent.cwd ?? "")" : herdr.workspaceLabel(agent))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
            Spacer()
            Button("Output") {
                Task { output = await herdr.recentOutput(agent) }
            }
            Button("Focus") {
                Task { await herdr.focus(agent) }
            }
            .help("Focus this agent in your herdr window")
        }
        .padding(.vertical, 3)
        .popover(isPresented: Binding(get: { output != nil }, set: { if !$0 { output = nil } })) {
            ScrollView {
                Text(output ?? "")
                    .font(.system(.caption, design: .monospaced))
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(12)
            }
            .frame(width: 640, height: 420)
            .defaultScrollAnchor(.bottom)
        }
    }
}

struct AgentStatusBadge: View {
    let status: String

    private var color: Color {
        switch status {
        case "blocked": .orange
        case "working": .blue
        case "done": .green
        case "idle": .secondary
        default: .gray
        }
    }

    var body: some View {
        Text(status)
            .font(.caption.weight(.semibold))
            .padding(.horizontal, 7)
            .padding(.vertical, 2)
            .foregroundStyle(color)
            .background(color.opacity(0.15), in: Capsule())
    }
}
