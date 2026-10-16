import SwiftUI

struct InspectorView: View {
    let toolID: Tool.ID?
    let open: (Tool) -> Void
    let showTerminal: () -> Void

    @Environment(ToolStore.self) private var store
    @Environment(TerminalManager.self) private var terminals

    var body: some View {
        if let tool = store.tool(toolID) {
            details(tool)
        } else {
            ContentUnavailableView("No Selection", systemImage: "sidebar.right", description: Text("Select a tool to see its details."))
        }
    }

    private func details(_ tool: Tool) -> some View {
        Form {
            Section {
                ToolThumbnail(tool: tool)
                TextField("Name", text: binding(tool.id, \.name, default: ""))
                if tool.isMissing {
                    Label("Nothing found at this location. It may have been moved or deleted.", systemImage: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                }
                HStack {
                    Button("Open") { open(tool) }
                        .buttonStyle(.borderedProminent)
                        .disabled(tool.isMissing)
                    Toggle(isOn: binding(tool.id, \.isFavorite, default: false)) {
                        Label("Favorite", systemImage: tool.isFavorite ? "star.fill" : "star")
                    }
                    .toggleStyle(.button)
                }
            }

            Section("Details") {
                LabeledContent("Kind", value: tool.kind.title)
                LabeledContent("Location") {
                    Text(tool.displayLocation)
                        .textSelection(.enabled)
                        .multilineTextAlignment(.trailing)
                }
                if let entry = tool.entry {
                    LabeledContent("Entry", value: entry)
                }
                if tool.kind == .devProject || tool.kind == .script {
                    TextField("Command", text: Binding(
                        get: { store.tool(tool.id)?.command ?? "" },
                        set: { value in store.update(tool.id) { $0.command = value.isEmpty ? nil : value } }
                    ), prompt: Text(tool.kind == .devProject ? "npm run dev" : "Default for file type"))
                }
                LabeledContent("Added", value: tool.addedAt.formatted(date: .abbreviated, time: .shortened))
                LabeledContent("Last Opened", value: tool.lastOpenedAt?.formatted(.relative(presentation: .named)) ?? "Never")
            }

            Section("Description") {
                TextField("Description", text: binding(tool.id, \.summary, default: ""), prompt: Text("What is this tool for?"), axis: .vertical)
                    .labelsHidden()
                    .lineLimit(2...5)
                TagsField(toolID: tool.id)
            }

            Section("Notes") {
                TextEditor(text: binding(tool.id, \.notes, default: ""))
                    .font(.body)
                    .frame(minHeight: 90)
            }

            if tool.folderURL != nil && !tool.isMissing {
                Section("Work on It") {
                    Button("Show in Finder", systemImage: "folder") { ToolActions.revealInFinder(tool) }
                    Button("Terminal Here", systemImage: "terminal") {
                        showTerminal()
                        _ = terminals.session(for: tool)
                    }
                    Button("Claude Code in Terminal Panel", systemImage: "sparkles") {
                        showTerminal()
                        terminals.run("claude", in: tool)
                    }
                    Button(ToolActions.hasITerm ? "Open in iTerm" : "Open in Terminal", systemImage: "macwindow") {
                        ToolActions.openTerminal(for: tool)
                    }
                    if tool.opensInWebView {
                        Button("Open in Browser", systemImage: "safari") { ToolActions.openInBrowser(tool) }
                    }
                }
                .buttonStyle(.borderless)
            }
        }
        .formStyle(.grouped)
    }

    private func binding<Value>(_ id: Tool.ID, _ keyPath: WritableKeyPath<Tool, Value>, default fallback: Value) -> Binding<Value> {
        Binding(
            get: { store.tool(id)?[keyPath: keyPath] ?? fallback },
            set: { value in store.update(id) { $0[keyPath: keyPath] = value } }
        )
    }
}

private struct TagsField: View {
    let toolID: Tool.ID
    @Environment(ToolStore.self) private var store
    @State private var text = ""

    var body: some View {
        TextField("Tags", text: $text, prompt: Text("Comma-separated"))
            .task(id: toolID) {
                text = store.tool(toolID)?.tags.joined(separator: ", ") ?? ""
            }
            .onChange(of: text) {
                let tags = text.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
                store.update(toolID) { $0.tags = tags }
            }
    }
}
