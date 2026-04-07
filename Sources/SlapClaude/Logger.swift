import Foundation

private let logURL = FileManager.default.homeDirectoryForCurrentUser
    .appendingPathComponent(".config/slapclaude/debug.log")

func log(_ message: String) {
    let line = "[\(Date())] \(message)\n"
    if let data = line.data(using: .utf8) {
        if FileManager.default.fileExists(atPath: logURL.path) {
            if let fh = try? FileHandle(forWritingTo: logURL) {
                fh.seekToEndOfFile()
                fh.write(data)
                try? fh.close()
            }
        } else {
            try? FileManager.default.createDirectory(at: logURL.deletingLastPathComponent(),
                                                      withIntermediateDirectories: true)
            try? data.write(to: logURL)
        }
    }
}
