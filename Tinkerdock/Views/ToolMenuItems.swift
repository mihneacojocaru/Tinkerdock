import SwiftUI

struct ToolMenuItems: View {
    let tool: Tool
    let open: (Tool) -> Void

    @Environment(ToolStore.self) private var store
    @Environment(ThumbnailStore.self) private var thumbnails

    var body: some View {
        Button("Open") { open(tool) }
        if tool.opensInWebView {
            Button("Open in Browser") { ToolActions.openInBrowser(tool) }
        }
        if tool.fileURL != nil {
            Divider()
            Button("Show in Finder") { ToolActions.revealInFinder(tool) }
            Button(ToolActions.hasITerm ? "Open in iTerm" : "Open in Terminal") { ToolActions.openTerminal(for: tool) }
            Button("Start Claude Code Here") { ToolActions.openTerminal(for: tool, running: "claude") }
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
            store.remove([tool.id])
        }
    }
}
