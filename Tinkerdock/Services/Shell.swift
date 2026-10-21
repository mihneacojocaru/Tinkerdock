import Foundation

enum Shell {
    struct Result {
        var status: Int32
        var output: String
    }

    static func run(_ executable: String, _ arguments: [String], in directory: URL? = nil, environment: [String: String]? = nil) async -> Result {
        await Task.detached {
            let process = Process()
            process.executableURL = URL(fileURLWithPath: executable)
            process.arguments = arguments
            process.currentDirectoryURL = directory
            if let environment { process.environment = environment }
            let pipe = Pipe()
            process.standardOutput = pipe
            process.standardError = pipe
            do {
                try process.run()
            } catch {
                return Result(status: -1, output: error.localizedDescription)
            }
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            process.waitUntilExit()
            return Result(status: process.terminationStatus, output: String(decoding: data, as: UTF8.self))
        }.value
    }
}
