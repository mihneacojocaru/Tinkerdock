import SwiftUI

/// In-window notices about agents that finished or wait for input, shown outside the Agents view.
struct AgentToasts: View {
    let showAgents: () -> Void
    @Environment(HerdrMonitor.self) private var herdr

    var body: some View {
        VStack(alignment: .trailing, spacing: 10) {
            ForEach(herdr.events.reversed()) { event in
                AgentToast(event: event, showAgents: showAgents)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .padding(16)
        .animation(.snappy, value: herdr.events)
    }
}

private struct AgentToast: View {
    let event: AgentEvent
    let showAgents: () -> Void

    @Environment(HerdrMonitor.self) private var herdr
    @State private var errorMessage: String?

    private static let lifetime: Duration = .seconds(12)

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: event.kind == .finished ? "checkmark.circle.fill" : "exclamationmark.bubble.fill")
                .font(.title2)
                .foregroundStyle(event.kind == .finished ? Color.green : Color.orange)
            VStack(alignment: .leading, spacing: 3) {
                Text(event.title).font(.headline)
                Text("\(event.agent.folderName) · Workspace \(herdr.workspaceLabel(event.agent))")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                if let errorMessage {
                    Text(errorMessage).font(.caption).foregroundStyle(.orange)
                }
                HStack(spacing: 8) {
                    Button("Show in herdr") {
                        Task {
                            errorMessage = await herdr.show(event.agent)
                            if errorMessage == nil { herdr.dismiss(event.id) }
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    Button("All Agents") {
                        showAgents()
                    }
                }
                .controlSize(.small)
                .padding(.top, 4)
            }
            Button {
                herdr.dismiss(event.id)
            } label: {
                Image(systemName: "xmark")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.secondary)
                    .frame(width: 20, height: 20)
            }
            .buttonStyle(.plain)
            .help("Dismiss")
        }
        .padding(14)
        .frame(width: 340, alignment: .leading)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(Color.primary.opacity(0.08)))
        .shadow(color: .black.opacity(0.25), radius: 12, y: 4)
        .task(id: event.id) {
            try? await Task.sleep(for: Self.lifetime)
            herdr.dismiss(event.id)
        }
    }
}
