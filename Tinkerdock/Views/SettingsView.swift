import SwiftUI

struct SettingsView: View {
    var body: some View {
        TabView {
            FoldersSettings()
                .tabItem { Label("Folders", systemImage: "folder") }
            IntegrationSettings()
                .tabItem { Label("Integrations", systemImage: "puzzlepiece.extension") }
        }
        .frame(width: 560, height: 380)
    }
}

private struct FoldersSettings: View {
    @Environment(DiscoveryStore.self) private var discovery
    @State private var selection: String?

    var body: some View {
        Form {
            Section {
                List(selection: $selection) {
                    ForEach(discovery.watchedFolders, id: \.self) { path in
                        Label((path as NSString).abbreviatingWithTildeInPath, systemImage: "folder")
                    }
                }
                .frame(minHeight: 160)
                HStack {
                    Button("Add Folder…", action: addFolder)
                    Button("Remove") {
                        if let selection { discovery.removeFolder(selection) }
                    }
                    .disabled(selection == nil)
                    Spacer()
                    Button("Show Ignored Again") { discovery.clearIgnored() }
                }
            } header: {
                Text("Watched Folders")
            } footer: {
                Text("Tinkerdock looks up to three levels deep for HTML files and folders with an index.html, package.json or tinkerdock.json, and lists new ones under Discovered.")
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
    }

    private func addFolder() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = true
        panel.prompt = "Watch"
        if panel.runModal() == .OK {
            panel.urls.forEach(discovery.addFolder)
        }
    }
}

private struct IntegrationSettings: View {
    @State private var commandInstalled = Installer.isCommandInstalled
    @State private var skillInstalled = Installer.isSkillInstalled
    @State private var errorMessage: String?

    var body: some View {
        Form {
            Section {
                LabeledContent {
                    Button(commandInstalled ? "Reinstall" : "Install") {
                        perform(Installer.installCommand)
                    }
                } label: {
                    Text("Command line tool")
                    Text(commandInstalled ? "Installed at ~/.local/bin/tinkerdock" : "Adds `tinkerdock` to ~/.local/bin")
                }
                LabeledContent {
                    Button(skillInstalled ? "Reinstall" : "Install") {
                        perform(Installer.installSkill)
                    }
                } label: {
                    Text("Claude Code skill")
                    Text(skillInstalled ? "Installed at ~/.claude/skills/tinkerdock" : "Teaches Claude Code to register finished tools")
                }
            } footer: {
                if let errorMessage {
                    Text(errorMessage).foregroundStyle(.red)
                } else {
                    Text("Make sure ~/.local/bin is in your PATH.").foregroundStyle(.secondary)
                }
            }
        }
        .formStyle(.grouped)
    }

    private func perform(_ action: () throws -> Void) {
        do {
            try action()
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
        commandInstalled = Installer.isCommandInstalled
        skillInstalled = Installer.isSkillInstalled
    }
}
