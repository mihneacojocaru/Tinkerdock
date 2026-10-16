import SwiftUI

@main
struct TinkerdockApp: App {
    @State private var store = ToolStore()
    @State private var thumbnails = ThumbnailStore()
    @State private var terminals = TerminalManager()

    var body: some Scene {
        Window("Tinkerdock", id: "library") {
            ContentView()
                .environment(store)
                .environment(thumbnails)
                .environment(terminals)
                .frame(minWidth: 900, minHeight: 560)
        }
        .defaultSize(width: 1280, height: 800)

        WindowGroup("Tool", id: "tool", for: Tool.ID.self) { $toolID in
            ToolWindowView(toolID: toolID)
                .environment(store)
        }
        .defaultSize(width: 1200, height: 820)
    }
}
