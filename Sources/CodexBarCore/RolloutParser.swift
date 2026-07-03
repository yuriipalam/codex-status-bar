import Foundation

public final class RolloutParser {
    public init() {}

    public func parse(fileURL: URL) -> ParsedRollout {
        guard let contents = try? String(contentsOf: fileURL, encoding: .utf8) else {
            return ParsedRollout(
                path: fileURL.path,
                latestEventAt: nil,
                latestTaskStartedAt: nil,
                latestTaskCompletedAt: nil,
                latestStatusLabel: nil,
                usage: nil
            )
        }

        return parse(lines: contents.split(separator: "\n", omittingEmptySubsequences: false).map(String.init), path: fileURL.path)
    }

    public func parse(lines: [String], path: String = "") -> ParsedRollout {
        var latestEventAt: Date?
        var latestTaskStartedAt: Date?
        var latestTaskCompletedAt: Date?
        var latestStatusLabel: String?
        var latestToolLabel: String?
        var latestUsage: UsageSnapshot?
        var metadata: SessionMetadata?
        var importedSessionIDs: Set<String> = []
        var forkedFromID: String?
        var hasOpenTask = false

        func taskCurrentlyOpen() -> Bool {
            hasOpenTask
        }

        for line in lines where !line.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            guard
                let data = line.data(using: .utf8),
                let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
            else {
                continue
            }

            let timestamp = DateParsing.parseISO8601(root["timestamp"] as? String)
            if let timestamp, latestEventAt.map({ timestamp > $0 }) ?? true {
                latestEventAt = timestamp
            }

            let type = root["type"] as? String
            let payload = root["payload"] as? [String: Any] ?? [:]

            if type == "session_meta" {
                let parsedMetadata = parseSessionMetadata(from: payload, rootTimestamp: timestamp)
                if let parsedForkedFromID = parsedMetadata.forkedFromID?.nilIfEmpty,
                   parsedForkedFromID != parsedMetadata.id {
                    forkedFromID = parsedForkedFromID
                }

                if metadata == nil || metadata?.id?.nilIfEmpty == nil {
                    metadata = parsedMetadata
                } else if let id = parsedMetadata.id?.nilIfEmpty, id != metadata?.id {
                    importedSessionIDs.insert(id)
                }
            } else if type == "event_msg" {
                let payloadType = payload["type"] as? String
                switch payloadType {
                case "task_started":
                    latestTaskStartedAt = Self.lifecycleDate(payload["started_at"], fallback: timestamp)
                    hasOpenTask = true
                    latestStatusLabel = "Thinking..."
                    latestToolLabel = nil
                case "task_complete":
                    latestTaskCompletedAt = Self.lifecycleDate(payload["completed_at"], fallback: timestamp)
                    hasOpenTask = false
                    latestStatusLabel = nil
                    latestToolLabel = nil
                case "turn_aborted":
                    latestTaskCompletedAt = Self.lifecycleDate(payload["completed_at"], fallback: timestamp)
                    hasOpenTask = false
                    latestStatusLabel = nil
                    latestToolLabel = nil
                case "token_count":
                    if let timestamp, let usage = parseUsage(from: payload, capturedAt: timestamp) {
                        latestUsage = usage
                    }
                case "agent_message":
                    if taskCurrentlyOpen() {
                        latestStatusLabel = "Writing update"
                    }
                case "context_compacted":
                    if taskCurrentlyOpen() {
                        latestStatusLabel = "Compacting context"
                    }
                case "thread_goal_updated":
                    if taskCurrentlyOpen() {
                        latestToolLabel = "Updating goal"
                        latestStatusLabel = "Updating goal"
                    }
                case "patch_apply_end":
                    if taskCurrentlyOpen() {
                        latestToolLabel = "Editing"
                        latestStatusLabel = "Editing"
                    }
                case "web_search_end":
                    if taskCurrentlyOpen() {
                        latestStatusLabel = StatusLabelMapper.reviewLabel(after: "Searching web")
                    }
                case "mcp_tool_call_start", "mcp_tool_call_end":
                    if taskCurrentlyOpen() {
                        let invocation = payload["invocation"] as? [String: Any]
                        let label = StatusLabelMapper.label(
                            forMCPServer: invocation?["server"] as? String,
                            toolName: invocation?["tool"] as? String
                        )
                        latestToolLabel = label
                        latestStatusLabel = payloadType == "mcp_tool_call_start"
                            ? label
                            : StatusLabelMapper.reviewLabel(after: label)
                    }
                default:
                    break
                }
            } else if type == "response_item" {
                let payloadType = payload["type"] as? String
                switch payloadType {
                case "reasoning":
                    if taskCurrentlyOpen() {
                        latestStatusLabel = "Reasoning"
                    }
                case "message":
                    if taskCurrentlyOpen() {
                        latestStatusLabel = "Writing update"
                    }
                case "function_call", "custom_tool_call":
                    if taskCurrentlyOpen() {
                        let label = StatusLabelMapper.label(forToolName: payload["name"] as? String)
                        latestToolLabel = label
                        latestStatusLabel = label
                    }
                case "function_call_output", "custom_tool_call_output":
                    if taskCurrentlyOpen() {
                        latestStatusLabel = StatusLabelMapper.reviewLabel(after: latestToolLabel)
                    }
                case "web_search_call":
                    if taskCurrentlyOpen() {
                        latestToolLabel = "Searching web"
                        latestStatusLabel = "Searching web"
                    }
                case "tool_search_call":
                    if taskCurrentlyOpen() {
                        latestToolLabel = "Searching tools"
                        latestStatusLabel = "Searching tools"
                    }
                case "tool_search_output":
                    if taskCurrentlyOpen() {
                        latestStatusLabel = StatusLabelMapper.reviewLabel(after: latestToolLabel)
                    }
                default:
                    break
                }
            }
        }

        return ParsedRollout(
            path: path,
            latestEventAt: latestEventAt,
            latestTaskStartedAt: latestTaskStartedAt,
            latestTaskCompletedAt: latestTaskCompletedAt,
            latestStatusLabel: latestStatusLabel,
            usage: latestUsage,
            metadata: metadata,
            relatedSessionIDs: forkedFromID == nil ? importedSessionIDs : [],
            forkedFromID: forkedFromID,
            hasOpenTask: hasOpenTask
        )
    }

    private static func lifecycleDate(_ value: Any?, fallback: Date?) -> Date? {
        doubleValue(value).map(Date.init(timeIntervalSince1970:)) ?? fallback
    }

    private func parseSessionMetadata(from payload: [String: Any], rootTimestamp: Date?) -> SessionMetadata {
        let timestamp = DateParsing.parseISO8601(payload["timestamp"] as? String) ?? rootTimestamp
        let id = (payload["id"] as? String)?.nilIfEmpty ?? (payload["session_id"] as? String)?.nilIfEmpty

        return SessionMetadata(
            id: id,
            cwd: payload["cwd"] as? String ?? "",
            originator: payload["originator"] as? String,
            source: payload["source"] as? String,
            threadSource: payload["thread_source"] as? String,
            forkedFromID: payload["forked_from_id"] as? String,
            createdAt: timestamp
        )
    }

    private func parseUsage(from payload: [String: Any], capturedAt: Date) -> UsageSnapshot? {
        guard let rateLimits = payload["rate_limits"] as? [String: Any] ?? payload["rateLimits"] as? [String: Any] else {
            return nil
        }

        let primary = (rateLimits["primary"] as? [String: Any]).flatMap {
            parseWindow($0, label: "5h")
        }
        let secondary = (rateLimits["secondary"] as? [String: Any]).flatMap {
            parseWindow($0, label: "week")
        }

        guard primary != nil || secondary != nil else {
            return nil
        }

        let planType = rateLimits["plan_type"] as? String ?? rateLimits["planType"] as? String
        return UsageSnapshot(primary: primary, secondary: secondary, planType: planType, capturedAt: capturedAt)
    }

    private func parseWindow(_ value: [String: Any], label: String) -> UsageWindow? {
        guard let usedPercent = doubleValue(value["used_percent"] ?? value["usedPercent"]) else {
            return nil
        }

        let windowMinutes = intValue(value["window_minutes"] ?? value["windowDurationMins"])
        let resetsAtSeconds = doubleValue(value["resets_at"] ?? value["resetsAt"])
        let resetsAt = resetsAtSeconds.map(Date.init(timeIntervalSince1970:))
        return UsageWindow(label: label, usedPercent: usedPercent, windowMinutes: windowMinutes, resetsAt: resetsAt)
    }
}

func doubleValue(_ value: Any?) -> Double? {
    switch value {
    case let value as Double:
        return value
    case let value as Float:
        return Double(value)
    case let value as Int:
        return Double(value)
    case let value as Int64:
        return Double(value)
    case let value as NSNumber:
        return value.doubleValue
    case let value as String:
        return Double(value)
    default:
        return nil
    }
}

func intValue(_ value: Any?) -> Int? {
    switch value {
    case let value as Int:
        return value
    case let value as Int64:
        return Int(value)
    case let value as NSNumber:
        return value.intValue
    case let value as String:
        return Int(value)
    default:
        return nil
    }
}
