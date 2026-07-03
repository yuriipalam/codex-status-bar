import Foundation

public struct CodexUnreadState: Equatable, Sendable {
    public static let empty = CodexUnreadState(threadIDsByHost: [:])

    public let threadIDsByHost: [String: Set<String>]

    public init(threadIDsByHost: [String: Set<String>]) {
        self.threadIDsByHost = threadIDsByHost
    }

    public func threadIDs(hostID: String = "local") -> Set<String> {
        threadIDsByHost[hostID] ?? []
    }

    public func allThreadIDs() -> Set<String> {
        threadIDsByHost.values.reduce(into: Set<String>()) { result, threadIDs in
            result.formUnion(threadIDs)
        }
    }

    public func isUnread(threadID: String, hostID: String = "local") -> Bool {
        if threadIDsByHost[hostID]?.contains(threadID) == true {
            return true
        }

        return threadIDsByHost.values.contains { $0.contains(threadID) }
    }
}

public final class CodexUnreadStateReader {
    private let codexHome: URL
    private let fileManager: FileManager

    public init(codexHome: URL, fileManager: FileManager = .default) {
        self.codexHome = codexHome
        self.fileManager = fileManager
    }

    public func load() -> CodexUnreadState {
        let stateFile = codexHome.appendingPathComponent(".codex-global-state.json")
        guard fileManager.fileExists(atPath: stateFile.path),
              let data = try? Data(contentsOf: stateFile),
              let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let persistedState = root["electron-persisted-atom-state"] as? [String: Any],
              let unreadByHost = persistedState["unread-thread-ids-by-host-v1"] as? [String: Any]
        else {
            return .empty
        }

        var threadIDsByHost: [String: Set<String>] = [:]
        for (hostID, value) in unreadByHost {
            guard let threadIDs = value as? [String] else { continue }
            threadIDsByHost[hostID] = Set(threadIDs.filter { !$0.isEmpty })
        }

        return CodexUnreadState(threadIDsByHost: threadIDsByHost)
    }
}
