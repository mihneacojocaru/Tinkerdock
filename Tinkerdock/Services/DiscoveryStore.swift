import AppKit
import Observation

/// Finds tools in watched folders that are not registered yet.
@MainActor @Observable
final class DiscoveryStore {
    private(set) var watchedFolders: [String]
    private(set) var isScanning = false
    private var found: [Tool] = []
    private var ignored: Set<String>

    @ObservationIgnored private let store: ToolStore
    @ObservationIgnored private var watcher: FolderWatcher?
    @ObservationIgnored private var rescanTask: Task<Void, Never>?

    private static let watchedKey = "watchedFolders"
    private static let ignoredKey = "ignoredPaths"
    nonisolated private static let skippedNames: Set<String> = ["node_modules", "vendor", "Pods", "DerivedData", "Library", "build", "dist", "out", "target"]
    nonisolated private static let maxDepth = 3

    init(store: ToolStore) {
        self.store = store
        watchedFolders = UserDefaults.standard.stringArray(forKey: Self.watchedKey) ?? []
        ignored = Set(UserDefaults.standard.stringArray(forKey: Self.ignoredKey) ?? [])
        restartWatcher()
        rescan()
        NotificationCenter.default.addObserver(forName: NSApplication.didBecomeActiveNotification, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.scheduleRescan() }
        }
    }

    var pending: [Tool] {
        let known = Set(store.tools.map(\.location))
        return found.filter { !known.contains($0.location) && !ignored.contains($0.location) }
    }

    func addFolder(_ url: URL) {
        let path = url.standardizedFileURL.path
        guard !watchedFolders.contains(path) else { return }
        watchedFolders.append(path)
        foldersChanged()
    }

    func removeFolder(_ path: String) {
        watchedFolders.removeAll { $0 == path }
        foldersChanged()
    }

    func ignore(_ tool: Tool) {
        ignored.insert(tool.location)
        UserDefaults.standard.set(Array(ignored), forKey: Self.ignoredKey)
    }

    func clearIgnored() {
        ignored.removeAll()
        UserDefaults.standard.removeObject(forKey: Self.ignoredKey)
    }

    func rescan() {
        let roots = watchedFolders
        isScanning = true
        Task {
            let result = await Task.detached { Self.scan(roots) }.value
            found = result
            isScanning = false
        }
    }

    private func scheduleRescan() {
        rescanTask?.cancel()
        rescanTask = Task {
            try? await Task.sleep(for: .seconds(3))
            guard !Task.isCancelled else { return }
            rescan()
        }
    }

    private func foldersChanged() {
        UserDefaults.standard.set(watchedFolders, forKey: Self.watchedKey)
        restartWatcher()
        rescan()
    }

    private func restartWatcher() {
        watcher = FolderWatcher(paths: watchedFolders) { [weak self] in
            MainActor.assumeIsolated { self?.scheduleRescan() }
        }
    }

    nonisolated private static func scan(_ roots: [String]) -> [Tool] {
        var result: [Tool] = []
        for root in roots {
            walk(URL(fileURLWithPath: root, isDirectory: true), depth: 0, into: &result)
        }
        return result
    }

    nonisolated private static func walk(_ folder: URL, depth: Int, into result: inout [Tool]) {
        let keys: [URLResourceKey] = [.isDirectoryKey, .isPackageKey]
        guard let items = try? FileManager.default.contentsOfDirectory(at: folder, includingPropertiesForKeys: keys, options: [.skipsHiddenFiles]) else { return }

        for item in items where !skippedNames.contains(item.lastPathComponent) {
            let values = try? item.resourceValues(forKeys: Set(keys))
            let ext = item.pathExtension.lowercased()
            if values?.isDirectory == true {
                guard values?.isPackage != true else { continue }
                if var tool = ToolDetector.tool(for: item), tool.kind != .app {
                    tool.location = item.standardizedFileURL.path
                    result.append(tool)
                } else if depth < maxDepth {
                    walk(item, depth: depth + 1, into: &result)
                }
            } else if ext == "html" || ext == "htm", var tool = ToolDetector.tool(for: item) {
                tool.location = item.standardizedFileURL.path
                result.append(tool)
            }
        }
    }
}
