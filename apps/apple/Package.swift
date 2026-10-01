// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Ziwei",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(
            name: "Ziwei",
            path: "Sources/Ziwei",
            swiftSettings: [.swiftLanguageMode(.v5)]
        ),
    ]
)
