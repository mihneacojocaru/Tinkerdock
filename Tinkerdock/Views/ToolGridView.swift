import SwiftUI

struct ToolGridView: View {
    let tools: [Tool]
    @Binding var selection: Tool.ID?
    let open: (Tool) -> Void
    let quickLook: (Tool) -> Void

    private let columns = [GridItem(.adaptive(minimum: 170, maximum: 240), spacing: 20)]

    var body: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 24) {
                ForEach(tools) { tool in
                    ToolTile(tool: tool, isSelected: selection == tool.id)
                        .onTapGesture(count: 2) { open(tool) }
                        .simultaneousGesture(TapGesture().onEnded { selection = tool.id })
                        .contextMenu { ToolMenuItems(tool: tool, open: open) }
                }
            }
            .padding(20)
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
