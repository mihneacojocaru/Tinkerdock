import SwiftUI

struct ToolListView: View {
    let tools: [Tool]
    @Binding var selection: Tool.ID?
    let open: (Tool) -> Void
    let quickLook: (Tool) -> Void

    @Environment(ToolStore.self) private var store
    @State private var sortOrder = [KeyPathComparator(\Tool.name, comparator: .localizedStandard)]

    var body: some View {
        Table(tools.sorted(using: sortOrder), selection: $selection, sortOrder: $sortOrder) {
            TableColumn("Name", value: \.name) { tool in
                Label {
                    Text(tool.name)
                } icon: {
                    Image(systemName: tool.isMissing ? "exclamationmark.triangle.fill" : tool.kind.symbol)
                        .foregroundStyle(tool.isMissing ? Color.orange : Color.secondary)
                }
            }
            TableColumn("Kind", value: \.kindTitle)
                .width(min: 80, ideal: 100)
            TableColumn("Location", value: \.displayLocation) { tool in
                Text(tool.displayLocation)
                    .foregroundStyle(.secondary)
                    .truncationMode(.head)
            }
            TableColumn("Last Opened", value: \.lastOpenedSortKey) { tool in
                Text(tool.lastOpenedAt.map { $0.formatted(.relative(presentation: .named)) } ?? "–")
            }
            .width(min: 90, ideal: 120)
            TableColumn("Added", value: \.addedAt) { tool in
                Text(tool.addedAt.formatted(date: .abbreviated, time: .omitted))
            }
            .width(min: 80, ideal: 100)
        }
        .contextMenu(forSelectionType: Tool.ID.self) { ids in
            if let tool = store.tool(ids.first) {
                ToolMenuItems(tool: tool, open: open)
            }
        } primaryAction: { ids in
            if let tool = store.tool(ids.first) { open(tool) }
        }
        .onKeyPress(.space) {
            guard let tool = store.tool(selection) else { return .ignored }
            quickLook(tool)
            return .handled
        }
    }
}
