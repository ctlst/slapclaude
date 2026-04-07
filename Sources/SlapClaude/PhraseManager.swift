import AppKit
import Foundation

// Loads encouraging phrases from ~/.config/slapclaude/phrases.txt (one per line).
// Seeds the file with defaults on first launch so it's ready to edit.
final class PhraseManager {
    private let phrasesURL: URL = {
        let config = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".config/slapclaude")
        try? FileManager.default.createDirectory(at: config, withIntermediateDirectories: true)
        return config.appendingPathComponent("phrases.txt")
    }()

    private let defaults = """
        yes keep going
        you're doing great
        absolutely, continue
        perfect, keep it up
        exactly right
        yes! that's it
        looking good
        that's the way
        nailed it
        brilliant
        yes yes yes
        that's perfect
        you got this
        keep going
        right on track
        exactly what I was thinking
        love it, more
        chef's kiss
        100%
        you're crushing it
        """

    init() {
        seedIfNeeded()
    }

    func randomPhrase() -> String {
        let lines = phrases()
        return lines.randomElement() ?? "yes keep going"
    }

    func openForEditing() {
        NSWorkspace.shared.open(phrasesURL)
    }

    private func phrases() -> [String] {
        guard let raw = try? String(contentsOf: phrasesURL, encoding: .utf8) else {
            return defaults.components(separatedBy: "\n").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
        }
        return raw.components(separatedBy: "\n")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
    }

    private func seedIfNeeded() {
        guard !FileManager.default.fileExists(atPath: phrasesURL.path) else { return }
        try? defaults.write(to: phrasesURL, atomically: true, encoding: .utf8)
    }
}
