import QuickLook
import SwiftUI

enum LibraryViewMode: String {
    case grid, list
}

enum LibrarySortOrder: String, CaseIterable, Identifiable {
    case name, kind, added, opened

    var id: String { rawValue }

    var title: String {
        switch self {
        case .name: "Name"
        case .kind: "Kind"
        case .added: "Date Added"
        case .opened: "Last Opened"
        }
    }

    func sort(_ tools: [Tool]) -> [Tool] {
        switch self {
        case .name: tools.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
        case .kind:
            tools.sorted {
                let order = $0.fileTypeDescription.localizedStandardCompare($1.fileTypeDescription)
                return order == .orderedSame ? $0.name.localizedStandardCompare($1.name) == .orderedAscending : order == .orderedAscending
            }
        case .added: tools.sorted { $0.addedAt > $1.addedAt }
        case .opened: tools.sorted { $0.lastOpenedSortKey > $1.lastOpenedSortKey }
        }
    }
}

struct ContentView: View {
    @Environment(ToolStore.self) private var store
    @Environment(BrowserSessions.self) private var sessions
    @Environment(DevServerManager.self) private var devServers
    @Environment(AppRouter.self) private var router

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
    @AppStorage("sortOrder") private var sortOrder: LibrarySortOrder = .name
    @AppStorage("groupByKind") private var groupByKind = true

    private var openedTool: Tool? {
        guard case .openTool(let id) = filter, let tool = store.tool(id), tool.opensInWebView || tool.kind == .devProject else { return nil }
        return tool
    }

    private var visibleTools: [Tool] {
        let filtered = (filter ?? .all).apply(to: store.tools).filter { $0.matches(search) }
        if filter == .recent { return filtered }
        return sortOrder.sort(filtered)
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
        .onChange(of: router.openRequest) {
            if let id = router.openRequest?.toolID, let tool = store.tool(id) { open(tool) }
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
        Group {
            if showTerminal {
                VSplitView {
                    mainPane
                        .frame(maxWidth: .infinity, minHeight: 220, maxHeight: .infinity)
                    TerminalPanel(tool: store.tool(selection))
                        .frame(maxWidth: .infinity, minHeight: 140, idealHeight: 280)
                }
            } else {
                mainPane
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
            ToolPage(tool: tool)
                .id(tool.id)
        } else if filter == .agents {
            AgentsView()
        } else if filter == .discovered {
            DiscoveredView { selection = $0 }
        } else {
            library
        }
    }

    private var subtitle: String {
        if let tool = openedTool { return tool.displayLocation }
        if filter == .discovered || filter == .agents { return "" }
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
                ToolGridView(tools: visibleTools, groupByKind: groupByKind, selection: $selection, open: open, quickLook: quickLook)
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
            Menu {
                Picker("Sort By", selection: $sortOrder) {
                    ForEach(LibrarySortOrder.allCases) { Text($0.title).tag($0) }
                }
                .pickerStyle(.inline)
                Divider()
                Toggle("Group by Kind", isOn: $groupByKind)
            } label: {
                Label("Sort and Group", systemImage: "arrow.up.arrow.down")
            }
            .help("Sort and group tools")
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
            if !devServers.isActive(tool.id) { devServers.start(tool) }
            sessions.open(tool)
            filter = .openTool(tool.id)
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
