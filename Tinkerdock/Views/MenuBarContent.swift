import SwiftUI

struct MenuBarContent: View {
    @Environment(ToolStore.self) private var store
    @Environment(DevServerManager.self) private var devServers
    @Environment(AppRouter.self) private var router
    @Environment(\.openWindow) private var openWindow

    private var running: [Tool] {
        devServers.runningIDs.compactMap { store.tool($0) }
    }

    private var favorites: [Tool] {
        store.tools.filter(\.isFavorite).sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }

    private var recent: [Tool] {
        Array(LibraryFilter.recent.apply(to: store.tools).filter { !$0.isFavorite }.prefix(5))
    }

    var body: some View {
        if !running.isEmpty {
            Section("Running") {
                ForEach(running) { tool in
                    Menu(tool.name) {
                        Button("Open") { open(tool) }
                        Button("Stop Dev Server") { devServers.stop(tool.id) }
                    }
                }
            }
        }
        if !favorites.isEmpty {
            Section("Favorites") {
                ForEach(favorites) { tool in
                    Button(tool.name) { open(tool) }
                }
            }
        }
        if !recent.isEmpty {
            Section("Recently Opened") {
                ForEach(recent) { tool in
                    Button(tool.name) { open(tool) }
                }
            }
        }
        Divider()
        Button("Show Tinkerdock") { showLibrary() }
        SettingsLink { Text("Settings…") }
        Divider()
        Button("Quit Tinkerdock") { NSApp.terminate(nil) }
    }

    private func open(_ tool: Tool) {
        showLibrary()
        router.open(tool.id)
    }

    private func showLibrary() {
        openWindow(id: "library")
        NSApp.activate(ignoringOtherApps: true)
    }
}
