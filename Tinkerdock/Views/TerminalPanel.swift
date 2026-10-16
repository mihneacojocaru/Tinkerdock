import SwiftTerm
import SwiftUI

struct TerminalPanel: View {
    let tool: Tool?
    @Environment(TerminalManager.self) private var terminals

    private var usableTool: Tool? {
        guard let tool, tool.folderURL != nil, !tool.isMissing else { return nil }
        return tool
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                Image(systemName: "terminal")
                Text(usableTool?.name ?? "Terminal").font(.headline)
                if let path = usableTool?.folderURL?.path {
                    Text((path as NSString).abbreviatingWithTildeInPath)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.head)
                }
                Spacer()
                if let tool = usableTool {
                    Button("Run Claude Code") { terminals.run("claude", in: tool) }
                        .controlSize(.small)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(.bar)

            Divider()

            if let tool = usableTool {
                TerminalHost(terminal: terminals.session(for: tool))
                    .id(tool.id)
            } else {
                ContentUnavailableView("No Folder", systemImage: "terminal", description: Text("Select a tool with a local folder to open a shell there."))
            }
        }
    }
}

/// Hosts a long-lived terminal view so its shell survives switching between tools.
private struct TerminalHost: NSViewRepresentable {
    let terminal: LocalProcessTerminalView

    func makeNSView(context: Context) -> NSView {
        let container = NSView()
        attach(to: container)
        return container
    }

    func updateNSView(_ container: NSView, context: Context) {
        if terminal.superview !== container {
            attach(to: container)
        }
    }

    private func attach(to container: NSView) {
        container.subviews.forEach { $0.removeFromSuperview() }
        terminal.frame = container.bounds
        terminal.autoresizingMask = [.width, .height]
        container.addSubview(terminal)
    }
}
