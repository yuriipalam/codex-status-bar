import Foundation
import Testing
import CodexBarCore

@Suite
struct UsageFormatterTests {
    @Test
    func compactUsageHonorsToggles() {
        let usage = UsageSnapshot(
            primary: UsageWindow(label: "5h", usedPercent: 12, windowMinutes: 300, resetsAt: nil),
            secondary: UsageWindow(label: "week", usedPercent: 46, windowMinutes: 10080, resetsAt: nil),
            planType: "prolite",
            capturedAt: Date(timeIntervalSince1970: 100)
        )

        #expect(UsageFormatter.compactUsage(usage, showPrimary: true, showSecondary: true) == "5h 88% / week 54%")
        #expect(UsageFormatter.compactUsage(usage, showPrimary: true, showSecondary: false) == "5h 88%")
        #expect(UsageFormatter.compactUsage(usage, showPrimary: false, showSecondary: true) == "week 54%")
        #expect(UsageFormatter.compactUsage(usage, showPrimary: false, showSecondary: false) == "")
    }

    @Test
    func percentClampsValues() {
        #expect(UsageFormatter.percent(-2) == "0%")
        #expect(UsageFormatter.percent(101) == "100%")
        #expect(UsageFormatter.percent(53.04) == "53%")
        #expect(UsageFormatter.percent(53.5) == "53.5%")
    }

    @Test
    func missingWindowsAreReadable() {
        #expect(UsageFormatter.leftLine(nil, fallbackLabel: "5h") == "5h left: unavailable")
        #expect(UsageFormatter.resetLine(nil, fallbackLabel: "Week", now: Date(timeIntervalSince1970: 0)) == "Week reset: unavailable")
        #expect(UsageFormatter.snapshotLine(nil, now: Date(timeIntervalSince1970: 0)) == "Snapshot: unavailable")
    }

    @Test
    func relativeTimeFormatsFutureAndPast() {
        let now = Date(timeIntervalSince1970: 1_000)
        #expect(UsageFormatter.relativeTime(from: now, to: Date(timeIntervalSince1970: 1_003)) == "now")
        #expect(UsageFormatter.relativeTime(from: now, to: Date(timeIntervalSince1970: 1_030)) == "30s left")
        #expect(UsageFormatter.relativeTime(from: now, to: Date(timeIntervalSince1970: 1_060)) == "1m left")
        #expect(UsageFormatter.relativeTime(from: now, to: Date(timeIntervalSince1970: 4_700)) == "1h 1m left")
        #expect(UsageFormatter.relativeTime(from: now, to: Date(timeIntervalSince1970: 90_000)) == "1d left")
        #expect(UsageFormatter.relativeTime(from: now, to: Date(timeIntervalSince1970: 940)) == "1m ago")
    }

    @Test
    func resetAndSnapshotLinesUseRelativeTimes() {
        let now = Date(timeIntervalSince1970: 1_000)
        let window = UsageWindow(
            label: "5h",
            usedPercent: 25,
            windowMinutes: 300,
            resetsAt: Date(timeIntervalSince1970: 4_600)
        )
        let usage = UsageSnapshot(
            primary: window,
            secondary: nil,
            planType: "pro",
            capturedAt: Date(timeIntervalSince1970: 940)
        )

        #expect(UsageFormatter.leftLine(window, fallbackLabel: "5h") == "5h left: 75%")
        #expect(UsageFormatter.resetLine(window, fallbackLabel: "5h", now: now) == "5h reset: 1h left")
        #expect(UsageFormatter.snapshotLine(usage, now: now) == "Snapshot: 1m ago")
    }
}
