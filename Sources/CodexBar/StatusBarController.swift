import AppKit
import CodexBarCore

final class StatusBarController: NSObject, NSMenuDelegate {
    private enum DefaultsKey {
        static let showTimer = "showTimer"
        static let showFiveHourUsage = "showFiveHourUsage"
        static let showWeeklyUsage = "showWeeklyUsage"
        static let iconColorMode = "iconColorMode"
        static let iconAnimationMode = "iconAnimationMode"
        static let didShowCodexAvailabilityCheck = "didShowCodexAvailabilityCheck"
        static let didOfferDisableCodexMenuBarIcon = "didOfferDisableCodexMenuBarIcon"
    }

    private enum MenuLayout {
        static let maxWidth: CGFloat = 300
    }

    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    private let reader = CodexStateReader()
    private let renderer = StatusIconRenderer()
    private let statusDotView = StatusDotView(color: StatusDotPalette.unread)
    private let codexConfigURL = CodexDesktopConfig.defaultConfigURL()
    private let readerQueue = DispatchQueue(label: "CodexBar.reader", qos: .utility)
    private let sessionMenuLimit = 6
    private let pollInterval: TimeInterval = 0.2

    private var pollTimer: Timer?
    private var animationTimer: Timer?
    private var animationTimerMode: StatusIconAnimationMode?
    private var animationFrame = 0
    private var isLoading = false
    private var isMenuOpen = false
    private var snapshot = CodexSnapshot.empty()
    private var sessionRows: [String: SessionMenuItemView] = [:]
    private var sessionRowIDs: [String] = []

    private var showTimer: Bool {
        get { UserDefaults.standard.bool(forKey: DefaultsKey.showTimer, defaultValue: true) }
        set { UserDefaults.standard.set(newValue, forKey: DefaultsKey.showTimer) }
    }

    private var showFiveHourUsage: Bool {
        get { UserDefaults.standard.bool(forKey: DefaultsKey.showFiveHourUsage, defaultValue: true) }
        set { UserDefaults.standard.set(newValue, forKey: DefaultsKey.showFiveHourUsage) }
    }

    private var showWeeklyUsage: Bool {
        get { UserDefaults.standard.bool(forKey: DefaultsKey.showWeeklyUsage, defaultValue: true) }
        set { UserDefaults.standard.set(newValue, forKey: DefaultsKey.showWeeklyUsage) }
    }

    private var iconColorMode: StatusIconColorMode {
        get {
            let rawValue = UserDefaults.standard.string(forKey: DefaultsKey.iconColorMode) ?? StatusIconColorMode.system.rawValue
            return StatusIconColorMode(rawValue: rawValue) ?? .system
        }
        set { UserDefaults.standard.set(newValue.rawValue, forKey: DefaultsKey.iconColorMode) }
    }

    private var iconAnimationMode: StatusIconAnimationMode {
        get {
            let rawValue = UserDefaults.standard.string(forKey: DefaultsKey.iconAnimationMode) ?? StatusIconAnimationMode.orbit.rawValue
            return StatusIconAnimationMode(rawValue: rawValue) ?? .orbit
        }
        set { UserDefaults.standard.set(newValue.rawValue, forKey: DefaultsKey.iconAnimationMode) }
    }

    override init() {
        super.init()

        let menu = NSMenu()
        menu.delegate = self
        statusItem.menu = menu
        statusItem.button?.imagePosition = .imageOnly
        statusItem.button?.imageScaling = .scaleNone
        statusItem.button?.contentTintColor = nil
        statusDotView.isHidden = true
        applyRoundedButtonChrome()

        render()
        loadSnapshot()

        let timer = Timer(timeInterval: pollInterval, repeats: true) { [weak self] _ in
            self?.tick()
        }
        RunLoop.main.add(timer, forMode: .common)
        RunLoop.main.add(timer, forMode: .eventTracking)
        pollTimer = timer

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { [weak self] in
            self?.runFirstLaunchChecks()
        }
    }

    private func runFirstLaunchChecks() {
        let status = CodexInstallDetector.detect()

        if !UserDefaults.standard.bool(forKey: DefaultsKey.didShowCodexAvailabilityCheck, defaultValue: false) {
            UserDefaults.standard.set(true, forKey: DefaultsKey.didShowCodexAvailabilityCheck)
            showCodexAvailabilityAlertIfNeeded(status)
        }

        offerDisableCodexMenuBarIconIfNeeded(status)
    }

    private func showCodexAvailabilityAlertIfNeeded(_ status: CodexInstallStatus) {
        if !status.isInstalled {
            showAlert(
                message: "Codex is not installed",
                informativeText: "Codex Status Bar needs Codex Desktop, the Codex CLI, or an IDE extension to read local activity.",
                buttons: ["OK"]
            )
            return
        }

        guard !status.isRunning else { return }

        if status.desktopAppURL != nil {
            let response = showAlert(
                message: "Codex is not running",
                informativeText: "Open Codex so Codex Status Bar can show live local activity. Recent local sessions may still appear.",
                buttons: ["Open Codex", "Not Now"]
            )

            if response == .alertFirstButtonReturn {
                openCodex()
            }
        } else {
            showAlert(
                message: "Codex is not running",
                informativeText: "Start Codex from your CLI or IDE so Codex Status Bar can show live local activity.",
                buttons: ["OK"]
            )
        }
    }

    private func offerDisableCodexMenuBarIconIfNeeded(_ status: CodexInstallStatus) {
        guard let codexAppURL = status.desktopAppURL,
              !UserDefaults.standard.bool(forKey: DefaultsKey.didOfferDisableCodexMenuBarIcon, defaultValue: false),
              CodexDesktopConfig.menuBarIconEnabled(configURL: codexConfigURL)
        else {
            return
        }

        let response = showAlert(
            message: "Disable Codex's built-in menu bar icon?",
            informativeText: "Codex Status Bar already shows Codex activity in the menu bar, so disabling Codex's own icon prevents duplicate menu bar items.",
            buttons: ["Disable", "Not Now"]
        )

        guard response == .alertFirstButtonReturn else {
            UserDefaults.standard.set(true, forKey: DefaultsKey.didOfferDisableCodexMenuBarIcon)
            return
        }

        do {
            try CodexDesktopConfig.setMenuBarIconEnabled(false, configURL: codexConfigURL)
            UserDefaults.standard.set(true, forKey: DefaultsKey.didOfferDisableCodexMenuBarIcon)
            showCodexRelaunchPrompt(codexAppURL: codexAppURL)
        } catch {
            showAlert(
                message: "Could not update Codex's menu bar setting",
                informativeText: error.localizedDescription,
                buttons: ["OK"]
            )
        }
    }

    private func showCodexRelaunchPrompt(codexAppURL: URL) {
        let isCodexDesktopRunning = isCodexDesktopRunning()
        let response = showAlert(
            message: isCodexDesktopRunning ? "Relaunch Codex now?" : "Open Codex now?",
            informativeText: isCodexDesktopRunning
                ? "Codex Status Bar saved the setting. Relaunch Codex Desktop now to hide the duplicate menu bar icon, or do it later."
                : "Codex Status Bar saved the setting. Open Codex Desktop now to use the new menu bar setting, or do it later.",
            buttons: [isCodexDesktopRunning ? "Relaunch Now" : "Open Now", "Later"]
        )

        guard response == .alertFirstButtonReturn else { return }

        if isCodexDesktopRunning {
            relaunchCodex(at: codexAppURL)
        } else {
            openCodexApplication(at: codexAppURL)
        }
    }

    private func relaunchCodex(at appURL: URL) {
        let runningApplications = runningCodexDesktopApplications()
        guard !runningApplications.isEmpty else {
            openCodexApplication(at: appURL)
            return
        }

        var requestedTermination = false
        for application in runningApplications {
            requestedTermination = application.terminate() || requestedTermination
        }

        guard requestedTermination else {
            showAlert(
                message: "Could not relaunch Codex",
                informativeText: "Codex Status Bar could not ask Codex Desktop to quit. Quit and reopen Codex manually to apply the menu bar setting.",
                buttons: ["OK"]
            )
            return
        }

        openCodexAfterTermination(at: appURL, deadline: Date().addingTimeInterval(8))
    }

    private func openCodexAfterTermination(at appURL: URL, deadline: Date) {
        guard isCodexDesktopRunning() else {
            openCodexApplication(at: appURL)
            return
        }

        guard Date() < deadline else {
            showAlert(
                message: "Codex did not quit",
                informativeText: "Codex Status Bar asked Codex Desktop to quit, but it is still running. Quit and reopen Codex manually to apply the menu bar setting.",
                buttons: ["OK"]
            )
            return
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) { [weak self] in
            self?.openCodexAfterTermination(at: appURL, deadline: deadline)
        }
    }

    private func isCodexDesktopRunning() -> Bool {
        !runningCodexDesktopApplications().isEmpty
    }

    private func runningCodexDesktopApplications() -> [NSRunningApplication] {
        NSWorkspace.shared.runningApplications.filter { application in
            application.bundleIdentifier == "com.openai.codex"
        }
    }

    @discardableResult
    private func showAlert(message: String, informativeText: String, buttons: [String]) -> NSApplication.ModalResponse {
        let alert = NSAlert()
        alert.messageText = message
        alert.informativeText = informativeText
        alert.alertStyle = .informational
        buttons.forEach { alert.addButton(withTitle: $0) }
        NSApp.activate(ignoringOtherApps: true)
        return alert.runModal()
    }

    private func tick() {
        loadSnapshot()
        render()
    }

    private func loadSnapshot() {
        guard !isLoading else { return }
        isLoading = true

        readerQueue.async { [reader] in
            let next = reader.loadSnapshot()
            DispatchQueue.main.async { [weak self] in
                guard let self else { return }

                self.snapshot = next
                self.isLoading = false
                self.render()
                self.refreshOpenSessionRows()
            }
        }
    }

    private func render() {
        let state = CodexBarPresentation.displayState(
            snapshot: snapshot,
            options: displayOptions(),
            now: Date()
        )
        updateAnimation(active: state.animatesIcon, mode: iconAnimationMode)

        let appearance = statusItem.button?.effectiveAppearance ?? NSApp.effectiveAppearance
        statusItem.button?.image = renderer.image(
            active: state.animatesIcon,
            frame: animationFrame,
            colorMode: iconColorMode,
            animationMode: iconAnimationMode,
            appearance: appearance
        )
        applyTitle(state.title, statusDot: state.statusDot)
    }

    private func updateAnimation(active: Bool, mode: StatusIconAnimationMode) {
        if active {
            guard animationTimer == nil || animationTimerMode != mode else { return }
            animationTimer?.invalidate()
            animationTimerMode = mode
            let timer = Timer(timeInterval: mode.frameInterval, repeats: true) { [weak self] _ in
                self?.animationFrame += 1
                self?.render()
            }
            RunLoop.main.add(timer, forMode: .common)
            animationTimer = timer
        } else {
            animationTimer?.invalidate()
            animationTimer = nil
            animationTimerMode = nil
            animationFrame = 0
        }
    }

    private func displayOptions() -> CodexBarDisplayOptions {
        CodexBarDisplayOptions(
            showTimer: showTimer,
            showFiveHourUsage: showFiveHourUsage,
            showWeeklyUsage: showWeeklyUsage
        )
    }

    private func applyTitle(_ title: String, statusDot: CodexBarStatusDot?) {
        guard let button = statusItem.button else { return }
        let title = singleLine(title).trimmingCharacters(in: .whitespacesAndNewlines)

        if title.isEmpty {
            button.imagePosition = .imageOnly
            button.title = ""
            button.attributedTitle = NSAttributedString(string: "")
            statusDotView.isHidden = true
            statusItem.length = 28
            applyRoundedButtonChrome()
            return
        }

        button.imagePosition = .imageLeading
        button.alignment = .left
        button.cell?.alignment = .left
        let font = NSFont.monospacedDigitSystemFont(ofSize: 13, weight: .regular)
        button.font = font
        button.cell?.lineBreakMode = .byTruncatingTail

        let buttonTitle = Self.buttonTitle(title, statusDot: statusDot)
        button.title = buttonTitle
        let imageWidth = button.image?.size.width ?? 18
        statusItem.length = max(48, ceil(Self.titleWidth(buttonTitle, font: font) + imageWidth + 16))
        button.layoutSubtreeIfNeeded()
        updateStatusDot(statusDot, in: button, font: font)
        applyRoundedButtonChrome()
    }

    private func updateStatusDot(_ statusDot: CodexBarStatusDot?, in button: NSStatusBarButton, font: NSFont) {
        guard let statusDot else {
            statusDotView.isHidden = true
            return
        }

        if statusDotView.superview !== button {
            button.addSubview(statusDotView)
        }
        statusDotView.update(color: StatusDotPalette.color(for: statusDot))
        let dotSize = statusDotView.intrinsicContentSize
        let buttonHeight = button.bounds.height > 0 ? button.bounds.height : NSStatusBar.system.thickness
        let titleRect = button.cell?.titleRect(forBounds: button.bounds) ?? button.bounds
        let spaceWidth = Self.titleWidth(" ", font: font)
        let dotSlotWidth = Self.titleWidth(Self.statusDotPlaceholder, font: font)
        statusDotView.frame = NSRect(
            x: titleRect.minX + spaceWidth + floor((dotSlotWidth - dotSize.width) / 2),
            y: floor((buttonHeight - dotSize.height) / 2),
            width: dotSize.width,
            height: dotSize.height
        )
        statusDotView.isHidden = false
    }

    private static let statusDotPlaceholder = "\u{2007}"

    private static func buttonTitle(_ title: String, statusDot: CodexBarStatusDot?) -> String {
        statusDot == nil ? " \(title)" : " \(Self.statusDotPlaceholder) \(title)"
    }

    private static func titleWidth(_ title: String, font: NSFont) -> CGFloat {
        (title as NSString).size(withAttributes: [.font: font]).width
    }

    private func applyRoundedButtonChrome() {
        guard let button = statusItem.button else { return }
        button.layer?.masksToBounds = false
        button.wantsLayer = false
    }

    func menuNeedsUpdate(_ menu: NSMenu) {
        menu.removeAllItems()
        sessionRows.removeAll()
        sessionRowIDs.removeAll()

        let openItem = NSMenuItem(title: "Open Codex", action: #selector(openCodex), keyEquivalent: "")
        openItem.target = self
        menu.addItem(openItem)

        menu.addItem(.separator())
        menu.addItem(disabledItem("Sessions"))
        addSessionRows(to: menu)

        menu.addItem(.separator())
        menu.addItem(disabledItem("Options"))

        let timerItem = NSMenuItem(title: "Show timer", action: #selector(toggleTimer), keyEquivalent: "")
        timerItem.target = self
        timerItem.state = showTimer ? .on : .off
        menu.addItem(timerItem)

        let fiveHourItem = NSMenuItem(title: "Show 5-hour usage", action: #selector(toggleFiveHourUsage), keyEquivalent: "")
        fiveHourItem.target = self
        fiveHourItem.state = showFiveHourUsage ? .on : .off
        menu.addItem(fiveHourItem)

        let weeklyItem = NSMenuItem(title: "Show weekly usage", action: #selector(toggleWeeklyUsage), keyEquivalent: "")
        weeklyItem.target = self
        weeklyItem.state = showWeeklyUsage ? .on : .off
        menu.addItem(weeklyItem)

        menu.addItem(.separator())
        addColorMenu(to: menu)
        addAnimationMenu(to: menu)

        menu.addItem(.separator())
        addStatusRows(to: menu)

        menu.addItem(.separator())
        menu.addItem(disabledItem(versionTitle()))

        let quit = NSMenuItem(title: "Quit Codex Status Bar", action: #selector(quit), keyEquivalent: "q")
        quit.target = self
        menu.addItem(quit)
    }

    func menuWillOpen(_ menu: NSMenu) {
        isMenuOpen = true
        refreshOpenSessionRows()
    }

    func menuDidClose(_ menu: NSMenu) {
        isMenuOpen = false
        sessionRows.removeAll()
        sessionRowIDs.removeAll()
    }

    private func addSessionRows(to menu: NSMenu) {
        sessionRowIDs.removeAll()
        let sessions = visibleMenuSessions()

        guard !sessions.isEmpty else {
            menu.addItem(disabledItem("No active or unread sessions"))
            return
        }

        for session in sessions {
            menu.addItem(sessionMenuItem(for: session))
        }
    }

    private func visibleMenuSessions() -> [CodexSession] {
        CodexBarPresentation.visibleMenuSessions(snapshot: snapshot, limit: sessionMenuLimit)
    }

    private func sessionMenuItem(for session: CodexSession) -> NSMenuItem {
        let item = NSMenuItem()
        let view = SessionMenuItemView(width: MenuLayout.maxWidth, session: session, now: snapshot.generatedAt) { [weak self, weak item] currentSession in
            item?.menu?.cancelTracking()
            self?.openCodexThread(currentSession)
        }
        item.view = view
        item.toolTip = session.statusLabel
        sessionRows[sessionRowKey(for: session)] = view
        sessionRowIDs.append(sessionRowKey(for: session))
        return item
    }

    private func refreshOpenSessionRows() {
        guard isMenuOpen, let menu = statusItem.menu else { return }

        let sessions = visibleMenuSessions()
        let nextIDs = sessions.map(sessionRowKey)

        guard nextIDs == sessionRowIDs else {
            replaceSessionRows(in: menu, with: sessions)
            return
        }

        for session in sessions {
            sessionRows[sessionRowKey(for: session)]?.update(session: session, now: snapshot.generatedAt)
        }
    }

    private func sessionRowKey(for session: CodexSession) -> String {
        session.rolloutPath
    }

    private func replaceSessionRows(in menu: NSMenu, with sessions: [CodexSession]) {
        let startIndex = 3
        guard menu.numberOfItems >= startIndex else { return }

        var endIndex = startIndex
        while endIndex < menu.numberOfItems,
              menu.item(at: endIndex)?.isSeparatorItem == false {
            endIndex += 1
        }

        if endIndex > startIndex {
            for index in stride(from: endIndex - 1, through: startIndex, by: -1) {
                menu.removeItem(at: index)
            }
        }

        sessionRows.removeAll()
        sessionRowIDs.removeAll()

        if sessions.isEmpty {
            menu.insertItem(disabledItem("No active or unread sessions"), at: startIndex)
            return
        }

        for (offset, session) in sessions.enumerated() {
            menu.insertItem(sessionMenuItem(for: session), at: startIndex + offset)
        }
    }

    private func addColorMenu(to menu: NSMenu) {
        let item = NSMenuItem(title: "Color", action: nil, keyEquivalent: "")
        let submenu = NSMenu()

        for mode in StatusIconColorMode.allCases {
            let modeItem = NSMenuItem(title: mode.title, action: #selector(setIconColorMode(_:)), keyEquivalent: "")
            modeItem.target = self
            modeItem.representedObject = mode.rawValue
            modeItem.state = iconColorMode == mode ? .on : .off
            submenu.addItem(modeItem)
        }

        item.submenu = submenu
        menu.addItem(item)
    }

    private func addAnimationMenu(to menu: NSMenu) {
        let item = NSMenuItem(title: "Animation", action: nil, keyEquivalent: "")
        let submenu = NSMenu()

        for mode in StatusIconAnimationMode.allCases {
            let modeItem = NSMenuItem(title: mode.title, action: #selector(setIconAnimationMode(_:)), keyEquivalent: "")
            modeItem.target = self
            modeItem.representedObject = mode.rawValue
            modeItem.state = iconAnimationMode == mode ? .on : .off
            submenu.addItem(modeItem)
        }

        item.submenu = submenu
        menu.addItem(item)
    }

    private func addStatusRows(to menu: NSMenu) {
        let now = Date()

        menu.addItem(disabledItem(UsageFormatter.leftLine(snapshot.usage?.primary, fallbackLabel: "5h")))
        menu.addItem(disabledItem(UsageFormatter.leftLine(snapshot.usage?.secondary, fallbackLabel: "Week")))
        menu.addItem(disabledItem(UsageFormatter.resetLine(snapshot.usage?.primary, fallbackLabel: "5h", now: now)))
        menu.addItem(disabledItem(UsageFormatter.resetLine(snapshot.usage?.secondary, fallbackLabel: "Week", now: now)))

        if let lastError = snapshot.lastError?.nilIfEmpty {
            menu.addItem(disabledItem(truncate("Data: \(lastError)", limit: 30)))
        }
    }

    private func disabledItem(_ title: String) -> NSMenuItem {
        let title = truncate(title, limit: 30)
        let item = NSMenuItem(title: title, action: nil, keyEquivalent: "")
        item.isEnabled = false
        return item
    }

    private func versionTitle() -> String {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0.1.0"
        return "Version \(version)"
    }

    @objc private func openCodex() {
        let workspace = NSWorkspace.shared
        if let appURL = workspace.urlForApplication(withBundleIdentifier: "com.openai.codex") {
            openCodexApplication(at: appURL)
            return
        }

        let fallbackURL = URL(fileURLWithPath: "/Applications/Codex.app")
        if FileManager.default.fileExists(atPath: fallbackURL.path) {
            openCodexApplication(at: fallbackURL)
        }
    }

    private func openCodexApplication(at appURL: URL) {
        NSWorkspace.shared.openApplication(at: appURL, configuration: NSWorkspace.OpenConfiguration())
    }

    private func openCodexThread(_ session: CodexSession) {
        guard let threadURL = CodexBarPresentation.codexThreadURL(for: session.id),
              NSWorkspace.shared.open(threadURL)
        else {
            openCodex()
            return
        }
    }

    @objc private func toggleTimer() {
        showTimer.toggle()
        render()
    }

    @objc private func toggleFiveHourUsage() {
        showFiveHourUsage.toggle()
        render()
    }

    @objc private func toggleWeeklyUsage() {
        showWeeklyUsage.toggle()
        render()
    }

    @objc private func setIconColorMode(_ sender: NSMenuItem) {
        guard
            let rawValue = sender.representedObject as? String,
            let mode = StatusIconColorMode(rawValue: rawValue)
        else {
            return
        }

        iconColorMode = mode
        render()
    }

    @objc private func setIconAnimationMode(_ sender: NSMenuItem) {
        guard
            let rawValue = sender.representedObject as? String,
            let mode = StatusIconAnimationMode(rawValue: rawValue)
        else {
            return
        }

        iconAnimationMode = mode
        render()
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }

    private func truncate(_ value: String, limit: Int) -> String {
        CodexBarPresentation.truncate(value, limit: limit)
    }

    private func singleLine(_ value: String) -> String {
        CodexBarPresentation.singleLine(value)
    }

}

private extension UserDefaults {
    func bool(forKey key: String, defaultValue: Bool) -> Bool {
        object(forKey: key) == nil ? defaultValue : bool(forKey: key)
    }
}

private extension String {
    var nilIfEmpty: String? {
        isEmpty ? nil : self
    }
}

private enum StatusDotPalette {
    static let approval = NSColor(calibratedRed: CGFloat(0x42) / 255, green: CGFloat(0xc6) / 255, blue: CGFloat(0x77) / 255, alpha: 1)
    static let unread = NSColor(calibratedRed: CGFloat(0x83) / 255, green: CGFloat(0xc4) / 255, blue: CGFloat(0xff) / 255, alpha: 1)

    static func color(for statusDot: CodexBarStatusDot) -> NSColor {
        switch statusDot {
        case .approval:
            return approval
        case .unread:
            return unread
        }
    }
}

private final class SessionMenuItemView: NSView {
    private enum LeadingIndicator: Equatable {
        case approval
        case active
        case unread
        case disclosure
    }

    private static let rowHeight: CGFloat = 24
    private static let iconBoxWidth: CGFloat = 10
    private static let indicatorTitleSpacing: CGFloat = 5

    private let width: CGFloat
    private var session: CodexSession
    private var renderedIndicator: LeadingIndicator?
    private var iconConstraints: [NSLayoutConstraint] = []
    private let iconBox = NSView()
    private let titleLabel = NSTextField(labelWithString: "")
    private let timeLabel = NSTextField(labelWithString: "")
    private let badgeView: BadgeView
    private let chevronView = NSImageView()
    private let clickHandler: (CodexSession) -> Void

    private var isOpenable: Bool {
        session.client == .app
    }

    private var trackingArea: NSTrackingArea?
    private var highlighted = false {
        didSet {
            updateColors()
            needsDisplay = true
        }
    }

    init(width: CGFloat, session: CodexSession, now: Date, clickHandler: @escaping (CodexSession) -> Void) {
        self.width = width
        self.session = session
        self.badgeView = BadgeView(text: session.client?.rawValue)
        self.clickHandler = clickHandler

        super.init(frame: NSRect(origin: .zero, size: NSSize(width: width, height: Self.rowHeight)))

        setupLayout()
        update(session: session, now: now)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override var intrinsicContentSize: NSSize {
        NSSize(width: width, height: Self.rowHeight)
    }

    override func setFrameSize(_ newSize: NSSize) {
        super.setFrameSize(NSSize(width: min(newSize.width, width), height: Self.rowHeight))
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)

        guard highlighted else { return }

        NSColor.controlAccentColor.setFill()
        let rect = bounds.insetBy(dx: 5, dy: 1)
        NSBezierPath(roundedRect: rect, xRadius: 4, yRadius: 4).fill()
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()

        if let trackingArea {
            removeTrackingArea(trackingArea)
        }

        let area = NSTrackingArea(
            rect: bounds,
            options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect],
            owner: self
        )
        addTrackingArea(area)
        trackingArea = area
    }

    override func mouseEntered(with event: NSEvent) {
        guard isOpenable else { return }
        highlighted = true
    }

    override func mouseExited(with event: NSEvent) {
        highlighted = false
    }

    override func mouseDown(with event: NSEvent) {
        guard isOpenable else { return }
        clickHandler(session)
    }

    func update(session: CodexSession, now: Date) {
        self.session = session
        if !isOpenable {
            highlighted = false
        }
        toolTip = session.statusLabel

        titleLabel.stringValue = session.title
        badgeView.update(text: session.client?.rawValue)
        updateIconIfNeeded(indicator: leadingIndicator(for: session))
        updateElapsedTime(now: now)
        updateColors()
    }

    private func setupLayout() {
        iconBox.translatesAutoresizingMaskIntoConstraints = false

        titleLabel.font = .menuFont(ofSize: 13)
        configureSingleLineLabel(titleLabel, lineBreakMode: .byTruncatingTail)
        titleLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        titleLabel.setContentHuggingPriority(.defaultLow, for: .horizontal)

        timeLabel.font = .monospacedDigitSystemFont(ofSize: 12, weight: .medium)
        configureSingleLineLabel(timeLabel, lineBreakMode: .byTruncatingTail)
        timeLabel.setContentCompressionResistancePriority(.required, for: .horizontal)
        timeLabel.setContentHuggingPriority(.required, for: .horizontal)

        badgeView.setContentCompressionResistancePriority(.required, for: .horizontal)
        badgeView.setContentHuggingPriority(.required, for: .horizontal)

        let stack = NSStackView(views: [iconBox, titleLabel, timeLabel, badgeView])
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.detachesHiddenViews = true
        stack.orientation = .horizontal
        stack.alignment = .centerY
        stack.spacing = 8
        stack.distribution = .fill
        stack.setCustomSpacing(Self.indicatorTitleSpacing, after: iconBox)
        addSubview(stack)

        NSLayoutConstraint.activate([
            iconBox.widthAnchor.constraint(equalToConstant: Self.iconBoxWidth),
            iconBox.heightAnchor.constraint(equalToConstant: 14),
            stack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 12),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -10),
            stack.centerYAnchor.constraint(equalTo: centerYAnchor),
        ])
    }

    private func updateIconIfNeeded(indicator: LeadingIndicator) {
        guard renderedIndicator != indicator else { return }

        NSLayoutConstraint.deactivate(iconConstraints)
        iconConstraints.removeAll()
        iconBox.subviews.forEach { $0.removeFromSuperview() }
        renderedIndicator = indicator

        switch indicator {
        case .approval:
            let dotView = StatusDotView(color: StatusDotPalette.approval)
            dotView.translatesAutoresizingMaskIntoConstraints = false
            iconBox.addSubview(dotView)

            iconConstraints = [
                dotView.centerXAnchor.constraint(equalTo: iconBox.centerXAnchor),
                dotView.centerYAnchor.constraint(equalTo: iconBox.centerYAnchor),
                dotView.widthAnchor.constraint(equalToConstant: 7),
                dotView.heightAnchor.constraint(equalToConstant: 7),
            ]

        case .active:
            let spinner = NSProgressIndicator()
            spinner.translatesAutoresizingMaskIntoConstraints = false
            spinner.style = .spinning
            spinner.controlSize = .small
            spinner.isIndeterminate = true
            spinner.isDisplayedWhenStopped = true
            spinner.startAnimation(nil)
            iconBox.addSubview(spinner)

            iconConstraints = [
                spinner.centerXAnchor.constraint(equalTo: iconBox.centerXAnchor),
                spinner.centerYAnchor.constraint(equalTo: iconBox.centerYAnchor),
                spinner.widthAnchor.constraint(equalToConstant: 12),
                spinner.heightAnchor.constraint(equalToConstant: 12),
            ]

        case .unread:
            let dotView = StatusDotView(color: StatusDotPalette.unread)
            dotView.translatesAutoresizingMaskIntoConstraints = false
            iconBox.addSubview(dotView)

            iconConstraints = [
                dotView.centerXAnchor.constraint(equalTo: iconBox.centerXAnchor),
                dotView.centerYAnchor.constraint(equalTo: iconBox.centerYAnchor),
                dotView.widthAnchor.constraint(equalToConstant: 7),
                dotView.heightAnchor.constraint(equalToConstant: 7),
            ]

        case .disclosure:
            chevronView.translatesAutoresizingMaskIntoConstraints = false
            chevronView.image = NSImage(systemSymbolName: "chevron.right", accessibilityDescription: nil)
            chevronView.symbolConfiguration = NSImage.SymbolConfiguration(pointSize: 9, weight: .regular)
            iconBox.addSubview(chevronView)

            iconConstraints = [
                chevronView.centerXAnchor.constraint(equalTo: iconBox.centerXAnchor),
                chevronView.centerYAnchor.constraint(equalTo: iconBox.centerYAnchor),
                chevronView.widthAnchor.constraint(equalToConstant: 8),
                chevronView.heightAnchor.constraint(equalToConstant: 10),
            ]
        }

        NSLayoutConstraint.activate(iconConstraints)
    }

    private func leadingIndicator(for session: CodexSession) -> LeadingIndicator {
        if let statusLabel = session.statusLabel,
           CodexBarPresentation.isApprovalLabel(statusLabel) {
            return .approval
        }

        if session.isActive {
            return .active
        }

        if session.isUnread {
            return .unread
        }

        return .disclosure
    }

    private func updateColors() {
        let primaryColor: NSColor
        let secondaryColor: NSColor

        if highlighted {
            primaryColor = .selectedMenuItemTextColor
            secondaryColor = .selectedMenuItemTextColor.withAlphaComponent(0.84)
        } else if session.isActive || session.isUnread {
            primaryColor = .labelColor
            secondaryColor = .secondaryLabelColor
        } else {
            primaryColor = .secondaryLabelColor
            secondaryColor = .tertiaryLabelColor
        }

        titleLabel.textColor = primaryColor
        timeLabel.textColor = secondaryColor
        chevronView.contentTintColor = secondaryColor
        badgeView.highlighted = highlighted
    }

    private func updateElapsedTime(now: Date) {
        let timeText = session.activeStartedAt.map { Self.elapsedText(since: $0, now: now) } ?? ""
        guard timeLabel.stringValue != timeText || timeLabel.isHidden != timeText.isEmpty else { return }

        timeLabel.stringValue = timeText
        timeLabel.isHidden = timeText.isEmpty
        timeLabel.invalidateIntrinsicContentSize()
        needsLayout = true
    }

    private static func elapsedText(since start: Date, now: Date) -> String {
        CodexBarPresentation.elapsedText(since: start, now: now)
    }

    private func configureSingleLineLabel(_ label: NSTextField, lineBreakMode: NSLineBreakMode) {
        label.lineBreakMode = lineBreakMode
        label.maximumNumberOfLines = 1
        label.usesSingleLineMode = true
        label.cell?.wraps = false
        label.cell?.isScrollable = false
        label.cell?.lineBreakMode = lineBreakMode
    }
}

private final class StatusDotView: NSView {
    private var color: NSColor

    init(color: NSColor) {
        self.color = color
        super.init(frame: .zero)
    }

    func update(color: NSColor) {
        guard !self.color.isEqual(color) else { return }

        self.color = color
        needsDisplay = true
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override var intrinsicContentSize: NSSize {
        NSSize(width: 7, height: 7)
    }

    override func hitTest(_ point: NSPoint) -> NSView? {
        nil
    }

    override func draw(_ dirtyRect: NSRect) {
        color.setFill()
        NSBezierPath(ovalIn: bounds).fill()
    }
}

private final class BadgeView: NSView {
    private static let height: CGFloat = 16
    private static let horizontalPadding: CGFloat = 6

    private var text: String?
    private let font = NSFont.systemFont(ofSize: 9, weight: .semibold)
    private let label = NSTextField(labelWithString: "")

    var highlighted = false {
        didSet {
            updateColors()
            needsDisplay = true
        }
    }

    init(text: String?) {
        self.text = text
        super.init(frame: .zero)
        setupLayout()
        updateColors()
        isHidden = text == nil
        label.stringValue = text ?? ""
    }

    func update(text: String?) {
        guard self.text != text else { return }

        self.text = text
        isHidden = text == nil
        label.stringValue = text ?? ""
        invalidateIntrinsicContentSize()
        needsDisplay = true
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override var intrinsicContentSize: NSSize {
        guard text != nil else { return .zero }

        let width = label.intrinsicContentSize.width + (Self.horizontalPadding * 2)
        return NSSize(width: max(30, ceil(width)), height: Self.height)
    }

    override func draw(_ dirtyRect: NSRect) {
        guard text != nil else { return }

        let fill = highlighted
            ? NSColor.selectedMenuItemTextColor.withAlphaComponent(0.16)
            : NSColor.tertiaryLabelColor.withAlphaComponent(0.18)
        fill.setFill()

        let rect = bounds.insetBy(dx: 0, dy: 1)
        NSBezierPath(roundedRect: rect, xRadius: 7, yRadius: 7).fill()
    }

    private func setupLayout() {
        label.translatesAutoresizingMaskIntoConstraints = false
        label.font = font
        label.alignment = .center
        label.lineBreakMode = .byClipping
        label.maximumNumberOfLines = 1
        label.usesSingleLineMode = true
        label.cell?.wraps = false
        label.cell?.isScrollable = false
        label.cell?.lineBreakMode = .byClipping
        addSubview(label)

        NSLayoutConstraint.activate([
            label.centerXAnchor.constraint(equalTo: centerXAnchor),
            label.centerYAnchor.constraint(equalTo: centerYAnchor),
        ])
    }

    private func updateColors() {
        label.textColor = highlighted ? NSColor.selectedMenuItemTextColor : NSColor.secondaryLabelColor
    }
}
