import Foundation
import Testing
@testable import CodexBarCore

@Suite
struct CodexUnreadStateReaderTests {
    @Test
    func readsUnreadThreadIDsFromCodexGlobalState() throws {
        let fileManager = FileManager.default
        let root = fileManager.temporaryDirectory.appendingPathComponent("CodexBarUnreadReaderTests-\(UUID().uuidString)")
        defer { try? fileManager.removeItem(at: root) }

        try fileManager.createDirectory(at: root, withIntermediateDirectories: true)
        try """
        {
          "electron-persisted-atom-state": {
            "unread-thread-ids-by-host-v1": {
              "local": ["thread-1", "thread-2"],
              "remote": ["thread-3"]
            }
          }
        }
        """.write(to: root.appendingPathComponent(".codex-global-state.json"), atomically: true, encoding: .utf8)

        let state = CodexUnreadStateReader(codexHome: root).load()

        #expect(state.threadIDs(hostID: "local") == ["thread-1", "thread-2"])
        #expect(state.allThreadIDs() == ["thread-1", "thread-2", "thread-3"])
        #expect(state.isUnread(threadID: "thread-1") == true)
        #expect(state.isUnread(threadID: "thread-3") == true)
        #expect(state.isUnread(threadID: "thread-4") == false)
    }

    @Test
    func ignoresEmptyThreadIDsAndMalformedHostValues() throws {
        let fileManager = FileManager.default
        let root = fileManager.temporaryDirectory.appendingPathComponent("CodexBarUnreadMalformedHostTests-\(UUID().uuidString)")
        defer { try? fileManager.removeItem(at: root) }

        try fileManager.createDirectory(at: root, withIntermediateDirectories: true)
        try """
        {
          "electron-persisted-atom-state": {
            "unread-thread-ids-by-host-v1": {
              "local": ["thread-1", "", "thread-2"],
              "remote": "not-an-array"
            }
          }
        }
        """.write(to: root.appendingPathComponent(".codex-global-state.json"), atomically: true, encoding: .utf8)

        let state = CodexUnreadStateReader(codexHome: root).load()

        #expect(state.threadIDs(hostID: "local") == ["thread-1", "thread-2"])
        #expect(state.threadIDs(hostID: "remote") == [])
        #expect(state.allThreadIDs() == ["thread-1", "thread-2"])
    }

    @Test
    func malformedGlobalStateMeansNoUnreadThreads() throws {
        let fileManager = FileManager.default
        let root = fileManager.temporaryDirectory.appendingPathComponent("CodexBarMalformedUnreadReaderTests-\(UUID().uuidString)")
        defer { try? fileManager.removeItem(at: root) }

        try fileManager.createDirectory(at: root, withIntermediateDirectories: true)
        try "{not-json".write(to: root.appendingPathComponent(".codex-global-state.json"), atomically: true, encoding: .utf8)

        let state = CodexUnreadStateReader(codexHome: root).load()

        #expect(state == .empty)
    }

    @Test
    func missingGlobalStateMeansNoUnreadThreads() {
        let fileManager = FileManager.default
        let root = fileManager.temporaryDirectory.appendingPathComponent("CodexBarMissingUnreadReaderTests-\(UUID().uuidString)")
        defer { try? fileManager.removeItem(at: root) }

        let state = CodexUnreadStateReader(codexHome: root).load()

        #expect(state == .empty)
    }
}
