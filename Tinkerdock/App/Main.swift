import Foundation

@main
enum Main {
    static func main() {
        let arguments = Array(CommandLine.arguments.dropFirst())
        // Finder and Xcode pass flags like -psn_… or -NSDocumentRevisionsDebugMode; commands never start with a dash.
        if let first = arguments.first, !first.hasPrefix("-") {
            exit(CommandLineInterface.run(arguments))
        }
        TinkerdockApp.main()
    }
}
