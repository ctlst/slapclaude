import AppKit
import Foundation

// Checks whether a supported coding tool is the active application.
// Handles two cases:
//   1. A supported desktop app is frontmost.
//   2. A supported terminal emulator is frontmost AND a supported CLI process is running.
final class FocusChecker {
    private let supportedAppNames: Set<String> = ["Claude", "Claude Code", "Codex", "OpenCode"]
    private let supportedBundleIDs: Set<String> = [
        "com.anthropic.claudecode",
        "com.anthropic.claude",
    ]
    private let supportedCLIProcesses: Set<String> = ["claude", "codex", "opencode"]
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

    func isSupportedToolActive() -> Bool {
        guard let front = NSWorkspace.shared.frontmostApplication else { return false }
        let name   = front.localizedName ?? ""
        let bundle = front.bundleIdentifier ?? ""

        if supportedAppNames.contains(name) || supportedBundleIDs.contains(bundle) {
            return true
        }
        if terminalBundleIDs.contains(bundle) {
            return isSupportedCLIRunning()
        }
        return false
    }

    private func isSupportedCLIRunning() -> Bool {
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
            return output.components(separatedBy: "\n").contains {
                supportedCLIProcesses.contains($0.trimmingCharacters(in: .whitespaces))
            }
        } catch {
            return false
        }
    }
}
