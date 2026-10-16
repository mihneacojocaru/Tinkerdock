import Foundation

/// A registration written by the command line tool and picked up by the running app.
struct InboxRequest: Codable {
    var location: String
    var name: String?
    var description: String?
    var tags: [String]?
    var command: String?
    var open: Bool?

    var url: URL? {
        location.hasPrefix("/") ? URL(fileURLWithPath: location) : URL(string: location)
    }
}
