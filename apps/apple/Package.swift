// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "StillLink",
    platforms: [.macOS(.v13)],
    targets: [
        .executableTarget(
            name: "StillLink",
            path: "Sources/StillLink",
            swiftSettings: [.swiftLanguageMode(.v5)]
        ),
    ]
)
