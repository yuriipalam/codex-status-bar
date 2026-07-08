import Testing
@testable import CodexBarCore

@Suite
struct CodexBarMenuLayoutTests {
    @Test
    func configurationMenusKeepOptionsColorAndAnimationAtTopLevel() {
        #expect(CodexBarMenuLayout.configurationMenuTitles == [
            "Options",
            "Color",
            "Animation",
        ])
    }

    @Test
    func optionsMenuContainsOnlyToggles() {
        #expect(CodexBarMenuLayout.optionToggleTitles == [
            "Show timer",
            "Show 5-hour usage",
            "Show weekly usage",
            "Start at login",
        ])
    }
}
