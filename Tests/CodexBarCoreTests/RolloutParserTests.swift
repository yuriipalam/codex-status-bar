import Foundation
import Testing
@testable import CodexBarCore

@Suite
struct RolloutParserTests {
    private let parser = RolloutParser()

    @Test
    func completedTurnIsIdle() {
        let parsed = parser.parse(lines: [
            event("2026-06-24T20:00:00.000Z", "task_started"),
            event("2026-06-24T20:01:00.000Z", "task_complete"),
        ])

        #expect(!parsed.hasOpenTask)
        #expect(parsed.activeAgent(thread: thread(), now: date("2026-06-24T20:02:00.000Z"), staleAfter: 600) == nil)
    }

    @Test
    func activeTurnMapsCommandLabel() {
        let parsed = parser.parse(lines: [
            event("2026-06-24T20:00:00.000Z", "task_started"),
            responseItem("2026-06-24T20:00:10.000Z", type: "function_call", fields: ["name": "exec_command"]),
        ])

        let active = parsed.activeAgent(thread: thread(), now: date("2026-06-24T20:00:20.000Z"), staleAfter: 600)
        #expect(active?.label == "Running command")
        #expect(active?.title == "Build Codex status bar")
    }

    @Test
    func approvalRequiredCommandShowsWaitingForApproval() {
        let parsed = parser.parse(lines: [
            event("2026-06-24T20:00:00.000Z", "task_started"),
            #"""
            {"timestamp":"2026-06-24T20:00:10.000Z","type":"response_item","payload":{"type":"function_call","name":"exec_command","arguments":"{\"cmd\":\"printf 'ok'\",\"workdir\":\"/tmp\",\"sandbox_permissions\":\"require_escalated\",\"justification\":\"Do you want to run this?\"}"}}
            """#,
        ])

        let active = parsed.activeAgent(thread: thread(), now: date("2026-06-24T20:00:20.000Z"), staleAfter: 600)
        #expect(parsed.latestStatusLabel == "Waiting for approval")
        #expect(active?.label == "Waiting for approval")
    }

    @Test
    func approvalRequiredCommandOutputStillReviewsCommandOutput() {
        let parsed = parser.parse(lines: [
            event("2026-06-24T20:00:00.000Z", "task_started"),
            #"""
            {"timestamp":"2026-06-24T20:00:10.000Z","type":"response_item","payload":{"type":"function_call","name":"exec_command","arguments":"{\"cmd\":\"printf 'ok'\",\"workdir\":\"/tmp\",\"sandbox_permissions\":\"require_escalated\",\"justification\":\"Do you want to run this?\"}"}}
            """#,
            responseItem("2026-06-24T20:00:15.000Z", type: "function_call_output", fields: [:]),
        ])

        #expect(parsed.latestStatusLabel == "Reviewing output")
    }

    @Test
    func multipleOpenRolloutsCanBeCountedAsActiveAgents() {
        let first = parser.parse(lines: [
            event("2026-06-24T20:00:00.000Z", "task_started"),
            responseItem("2026-06-24T20:00:10.000Z", type: "function_call", fields: ["name": "exec_command"]),
        ])
        let second = parser.parse(lines: [
            event("2026-06-24T20:01:00.000Z", "task_started"),
            responseItem("2026-06-24T20:01:10.000Z", type: "function_call", fields: ["name": "apply_patch"]),
        ])

        let now = date("2026-06-24T20:01:20.000Z")
        let activeAgents = [
            first.activeAgent(thread: thread(id: "thread-1", title: "First"), now: now, staleAfter: 600),
            second.activeAgent(thread: thread(id: "thread-2", title: "Second"), now: now, staleAfter: 600),
        ].compactMap { $0 }

        #expect(activeAgents.count == 2)
        #expect(activeAgents.map(\.label) == ["Running command", "Editing"])
    }

    @Test
    func multipleToolLabelsReturnToThinkingAfterOutput() {
        let parsed = parser.parse(lines: [
            event("2026-06-24T20:00:00.000Z", "task_started"),
            responseItem("2026-06-24T20:00:05.000Z", type: "function_call", fields: ["name": "apply_patch"]),
            responseItem("2026-06-24T20:00:07.000Z", type: "function_call_output", fields: [:]),
            responseItem("2026-06-24T20:00:09.000Z", type: "web_search_call", fields: [:]),
        ])

        let active = parsed.activeAgent(thread: thread(), now: date("2026-06-24T20:00:10.000Z"), staleAfter: 600)
        #expect(active?.label == "Searching web")
    }

    @Test
    func functionCallOutputShowsReviewingOutput() {
        let parsed = parser.parse(lines: [
            event("2026-06-24T20:00:00.000Z", "task_started"),
            responseItem("2026-06-24T20:00:05.000Z", type: "function_call", fields: ["name": "exec_command"]),
            responseItem("2026-06-24T20:00:07.000Z", type: "function_call_output", fields: [:]),
        ])

        #expect(parsed.latestStatusLabel == "Reviewing output")
    }

    @Test
    func customToolCallMapsToEditing() {
        let parsed = parser.parse(lines: [
            event("2026-06-24T20:00:00.000Z", "task_started"),
            responseItem("2026-06-24T20:00:05.000Z", type: "custom_tool_call", fields: ["name": "apply_patch"]),
        ])

        #expect(parsed.latestStatusLabel == "Editing")
    }

    @Test
    func reasoningAndGoalEventsAreLabeled() {
        let parsed = parser.parse(lines: [
            event("2026-06-24T20:00:00.000Z", "task_started"),
            responseItem("2026-06-24T20:00:05.000Z", type: "reasoning", fields: [:]),
            event("2026-06-24T20:00:07.000Z", "thread_goal_updated"),
        ])

        #expect(parsed.latestStatusLabel == "Updating goal")
    }

    @Test
    func malformedLinesAreIgnored() {
        let parsed = parser.parse(lines: [
            "{not json",
            event("2026-06-24T20:00:00.000Z", "task_started"),
            "",
            responseItem("2026-06-24T20:00:05.000Z", type: "function_call", fields: ["name": "read_mcp_resource"]),
        ])

        #expect(parsed.hasOpenTask)
        #expect(parsed.latestStatusLabel == "Reading")
    }

    @Test
    func missingTokenSnapshotReturnsNilUsage() {
        let parsed = parser.parse(lines: [
            event("2026-06-24T20:00:00.000Z", "task_started"),
        ])

        #expect(parsed.usage == nil)
    }

    @Test
    func tokenSnapshotParsesPrimaryAndSecondaryLimits() {
        let parsed = parser.parse(lines: [
            """
            {"timestamp":"2026-06-24T20:00:00.000Z","type":"event_msg","payload":{"type":"token_count","rate_limits":{"primary":{"used_percent":12,"window_minutes":300,"resets_at":1782349443},"secondary":{"used_percent":46.5,"window_minutes":10080,"resets_at":1782590010},"plan_type":"prolite"}}}
            """,
        ])

        #expect(parsed.usage?.primary?.label == "5h")
        #expect(parsed.usage?.primary?.leftPercent == 88)
        #expect(parsed.usage?.secondary?.label == "week")
        #expect(parsed.usage?.secondary?.leftPercent == 53.5)
        #expect(parsed.usage?.planType == "prolite")
    }

    @Test
    func tokenSnapshotParsesCamelCaseLimitFields() {
        let parsed = parser.parse(lines: [
            """
            {"timestamp":"2026-06-24T20:00:00.000Z","type":"event_msg","payload":{"type":"token_count","rateLimits":{"primary":{"usedPercent":"12.5","windowDurationMins":"300","resetsAt":"1782349443"},"secondary":{"usedPercent":46,"windowDurationMins":10080,"resetsAt":1782590010},"planType":"pro"}}}
            """,
        ])

        #expect(parsed.usage?.primary?.leftPercent == 87.5)
        #expect(parsed.usage?.primary?.windowMinutes == 300)
        #expect(parsed.usage?.primary?.resetsAt == Date(timeIntervalSince1970: 1_782_349_443))
        #expect(parsed.usage?.secondary?.leftPercent == 54)
        #expect(parsed.usage?.planType == "pro")
    }

    @Test
    func tokenSnapshotRequiresAtLeastOneValidWindow() {
        let parsed = parser.parse(lines: [
            """
            {"timestamp":"2026-06-24T20:00:00.000Z","type":"event_msg","payload":{"type":"token_count","rate_limits":{"primary":{"window_minutes":300},"secondary":{"resets_at":1782590010},"plan_type":"pro"}}}
            """,
        ])

        #expect(parsed.usage == nil)
    }

    @Test
    func sessionMetadataIsParsedWithoutConversationContent() {
        let parsed = parser.parse(lines: [
            """
            {"timestamp":"2026-06-24T20:00:00.000Z","type":"session_meta","payload":{"session_id":"thread-1","id":"thread-1","timestamp":"2026-06-24T19:59:58.000Z","cwd":"/Users/yurii/Documents/codex-bar","originator":"Codex Desktop","source":"vscode","thread_source":"user"}}
            """,
        ])

        #expect(parsed.metadata?.id == "thread-1")
        #expect(parsed.metadata?.cwd == "/Users/yurii/Documents/codex-bar")
        #expect(parsed.metadata?.client == .app)
        #expect(parsed.metadata?.threadSource == "user")
        #expect(parsed.metadata?.createdAt == date("2026-06-24T19:59:58.000Z"))
    }

    @Test
    func continuedThreadKeepsFirstMetadataAndTracksImportedIDs() {
        let parsed = parser.parse(lines: [
            """
            {"timestamp":"2026-06-27T18:17:56.747Z","type":"session_meta","payload":{"session_id":"continued-thread","id":"continued-thread","timestamp":"2026-06-27T18:17:56.747Z","cwd":"/Users/yurii/Documents/codex-bar","originator":"Codex Desktop","source":"vscode","thread_source":"user"}}
            """,
            """
            {"timestamp":"2026-06-27T18:17:56.748Z","type":"session_meta","payload":{"session_id":"imported-thread","id":"imported-thread","timestamp":"2026-06-27T18:17:56.748Z","cwd":"/Users/yurii/Documents/codex-bar","originator":"Codex Desktop","source":"vscode","thread_source":"user"}}
            """,
            """
            {"timestamp":"2026-06-27T18:17:57.000Z","type":"event_msg","payload":{"type":"task_started"}}
            """,
        ])

        #expect(parsed.metadata?.id == "continued-thread")
        #expect(parsed.relatedSessionIDs == ["imported-thread"])
    }

    @Test
    func forkedThreadKeepsParentIDOutOfRelatedAliases() {
        let parsed = parser.parse(lines: [
            """
            {"timestamp":"2026-06-27T18:17:56.747Z","type":"session_meta","payload":{"session_id":"side-thread","id":"side-thread","forked_from_id":"parent-thread","timestamp":"2026-06-27T18:17:56.747Z","cwd":"/Users/yurii/Documents/codex-bar","originator":"Codex Desktop","source":"vscode","thread_source":"user"}}
            """,
            """
            {"timestamp":"2026-06-27T18:17:56.748Z","type":"session_meta","payload":{"session_id":"parent-thread","id":"parent-thread","timestamp":"2026-06-27T18:17:56.748Z","cwd":"/Users/yurii/Documents/codex-bar","originator":"Codex Desktop","source":"vscode","thread_source":"user"}}
            """,
            """
            {"timestamp":"2026-06-27T18:17:57.000Z","type":"event_msg","payload":{"type":"task_started"}}
            """,
        ])

        #expect(parsed.metadata?.id == "side-thread")
        #expect(parsed.metadata?.forkedFromID == "parent-thread")
        #expect(parsed.forkedFromID == "parent-thread")
        #expect(parsed.relatedSessionIDs.isEmpty)
    }

    @Test
    func sessionClientClassifiesAppCliAndIDE() {
        #expect(CodexSessionClient.classify(originator: "Codex Desktop") == .app)
        #expect(CodexSessionClient.classify(originator: "codex_vscode") == .ide)
        #expect(CodexSessionClient.classify(originator: "codex_cli") == .cli)
        #expect(CodexSessionClient.classify(originator: nil) == nil)
        #expect(CodexSessionClient.classify(originator: "unknown") == nil)
    }

    @Test
    func staleOpenTurnIsNotActive() {
        let parsed = parser.parse(lines: [
            event("2026-06-24T20:00:00.000Z", "task_started"),
            responseItem("2026-06-24T20:00:10.000Z", type: "function_call", fields: ["name": "exec_command"]),
        ])

        #expect(parsed.activeAgent(thread: thread(), now: date("2026-06-24T21:00:11.000Z"), staleAfter: 3_600) == nil)
    }

    @Test
    func turnAbortedClosesOpenTask() {
        let parsed = parser.parse(lines: [
            event("2026-06-24T20:00:00.000Z", "task_started"),
            responseItem("2026-06-24T20:00:05.000Z", type: "function_call", fields: ["name": "exec_command"]),
            event("2026-06-24T20:00:10.000Z", "turn_aborted"),
        ])

        #expect(parsed.hasOpenTask == false)
        #expect(parsed.latestStatusLabel == nil)
    }

    @Test
    func newerStartAfterOlderCompletionReopensTask() {
        let parsed = parser.parse(lines: [
            event("2026-06-24T20:00:00.000Z", "task_started"),
            event("2026-06-24T20:00:10.000Z", "task_complete"),
            event("2026-06-24T20:01:00.000Z", "task_started"),
            responseItem("2026-06-24T20:01:05.000Z", type: "function_call", fields: ["name": "tool_search_tool"]),
        ])

        #expect(parsed.hasOpenTask == true)
        #expect(parsed.latestStatusLabel == "Searching tools")
    }

    @Test
    func sameTimestampStartAfterCompletionReopensByEventOrder() {
        let parsed = parser.parse(lines: [
            event("2026-06-27T18:17:56.776Z", "task_started"),
            event("2026-06-27T18:17:56.776Z", "task_complete"),
            event("2026-06-27T18:17:56.776Z", "task_started"),
            event("2026-06-27T18:17:56.777Z", "context_compacted"),
        ])

        let active = parsed.activeAgent(thread: thread(), now: date("2026-06-27T18:17:57.000Z"), staleAfter: 60)

        #expect(parsed.hasOpenTask == true)
        #expect(parsed.latestStatusLabel == "Compacting context")
        #expect(active?.label == "Compacting context")
    }

    @Test
    func sameTimestampCompletionAfterStartClosesByEventOrder() {
        let parsed = parser.parse(lines: [
            event("2026-06-27T18:17:56.776Z", "task_started"),
            event("2026-06-27T18:17:56.776Z", "task_complete"),
        ])

        #expect(parsed.hasOpenTask == false)
        #expect(parsed.latestStatusLabel == nil)
    }

    @Test
    func lifecyclePayloadTimestampsDriveStartedAndCompletedTimes() {
        let parsed = parser.parse(lines: [
            """
            {"timestamp":"2026-06-27T18:17:56.776Z","type":"event_msg","payload":{"type":"task_started","turn_id":"turn-1","started_at":1782573078}}
            """,
            event("2026-06-27T18:17:56.777Z", "context_compacted"),
            """
            {"timestamp":"2026-06-27T18:17:56.780Z","type":"event_msg","payload":{"type":"task_complete","turn_id":"turn-1","completed_at":1782573429}}
            """,
        ])

        #expect(parsed.latestTaskStartedAt == Date(timeIntervalSince1970: 1_782_573_078))
        #expect(parsed.latestTaskCompletedAt == Date(timeIntervalSince1970: 1_782_573_429))
        #expect(parsed.hasOpenTask == false)
    }

    @Test
    func statusEventsAfterCompletionDoNotReopenTask() {
        let parsed = parser.parse(lines: [
            event("2026-06-24T20:00:00.000Z", "task_started"),
            event("2026-06-24T20:00:10.000Z", "task_complete"),
            responseItem("2026-06-24T20:00:15.000Z", type: "function_call", fields: ["name": "apply_patch"]),
        ])

        #expect(parsed.hasOpenTask == false)
        #expect(parsed.latestStatusLabel == nil)
    }

    @Test
    func mcpToolEventsMapStartAndEndLabels() {
        let parsed = parser.parse(lines: [
            event("2026-06-24T20:00:00.000Z", "task_started"),
            mcpToolEvent("2026-06-24T20:00:05.000Z", payloadType: "mcp_tool_call_start", server: "node_repl", tool: "js"),
            mcpToolEvent("2026-06-24T20:00:10.000Z", payloadType: "mcp_tool_call_end", server: "node_repl", tool: "js"),
        ])

        #expect(parsed.latestStatusLabel == "Reviewing output")
    }

    @Test
    func webSearchAndToolSearchOutputReturnToReviewLabels() {
        let parsed = parser.parse(lines: [
            event("2026-06-24T20:00:00.000Z", "task_started"),
            responseItem("2026-06-24T20:00:05.000Z", type: "web_search_call", fields: [:]),
            event("2026-06-24T20:00:10.000Z", "web_search_end"),
            responseItem("2026-06-24T20:00:15.000Z", type: "tool_search_call", fields: [:]),
            responseItem("2026-06-24T20:00:20.000Z", type: "tool_search_output", fields: [:]),
        ])

        #expect(parsed.latestStatusLabel == "Reading results")
    }

    @Test
    func messageAndAgentEventsShowWritingUpdate() {
        let messageParsed = parser.parse(lines: [
            event("2026-06-24T20:00:00.000Z", "task_started"),
            responseItem("2026-06-24T20:00:05.000Z", type: "message", fields: [:]),
        ])
        let agentMessageParsed = parser.parse(lines: [
            event("2026-06-24T20:00:00.000Z", "task_started"),
            event("2026-06-24T20:00:05.000Z", "agent_message"),
        ])

        #expect(messageParsed.latestStatusLabel == "Writing update")
        #expect(agentMessageParsed.latestStatusLabel == "Writing update")
    }

    @Test
    func compactAndPatchEventsUpdateStatus() {
        let compacted = parser.parse(lines: [
            event("2026-06-24T20:00:00.000Z", "task_started"),
            event("2026-06-24T20:00:05.000Z", "context_compacted"),
        ])
        let patched = parser.parse(lines: [
            event("2026-06-24T20:00:00.000Z", "task_started"),
            event("2026-06-24T20:00:05.000Z", "patch_apply_end"),
        ])

        #expect(compacted.latestStatusLabel == "Compacting context")
        #expect(patched.latestStatusLabel == "Editing")
    }

    @Test
    func tokenCountWithoutRateLimitsIsIgnored() {
        let parsed = parser.parse(lines: [
            """
            {"timestamp":"2026-06-24T20:00:00.000Z","type":"event_msg","payload":{"type":"token_count","total_token_usage":{"input_tokens":10}}}
            """,
        ])

        #expect(parsed.usage == nil)
    }

    @Test
    func conversionHelpersHandleSupportedNumericTypes() {
        #expect(doubleValue(Float(12.5)) == 12.5)
        #expect(doubleValue(12) == 12)
        #expect(doubleValue(Int64(13)) == 13)
        #expect(doubleValue(NSNumber(value: 14.5)) == 14.5)
        #expect(doubleValue("bad") == nil)

        #expect(intValue(Int64(15)) == 15)
        #expect(intValue(NSNumber(value: 16)) == 16)
        #expect(intValue(Date()) == nil)
    }

    @Test
    func parseFileReturnsEmptyRolloutForUnreadableFile() {
        let fileURL = URL(fileURLWithPath: "/tmp/does-not-exist-\(UUID().uuidString).jsonl")

        let parsed = parser.parse(fileURL: fileURL)

        #expect(parsed.path == fileURL.path)
        #expect(parsed.latestEventAt == nil)
        #expect(parsed.hasOpenTask == false)
        #expect(parsed.usage == nil)
        #expect(parsed.metadata == nil)
    }

    private func thread(id: String = "thread-1", title: String = "Build Codex status bar") -> ThreadRecord {
        ThreadRecord(
            id: id,
            title: title,
            rolloutPath: "/tmp/thread.jsonl",
            cwd: "/tmp",
            updatedAt: nil
        )
    }

    private func event(_ timestamp: String, _ type: String) -> String {
        """
        {"timestamp":"\(timestamp)","type":"event_msg","payload":{"type":"\(type)"}}
        """
    }

    private func responseItem(_ timestamp: String, type: String, fields: [String: String]) -> String {
        var payload = fields.map { #""\#($0.key)":"\#($0.value)""# }.joined(separator: ",")
        if !payload.isEmpty {
            payload = "," + payload
        }
        return """
        {"timestamp":"\(timestamp)","type":"response_item","payload":{"type":"\(type)"\(payload)}}
        """
    }

    private func mcpToolEvent(_ timestamp: String, payloadType: String, server: String, tool: String) -> String {
        """
        {"timestamp":"\(timestamp)","type":"event_msg","payload":{"type":"\(payloadType)","invocation":{"server":"\(server)","tool":"\(tool)"}}}
        """
    }

    private func date(_ value: String) -> Date {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter.date(from: value)!
    }
}
