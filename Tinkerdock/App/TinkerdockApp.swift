import SwiftUI

struct TinkerdockApp: App {
    @State private var services = AppServices()

    var body: some Scene {
        Window("Tinkerdock", id: "library") {
            ContentView()
                .environment(services)
                .frame(minWidth: 900, minHeight: 560)
        }
        .defaultSize(width: 1280, height: 800)

        WindowGroup("Tool", id: "tool", for: Tool.ID.self) { $toolID in
            ToolWindowView(toolID: toolID)
                .environment(services)
        }
        .defaultSize(width: 1200, height: 820)

        MenuBarExtra("Tinkerdock", systemImage: "shippingbox") {
            MenuBarContent()
                .environment(services)
        }

        Settings {
            SettingsView()
                .environment(services)
        }
    }
}
