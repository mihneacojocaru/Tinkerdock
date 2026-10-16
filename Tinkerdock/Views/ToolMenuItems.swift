import SwiftUI

struct ToolMenuItems: View {
    let tool: Tool
    let open: (Tool) -> Void

    @Environment(ToolStore.self) private var store
    @Environment(ThumbnailStore.self) private var thumbnails
    @Environment(BrowserSessions.self) private var sessions
    @Environment(DevServerManager.self) private var devServers
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        Button("Open") { open(tool) }
        if tool.opensInWebView {
            Button("Open in New Window") { openWindow(id: "tool", value: tool.id) }
            Button("Open in Browser") { ToolActions.openInBrowser(tool) }
        }
        if tool.kind == .devProject {
            if devServers.isActive(tool.id) {
                Button("Stop Dev Server") { devServers.stop(tool.id) }
                Button("Restart Dev Server") { devServers.restart(tool) }
            } else {
                Button("Start Dev Server") { devServers.start(tool) }
            }
        }
        if tool.fileURL != nil {
            Divider()
            Button("Show in Finder") { ToolActions.revealInFinder(tool) }
            Button(ToolActions.hasITerm ? "Open in iTerm" : "Open in Terminal") { ToolActions.openTerminal(for: tool) }
            Button("Start Claude Code Here") { ToolActions.openTerminal(for: tool, running: "claude") }
            Button("Export as ZIP…") { ToolActions.exportZip(tool) }
        }
        Divider()
        Button(tool.isFavorite ? "Remove from Favorites" : "Add to Favorites") {
            store.update(tool.id) { $0.isFavorite.toggle() }
        }
        if tool.entryURL != nil {
            Button("Refresh Thumbnail") { thumbnails.refresh(tool) }
        }
        Divider()
        Button("Remove from Tinkerdock", role: .destructive) {
            devServers.stop(tool.id)
            sessions.close(tool.id)
            store.remove([tool.id])
        }
    }
}
