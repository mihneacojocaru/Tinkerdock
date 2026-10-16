import QuickLook
import SwiftUI

enum LibraryViewMode: String {
    case grid, list
}

struct ContentView: View {
    @Environment(ToolStore.self) private var store
    @Environment(TerminalManager.self) private var terminals
    @Environment(BrowserSessions.self) private var sessions

    @State private var filter: LibraryFilter? = .all
    @State private var selection: Tool.ID?
    @State private var search = ""
    @State private var quickLookURL: URL?
    @State private var isAddingLink = false
    @State private var isDropTargeted = false
    @State private var rejected: [URL] = []

    @AppStorage("viewMode") private var viewMode: LibraryViewMode = .grid
    @AppStorage("showInspector") private var showInspector = true
    @AppStorage("showTerminal") private var showTerminal = false

    private var openedTool: Tool? {
        guard case .openTool(let id) = filter, let tool = store.tool(id), tool.entryURL != nil else { return nil }
        return tool
    }

    private var visibleTools: [Tool] {
        let filtered = (filter ?? .all).apply(to: store.tools).filter { $0.matches(search) }
        if filter == .recent { return filtered }
        return filtered.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }

    var body: some View {
        NavigationSplitView {
            SidebarView(selection: $filter)
        } detail: {
            detail
        }
        .navigationTitle(openedTool?.name ?? (filter ?? .all).title)
        .navigationSubtitle(subtitle)
        .onChange(of: filter) {
            if case .openTool(let id) = filter { selection = id }
        }
        .searchable(text: $search, placement: .toolbar, prompt: "Search tools")
        .toolbar { toolbar }
        .quickLookPreview($quickLookURL)
        .sheet(isPresented: $isAddingLink) {
            AddLinkSheet { selection = $0 }
        }
        .alert("Some items weren't added", isPresented: showsRejected) {
            Button("OK") {}
        } message: {
            Text(rejectedMessage)
        }
    }

    private var detail: some View {
        VSplitView {
            mainPane
                .frame(minHeight: 220, maxHeight: .infinity)
            if showTerminal {
                TerminalPanel(tool: store.tool(selection))
                    .frame(minHeight: 140, idealHeight: 280)
            }
        }
        .inspector(isPresented: $showInspector) {
            InspectorView(toolID: selection, open: open, showTerminal: { showTerminal = true })
                .inspectorColumnWidth(min: 260, ideal: 300, max: 420)
        }
    }

    @ViewBuilder
    private var mainPane: some View {
        if let tool = openedTool {
            ToolBrowserView(tool: tool, browser: sessions.model(for: tool), showsWindowButton: true)
                .id(tool.id)
        } else {
            library
        }
    }

    private var subtitle: String {
        if let tool = openedTool { return tool.displayLocation }
        let count = visibleTools.count
        return count == 1 ? "1 tool" : "\(count) tools"
    }

    private var showsRejected: Binding<Bool> {
        Binding(get: { !rejected.isEmpty }, set: { if !$0 { rejected = [] } })
    }

    private var rejectedMessage: String {
        let names = rejected.map(\.lastPathComponent).joined(separator: ", ")
        return "Tinkerdock recognizes HTML files, folders with an index.html, package.json or tinkerdock.json, scripts, apps and web links.\n\n\(names)"
    }

    @ViewBuilder
    private var library: some View {
        Group {
            if store.tools.isEmpty {
                emptyLibrary
            } else if visibleTools.isEmpty {
                ContentUnavailableView.search(text: search)
            } else if viewMode == .grid {
                ToolGridView(tools: visibleTools, selection: $selection, open: open, quickLook: quickLook)
            } else {
                ToolListView(tools: visibleTools, selection: $selection, open: open, quickLook: quickLook)
            }
        }
        .overlay {
            if isDropTargeted {
                RoundedRectangle(cornerRadius: 10)
                    .strokeBorder(Color.accentColor, lineWidth: 3)
                    .padding(6)
                    .allowsHitTesting(false)
            }
        }
        .dropDestination(for: URL.self) { urls, _ in
            register(urls)
            return true
        } isTargeted: { isDropTargeted = $0 }
    }

    private var emptyLibrary: some View {
        ContentUnavailableView {
            Label("No Tools Yet", systemImage: "shippingbox")
        } description: {
            Text("Drop HTML files, project folders, scripts, apps or links here.")
        } actions: {
            Button("Add Files or Folders…", action: chooseFiles)
            Button("Add Web Link…") { isAddingLink = true }
        }
    }

    @ToolbarContentBuilder
    private var toolbar: some ToolbarContent {
        ToolbarItem(placement: .primaryAction) {
            Menu {
                Button("Add Files or Folders…", action: chooseFiles)
                Button("Add Web Link…") { isAddingLink = true }
            } label: {
                Label("Add Tool", systemImage: "plus")
            } primaryAction: {
                chooseFiles()
            }
            .help("Add a tool. Click and hold for more options.")
        }
        ToolbarItem {
            Picker("View", selection: libraryViewMode) {
                Label("Icons", systemImage: "square.grid.2x2").tag(LibraryViewMode.grid)
                Label("List", systemImage: "list.bullet").tag(LibraryViewMode.list)
            }
            .pickerStyle(.segmented)
            .help("Switch between icons and list")
        }
        ToolbarItem {
            Button {
                showTerminal.toggle()
            } label: {
                Label("Terminal", systemImage: "terminal")
            }
            .keyboardShortcut("j")
            .help("Show or hide the terminal (⌘J)")
        }
        ToolbarItem {
            Button {
                showInspector.toggle()
            } label: {
                Label("Inspector", systemImage: "sidebar.right")
            }
            .keyboardShortcut("i", modifiers: [.command, .option])
            .help("Show or hide the inspector (⌥⌘I)")
        }
    }

    private func open(_ tool: Tool) {
        selection = tool.id
        guard !tool.isMissing else {
            NSSound.beep()
            showInspector = true
            return
        }
        store.markOpened(tool.id)
        switch tool.kind {
        case .htmlFile, .staticFolder, .url:
            sessions.open(tool)
            filter = .openTool(tool.id)
        case .app:
            ToolActions.launchApp(tool)
        case .script:
            ToolActions.runScript(tool)
        case .devProject:
            showTerminal = true
            terminals.run(tool.command ?? "npm run dev", in: tool)
        }
    }

    // Picking a view mode while a tool is shown returns to the library.
    private var libraryViewMode: Binding<LibraryViewMode> {
        Binding(
            get: { viewMode },
            set: { mode in
                viewMode = mode
                if openedTool != nil { filter = .all }
            }
        )
    }

    private func quickLook(_ tool: Tool) {
        quickLookURL = tool.quickLookURL
    }

    private func chooseFiles() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = true
        panel.prompt = "Add"
        panel.message = "Choose HTML files, project folders, scripts or apps."
        if panel.runModal() == .OK {
            register(panel.urls)
        }
    }

    private func register(_ urls: [URL]) {
        let known = Set(store.tools.map(\.id))
        rejected = store.add(urls)
        if let added = store.tools.last(where: { !known.contains($0.id) }) {
            selection = added.id
        }
    }
}
