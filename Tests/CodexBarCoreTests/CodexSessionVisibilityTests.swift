import Foundation
import Testing
@testable import CodexBarCore

@Suite
struct CodexSessionVisibilityTests {
    @Test
    func activeSessionsAreVisible() {
        let session = codexSession(
            activeStartedAt: date("2026-06-24T20:00:05.000Z"),
            lastEventAt: date("2026-06-24T20:00:10.000Z"),
            isUnread: false
        )

        #expect(session.isVisibleInSessionMenu == true)
    }

    @Test
    func inactiveSessionsUseCodexUnreadState() {
        let readSession = codexSession(
            activeStartedAt: nil,
            lastEventAt: date("2026-06-24T20:00:10.000Z"),
            isUnread: false
        )
        let unreadSession = codexSession(
            activeStartedAt: nil,
            lastEventAt: date("2026-06-24T20:00:10.000Z"),
            isUnread: true
        )

        #expect(readSession.isVisibleInSessionMenu == false)
        #expect(unreadSession.isVisibleInSessionMenu == true)
    }

    @Test
    func activeAgentUsesThinkingFallbackForBlankStatus() {
        let parsed = ParsedRollout(
            path: "/tmp/thread.jsonl",
            latestEventAt: date("2026-06-24T20:00:10.000Z"),
            latestTaskStartedAt: date("2026-06-24T20:00:00.000Z"),
            latestTaskCompletedAt: nil,
            latestStatusLabel: "",
            usage: nil
        )

        let active = parsed.activeAgent(
            thread: ThreadRecord(id: "thread-1", title: "Codex", rolloutPath: "/tmp/thread.jsonl", cwd: "/tmp", updatedAt: nil),
            now: date("2026-06-24T20:00:20.000Z"),
            staleAfter: 60
        )

        #expect(active?.label == "Thinking...")
    }

    @Test
    func usageWindowLeftPercentIsClamped() {
        let overUsed = UsageWindow(label: "5h", usedPercent: 125, windowMinutes: nil, resetsAt: nil)
        let underUsed = UsageWindow(label: "5h", usedPercent: -10, windowMinutes: nil, resetsAt: nil)

        #expect(overUsed.leftPercent == 0)
        #expect(underUsed.leftPercent == 100)
    }

    private func codexSession(activeStartedAt: Date?, lastEventAt: Date?, isUnread: Bool) -> CodexSession {
        CodexSession(
            id: "thread-1",
            title: "ripple-effect",
            rolloutPath: "/tmp/thread.jsonl",
            cwd: "/tmp/ripple-effect",
            client: .app,
            updatedAt: date("2026-06-24T20:00:00.000Z"),
            activeStartedAt: activeStartedAt,
            lastEventAt: lastEventAt,
            statusLabel: nil,
            isUnread: isUnread
        )
    }

    private func date(_ value: String) -> Date {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter.date(from: value)!
    }
}
