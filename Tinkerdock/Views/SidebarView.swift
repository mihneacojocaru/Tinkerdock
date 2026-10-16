import SwiftUI

struct SidebarView: View {
    @Environment(ToolStore.self) private var store
    @Environment(BrowserSessions.self) private var sessions
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
