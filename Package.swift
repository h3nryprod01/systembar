// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "SystemBar",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(
            name: "SystemBar",
            path: "Sources/SystemBar"
        )
    ]
)
