import SwiftUI

struct SidebarView: View {
    @Environment(ToolStore.self) private var store
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

    private func count(_ filter: LibraryFilter) -> Int {
        filter.apply(to: store.tools).count
    }
}
