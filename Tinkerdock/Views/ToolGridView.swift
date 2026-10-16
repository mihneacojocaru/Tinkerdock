import SwiftUI

struct ToolGridView: View {
    let tools: [Tool]
    let groupByKind: Bool
    @Binding var selection: Tool.ID?
    let open: (Tool) -> Void
    let quickLook: (Tool) -> Void

    private let columns = [GridItem(.adaptive(minimum: 170, maximum: 240), spacing: 20)]

    var body: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 24, pinnedViews: [.sectionHeaders]) {
                if groupByKind {
                    ForEach(groups, id: \.title) { group in
                        Section {
                            ForEach(group.tools, content: tile)
                        } header: {
                            header(group.title, count: group.tools.count)
                        }
                    }
                } else {
                    ForEach(tools, content: tile)
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 20)
            .padding(.top, groupByKind ? 0 : 20)
        }
        .contentShape(Rectangle())
        .onTapGesture { selection = nil }
        .focusable()
        .focusEffectDisabled()
        .onKeyPress(.space) {
            guard let tool = tools.first(where: { $0.id == selection }) else { return .ignored }
            quickLook(tool)
            return .handled
        }
        .onKeyPress(.return) {
            guard let tool = tools.first(where: { $0.id == selection }) else { return .ignored }
            open(tool)
            return .handled
        }
    }
}

extension ToolGridView {
    private func tile(_ tool: Tool) -> some View {
        ToolTile(tool: tool, isSelected: selection == tool.id)
            .onTapGesture(count: 2) { open(tool) }
            .simultaneousGesture(TapGesture().onEnded { selection = tool.id })
            .contextMenu { ToolMenuItems(tool: tool, open: open) }
    }

    private var groups: [(title: String, tools: [Tool])] {
        Dictionary(grouping: tools, by: \.fileTypeDescription)
            .map { (title: $0.key, tools: $0.value) }
            .sorted { $0.title.localizedStandardCompare($1.title) == .orderedAscending }
    }

    private func header(_ title: String, count: Int) -> some View {
        HStack(spacing: 8) {
            Text(title)
                .font(.headline)
            Text("\(count)")
                .foregroundStyle(.secondary)
            Spacer()
        }
        .padding(.vertical, 10)
        .background(.background)
    }
}

private struct ToolTile: View {
    let tool: Tool
    let isSelected: Bool

    var body: some View {
        VStack(spacing: 8) {
            ToolThumbnail(tool: tool)
                .overlay {
                    RoundedRectangle(cornerRadius: 8)
                        .strokeBorder(isSelected ? Color.accentColor : Color.primary.opacity(0.12), lineWidth: isSelected ? 3 : 1)
                }
                .shadow(color: .black.opacity(0.12), radius: 3, y: 1)

            VStack(spacing: 3) {
                HStack(spacing: 4) {
                    if tool.isFavorite {
                        Image(systemName: "star.fill").font(.caption2)
                    }
                    Text(tool.name).lineLimit(1)
                }
                .font(.callout)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .foregroundStyle(isSelected ? Color.white : Color.primary)
                .background(isSelected ? Color.accentColor : Color.clear, in: RoundedRectangle(cornerRadius: 4))

                if tool.isMissing {
                    Label("Not found", systemImage: "exclamationmark.triangle.fill")
                        .font(.caption)
                        .foregroundStyle(.orange)
                } else {
                    Text(tool.kind.title)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .contentShape(Rectangle())
    }
}
