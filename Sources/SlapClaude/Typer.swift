import ApplicationServices
import CoreGraphics
import Foundation

// Injects keystrokes into the currently focused application via CGEventPost.
// Requires Accessibility permission — prompt is shown automatically on first use.
final class Typer {
    var hasAccessibilityPermission: Bool {
        AXIsProcessTrusted()
    }

    func requestAccessibilityPermission() {
        let key = kAXTrustedCheckOptionPrompt.takeRetainedValue() as String
        AXIsProcessTrustedWithOptions([key: true] as CFDictionary)
    }

    func type(_ string: String) {
        guard hasAccessibilityPermission else { return }
        let source = CGEventSource(stateID: .hidSystemState)

        for scalar in string.unicodeScalars {
            var ch = UniChar(scalar.value & 0xFFFF)
            guard let down = CGEvent(keyboardEventSource: source, virtualKey: 0, keyDown: true),
                  let up   = CGEvent(keyboardEventSource: source, virtualKey: 0, keyDown: false)
            else { continue }
            down.keyboardSetUnicodeString(stringLength: 1, unicodeString: &ch)
            up.keyboardSetUnicodeString(stringLength: 1, unicodeString: &ch)
            down.post(tap: .cghidEventTap)
            up.post(tap: .cghidEventTap)
        }

        // Press Return to submit in Claude Code
        let returnDown = CGEvent(keyboardEventSource: source, virtualKey: 0x24, keyDown: true)
        let returnUp   = CGEvent(keyboardEventSource: source, virtualKey: 0x24, keyDown: false)
        returnDown?.post(tap: .cghidEventTap)
        returnUp?.post(tap: .cghidEventTap)
    }
}
