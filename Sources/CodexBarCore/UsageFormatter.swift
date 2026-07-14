import Foundation

public enum UsageFormatter {
    public static func compactUsage(_ usage: UsageSnapshot?, showPrimary: Bool, showSecondary: Bool) -> String {
        guard let usage else { return "" }

        var parts: [String] = []
        if showPrimary, let primary = usage.primary {
            parts.append("5h \(percent(primary.leftPercent))")
        }
        if showSecondary, let secondary = usage.secondary {
            parts.append("week \(percent(secondary.leftPercent))")
        }

        return parts.joined(separator: " / ")
    }

    public static func percent(_ value: Double) -> String {
        let clamped = min(100, max(0, value))
        if abs(clamped.rounded() - clamped) < 0.05 {
            return "\(Int(clamped.rounded()))%"
        }
        return String(format: "%.1f%%", clamped)
    }

    public static func leftLine(_ window: UsageWindow?, fallbackLabel: String) -> String {
        guard let window else {
            return "\(fallbackLabel) left: --"
        }
        return "\(fallbackLabel) left: \(percent(window.leftPercent))"
    }

    public static func resetLine(_ window: UsageWindow?, fallbackLabel: String, now: Date) -> String {
        guard let reset = window?.resetsAt else {
            return "\(fallbackLabel) reset: --"
        }
        return "\(fallbackLabel) reset: \(relativeTime(from: now, to: reset))"
    }

    public static func snapshotLine(_ usage: UsageSnapshot?, now: Date) -> String {
        guard let usage else {
            return "Snapshot: --"
        }
        return "Snapshot: \(relativeTime(from: now, to: usage.capturedAt))"
    }

    public static func relativeTime(from now: Date, to date: Date) -> String {
        let seconds = Int(date.timeIntervalSince(now).rounded())
        let absSeconds = abs(seconds)

        if absSeconds < 5 {
            return "now"
        }

        let suffix = seconds >= 0 ? "left" : "ago"
        let value = absSeconds
        if value < 60 {
            return "\(value)s \(suffix)"
        }
        if value < 3_600 {
            return "\(value / 60)m \(suffix)"
        }
        if value < 86_400 {
            let hours = value / 3_600
            let minutes = (value % 3_600) / 60
            return minutes > 0 ? "\(hours)h \(minutes)m \(suffix)" : "\(hours)h \(suffix)"
        }

        let days = value / 86_400
        let hours = (value % 86_400) / 3_600
        return hours > 0 ? "\(days)d \(hours)h \(suffix)" : "\(days)d \(suffix)"
    }
}
