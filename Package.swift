// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "SlapClaude",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(
            name: "SlapClaude",
            path: "Sources/SlapClaude",
            linkerSettings: [
                .linkedFramework("CoreGraphics"),
                .linkedFramework("AppKit"),
                .linkedFramework("ApplicationServices"),
                .linkedFramework("AVFoundation"),
                .linkedFramework("CoreAudio"),
            ]
        )
    ]
)
