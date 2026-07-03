import Foundation

public struct ThreadRecord: Equatable, Sendable {
    public let id: String
    public let title: String
    public let rolloutPath: String
    public let cwd: String
    public let updatedAt: Date?

    public init(id: String, title: String, rolloutPath: String, cwd: String, updatedAt: Date?) {
        self.id = id
        self.title = title
        self.rolloutPath = rolloutPath
        self.cwd = cwd
        self.updatedAt = updatedAt
    }
}

public enum CodexSessionClient: String, Equatable, Sendable {
    case app = "APP"
    case cli = "CLI"
    case ide = "IDE"

    public static func classify(originator: String?) -> CodexSessionClient? {
        let originator = originator?.lowercased() ?? ""

        guard !originator.isEmpty else { return nil }

        if originator.contains("codex desktop") {
            return .app
        }

        if originator.contains("vscode") ||
            originator.contains("visual studio code") ||
            originator.contains("cursor") ||
            originator.contains("windsurf") ||
            originator.contains("jetbrains") ||
            originator.contains("ide") {
            return .ide
        }

        if originator.contains("cli") {
            return .cli
        }

        return nil
    }
}

public struct SessionMetadata: Equatable, Sendable {
    public let id: String?
    public let cwd: String
    public let originator: String?
    public let source: String?
    public let threadSource: String?
    public let forkedFromID: String?
    public let createdAt: Date?

    public init(
        id: String?,
        cwd: String,
        originator: String?,
        source: String?,
        threadSource: String?,
        forkedFromID: String? = nil,
        createdAt: Date?
    ) {
        self.id = id
        self.cwd = cwd
        self.originator = originator
        self.source = source
        self.threadSource = threadSource
        self.forkedFromID = forkedFromID
        self.createdAt = createdAt
    }

    public var client: CodexSessionClient? {
        CodexSessionClient.classify(originator: originator)
    }
}

public struct CodexSession: Equatable, Sendable {
    public let id: String
    public let title: String
    public let rolloutPath: String
    public let cwd: String
    public let client: CodexSessionClient?
    public let updatedAt: Date?
    public let activeStartedAt: Date?
    public let lastEventAt: Date?
    public let statusLabel: String?
    public let isUnread: Bool

    public init(
        id: String,
        title: String,
        rolloutPath: String,
        cwd: String,
        client: CodexSessionClient?,
        updatedAt: Date?,
        activeStartedAt: Date?,
        lastEventAt: Date?,
        statusLabel: String?,
        isUnread: Bool = false
    ) {
        self.id = id
        self.title = title
        self.rolloutPath = rolloutPath
        self.cwd = cwd
        self.client = client
        self.updatedAt = updatedAt
        self.activeStartedAt = activeStartedAt
        self.lastEventAt = lastEventAt
        self.statusLabel = statusLabel
        self.isUnread = isUnread
    }

    public var isActive: Bool {
        activeStartedAt != nil
    }

    public var isVisibleInSessionMenu: Bool {
        isActive || isUnread
    }
}

public struct ParsedRollout: Equatable, Sendable {
    public let path: String
    public let latestEventAt: Date?
    public let latestTaskStartedAt: Date?
    public let latestTaskCompletedAt: Date?
    public let latestStatusLabel: String?
    public let usage: UsageSnapshot?
    public let metadata: SessionMetadata?
    public let relatedSessionIDs: Set<String>
    public let forkedFromID: String?
    public let hasOpenTask: Bool

    public init(
        path: String,
        latestEventAt: Date?,
        latestTaskStartedAt: Date?,
        latestTaskCompletedAt: Date?,
        latestStatusLabel: String?,
        usage: UsageSnapshot?,
        metadata: SessionMetadata? = nil,
        relatedSessionIDs: Set<String> = [],
        forkedFromID: String? = nil,
        hasOpenTask: Bool? = nil
    ) {
        self.path = path
        self.latestEventAt = latestEventAt
        self.latestTaskStartedAt = latestTaskStartedAt
        self.latestTaskCompletedAt = latestTaskCompletedAt
        self.latestStatusLabel = latestStatusLabel
        self.usage = usage
        self.metadata = metadata
        self.relatedSessionIDs = relatedSessionIDs
        self.forkedFromID = forkedFromID
        self.hasOpenTask = hasOpenTask ?? Self.inferHasOpenTask(
            started: latestTaskStartedAt,
            completed: latestTaskCompletedAt
        )
    }

    private static func inferHasOpenTask(started: Date?, completed: Date?) -> Bool {
        guard let started else { return false }
        guard let completed else { return true }
        return started > completed
    }

    public func activeAgent(
        thread: ThreadRecord,
        now: Date,
        staleAfter: TimeInterval
    ) -> ActiveAgent? {
        guard hasOpenTask, let started = latestTaskStartedAt, let latestEventAt else {
            return nil
        }

        guard now.timeIntervalSince(latestEventAt) <= staleAfter else {
            return nil
        }

        return ActiveAgent(
            id: thread.id,
            title: thread.title,
            cwd: thread.cwd,
            label: latestStatusLabel?.nilIfEmpty ?? "Thinking...",
            startedAt: started,
            lastEventAt: latestEventAt
        )
    }
}

public struct ActiveAgent: Equatable, Sendable {
    public let id: String
    public let title: String
    public let cwd: String
    public let label: String
    public let startedAt: Date
    public let lastEventAt: Date

    public init(id: String, title: String, cwd: String, label: String, startedAt: Date, lastEventAt: Date) {
        self.id = id
        self.title = title
        self.cwd = cwd
        self.label = label
        self.startedAt = startedAt
        self.lastEventAt = lastEventAt
    }
}

public struct UsageSnapshot: Equatable, Sendable {
    public let primary: UsageWindow?
    public let secondary: UsageWindow?
    public let planType: String?
    public let capturedAt: Date

    public init(primary: UsageWindow?, secondary: UsageWindow?, planType: String?, capturedAt: Date) {
        self.primary = primary
        self.secondary = secondary
        self.planType = planType
        self.capturedAt = capturedAt
    }

    public func projected(at now: Date) -> UsageSnapshot {
        UsageSnapshot(
            primary: primary?.projected(capturedAt: capturedAt, now: now),
            secondary: secondary?.projected(capturedAt: capturedAt, now: now),
            planType: planType,
            capturedAt: capturedAt
        )
    }
}

public struct UsageWindow: Equatable, Sendable {
    public let label: String
    public let usedPercent: Double
    public let windowMinutes: Int?
    public let resetsAt: Date?

    public init(label: String, usedPercent: Double, windowMinutes: Int?, resetsAt: Date?) {
        self.label = label
        self.usedPercent = usedPercent
        self.windowMinutes = windowMinutes
        self.resetsAt = resetsAt
    }

    public var leftPercent: Double {
        min(100, max(0, 100 - usedPercent))
    }

    fileprivate func projected(capturedAt: Date, now: Date) -> UsageWindow {
        guard let resetsAt,
              let windowMinutes,
              windowMinutes > 0,
              capturedAt <= resetsAt,
              resetsAt <= now
        else {
            return self
        }

        let windowSeconds = TimeInterval(windowMinutes) * 60
        let elapsedWindows = floor(now.timeIntervalSince(resetsAt) / windowSeconds) + 1
        return UsageWindow(
            label: label,
            usedPercent: 0,
            windowMinutes: windowMinutes,
            resetsAt: resetsAt.addingTimeInterval(elapsedWindows * windowSeconds)
        )
    }
}

public struct CodexSnapshot: Equatable, Sendable {
    public let activeAgents: [ActiveAgent]
    public let sessions: [CodexSession]
    public let usage: UsageSnapshot?
    public let generatedAt: Date
    public let lastError: String?

    public init(
        activeAgents: [ActiveAgent],
        sessions: [CodexSession] = [],
        usage: UsageSnapshot?,
        generatedAt: Date,
        lastError: String?
    ) {
        self.activeAgents = activeAgents
        self.sessions = sessions
        self.usage = usage
        self.generatedAt = generatedAt
        self.lastError = lastError
    }

    public static func empty(now: Date = Date(), lastError: String? = nil) -> CodexSnapshot {
        CodexSnapshot(activeAgents: [], usage: nil, generatedAt: now, lastError: lastError)
    }
}

extension String {
    var nilIfEmpty: String? {
        isEmpty ? nil : self
    }
}
