import AppKit
import Foundation

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private let accel        = AccelerometerSlapDetector()
    private let audio        = AudioSlapDetector()
    private let focus        = FocusChecker()
    private let typer        = Typer()
    private let phrases      = PhraseManager()
    private var usingAccel   = false

    private var isEnabled: Bool {
        get { UserDefaults.standard.object(forKey: "enabled") as? Bool ?? true }
        set { UserDefaults.standard.set(newValue, forKey: "enabled"); refreshMenu() }
    }

    private var sensitivity: Sensitivity {
        get { Sensitivity(rawValue: UserDefaults.standard.integer(forKey: "sensitivity")) ?? .medium }
        set {
            UserDefaults.standard.set(newValue.rawValue, forKey: "sensitivity")
            accel.sensitivity = newValue
            audio.sensitivity = newValue
            refreshMenu()
        }
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        setupStatusItem()
        setupPipeline()
        checkAccessibility()
    }

    // MARK: - Status item

    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        refreshMenu()
    }

    private func refreshMenu() {
        updateIcon()
        statusItem.menu = buildMenu()
    }

    private func updateIcon() {
        let name = isEnabled ? "hand.tap.fill" : "hand.tap"
        statusItem.button?.image = NSImage(systemSymbolName: name, accessibilityDescription: "SlapClaude")
        statusItem.button?.image?.isTemplate = true
    }

    private func buildMenu() -> NSMenu {
        let menu = NSMenu()

        let toggle = NSMenuItem(title: "Enabled", action: #selector(toggleEnabled), keyEquivalent: "")
        toggle.state = isEnabled ? .on : .off
        toggle.target = self
        menu.addItem(toggle)

        menu.addItem(.separator())

        let sensMenu = NSMenu()
        for level in Sensitivity.allCases {
            let item = NSMenuItem(title: level.displayName, action: #selector(setSensitivity(_:)), keyEquivalent: "")
            item.tag = level.rawValue
            item.state = sensitivity == level ? .on : .off
            item.target = self
            sensMenu.addItem(item)
        }
        let sensItem = NSMenuItem(title: "Sensitivity", action: nil, keyEquivalent: "")
        sensItem.submenu = sensMenu
        menu.addItem(sensItem)

        menu.addItem(.separator())

        let edit = NSMenuItem(title: "Edit Phrases…", action: #selector(editPhrases), keyEquivalent: "")
        edit.target = self
        menu.addItem(edit)

        menu.addItem(.separator())

        let quit = NSMenuItem(title: "Quit SlapClaude", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        menu.addItem(quit)

        return menu
    }

    // MARK: - Actions

    @objc private func toggleEnabled() {
        isEnabled.toggle()
    }

    @objc private func setSensitivity(_ sender: NSMenuItem) {
        guard let level = Sensitivity(rawValue: sender.tag) else { return }
        sensitivity = level
    }

    @objc private func editPhrases() {
        phrases.openForEditing()
    }

    // MARK: - Pipeline

    private func setupPipeline() {
        accel.sensitivity = sensitivity
        accel.onSlap = { [weak self] in self?.handleSlap() }

        if accel.start() {
            usingAccel = true
            log("Using accelerometer for slap detection")
        } else {
            log("Accelerometer unavailable — falling back to microphone")
            audio.sensitivity = sensitivity
            audio.onSlap = { [weak self] in self?.handleSlap() }
            audio.requestPermissionAndStart { granted in
                if !granted {
                    self.showAlert(
                        title: "Microphone access required",
                        message: "SlapClaude needs microphone access. Grant it in System Settings → Privacy & Security → Microphone."
                    )
                }
            }
        }
    }

    private func handleSlap() {
        guard isEnabled else { log("blocked: disabled"); return }
        let front = NSWorkspace.shared.frontmostApplication
        log("slap — frontmost: \(front?.localizedName ?? "nil") [\(front?.bundleIdentifier ?? "nil")]")
        guard focus.isSupportedToolActive() else { log("blocked: focus check failed"); return }
        guard typer.hasAccessibilityPermission else { log("blocked: no accessibility"); return }
        let phrase = phrases.randomPhrase()
        log("typing: \(phrase)")
        typer.type(phrase)
    }

    // MARK: - Accessibility

    private func checkAccessibility() {
        if !typer.hasAccessibilityPermission {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                self.typer.requestAccessibilityPermission()
            }
        }
    }

    // MARK: - Helpers

    private func showAlert(title: String, message: String) {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = message
        alert.alertStyle = .warning
        alert.runModal()
    }
}
