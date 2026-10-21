import SwiftUI

@MainActor
final class AppServices {
    let store = ToolStore()
    let terminals = TerminalManager()
    let server = ToolServer()
    let devServers = DevServerManager()
    let router = AppRouter()
    let herdr = HerdrMonitor()
    let servers: ServerMonitor
    let thumbnails: ThumbnailStore
    let sessions: BrowserSessions
    let discovery: DiscoveryStore
    private let inbox: InboxWatcher

    init() {
        thumbnails = ThumbnailStore(server: server)
        servers = ServerMonitor(devServers: devServers)
        sessions = BrowserSessions(server: server, devServers: devServers)
        discovery = DiscoveryStore(store: store)
        inbox = InboxWatcher(store: store, router: router)
        devServers.onRunning = { [store, thumbnails] id, url in
            if let tool = store.tool(id) {
                thumbnails.captureIfMissing(tool, at: url)
            }
        }
    }
}

extension View {
    func environment(_ services: AppServices) -> some View {
        environment(services.store)
            .environment(services.terminals)
            .environment(services.server)
            .environment(services.devServers)
            .environment(services.router)
            .environment(services.thumbnails)
            .environment(services.sessions)
            .environment(services.discovery)
            .environment(services.herdr)
            .environment(services.servers)
    }
}
