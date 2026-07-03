import Foundation

public final class CodexStateReader {
    private typealias SessionFileRecord = (url: URL, modifiedAt: Date)

    private struct CachedRollout {
        let modifiedAt: Date
        let size: UInt64
        let parsed: ParsedRollout
    }

    private struct ActiveRollout {
        let activeAgent: ActiveAgent
        let session: CodexSession
        let lastSeenAt: Date
    }

    private struct LoadedRollout {
        let parsed: ParsedRollout
        let isVerified: Bool
    }

    private struct SnapshotCandidate {
        let parsed: ParsedRollout
        let activeAgent: ActiveAgent?
        let session: CodexSession

        var sortDate: Date {
            session.lastEventAt ?? session.updatedAt ?? .distantPast
        }
    }

    private let codexHome: URL
    private let parser: RolloutParser
    private let fileManager: FileManager
    private var cache: [String: CachedRollout] = [:]
    private var activeRollouts: [String: ActiveRollout] = [:]

    public var staleAfter: TimeInterval = 6 * 60 * 60
    public var missingActiveSessionGrace: TimeInterval = 5
    public var threadLimit: Int = 20

    public init(
        codexHome: URL? = nil,
        environment: [String: String] = ProcessInfo.processInfo.environment,
        parser: RolloutParser = RolloutParser(),
        fileManager: FileManager = .default
    ) {
        self.codexHome = codexHome ?? Self.resolveCodexHome(environment: environment, fileManager: fileManager)
        self.parser = parser
        self.fileManager = fileManager
    }

    public static func resolveCodexHome(
        environment: [String: String] = ProcessInfo.processInfo.environment,
        fileManager: FileManager = .default
    ) -> URL {
        let defaultHome = fileManager.homeDirectoryForCurrentUser.appendingPathComponent(".codex")
        guard let value = environment["CODEX_HOME"]?.trimmingCharacters(in: .whitespacesAndNewlines),
              !value.isEmpty
        else {
            return defaultHome
        }

        let expandedPath = NSString(string: value).expandingTildeInPath
        return URL(fileURLWithPath: expandedPath).standardizedFileURL
    }

    public func loadSnapshot(now: Date = Date()) -> CodexSnapshot {
        let unreadState = CodexUnreadStateReader(codexHome: codexHome, fileManager: fileManager).load()
        return buildSnapshot(
            from: threadRecords(unreadThreadIDs: unreadState.allThreadIDs(), now: now),
            unreadState: unreadState,
            now: now,
            lastError: nil
        )
    }

    private func buildSnapshot(
        from records: [ThreadRecord],
        unreadState: CodexUnreadState,
        now: Date,
        lastError: String?
    ) -> CodexSnapshot {
        var candidates: [SnapshotCandidate] = []
        var latestUsage: UsageSnapshot?
        var observedPaths: Set<String> = []

        for record in records {
            guard let loaded = parseCached(path: record.rolloutPath), loaded.isVerified else { continue }
            let parsed = loaded.parsed
            observedPaths.insert(record.rolloutPath)
            let thread = threadRecord(for: record, parsed: parsed)

            let activeAgent = parsed.activeAgent(thread: thread, now: now, staleAfter: staleAfter)

            let session = CodexSession(
                id: thread.id,
                title: thread.title,
                rolloutPath: thread.rolloutPath,
                cwd: thread.cwd,
                client: parsed.metadata?.client,
                updatedAt: thread.updatedAt,
                activeStartedAt: activeAgent?.startedAt,
                lastEventAt: parsed.latestEventAt,
                statusLabel: activeAgent?.label ?? parsed.latestStatusLabel,
                isUnread: isUnread(threadID: thread.id, aliases: parsed.relatedSessionIDs, unreadState: unreadState)
            )
            candidates.append(SnapshotCandidate(parsed: parsed, activeAgent: activeAgent, session: session))

            if let usage = parsed.usage,
               latestUsage.map({ usage.capturedAt > $0.capturedAt }) ?? true {
                latestUsage = usage
            }
        }

        let visibleCandidates = collapseImportedAliases(candidates)
        let visiblePaths = Set(visibleCandidates.map(\.session.rolloutPath))
        for path in observedPaths where !visiblePaths.contains(path) {
            activeRollouts[path] = nil
        }

        var activeAgents = visibleCandidates.compactMap(\.activeAgent)
        var sessions = visibleCandidates.map(\.session)

        for candidate in visibleCandidates {
            if let activeAgent = candidate.activeAgent {
                activeRollouts[candidate.session.rolloutPath] = ActiveRollout(
                    activeAgent: activeAgent,
                    session: candidate.session,
                    lastSeenAt: now
                )
            } else {
                activeRollouts[candidate.session.rolloutPath] = nil
            }
        }

        for (path, activeRollout) in activeRollouts where !observedPaths.contains(path) {
            guard now.timeIntervalSince(activeRollout.lastSeenAt) <= missingActiveSessionGrace else {
                activeRollouts[path] = nil
                continue
            }

            activeAgents.append(activeRollout.activeAgent)
            sessions.append(activeRollout.session)
        }

        activeAgents.sort {
            if $0.startedAt == $1.startedAt {
                if $0.title == $1.title { return $0.id < $1.id }
                return $0.title < $1.title
            }
            return $0.startedAt > $1.startedAt
        }

        sessions.sort {
            if $0.isActive != $1.isActive {
                return $0.isActive
            }

            if $0.isActive, $1.isActive {
                let leftStartedAt = $0.activeStartedAt ?? .distantPast
                let rightStartedAt = $1.activeStartedAt ?? .distantPast
                if leftStartedAt != rightStartedAt { return leftStartedAt > rightStartedAt }
                if $0.title == $1.title { return $0.id < $1.id }
                return $0.title < $1.title
            }

            if $0.isUnread != $1.isUnread {
                return $0.isUnread
            }

            let left = $0.lastEventAt ?? $0.updatedAt ?? .distantPast
            let right = $1.lastEventAt ?? $1.updatedAt ?? .distantPast
            if left == right {
                if $0.title == $1.title { return $0.id < $1.id }
                return $0.title < $1.title
            }
            return left > right
        }

        return CodexSnapshot(
            activeAgents: activeAgents,
            sessions: sessions,
            usage: latestUsage?.projected(at: now),
            generatedAt: now,
            lastError: lastError
        )
    }

    private func isUnread(threadID: String, aliases: Set<String>, unreadState: CodexUnreadState) -> Bool {
        if unreadState.isUnread(threadID: threadID) {
            return true
        }

        return aliases.contains { unreadState.isUnread(threadID: $0) }
    }

    private func collapseImportedAliases(_ candidates: [SnapshotCandidate]) -> [SnapshotCandidate] {
        let deduplicated = deduplicateCandidates(candidates)
        let candidatesByID = Dictionary(uniqueKeysWithValues: deduplicated.map { ($0.session.id, $0) })
        var suppressedIDs: Set<String> = []

        for candidate in deduplicated where candidate.session.isVisibleInSessionMenu {
            for alias in candidate.parsed.relatedSessionIDs where alias != candidate.session.id {
                guard let aliasedCandidate = candidatesByID[alias],
                      !aliasedCandidate.session.isActive,
                      shouldPrefer(candidate, over: aliasedCandidate)
                else {
                    continue
                }

                suppressedIDs.insert(alias)
            }
        }

        return deduplicated.filter { !suppressedIDs.contains($0.session.id) }
    }

    private func deduplicateCandidates(_ candidates: [SnapshotCandidate]) -> [SnapshotCandidate] {
        var candidatesByID: [String: SnapshotCandidate] = [:]

        for candidate in candidates {
            if let existing = candidatesByID[candidate.session.id] {
                if shouldPrefer(candidate, over: existing) {
                    candidatesByID[candidate.session.id] = candidate
                }
            } else {
                candidatesByID[candidate.session.id] = candidate
            }
        }

        return Array(candidatesByID.values)
    }

    private func shouldPrefer(_ candidate: SnapshotCandidate, over existing: SnapshotCandidate) -> Bool {
        if candidate.session.isActive != existing.session.isActive {
            return candidate.session.isActive
        }

        if candidate.session.isUnread != existing.session.isUnread {
            return candidate.session.isUnread
        }

        if candidate.sortDate != existing.sortDate {
            return candidate.sortDate > existing.sortDate
        }

        return candidate.session.rolloutPath > existing.session.rolloutPath
    }

    private func threadRecord(for record: ThreadRecord, parsed: ParsedRollout) -> ThreadRecord {
        let metadata = parsed.metadata
        let cwd = metadata?.cwd.nilIfEmpty ?? record.cwd
        let fallbackID = record.id
        let id = metadata?.id?.nilIfEmpty ?? fallbackID

        return ThreadRecord(
            id: id,
            title: sessionTitle(cwd: cwd, fallback: record.title),
            rolloutPath: record.rolloutPath,
            cwd: cwd,
            updatedAt: record.updatedAt
        )
    }

    private func sessionTitle(cwd: String, fallback: String) -> String {
        let cwd = cwd.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cwd.isEmpty else { return fallback }

        let title = URL(fileURLWithPath: cwd).lastPathComponent
        return title.nilIfEmpty ?? fallback
    }

    private func threadRecords(unreadThreadIDs: Set<String>, now: Date) -> [ThreadRecord] {
        let files = sessionFiles()
        var selected: [URL: Date] = [:]

        for item in files.sorted(by: { $0.modifiedAt > $1.modifiedAt }).prefix(threadLimit) {
            selected[item.url] = item.modifiedAt
        }

        for item in files where unreadThreadIDs.contains(Self.sessionID(from: item.url)) {
            selected[item.url] = item.modifiedAt
        }

        for path in activeRollouts.keys {
            let url = URL(fileURLWithPath: path)
            if let modifiedAt = try? url.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate {
                selected[url] = modifiedAt
            }
        }

        return selected
            .map { (url: $0.key, modifiedAt: $0.value) }
            .sorted { $0.modifiedAt > $1.modifiedAt }
            .map { item in
                ThreadRecord(
                    id: Self.sessionID(from: item.url),
                    title: "Codex",
                    rolloutPath: item.url.path,
                    cwd: "",
                    updatedAt: item.modifiedAt
                )
            }
    }

    private func sessionFiles() -> [SessionFileRecord] {
        let sessions = codexHome.appendingPathComponent("sessions")
        guard let enumerator = fileManager.enumerator(
            at: sessions,
            includingPropertiesForKeys: [.contentModificationDateKey],
            options: [.skipsHiddenFiles]
        ) else {
            return []
        }

        var files: [(url: URL, modifiedAt: Date)] = []
        for case let url as URL in enumerator where url.pathExtension == "jsonl" {
            let modifiedAt = (try? url.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
            files.append((url, modifiedAt))
        }

        return files
    }

    private func laterDate(_ left: Date?, _ right: Date?) -> Date? {
        switch (left, right) {
        case let (left?, right?):
            return max(left, right)
        case let (left?, nil):
            return left
        case let (nil, right?):
            return right
        case (nil, nil):
            return nil
        }
    }

    private static func sessionID(from url: URL) -> String {
        let fileName = url.deletingPathExtension().lastPathComponent
        guard fileName.count >= 36 else { return fileName }

        let suffix = String(fileName.suffix(36))
        return isUUIDLike(suffix) ? suffix : fileName
    }

    private static func isUUIDLike(_ value: String) -> Bool {
        let scalars = Array(value.unicodeScalars)
        guard scalars.count == 36 else { return false }

        for index in [8, 13, 18, 23] where scalars[index] != "-" {
            return false
        }

        return scalars.enumerated().allSatisfy { index, scalar in
            if [8, 13, 18, 23].contains(index) {
                return true
            }

            return CharacterSet(charactersIn: "0123456789abcdefABCDEF").contains(scalar)
        }
    }

    private func parseCached(path: String) -> LoadedRollout? {
        guard fileManager.fileExists(atPath: path),
              let attributes = try? fileManager.attributesOfItem(atPath: path),
              let modifiedAt = attributes[.modificationDate] as? Date
        else {
            return nil
        }

        let size = (attributes[.size] as? NSNumber)?.uint64Value ?? 0
        if let cached = cache[path], cached.modifiedAt == modifiedAt, cached.size == size {
            return LoadedRollout(parsed: cached.parsed, isVerified: true)
        }

        guard let contents = try? String(contentsOf: URL(fileURLWithPath: path), encoding: .utf8) else {
            return cache[path].map { LoadedRollout(parsed: $0.parsed, isVerified: false) }
        }

        let parsed = parser.parse(
            lines: contents.split(separator: "\n", omittingEmptySubsequences: false).map(String.init),
            path: path
        )
        cache[path] = CachedRollout(modifiedAt: modifiedAt, size: size, parsed: parsed)
        return LoadedRollout(parsed: parsed, isVerified: true)
    }
}
