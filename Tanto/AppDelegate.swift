import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private var accessibilityStatusItem: NSMenuItem?
    private var monitor: KeyMonitor?
    private let engine = ScriptEngine()

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSLog("Tanto: applicationDidFinishLaunching")
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem.button {
            if let icon = NSImage(named: "MenuBarIcon") {
                icon.isTemplate = true
                button.image = icon
                button.imagePosition = .imageOnly
                button.toolTip = "Tanto"
            } else {
                button.title = "Tanto"
                NSLog("Tanto: MenuBarIcon not found; using text fallback")
            }
        }
        let menu = NSMenu()
        let accessibilityItem = NSMenuItem(title: "Accessibility permission required", action: nil, keyEquivalent: "")
        accessibilityItem.isEnabled = false
        accessibilityItem.isHidden = true
        menu.addItem(accessibilityItem)
        accessibilityStatusItem = accessibilityItem

        menu.addItem(NSMenuItem(title: "Reset Accessibility…", action: #selector(resetAccessibility), keyEquivalent: ""))
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "About Tanto", action: #selector(showAbout), keyEquivalent: ""))
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "Open rules.js", action: #selector(openRules), keyEquivalent: ""))
        menu.addItem(NSMenuItem(title: "Reload rules.js", action: #selector(reloadRules), keyEquivalent: "r"))
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "Quit Tanto", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        statusItem.menu = menu

        engine.prepareDefaultRulesIfNeeded()
        engine.reload()
        monitor = KeyMonitor { [weak self] expression in self?.engine.evaluate(expression) }
        updateAccessibilityPresentation()

        monitor?.start()
    }

    private func updateAccessibilityPresentation() {
        let trusted = AXIsProcessTrusted()
        accessibilityStatusItem?.isHidden = trusted

        guard let button = statusItem.button else { return }
        if trusted {
            button.alphaValue = 1.0
            button.toolTip = "Tanto"
        } else {
            button.alphaValue = 0.35
            button.toolTip = "Tanto — Accessibility permission required"
        }
    }

    @objc private func resetAccessibility() {
        let alert = NSAlert()
        alert.messageText = "Reset Accessibility Permission"
        alert.informativeText = "This resets Tanto's Accessibility permission. After resetting, allow Tanto again in System Settings."
        alert.addButton(withTitle: "Reset")
        alert.addButton(withTitle: "Cancel")

        guard alert.runModal() == .alertFirstButtonReturn else { return }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/tccutil")
        process.arguments = ["reset", "Accessibility", "com.tulipsoft.Tanto"]

        do {
            try process.run()
            process.waitUntilExit()
            updateAccessibilityPresentation()

            if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
                NSWorkspace.shared.open(url)
            }
        } catch {
            let errorAlert = NSAlert()
            errorAlert.messageText = "Accessibility reset failed"
            errorAlert.informativeText = error.localizedDescription
            errorAlert.runModal()
        }
    }

    @objc private func showAbout() {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "—"

        let alert = NSAlert()
        alert.messageText = "Tanto"
        alert.informativeText = "Version \(version)\n\nTiny scripts, right where you type.\n\n© 2026 Tulipsoft"
        alert.addButton(withTitle: "OK")
        alert.addButton(withTitle: "https://tulipsoft.com/")

        let response = alert.runModal()
        if response == .alertSecondButtonReturn,
           let url = URL(string: "https://tulipsoft.com/") {
            NSWorkspace.shared.open(url)
        }
    }

    @objc private func openRules() { engine.openRules() }
    @objc private func reloadRules() { engine.reload() }
}
