import Foundation
import Testing
@testable import CodexBarCore

@Suite
struct CodexStateReaderTests {
    @Test
    func snapshotIncludesSessionRowsFromMetadata() throws {
        let fileManager = FileManager.default
        let root = fileManager.temporaryDirectory.appendingPathComponent("CodexBarTests-\(UUID().uuidString)")
        defer { try? fileManager.removeItem(at: root) }

        try writeActiveSession(in: root)

        let reader = CodexStateReader(codexHome: root)
        let snapshot = reader.loadSnapshot(now: date("2026-06-24T20:00:30.000Z"))

        #expect(snapshot.sessions.count == 1)
        #expect(snapshot.sessions.first?.id == "thread-1")
        #expect(snapshot.sessions.first?.title == "ripple-effect")
        #expect(snapshot.sessions.first?.client == .app)
        #expect(snapshot.sessions.first?.isActive == true)
        #expect(snapshot.sessions.first?.statusLabel == "Running command")
        #expect(snapshot.activeAgents.first?.title == "ripple-effect")
    }

    @Test
    func snapshotMarksUnreadSessionsFromCodexGlobalState() throws {
        let fileManager = FileManager.default
        let root = fileManager.temporaryDirectory.appendingPathComponent("CodexBarUnreadTests-\(UUID().uuidString)")
        defer { try? fileManager.removeItem(at: root) }

        try writeCompletedSession(in: root, id: "thread-1", folderName: "ripple-effect")
        try writeGlobalState(in: root, unreadThreadIDs: ["thread-1"])

        let reader = CodexStateReader(codexHome: root)
        let snapshot = reader.loadSnapshot(now: date("2026-06-24T20:00:30.000Z"))

        #expect(snapshot.sessions.first?.isActive == false)
        #expect(snapshot.sessions.first?.isUnread == true)
        #expect(snapshot.sessions.first?.isVisibleInSessionMenu == true)
    }

    @Test
    func snapshotIncludesUnreadSessionsOutsideRecentLimit() throws {
        let fileManager = FileManager.default
        let root = fileManager.temporaryDirectory.appendingPathComponent("CodexBarUnreadLimitTests-\(UUID().uuidString)")
        defer { try? fileManager.removeItem(at: root) }

        try writeCompletedSession(
            in: root,
            id: "019f08b4-91be-7091-bdb3-c92e769787e4",
            folderName: "old-unread",
            timestamp: date("2026-06-24T20:00:00.000Z")
        )
        try writeCompletedSession(
            in: root,
            id: "019f08b5-23f2-76b3-969a-2e41b496b4a6",
            folderName: "newer-read",
            timestamp: date("2026-06-24T21:00:00.000Z")
        )
        try writeGlobalState(in: root, unreadThreadIDs: ["019f08b4-91be-7091-bdb3-c92e769787e4"])

        let reader = CodexStateReader(codexHome: root)
        reader.threadLimit = 1
        let snapshot = reader.loadSnapshot(now: date("2026-06-24T21:00:30.000Z"))

        #expect(snapshot.sessions.map(\.id).contains("019f08b4-91be-7091-bdb3-c92e769787e4"))
        #expect(snapshot.sessions.first(where: { $0.id == "019f08b4-91be-7091-bdb3-c92e769787e4" })?.isUnread == true)
    }

    @Test
    func snapshotIncludesUnreadSessionsFromAnyHostOutsideRecentLimit() throws {
        let fileManager = FileManager.default
        let root = fileManager.temporaryDirectory.appendingPathComponent("CodexBarUnreadRemoteLimitTests-\(UUID().uuidString)")
        defer { try? fileManager.removeItem(at: root) }

        try writeCompletedSession(
            in: root,
            id: "019f08b4-91be-7091-bdb3-c92e769787e4",
            folderName: "old-unread",
            timestamp: date("2026-06-24T20:00:00.000Z")
        )
        try writeCompletedSession(
            in: root,
            id: "019f08b5-23f2-76b3-969a-2e41b496b4a6",
            folderName: "newer-read",
            timestamp: date("2026-06-24T21:00:00.000Z")
        )
        try writeGlobalState(in: root, unreadThreadIDsByHost: [
            "remote-host": ["019f08b4-91be-7091-bdb3-c92e769787e4"],
        ])

        let reader = CodexStateReader(codexHome: root)
        reader.threadLimit = 1
        let snapshot = reader.loadSnapshot(now: date("2026-06-24T21:00:30.000Z"))

        #expect(snapshot.sessions.map(\.id).contains("019f08b4-91be-7091-bdb3-c92e769787e4"))
        #expect(snapshot.sessions.first(where: { $0.id == "019f08b4-91be-7091-bdb3-c92e769787e4" })?.isUnread == true)
    }

    @Test
    func continuedThreadCollapsesImportedUnreadAlias() throws {
        let fileManager = FileManager.default
        let root = fileManager.temporaryDirectory.appendingPathComponent("CodexBarContinuedThreadTests-\(UUID().uuidString)")
        defer { try? fileManager.removeItem(at: root) }

        let importedID = "019eeadb-efee-70c2-93a3-9a0c8b95c1b9"
        let continuedID = "019f0a4d-760c-7da0-8eae-17d5f96d4f0e"

        try writeCompletedSession(
            in: root,
            id: importedID,
            folderName: "EnoParking_Frontend",
            timestamp: date("2026-06-27T18:00:00.000Z")
        )
        try writeSession(
            in: root,
            id: continuedID,
            folderName: "EnoParking_Frontend",
            timestamp: date("2026-06-27T18:17:56.000Z"),
            taskStartedAt: date("2026-06-27T18:18:00.000Z"),
            lastToolAt: date("2026-06-27T18:18:05.000Z"),
            toolName: "request_user_input",
            completed: false,
            importedSessionID: importedID
        )
        try writeGlobalState(in: root, unreadThreadIDs: [importedID])

        let reader = CodexStateReader(codexHome: root)
        let snapshot = reader.loadSnapshot(now: date("2026-06-27T18:18:10.000Z"))

        #expect(snapshot.sessions.map(\.id) == [continuedID])
        #expect(snapshot.sessions.first?.isUnread == true)
        #expect(snapshot.sessions.first?.isActive == true)
        #expect(snapshot.sessions.first?.statusLabel == "Waiting for input")
        #expect(snapshot.activeAgents.map(\.id) == [continuedID])
    }

    @Test
    func activeParentAndActiveForkBothRemainVisible() throws {
        let fileManager = FileManager.default
        let root = fileManager.temporaryDirectory.appendingPathComponent("CodexBarActiveForkTests-\(UUID().uuidString)")
        defer { try? fileManager.removeItem(at: root) }

        let parentID = "019eeadb-efee-70c2-93a3-9a0c8b95c1b9"
        let forkID = "019f0a4d-760c-7da0-8eae-17d5f96d4f0e"

        try writeSession(
            in: root,
            id: parentID,
            folderName: "EnoParking_Frontend",
            timestamp: date("2026-06-27T18:00:00.000Z"),
            taskStartedAt: date("2026-06-27T18:00:05.000Z"),
            lastToolAt: date("2026-06-27T18:02:00.000Z"),
            toolName: "exec_command",
            completed: false
        )
        try writeSession(
            in: root,
            id: forkID,
            folderName: "EnoParking_Frontend",
            timestamp: date("2026-06-27T18:17:56.000Z"),
            taskStartedAt: date("2026-06-27T18:18:00.000Z"),
            lastToolAt: date("2026-06-27T18:18:05.000Z"),
            toolName: "apply_patch",
            completed: false,
            importedSessionID: parentID,
            forkedFromID: parentID
        )

        let reader = CodexStateReader(codexHome: root)
        let snapshot = reader.loadSnapshot(now: date("2026-06-27T18:18:10.000Z"))

        #expect(snapshot.sessions.map(\.id) == [forkID, parentID])
        #expect(snapshot.activeAgents.map(\.id) == [forkID, parentID])
    }

    @Test
    func activeForkDoesNotInheritUnreadOrCollapseParent() throws {
        let fileManager = FileManager.default
        let root = fileManager.temporaryDirectory.appendingPathComponent("CodexBarForkedUnreadParentTests-\(UUID().uuidString)")
        defer { try? fileManager.removeItem(at: root) }

        let parentID = "019eeadb-efee-70c2-93a3-9a0c8b95c1b9"
        let forkID = "019f0a4d-760c-7da0-8eae-17d5f96d4f0e"

        try writeCompletedSession(
            in: root,
            id: parentID,
            folderName: "EnoParking_Frontend",
            timestamp: date("2026-06-27T18:00:00.000Z")
        )
        try writeSession(
            in: root,
            id: forkID,
            folderName: "EnoParking_Frontend",
            timestamp: date("2026-06-27T18:17:56.000Z"),
            taskStartedAt: date("2026-06-27T18:18:00.000Z"),
            lastToolAt: date("2026-06-27T18:18:05.000Z"),
            toolName: "apply_patch",
            completed: false,
            importedSessionID: parentID,
            forkedFromID: parentID
        )
        try writeGlobalState(in: root, unreadThreadIDs: [parentID])

        let reader = CodexStateReader(codexHome: root)
        let snapshot = reader.loadSnapshot(now: date("2026-06-27T18:18:10.000Z"))

        #expect(snapshot.sessions.map(\.id) == [forkID, parentID])
        #expect(snapshot.sessions.first(where: { $0.id == forkID })?.isUnread == false)
        #expect(snapshot.sessions.first(where: { $0.id == forkID })?.isActive == true)
        #expect(snapshot.sessions.first(where: { $0.id == parentID })?.isUnread == true)
        #expect(snapshot.sessions.first(where: { $0.id == parentID })?.isActive == false)
        #expect(snapshot.activeAgents.map(\.id) == [forkID])
    }

    @Test
    func snapshotCountsMultipleActiveAgentsAndSortsSessions() throws {
        let fileManager = FileManager.default
        let root = fileManager.temporaryDirectory.appendingPathComponent("CodexBarMultiAgentTests-\(UUID().uuidString)")
        defer { try? fileManager.removeItem(at: root) }

        try writeSession(
            in: root,
            id: "thread-older-active",
            folderName: "older-active",
            timestamp: date("2026-06-24T20:00:00.000Z"),
            taskStartedAt: date("2026-06-24T20:00:05.000Z"),
            lastToolAt: date("2026-06-24T20:02:30.000Z"),
            toolName: "exec_command",
            completed: false
        )
        try writeSession(
            in: root,
            id: "thread-newer-active",
            folderName: "newer-active",
            timestamp: date("2026-06-24T20:02:00.000Z"),
            taskStartedAt: date("2026-06-24T20:02:05.000Z"),
            lastToolAt: date("2026-06-24T20:02:10.000Z"),
            toolName: "apply_patch",
            completed: false
        )
        try writeCompletedSession(
            in: root,
            id: "thread-unread",
            folderName: "unread",
            timestamp: date("2026-06-24T20:01:00.000Z")
        )
        try writeCompletedSession(
            in: root,
            id: "thread-read",
            folderName: "read",
            timestamp: date("2026-06-24T20:03:00.000Z")
        )
        try writeGlobalState(in: root, unreadThreadIDs: ["thread-unread"])

        let reader = CodexStateReader(codexHome: root)
        let snapshot = reader.loadSnapshot(now: date("2026-06-24T20:03:00.000Z"))

        #expect(snapshot.activeAgents.map(\.id) == ["thread-newer-active", "thread-older-active"])
        #expect(snapshot.activeAgents.map(\.label) == ["Editing", "Running command"])
        #expect(snapshot.sessions.map(\.id) == ["thread-newer-active", "thread-older-active", "thread-unread", "thread-read"])
        #expect(snapshot.sessions.first?.title == "newer-active")
    }

    @Test
    func snapshotUsesLatestUsageSnapshotAcrossSessionFiles() throws {
        let fileManager = FileManager.default
        let root = fileManager.temporaryDirectory.appendingPathComponent("CodexBarUsageTests-\(UUID().uuidString)")
        defer { try? fileManager.removeItem(at: root) }

        try writeSession(
            in: root,
            id: "older-usage",
            folderName: "older-usage",
            timestamp: date("2026-06-24T20:00:00.000Z"),
            completed: true,
            tokenSnapshot: TokenSnapshot(
                capturedAt: date("2026-06-24T20:00:30.000Z"),
                primaryUsed: 90,
                secondaryUsed: 80
            )
        )
        try writeSession(
            in: root,
            id: "newer-usage",
            folderName: "newer-usage",
            timestamp: date("2026-06-24T21:00:00.000Z"),
            completed: true,
            tokenSnapshot: TokenSnapshot(
                capturedAt: date("2026-06-24T21:00:30.000Z"),
                primaryUsed: 10,
                secondaryUsed: 20
            )
        )

        let snapshot = CodexStateReader(codexHome: root).loadSnapshot(now: date("2026-06-24T21:01:00.000Z"))

        #expect(snapshot.usage?.capturedAt == date("2026-06-24T21:00:30.000Z"))
        #expect(snapshot.usage?.primary?.leftPercent == 90)
        #expect(snapshot.usage?.secondary?.leftPercent == 80)
    }

    @Test
    func snapshotProjectsUsageWindowAfterStaleReset() throws {
        let fileManager = FileManager.default
        let root = fileManager.temporaryDirectory.appendingPathComponent("CodexBarExpiredUsageTests-\(UUID().uuidString)")
        defer { try? fileManager.removeItem(at: root) }

        try writeSession(
            in: root,
            id: "expired-usage",
            folderName: "expired-usage",
            timestamp: date("2026-06-24T20:00:00.000Z"),
            completed: true,
            tokenSnapshot: TokenSnapshot(
                capturedAt: date("2026-06-24T20:00:30.000Z"),
                primaryUsed: 47,
                secondaryUsed: 86
            )
        )

        let snapshot = CodexStateReader(codexHome: root).loadSnapshot(now: date("2026-06-25T02:15:00.000Z"))

        #expect(snapshot.usage?.primary?.usedPercent == 0)
        #expect(snapshot.usage?.primary?.leftPercent == 100)
        #expect(snapshot.usage?.primary?.resetsAt == Date(timeIntervalSince1970: 1_782_349_443 + 300 * 60))
        #expect(snapshot.usage?.secondary?.leftPercent == 14)
    }

    @Test
    func openTasksStayActiveUntilGeneralStaleLimit() throws {
        let fileManager = FileManager.default
        let root = fileManager.temporaryDirectory.appendingPathComponent("CodexBarStaleLimitTests-\(UUID().uuidString)")
        defer { try? fileManager.removeItem(at: root) }

        try writeSession(
            in: root,
            id: "active-thread",
            folderName: "active",
            timestamp: date("2026-06-24T20:00:00.000Z"),
            taskStartedAt: date("2026-06-24T20:00:05.000Z"),
            lastToolAt: date("2026-06-24T20:00:10.000Z"),
            toolName: "exec_command",
            completed: false
        )

        let reader = CodexStateReader(codexHome: root)
        reader.staleAfter = 60 * 60
        let snapshot = reader.loadSnapshot(now: date("2026-06-24T20:59:59.000Z"))

        #expect(snapshot.activeAgents.count == 1)
        #expect(snapshot.sessions.first?.isActive == true)
    }

    @Test
    func quietOpenTasksStayActiveUntilGeneralStaleLimit() throws {
        let fileManager = FileManager.default
        let root = fileManager.temporaryDirectory.appendingPathComponent("CodexBarQuietStaleLimitTests-\(UUID().uuidString)")
        defer { try? fileManager.removeItem(at: root) }

        let rollout = try writeSession(
            in: root,
            id: "active-thread",
            folderName: "active",
            timestamp: date("2026-06-24T20:00:00.000Z"),
            taskStartedAt: date("2026-06-24T20:00:05.000Z"),
            lastToolAt: date("2026-06-24T20:00:10.000Z"),
            toolName: "exec_command",
            completed: false
        )
        try appendLine(
            """
            {"timestamp":"2026-06-24T20:00:12.000Z","type":"response_item","payload":{"type":"function_call_output"}}
            """,
            to: rollout,
            modifiedAt: date("2026-06-24T20:00:00.000Z")
        )

        let reader = CodexStateReader(codexHome: root)
        reader.staleAfter = 60 * 60
        let snapshot = reader.loadSnapshot(now: date("2026-06-24T20:15:00.000Z"))

        #expect(snapshot.activeAgents.count == 1)
        #expect(snapshot.sessions.first?.isActive == true)
        #expect(snapshot.sessions.first?.statusLabel == "Reviewing output")
    }

    @Test
    func staleUnreadOpenTasksRemainVisibleInSessionMenu() throws {
        let fileManager = FileManager.default
        let root = fileManager.temporaryDirectory.appendingPathComponent("CodexBarStaleUnreadTests-\(UUID().uuidString)")
        defer { try? fileManager.removeItem(at: root) }

        try writeSession(
            in: root,
            id: "stale-unread-thread",
            folderName: "stale-unread",
            timestamp: date("2026-06-24T20:00:00.000Z"),
            taskStartedAt: date("2026-06-24T20:00:05.000Z"),
            lastToolAt: date("2026-06-24T20:00:10.000Z"),
            toolName: "exec_command",
            completed: false
        )
        try writeGlobalState(in: root, unreadThreadIDs: ["stale-unread-thread"])

        let reader = CodexStateReader(codexHome: root)
        reader.staleAfter = 60
        let snapshot = reader.loadSnapshot(now: date("2026-06-24T20:02:00.000Z"))

        #expect(snapshot.activeAgents.isEmpty)
        #expect(snapshot.sessions.first?.isActive == false)
        #expect(snapshot.sessions.first?.isUnread == true)
        #expect(snapshot.sessions.first?.isVisibleInSessionMenu == true)
    }

    @Test
    func readerReparsesCachedSessionWhenFileSizeChanges() throws {
        let fileManager = FileManager.default
        let root = fileManager.temporaryDirectory.appendingPathComponent("CodexBarCacheTests-\(UUID().uuidString)")
        defer { try? fileManager.removeItem(at: root) }

        let modifiedAt = date("2026-06-24T20:00:00.000Z")
        let rollout = try writeSession(
            in: root,
            id: "thread-1",
            folderName: "cache-test",
            timestamp: modifiedAt,
            taskStartedAt: date("2026-06-24T20:00:05.000Z"),
            lastToolAt: date("2026-06-24T20:00:10.000Z"),
            toolName: "exec_command",
            completed: false
        )
        let reader = CodexStateReader(codexHome: root)
        reader.missingActiveSessionGrace = 5

        let activeSnapshot = reader.loadSnapshot(now: date("2026-06-24T20:00:30.000Z"))
        #expect(activeSnapshot.sessions.first?.isActive == true)

        try appendLine(
            """
            {"timestamp":"2026-06-24T20:00:40.000Z","type":"event_msg","payload":{"type":"task_complete"}}
            """,
            to: rollout,
            modifiedAt: modifiedAt
        )
        let completedSnapshot = reader.loadSnapshot(now: date("2026-06-24T20:00:50.000Z"))

        #expect(completedSnapshot.sessions.first?.isActive == false)
        #expect(completedSnapshot.activeAgents.isEmpty)
    }

    @Test
    func activeSessionRemainsVisibleDuringBriefFileDisappearance() throws {
        let fileManager = FileManager.default
        let root = fileManager.temporaryDirectory.appendingPathComponent("CodexBarMissingActiveTests-\(UUID().uuidString)")
        defer { try? fileManager.removeItem(at: root) }

        let rollout = try writeSession(
            in: root,
            id: "active-thread",
            folderName: "active",
            timestamp: date("2026-06-24T20:00:00.000Z"),
            completed: false
        )
        let reader = CodexStateReader(codexHome: root)
        reader.missingActiveSessionGrace = 5

        let activeSnapshot = reader.loadSnapshot(now: date("2026-06-24T20:00:30.000Z"))
        #expect(activeSnapshot.sessions.first?.isActive == true)

        try fileManager.removeItem(at: rollout)

        let graceSnapshot = reader.loadSnapshot(now: date("2026-06-24T20:00:33.000Z"))
        #expect(graceSnapshot.sessions.first?.id == "active-thread")
        #expect(graceSnapshot.sessions.first?.isActive == true)
        #expect(graceSnapshot.activeAgents.first?.id == "active-thread")

        let expiredSnapshot = reader.loadSnapshot(now: date("2026-06-24T20:00:36.000Z"))
        #expect(expiredSnapshot.sessions.isEmpty)
        #expect(expiredSnapshot.activeAgents.isEmpty)
    }

    @Test
    func activeSessionOutsideRecentLimitContinuesToBeVerified() throws {
        let fileManager = FileManager.default
        let root = fileManager.temporaryDirectory.appendingPathComponent("CodexBarKnownActiveLimitTests-\(UUID().uuidString)")
        defer { try? fileManager.removeItem(at: root) }

        try writeSession(
            in: root,
            id: "older-active",
            folderName: "older-active",
            timestamp: date("2026-06-24T20:00:00.000Z"),
            completed: false
        )
        let reader = CodexStateReader(codexHome: root)
        reader.threadLimit = 1

        let activeSnapshot = reader.loadSnapshot(now: date("2026-06-24T20:00:30.000Z"))
        #expect(activeSnapshot.sessions.first?.id == "older-active")
        #expect(activeSnapshot.sessions.first?.isActive == true)

        try writeCompletedSession(
            in: root,
            id: "newer-completed",
            folderName: "newer-completed",
            timestamp: date("2026-06-24T20:05:00.000Z")
        )

        let laterSnapshot = reader.loadSnapshot(now: date("2026-06-24T20:05:30.000Z"))
        #expect(laterSnapshot.sessions.map(\.id).contains("older-active"))
        #expect(laterSnapshot.sessions.first(where: { $0.id == "older-active" })?.isActive == true)
    }

    @Test
    func transientUnreadableSessionFileKeepsLastGoodParse() throws {
        let fileManager = FileManager.default
        let root = fileManager.temporaryDirectory.appendingPathComponent("CodexBarUnreadableActiveTests-\(UUID().uuidString)")
        defer { try? fileManager.removeItem(at: root) }

        let rollout = try writeSession(
            in: root,
            id: "active-thread",
            folderName: "active",
            timestamp: date("2026-06-24T20:00:00.000Z"),
            completed: false
        )
        let reader = CodexStateReader(codexHome: root)

        let activeSnapshot = reader.loadSnapshot(now: date("2026-06-24T20:00:30.000Z"))
        #expect(activeSnapshot.sessions.first?.isActive == true)

        try Data([0xff, 0xfe]).write(to: rollout, options: .atomic)
        try fileManager.setAttributes([.modificationDate: date("2026-06-24T20:00:31.000Z")], ofItemAtPath: rollout.path)

        let recoveredSnapshot = reader.loadSnapshot(now: date("2026-06-24T20:00:32.000Z"))
        #expect(recoveredSnapshot.sessions.first?.id == "active-thread")
        #expect(recoveredSnapshot.sessions.first?.isActive == true)
        #expect(recoveredSnapshot.activeAgents.first?.id == "active-thread")

        let expiredSnapshot = reader.loadSnapshot(now: date("2026-06-24T20:00:36.000Z"))
        #expect(expiredSnapshot.sessions.isEmpty)
        #expect(expiredSnapshot.activeAgents.isEmpty)
    }

    @Test
    func defaultReaderUsesCodexHomeEnvironment() throws {
        let fileManager = FileManager.default
        let root = fileManager.temporaryDirectory.appendingPathComponent("CodexBarEnvTests-\(UUID().uuidString)")
        defer { try? fileManager.removeItem(at: root) }

        try writeActiveSession(in: root)

        let reader = CodexStateReader(environment: ["CODEX_HOME": root.path])
        let snapshot = reader.loadSnapshot(now: date("2026-06-24T20:00:30.000Z"))

        #expect(snapshot.sessions.count == 1)
        #expect(snapshot.sessions.first?.title == "ripple-effect")
    }

    @Test
    func codexHomeResolverFallsBackToDefaultForMissingOrBlankEnvironment() {
        let expected = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".codex")

        #expect(CodexStateReader.resolveCodexHome(environment: [:]) == expected)
        #expect(CodexStateReader.resolveCodexHome(environment: ["CODEX_HOME": "   "]) == expected)
    }

    @Test
    func codexHomeResolverExpandsTilde() {
        let resolved = CodexStateReader.resolveCodexHome(environment: ["CODEX_HOME": "~/custom-codex"])
        let expected = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("custom-codex")

        #expect(resolved == expected.standardizedFileURL)
    }

    @Test
    func missingSessionsDirectoryReturnsEmptySnapshot() {
        let fileManager = FileManager.default
        let root = fileManager.temporaryDirectory.appendingPathComponent("CodexBarMissingSessionsTests-\(UUID().uuidString)")
        defer { try? fileManager.removeItem(at: root) }
        let now = date("2026-06-24T20:00:00.000Z")

        let snapshot = CodexStateReader(codexHome: root).loadSnapshot(now: now)

        #expect(snapshot.activeAgents.isEmpty)
        #expect(snapshot.sessions.isEmpty)
        #expect(snapshot.usage == nil)
        #expect(snapshot.generatedAt == now)
        #expect(snapshot.lastError == nil)
    }

    private struct TokenSnapshot {
        let capturedAt: Date
        let primaryUsed: Double
        let secondaryUsed: Double
    }

    private func writeActiveSession(in root: URL) throws {
        try writeSession(
            in: root,
            id: "thread-1",
            folderName: "ripple-effect",
            timestamp: date("2026-06-24T20:00:00.000Z"),
            completed: false
        )
    }

    private func writeCompletedSession(
        in root: URL,
        id: String,
        folderName: String,
        timestamp: Date? = nil
    ) throws {
        try writeSession(
            in: root,
            id: id,
            folderName: folderName,
            timestamp: timestamp ?? date("2026-06-24T20:00:00.000Z"),
            completed: true
        )
    }

    @discardableResult
    private func writeSession(
        in root: URL,
        id: String,
        folderName: String,
        timestamp: Date,
        taskStartedAt: Date? = nil,
        lastToolAt: Date? = nil,
        toolName: String = "exec_command",
        completed: Bool,
        originator: String = "Codex Desktop",
        source: String = "vscode",
        importedSessionID: String? = nil,
        forkedFromID: String? = nil,
        tokenSnapshot: TokenSnapshot? = nil
    ) throws -> URL {
        let fileManager = FileManager.default
        let sessions = root.appendingPathComponent("sessions/2026/06/24")
        try fileManager.createDirectory(at: sessions, withIntermediateDirectories: true)

        let timestampText = iso8601(timestamp)
        let rollout = sessions.appendingPathComponent("rollout-2026-06-24T20-00-00-\(id).jsonl")
        let forkedFromField = forkedFromID.map { #","forked_from_id":"\#($0)""# } ?? ""
        var lines = [
            """
            {"timestamp":"\(timestampText)","type":"session_meta","payload":{"id":"\(id)","timestamp":"\(timestampText)","cwd":"/tmp/\(folderName)","originator":"\(originator)","source":"\(source)","thread_source":"user"\(forkedFromField)}}
            """,
        ]

        if let importedSessionID {
            lines.append(
                """
                {"timestamp":"\(timestampText)","type":"session_meta","payload":{"id":"\(importedSessionID)","timestamp":"\(timestampText)","cwd":"/tmp/\(folderName)","originator":"\(originator)","source":"\(source)","thread_source":"user"}}
                """
            )
        }

        if let tokenSnapshot {
            lines.append(
                """
                {"timestamp":"\(iso8601(tokenSnapshot.capturedAt))","type":"event_msg","payload":{"type":"token_count","rate_limits":{"primary":{"used_percent":\(tokenSnapshot.primaryUsed),"window_minutes":300,"resets_at":1782349443},"secondary":{"used_percent":\(tokenSnapshot.secondaryUsed),"window_minutes":10080,"resets_at":1782590010},"plan_type":"pro"}}}
                """
            )
        }

        let taskStartedAt = taskStartedAt ?? date("2026-06-24T20:00:05.000Z")
        let lastToolAt = lastToolAt ?? date("2026-06-24T20:00:10.000Z")
        lines.append(contentsOf: [
            """
            {"timestamp":"\(iso8601(taskStartedAt))","type":"event_msg","payload":{"type":"task_started"}}
            """,
            """
            {"timestamp":"\(iso8601(lastToolAt))","type":"response_item","payload":{"type":"function_call","name":"\(toolName)"}}
            """,
        ])

        if completed {
            lines.append(
                """
                {"timestamp":"\(iso8601(lastToolAt.addingTimeInterval(10)))","type":"event_msg","payload":{"type":"task_complete"}}
                """
            )
        }

        let jsonl = lines.joined(separator: "\n")
        try jsonl.write(to: rollout, atomically: true, encoding: .utf8)
        try fileManager.setAttributes([.modificationDate: timestamp], ofItemAtPath: rollout.path)
        return rollout
    }

    private func writeGlobalState(in root: URL, unreadThreadIDs: [String]) throws {
        try writeGlobalState(in: root, unreadThreadIDsByHost: ["local": unreadThreadIDs])
    }

    private func writeGlobalState(in root: URL, unreadThreadIDsByHost: [String: [String]]) throws {
        let hosts = unreadThreadIDsByHost
            .map { hostID, threadIDs in
                let ids = threadIDs
                    .map { "\"\($0)\"" }
                    .joined(separator: ",")
                return "\"\(hostID)\":[\(ids)]"
            }
            .joined(separator: ",")
        let json = """
        {"electron-persisted-atom-state":{"unread-thread-ids-by-host-v1":{\(hosts)}}}
        """
        try json.write(to: root.appendingPathComponent(".codex-global-state.json"), atomically: true, encoding: .utf8)
    }

    private func appendLine(_ line: String, to fileURL: URL, modifiedAt: Date) throws {
        let handle = try FileHandle(forWritingTo: fileURL)
        defer { try? handle.close() }
        try handle.seekToEnd()
        try handle.write(contentsOf: Data("\n\(line)".utf8))
        try FileManager.default.setAttributes([.modificationDate: modifiedAt], ofItemAtPath: fileURL.path)
    }

    private func date(_ value: String) -> Date {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter.date(from: value)!
    }

    private func iso8601(_ value: Date) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter.string(from: value)
    }
}
