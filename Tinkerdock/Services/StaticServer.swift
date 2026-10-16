import Foundation
import Network
import UniformTypeIdentifiers

/// Minimal HTTP file server on 127.0.0.1, so pages can use fetch and modules like on a real web server.
final class StaticServer: @unchecked Sendable {
    let root: URL
    private let queue = DispatchQueue(label: "Tinkerdock.StaticServer")
    private var listener: NWListener?

    private static let extraTypes = ["mjs": "text/javascript", "wasm": "application/wasm", "webmanifest": "application/manifest+json"]

    init(root: URL) {
        self.root = root.resolvingSymlinksInPath()
    }

    /// Starts on the preferred port so the page keeps its origin (and localStorage) across launches.
    func start(preferredPort: UInt16) async -> UInt16? {
        if let port = await listen(on: NWEndpoint.Port(rawValue: preferredPort) ?? .any) { return port }
        return await listen(on: .any)
    }

    func stop() {
        listener?.cancel()
        listener = nil
    }

    private func listen(on port: NWEndpoint.Port) async -> UInt16? {
        let parameters = NWParameters.tcp
        parameters.requiredLocalEndpoint = .hostPort(host: "127.0.0.1", port: port)
        guard let listener = try? NWListener(using: parameters) else { return nil }

        return await withCheckedContinuation { continuation in
            let resumed = Flag()
            listener.stateUpdateHandler = { [weak self] state in
                guard !resumed.isSet else { return }
                switch state {
                case .ready:
                    resumed.isSet = true
                    self?.listener = listener
                    continuation.resume(returning: listener.port?.rawValue)
                case .failed, .cancelled:
                    resumed.isSet = true
                    listener.cancel()
                    continuation.resume(returning: nil)
                default:
                    break
                }
            }
            listener.newConnectionHandler = { [weak self] connection in
                self?.handle(connection)
            }
            listener.start(queue: queue)
        }
    }

    private func handle(_ connection: NWConnection) {
        connection.start(queue: queue)
        receive(on: connection, buffer: Data())
    }

    private func receive(on connection: NWConnection, buffer: Data) {
        connection.receive(minimumIncompleteLength: 1, maximumLength: 65_536) { [weak self] data, _, isComplete, error in
            guard let self else { return connection.cancel() }
            var buffer = buffer
            if let data { buffer.append(data) }
            if let end = buffer.range(of: Data("\r\n\r\n".utf8)) {
                respond(on: connection, head: buffer[..<end.lowerBound])
            } else if isComplete || error != nil || buffer.count > 65_536 {
                connection.cancel()
            } else {
                receive(on: connection, buffer: buffer)
            }
        }
    }

    private func respond(on connection: NWConnection, head: Data) {
        let requestLine = String(decoding: head, as: UTF8.self).components(separatedBy: "\r\n").first ?? ""
        let parts = requestLine.split(separator: " ")
        guard parts.count >= 2, parts[0] == "GET" || parts[0] == "HEAD" else {
            return send("405 Method Not Allowed", on: connection)
        }

        var path = String(parts[1])
        if let cut = path.firstIndex(where: { $0 == "?" || $0 == "#" }) {
            path = String(path[..<cut])
        }
        path = path.removingPercentEncoding ?? path

        var file = root.appendingPathComponent(path).resolvingSymlinksInPath()
        guard file.path == root.path || file.path.hasPrefix(root.path + "/") else {
            return send("403 Forbidden", on: connection)
        }
        var isDirectory: ObjCBool = false
        if FileManager.default.fileExists(atPath: file.path, isDirectory: &isDirectory), isDirectory.boolValue {
            file.appendPathComponent("index.html")
        }
        guard let body = try? Data(contentsOf: file) else {
            return send("404 Not Found", on: connection)
        }
        send("200 OK", on: connection, body: body, type: Self.mimeType(for: file), headOnly: parts[0] == "HEAD")
    }

    private func send(_ status: String, on connection: NWConnection, body: Data = Data(), type: String = "text/plain; charset=utf-8", headOnly: Bool = false) {
        let body = body.isEmpty && !status.hasPrefix("200") ? Data(status.utf8) : body
        let header = "HTTP/1.1 \(status)\r\nContent-Type: \(type)\r\nContent-Length: \(body.count)\r\nCache-Control: no-store\r\nConnection: close\r\n\r\n"
        var payload = Data(header.utf8)
        if !headOnly { payload.append(body) }
        connection.send(content: payload, completion: .contentProcessed { _ in connection.cancel() })
    }

    private static func mimeType(for file: URL) -> String {
        let ext = file.pathExtension.lowercased()
        let type = extraTypes[ext] ?? UTType(filenameExtension: ext)?.preferredMIMEType ?? "application/octet-stream"
        let isText = type.hasPrefix("text/") || type.hasSuffix("json") || type.hasSuffix("javascript") || type.hasSuffix("xml")
        return isText ? type + "; charset=utf-8" : type
    }
}

/// Only touched on the server's serial queue.
private final class Flag: @unchecked Sendable {
    var isSet = false
}
