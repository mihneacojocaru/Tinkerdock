import SwiftUI

struct SidebarView: View {
    @Environment(ToolStore.self) private var store
    @Environment(BrowserSessions.self) private var sessions
    @Environment(DiscoveryStore.self) private var discovery
    @Environment(DevServerManager.self) private var devServers
    @Environment(HerdrMonitor.self) private var herdr
    @Environment(ServerMonitor.self) private var servers
    @Binding var selection: LibraryFilter?

    var body: some View {
        List(selection: $selection) {
            Section("Library") {
                row(.all)
                row(.favorites)
                row(.recent)
                if count(.missing) > 0 {
                    row(.missing)
                }
                Label(LibraryFilter.discovered.title, systemImage: LibraryFilter.discovered.symbol)
                    .badge(discovery.pending.count)
                    .tag(LibraryFilter.discovered)
                if herdr.isAvailable {
                    Label(LibraryFilter.agents.title, systemImage: LibraryFilter.agents.symbol)
                        .badge(herdr.blockedCount)
                        .tag(LibraryFilter.agents)
                        .help("Agents in herdr. The number counts agents waiting for you.")
                }
                Label(LibraryFilter.servers.title, systemImage: LibraryFilter.servers.symbol)
                    .badge(servers.devServerCount)
                    .tag(LibraryFilter.servers)
                    .help("Local servers and their ports. The number counts dev servers and running DDEV projects.")
            }
            if !sessions.openIDs.isEmpty {
                Section("Open") {
                    ForEach(sessions.openIDs, id: \.self) { id in
                        if let tool = store.tool(id) {
                            openRow(tool)
                        }
                    }
                }
            }
            Section("Kinds") {
                ForEach(ToolKind.allCases) { kind in
                    if count(.kind(kind)) > 0 {
                        row(.kind(kind))
                    }
                }
            }
        }
        .navigationSplitViewColumnWidth(min: 180, ideal: 210)
    }

    private func row(_ filter: LibraryFilter) -> some View {
        Label(filter.title, systemImage: filter.symbol)
            .badge(count(filter))
            .tag(filter)
    }

    private func openRow(_ tool: Tool) -> some View {
        HStack {
            Label(tool.name, systemImage: tool.kind.symbol)
            Spacer()
            if devServers.url(for: tool.id) != nil {
                Circle().fill(.green).frame(width: 7, height: 7).help("Dev server running")
            }
            Button {
                close(tool.id)
            } label: {
                Image(systemName: "xmark.circle.fill")
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
            .help("Close")
        }
        .tag(LibraryFilter.openTool(tool.id))
    }

    private func close(_ id: Tool.ID) {
        if selection == .openTool(id) { selection = .all }
        sessions.close(id)
    }

    private func count(_ filter: LibraryFilter) -> Int {
        filter.apply(to: store.tools).count
    }
}
