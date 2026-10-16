import SwiftUI

@MainActor
final class AppServices {
    let store = ToolStore()
    let terminals = TerminalManager()
    let server = ToolServer()
    let devServers = DevServerManager()
    let router = AppRouter()
    let thumbnails: ThumbnailStore
    let sessions: BrowserSessions
    let discovery: DiscoveryStore
    private let inbox: InboxWatcher

    init() {
        thumbnails = ThumbnailStore(server: server)
        sessions = BrowserSessions(server: server, devServers: devServers)
        discovery = DiscoveryStore(store: store)
        inbox = InboxWatcher(store: store, router: router)
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
    }
}
