import SwiftUI

struct DiscoveredView: View {
    let onAdd: (Tool.ID) -> Void

    @Environment(DiscoveryStore.self) private var discovery
    @Environment(ToolStore.self) private var store

    var body: some View {
        if discovery.watchedFolders.isEmpty {
            ContentUnavailableView {
                Label("No Watched Folders", systemImage: "folder.badge.questionmark")
            } description: {
                Text("Choose folders where you keep your tools. New projects show up here automatically.")
            } actions: {
                SettingsLink { Text("Choose Folders…") }
            }
        } else if discovery.pending.isEmpty {
            ContentUnavailableView {
                Label("Nothing New", systemImage: "checkmark.circle")
            } description: {
                Text("Every tool in your watched folders is already in Tinkerdock or ignored.")
            } actions: {
                Button("Scan Again") { discovery.rescan() }
            }
        } else {
            List {
                Section {
                    ForEach(discovery.pending, id: \.location) { tool in
                        row(tool)
                    }
                } header: {
                    HStack {
                        Text("Found in your watched folders")
                        Spacer()
                        Button("Add All") {
                            for tool in discovery.pending { add(tool) }
                        }
                    }
                }
            }
        }
    }

    private func row(_ tool: Tool) -> some View {
        HStack(spacing: 12) {
            Image(systemName: tool.kind.symbol)
                .font(.title3)
                .frame(width: 28)
                .foregroundStyle(.secondary)
            VStack(alignment: .leading, spacing: 2) {
                Text(tool.name).font(.headline)
                Text("\(tool.kind.title) · \(tool.displayLocation)")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.head)
            }
            Spacer()
            Button("Ignore") { discovery.ignore(tool) }
            Button("Add") { add(tool) }
                .buttonStyle(.borderedProminent)
        }
        .padding(.vertical, 4)
    }

    private func add(_ tool: Tool) {
        store.add([URL(fileURLWithPath: tool.location)])
        if let added = store.tool(atLocation: tool.location) {
            onAdd(added.id)
        }
    }
}
