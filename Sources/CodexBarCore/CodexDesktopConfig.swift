import Foundation

public enum CodexDesktopConfig {
    public static let menuBarIconKey = "mac-menu-bar-enabled"

    public static func defaultConfigURL(
        environment: [String: String] = ProcessInfo.processInfo.environment,
        fileManager: FileManager = .default
    ) -> URL {
        CodexStateReader
            .resolveCodexHome(environment: environment, fileManager: fileManager)
            .appendingPathComponent("config.toml")
    }

    public static func menuBarIconEnabled(configURL: URL) -> Bool {
        guard let text = try? String(contentsOf: configURL, encoding: .utf8) else {
            return true
        }

        var currentSection: String?
        for line in normalizedLines(text) {
            let significant = significantPart(line)
            if let section = sectionName(significant) {
                currentSection = section
                continue
            }

            guard currentSection == "desktop",
                  let (key, value) = keyValue(significant),
                  key == menuBarIconKey
            else {
                continue
            }

            return value.lowercased() != "false"
        }

        return true
    }

    public static func setMenuBarIconEnabled(_ enabled: Bool, configURL: URL, fileManager: FileManager = .default) throws {
        let value = enabled ? "true" : "false"
        let text = (try? String(contentsOf: configURL, encoding: .utf8)) ?? ""
        var lines = normalizedLines(text)
        var currentSection: String?
        var desktopStartIndex: Int?
        var desktopEndIndex: Int?

        for index in lines.indices {
            let significant = significantPart(lines[index])
            if let section = sectionName(significant) {
                if desktopStartIndex != nil, desktopEndIndex == nil, section != "desktop" {
                    desktopEndIndex = index
                }

                currentSection = section
                if section == "desktop", desktopStartIndex == nil {
                    desktopStartIndex = index
                }
                continue
            }

            guard currentSection == "desktop",
                  let (key, _) = keyValue(significant),
                  key == menuBarIconKey
            else {
                continue
            }

            let indentation = lines[index].prefix { $0 == " " || $0 == "\t" }
            lines[index] = "\(indentation)\(menuBarIconKey) = \(value)"
            try write(lines: lines, to: configURL, fileManager: fileManager)
            return
        }

        if let desktopStartIndex {
            let sectionEndIndex = desktopEndIndex ?? lines.endIndex
            var insertionIndex = sectionEndIndex
            while insertionIndex > lines.index(after: desktopStartIndex),
                  lines[lines.index(before: insertionIndex)].trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                insertionIndex = lines.index(before: insertionIndex)
            }
            lines.insert("\(menuBarIconKey) = \(value)", at: insertionIndex)
        } else {
            if !lines.isEmpty, lines.last?.isEmpty == false {
                lines.append("")
            }
            lines.append("[desktop]")
            lines.append("\(menuBarIconKey) = \(value)")
        }

        try write(lines: lines, to: configURL, fileManager: fileManager)
    }

    private static func normalizedLines(_ text: String) -> [String] {
        text
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
            .split(separator: "\n", omittingEmptySubsequences: false)
            .map(String.init)
    }

    private static func significantPart(_ line: String) -> String {
        let withoutComment = line.split(separator: "#", maxSplits: 1, omittingEmptySubsequences: false).first ?? ""
        return withoutComment.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func sectionName(_ significantLine: String) -> String? {
        guard significantLine.hasPrefix("["),
              significantLine.hasSuffix("]"),
              !significantLine.hasPrefix("[[")
        else {
            return nil
        }

        return significantLine
            .dropFirst()
            .dropLast()
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func keyValue(_ significantLine: String) -> (key: String, value: String)? {
        let parts = significantLine.split(separator: "=", maxSplits: 1, omittingEmptySubsequences: false)
        guard parts.count == 2 else { return nil }

        return (
            key: parts[0].trimmingCharacters(in: .whitespacesAndNewlines),
            value: parts[1].trimmingCharacters(in: .whitespacesAndNewlines)
        )
    }

    private static func write(lines: [String], to configURL: URL, fileManager: FileManager) throws {
        var outputLines = lines
        while outputLines.last?.isEmpty == true {
            outputLines.removeLast()
        }

        try fileManager.createDirectory(at: configURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        try (outputLines.joined(separator: "\n") + "\n").write(to: configURL, atomically: true, encoding: .utf8)
    }
}
