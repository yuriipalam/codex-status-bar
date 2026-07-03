import Foundation
import Testing
@testable import CodexBarCore

@Suite
struct CodexDesktopConfigTests {
    @Test
    func missingConfigDefaultsToEnabled() {
        let configURL = FileManager.default.temporaryDirectory.appendingPathComponent("missing-\(UUID().uuidString)/config.toml")

        #expect(CodexDesktopConfig.menuBarIconEnabled(configURL: configURL) == true)
    }

    @Test
    func readsDisabledDesktopSetting() throws {
        let configURL = try writeConfig(
            """
            [desktop]
            mac-menu-bar-enabled = false
            """
        )

        #expect(CodexDesktopConfig.menuBarIconEnabled(configURL: configURL) == false)
    }

    @Test
    func readsMissingDesktopSettingAsEnabled() throws {
        let configURL = try writeConfig(
            """
            [desktop]
            dock-icon-preference = "app-default"
            """
        )

        #expect(CodexDesktopConfig.menuBarIconEnabled(configURL: configURL) == true)
    }

    @Test
    func disablesExistingDesktopSetting() throws {
        let configURL = try writeConfig(
            """
            [desktop]
            appearanceTheme = "system"
              mac-menu-bar-enabled = true

            [memories]
            use_memories = true
            """
        )

        try CodexDesktopConfig.setMenuBarIconEnabled(false, configURL: configURL)

        #expect(try String(contentsOf: configURL, encoding: .utf8) ==
            """
            [desktop]
            appearanceTheme = "system"
              mac-menu-bar-enabled = false

            [memories]
            use_memories = true

            """
        )
    }

    @Test
    func addsSettingToExistingDesktopSection() throws {
        let configURL = try writeConfig(
            """
            [desktop]
            appearanceTheme = "system"

            [memories]
            use_memories = true
            """
        )

        try CodexDesktopConfig.setMenuBarIconEnabled(false, configURL: configURL)

        #expect(try String(contentsOf: configURL, encoding: .utf8) ==
            """
            [desktop]
            appearanceTheme = "system"
            mac-menu-bar-enabled = false

            [memories]
            use_memories = true

            """
        )
    }

    @Test
    func createsDesktopSectionWhenMissing() throws {
        let configURL = try writeConfig(
            """
            [memories]
            use_memories = true
            """
        )

        try CodexDesktopConfig.setMenuBarIconEnabled(false, configURL: configURL)

        #expect(try String(contentsOf: configURL, encoding: .utf8) ==
            """
            [memories]
            use_memories = true

            [desktop]
            mac-menu-bar-enabled = false

            """
        )
    }

    private func writeConfig(_ text: String) throws -> URL {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("CodexDesktopConfigTests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let configURL = root.appendingPathComponent("config.toml")
        try (text + "\n").write(to: configURL, atomically: true, encoding: .utf8)
        return configURL
    }
}
