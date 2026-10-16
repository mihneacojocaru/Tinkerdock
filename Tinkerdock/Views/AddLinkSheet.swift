import SwiftUI

struct AddLinkSheet: View {
    let onAdd: (Tool.ID) -> Void

    @Environment(ToolStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var address = ""
    @State private var name = ""

    private var url: URL? {
        guard let url = URL(string: address.trimmingCharacters(in: .whitespaces)),
              ["http", "https"].contains(url.scheme?.lowercased() ?? ""),
              url.host() != nil else { return nil }
        return url
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Add Web Link").font(.headline)
            Form {
                TextField("Address", text: $address, prompt: Text("https://claude.ai/artifact/…"))
                TextField("Name", text: $name, prompt: Text("Optional"))
            }
            HStack {
                Spacer()
                Button("Cancel", role: .cancel) { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Button("Add", action: add)
                    .keyboardShortcut(.defaultAction)
                    .disabled(url == nil)
            }
        }
        .padding(20)
        .frame(width: 420)
    }

    private func add() {
        guard let url else { return }
        store.add([url])
        if let tool = store.tools.first(where: { $0.location == url.absoluteString }) {
            if !name.isEmpty { store.update(tool.id) { $0.name = name } }
            onAdd(tool.id)
        }
        dismiss()
    }
}
