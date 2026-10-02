// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "StillLink",
    platforms: [.macOS(.v13)],
    dependencies: [
        // App 內更新（檢查、下載、驗證簽名、安裝並重新打開）
        .package(url: "https://github.com/sparkle-project/Sparkle", from: "2.6.0"),
    ],
    targets: [
        .executableTarget(
            name: "StillLink",
            dependencies: [.product(name: "Sparkle", package: "Sparkle")],
            path: "Sources/StillLink",
            swiftSettings: [.swiftLanguageMode(.v5)],
            // Sparkle.framework 會放在 .app/Contents/Frameworks
            linkerSettings: [.unsafeFlags(["-Xlinker", "-rpath", "-Xlinker", "@executable_path/../Frameworks"])]
        ),
    ]
)
