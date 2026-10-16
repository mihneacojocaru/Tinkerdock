import Foundation

enum LibraryFilter: Hashable {
    case all
    case favorites
    case recent
    case missing
    case discovered
    case kind(ToolKind)
    case openTool(Tool.ID)

    var title: String {
        switch self {
        case .all: "All Tools"
        case .favorites: "Favorites"
        case .recent: "Recently Opened"
        case .missing: "Not Found"
        case .discovered: "Discovered"
        case .kind(let kind): kind.title
        case .openTool: "Tool"
        }
    }

    var symbol: String {
        switch self {
        case .all: "square.grid.2x2"
        case .favorites: "star"
        case .recent: "clock"
        case .missing: "exclamationmark.triangle"
        case .discovered: "sparkle.magnifyingglass"
        case .kind(let kind): kind.symbol
        case .openTool: "macwindow"
        }
    }

    func apply(to tools: [Tool]) -> [Tool] {
        switch self {
        case .all: tools
        case .favorites: tools.filter(\.isFavorite)
        case .recent:
            tools.filter { $0.lastOpenedAt != nil }
                .sorted { ($0.lastOpenedAt ?? .distantPast) > ($1.lastOpenedAt ?? .distantPast) }
        case .missing: tools.filter(\.isMissing)
        case .discovered: []
        case .kind(let kind): tools.filter { $0.kind == kind }
        case .openTool(let id): tools.filter { $0.id == id }
        }
    }
}
