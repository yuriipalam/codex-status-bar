import Foundation

public struct CodexBarDisplayOptions: Equatable, Sendable {
    public let showTimer: Bool
    public let showFiveHourUsage: Bool
    public let showWeeklyUsage: Bool

    public init(
        showTimer: Bool = true,
        showFiveHourUsage: Bool = true,
        showWeeklyUsage: Bool = true
    ) {
        self.showTimer = showTimer
        self.showFiveHourUsage = showFiveHourUsage
        self.showWeeklyUsage = showWeeklyUsage
    }
}

public struct CodexBarDisplayState: Equatable, Sendable {
    public let title: String
    public let animatesIcon: Bool
    public let statusDot: CodexBarStatusDot?

    public init(title: String, animatesIcon: Bool, statusDot: CodexBarStatusDot? = nil) {
        self.title = title
        self.animatesIcon = animatesIcon
        self.statusDot = statusDot
    }
}

public enum CodexBarStatusDot: Equatable, Sendable {
    case approval
    case unread
}

public struct CodexSessionMenuRow: Equatable, Sendable {
    public let id: String
    public let title: String
    public let clientBadge: String?
    public let timeText: String
    public let statusTooltip: String?
    public let isActive: Bool
    public let isUnread: Bool
    public let threadURL: URL?

    public init(
        id: String,
        title: String,
        clientBadge: String?,
        timeText: String,
        statusTooltip: String?,
        isActive: Bool,
        isUnread: Bool,
        threadURL: URL?
    ) {
        self.id = id
        self.title = title
        self.clientBadge = clientBadge
        self.timeText = timeText
        self.statusTooltip = statusTooltip
        self.isActive = isActive
        self.isUnread = isUnread
        self.threadURL = threadURL
    }
}

public enum CodexBarPresentation {
    public static func displayState(
        snapshot: CodexSnapshot,
        options: CodexBarDisplayOptions = CodexBarDisplayOptions(),
        now: Date
    ) -> CodexBarDisplayState {
        let activeAgents = snapshot.activeAgents

        if let approvalAgent = approvalPriorityAgent(from: activeAgents) {
            return CodexBarDisplayState(
                title: activeTitle("Awaiting approval", since: approvalAgent.startedAt, now: now, showTimer: options.showTimer),
                animatesIcon: activeAgents.contains { shouldAnimateActiveAgent($0) },
                statusDot: .approval
            )
        }

        if activeAgents.count == 1, let agent = activeAgents.first {
            return CodexBarDisplayState(
                title: activeTitle(shortStatusLabel(agent.label), since: agent.startedAt, now: now, showTimer: options.showTimer),
                animatesIcon: shouldAnimateActiveAgent(agent)
            )
        }

        if activeAgents.count > 1 {
            let youngestStart = activeAgents.map(\.startedAt).max() ?? now
            let anyAgentWorking = activeAgents.contains { shouldAnimateActiveAgent($0) }
            let status = anyAgentWorking ? "\(activeAgents.count) agents running" : "\(activeAgents.count) waiting"
            return CodexBarDisplayState(
                title: activeTitle(status, since: youngestStart, now: now, showTimer: options.showTimer),
                animatesIcon: anyAgentWorking
            )
        }

        let usage = compactMenuBarUsage(snapshot.usage, options: options)
        let unreadCount = snapshot.sessions.filter(\.isUnread).count
        if unreadCount > 0 {
            let unread = "\(unreadCount) unread"
            let title = usage.isEmpty ? unread : "\(unread) \(usage)"
            return CodexBarDisplayState(title: title, animatesIcon: false, statusDot: .unread)
        }

        return CodexBarDisplayState(title: usage.isEmpty ? "Idle" : usage, animatesIcon: false)
    }

    private static func approvalPriorityAgent(from activeAgents: [ActiveAgent]) -> ActiveAgent? {
        activeAgents
            .filter { isApprovalLabel($0.label) }
            .max {
                if $0.startedAt == $1.startedAt { return $0.title > $1.title }
                return $0.startedAt < $1.startedAt
            }
    }

    private static func shouldAnimateActiveAgent(_ agent: ActiveAgent) -> Bool {
        !isApprovalLabel(agent.label) && !isUserInputLabel(agent.label)
    }

    public static func compactMenuBarUsage(
        _ usage: UsageSnapshot?,
        options: CodexBarDisplayOptions
    ) -> String {
        var parts: [String] = []

        if options.showFiveHourUsage {
            if let primary = usage?.primary {
                parts.append("5h\(UsageFormatter.percent(primary.leftPercent))")
            } else {
                parts.append("5h --")
            }
        }

        if options.showWeeklyUsage {
            if let secondary = usage?.secondary {
                parts.append("w\(UsageFormatter.percent(secondary.leftPercent))")
            } else {
                parts.append("w --")
            }
        }

        return parts.joined(separator: " ")
    }

    public static func activeTitle(
        _ status: String,
        since start: Date,
        now: Date,
        showTimer: Bool
    ) -> String {
        guard showTimer else { return status }
        return "\(status) \(elapsedText(since: start, now: now))"
    }

    public static func elapsedText(since start: Date, now: Date) -> String {
        let seconds = max(0, Int(now.timeIntervalSince(start)))
        if seconds >= 3_600 {
            let hours = seconds / 3_600
            let minutes = (seconds % 3_600) / 60
            return "\(hours)h \(minutes)m"
        }
        if seconds >= 60 {
            let minutes = seconds / 60
            let remainder = seconds % 60
            return "\(minutes)m \(remainder)s"
        }
        return "\(seconds)s"
    }

    public static func isApprovalLabel(_ label: String) -> Bool {
        let lowercased = label.lowercased()
        return lowercased.contains("permission") ||
            lowercased.contains("approval") ||
            lowercased.contains("approve") ||
            lowercased.contains("authorization")
    }

    public static func isUserInputLabel(_ label: String) -> Bool {
        switch singleLine(label) {
        case "Waiting for input", "Needs input":
            return true
        default:
            return false
        }
    }

    public static func shortStatusLabel(_ label: String) -> String {
        switch singleLine(label) {
        case "Thinking...", "Reasoning":
            return "Thinking"
        case "Writing update",
             "Reviewing output", "Reviewing edits", "Reviewing data", "Reading results",
             "Checking app", "Checking goal",
             "Inspecting image",
             "Compacting context":
            return "Working"
        case "Applying settings":
            return "Settings"
        case "Rolling back":
            return "Rolling back"
        case "Searching web":
            return "Web search"
        case "Searching tools":
            return "Tool search"
        case "Searching files":
            return "Searching"
        case "Viewing image":
            return "Viewing"
        case "Creating image":
            return "Image"
        case "Sending input":
            return "Writing"
        case "Running JS":
            return "Running JS"
        case "Reading email":
            return "Email"
        case "Querying data":
            return "Querying"
        case "Waiting for input", "Needs input":
            return "Waiting for input"
        case "Using tools":
            return "Using tools"
        default:
            return singleLine(label)
        }
    }

    public static func visibleMenuSessions(
        snapshot: CodexSnapshot,
        limit: Int
    ) -> [CodexSession] {
        Array(snapshot.sessions.filter(\.isVisibleInSessionMenu).prefix(limit))
    }

    public static func sessionRows(
        snapshot: CodexSnapshot,
        limit: Int
    ) -> [CodexSessionMenuRow] {
        visibleMenuSessions(snapshot: snapshot, limit: limit).map { session in
            CodexSessionMenuRow(
                id: session.id,
                title: session.title,
                clientBadge: session.client?.rawValue,
                timeText: session.activeStartedAt.map { elapsedText(since: $0, now: snapshot.generatedAt) } ?? "",
                statusTooltip: session.statusLabel,
                isActive: session.isActive,
                isUnread: session.isUnread,
                threadURL: threadURL(for: session)
            )
        }
    }

    private static func threadURL(for session: CodexSession) -> URL? {
        guard session.client == .app else { return nil }
        return codexThreadURL(for: session.id)
    }

    public static func codexThreadURL(for sessionID: String) -> URL? {
        var components = URLComponents()
        components.scheme = "codex"
        components.host = "threads"
        components.path = "/\(sessionID)"
        return components.url
    }

    public static func truncate(_ value: String, limit: Int) -> String {
        let value = singleLine(value)
        guard value.count > limit else { return value }
        return String(value.prefix(max(0, limit - 3))) + "..."
    }

    public static func singleLine(_ value: String) -> String {
        value
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
