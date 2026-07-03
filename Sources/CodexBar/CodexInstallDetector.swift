import AppKit
import CodexBarCore
import Foundation

struct CodexInstallStatus {
    let desktopAppURL: URL?
    let isInstalled: Bool
    let isRunning: Bool
}

enum CodexInstallDetector {
    static func detect(
        environment: [String: String] = ProcessInfo.processInfo.environment,
        fileManager: FileManager = .default,
        workspace: NSWorkspace = .shared
    ) -> CodexInstallStatus {
        let desktopAppURL = findDesktopApp(fileManager: fileManager, workspace: workspace)
        let codexHome = CodexStateReader.resolveCodexHome(environment: environment, fileManager: fileManager)
        let isInstalled = desktopAppURL != nil
            || hasCodexCLI(environment: environment, fileManager: fileManager)
            || hasIDEExtension(fileManager: fileManager)
            || hasCodexState(codexHome: codexHome, fileManager: fileManager)

        return CodexInstallStatus(
            desktopAppURL: desktopAppURL,
            isInstalled: isInstalled,
            isRunning: isDesktopRunning(workspace: workspace) || hasCodexProcess()
        )
    }

    private static func findDesktopApp(fileManager: FileManager, workspace: NSWorkspace) -> URL? {
        if let appURL = workspace.urlForApplication(withBundleIdentifier: "com.openai.codex") {
            return appURL
        }

        let fallbackURL = URL(fileURLWithPath: "/Applications/Codex.app")
        return fileManager.fileExists(atPath: fallbackURL.path) ? fallbackURL : nil
    }

    private static func isDesktopRunning(workspace: NSWorkspace) -> Bool {
        workspace.runningApplications.contains { application in
            application.bundleIdentifier == "com.openai.codex"
        }
    }

    private static func hasCodexCLI(environment: [String: String], fileManager: FileManager) -> Bool {
        executableSearchPaths(environment: environment, fileManager: fileManager).contains { path in
            fileManager.isExecutableFile(atPath: URL(fileURLWithPath: path).appendingPathComponent("codex").path)
        }
    }

    private static func executableSearchPaths(environment: [String: String], fileManager: FileManager) -> [String] {
        let home = fileManager.homeDirectoryForCurrentUser.path
        let pathValue = environment["PATH"] ?? ""
        let paths = pathValue
            .split(separator: ":", omittingEmptySubsequences: true)
            .map(String.init)

        return Array(Set(paths + [
            "/opt/homebrew/bin",
            "/usr/local/bin",
            "\(home)/.local/bin",
            "\(home)/bin",
        ]))
    }

    private static func hasIDEExtension(fileManager: FileManager) -> Bool {
        ideExtensionRoots(fileManager: fileManager).contains { root in
            containsCodexExtension(in: root, fileManager: fileManager)
        }
    }

    private static func ideExtensionRoots(fileManager: FileManager) -> [URL] {
        let home = fileManager.homeDirectoryForCurrentUser
        return [
            home.appendingPathComponent(".vscode/extensions"),
            home.appendingPathComponent(".cursor/extensions"),
            home.appendingPathComponent(".windsurf/extensions"),
        ]
    }

    private static func containsCodexExtension(in root: URL, fileManager: FileManager) -> Bool {
        guard let entries = try? fileManager.contentsOfDirectory(
            at: root,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        ) else {
            return false
        }

        return entries.contains { entry in
            let name = entry.lastPathComponent.lowercased()
            return name.hasPrefix("openai.chatgpt") || (name.contains("openai") && name.contains("codex"))
        }
    }

    private static func hasCodexState(codexHome: URL, fileManager: FileManager) -> Bool {
        [
            codexHome.appendingPathComponent("config.toml"),
            codexHome.appendingPathComponent("auth.json"),
            codexHome.appendingPathComponent("sessions"),
        ].contains { fileManager.fileExists(atPath: $0.path) }
    }

    private static func hasCodexProcess() -> Bool {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/pgrep")
        process.arguments = ["-f", codexProcessPattern]
        process.standardOutput = Pipe()
        process.standardError = Pipe()

        do {
            try process.run()
            process.waitUntilExit()
            return process.terminationStatus == 0
        } catch {
            return false
        }
    }

    private static let codexProcessPattern = #"(^|/)(codex|codex-cli)( |$)|codex app-server|com\.openai\.codex"#
}
