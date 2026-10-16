import Foundation
import Observation

/// Lets the menu bar and the command line ask the main window to open a tool.
@MainActor @Observable
final class AppRouter {
    struct OpenRequest: Equatable {
        let toolID: Tool.ID
        let token = UUID()
    }

    var openRequest: OpenRequest?

    func open(_ id: Tool.ID) {
        openRequest = OpenRequest(toolID: id)
    }
}
