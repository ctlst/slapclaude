import AppKit
import Foundation

// Checks whether Claude Code is the active application.
// Handles two cases:
//   1. The Claude Code desktop app is frontmost.
//   2. A supported terminal emulator is frontmost AND a 'claude' process is running.
final class FocusChecker {
    private let claudeAppNames: Set<String> = ["Claude", "Claude Code"]
    private let claudeBundleIDs: Set<String> = [
        "com.anthropic.claudecode",
        "com.anthropic.claude",
    ]
    private let terminalBundleIDs: Set<String> = [
        "com.apple.Terminal",
        "com.googlecode.iterm2",
        "dev.warp.Warp-Stable",
        "com.mitchellh.ghostty",
        "io.alacritty",
        "net.kovidgoyal.kitty",
        "co.zeit.hyper",
        "com.github.wez.wezterm",
        "com.qvacua.VimR",
    ]

    func isClaudeCodeActive() -> Bool {
        guard let front = NSWorkspace.shared.frontmostApplication else { return false }
        let name   = front.localizedName ?? ""
        let bundle = front.bundleIdentifier ?? ""

        if claudeAppNames.contains(name) || claudeBundleIDs.contains(bundle) {
            return true
        }
        if terminalBundleIDs.contains(bundle) {
            return isClaudeCLIRunning()
        }
        return false
    }

    private func isClaudeCLIRunning() -> Bool {
        // pgrep -x is unreliable on macOS for some process names; use ps instead.
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/bin/ps")
        task.arguments = ["-axo", "comm"]
        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = Pipe()
        do {
            try task.run()
            task.waitUntilExit()
            let output = String(data: pipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
            return output.components(separatedBy: "\n").contains { $0.trimmingCharacters(in: .whitespaces) == "claude" }
        } catch {
            return false
        }
    }
}
