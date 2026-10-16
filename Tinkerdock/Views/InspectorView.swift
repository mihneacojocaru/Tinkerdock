import SwiftUI

struct InspectorView: View {
    let toolID: Tool.ID?
    let open: (Tool) -> Void
    let showTerminal: () -> Void

    @Environment(ToolStore.self) private var store
    @Environment(TerminalManager.self) private var terminals
    @Environment(DevServerManager.self) private var devServers

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

            if tool.kind == .devProject && !tool.isMissing {
                DevServerSection(tool: tool)
            }

            if let folder = tool.folderURL, !tool.isMissing, tool.kind != .app {
                AgentSection(tool: tool, folder: folder)
                GitSection(folder: folder)
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
                    Button("Export as ZIP…", systemImage: "doc.zipper") { ToolActions.exportZip(tool) }
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

private struct DevServerSection: View {
    let tool: Tool
    @Environment(DevServerManager.self) private var devServers

    var body: some View {
        Section("Dev Server") {
            switch devServers.state(tool.id) {
            case .stopped:
                LabeledContent("Status", value: "Stopped")
            case .starting:
                LabeledContent("Status", value: "Starting…")
            case .running(let url):
                LabeledContent("Status") {
                    Label("Running", systemImage: "circle.fill").foregroundStyle(.green)
                }
                LabeledContent("Address") {
                    Link(url.absoluteString, destination: url)
                }
            case .failed(let message):
                LabeledContent("Status") {
                    Text(message).foregroundStyle(.orange)
                }
            }
            HStack {
                if devServers.isActive(tool.id) {
                    Button("Stop") { devServers.stop(tool.id) }
                    Button("Restart") { devServers.restart(tool) }
                } else {
                    Button("Start") { devServers.start(tool) }
                }
            }
        }
    }
}

private struct GitSection: View {
    let folder: URL
    @State private var info: GitInfo?
    @State private var loaded = false

    var body: some View {
        Group {
            if let info {
                Section("Git") {
                    LabeledContent("Branch", value: info.branch)
                    LabeledContent("Changes", value: info.changedFiles == 0 ? "Clean" : "\(info.changedFiles) uncommitted")
                    if info.ahead > 0 {
                        LabeledContent("Not Pushed", value: "\(info.ahead) commits")
                    }
                    if let lastCommit = info.lastCommit {
                        LabeledContent("Last Commit") {
                            Text(lastCommit).multilineTextAlignment(.trailing)
                        }
                    }
                }
            }
        }
        .task(id: folder) {
            info = await GitInspector.info(for: folder)
        }
    }
}

private struct AgentSection: View {
    let tool: Tool
    let folder: URL
    @Environment(HerdrMonitor.self) private var herdr
    @State private var errorMessage: String?

    var body: some View {
        if herdr.isAvailable && herdr.errorMessage == nil {
            Section("Agents") {
                ForEach(herdr.agents(in: folder)) { agent in
                    AgentRow(agent: agent)
                }
                Button("Start Claude Code in herdr", systemImage: "plus.circle") {
                    Task { errorMessage = await herdr.startClaude(in: folder, name: tool.name) }
                }
                .buttonStyle(.borderless)
                if let errorMessage {
                    Text(errorMessage).font(.caption).foregroundStyle(.red)
                }
            }
        }
    }
}
