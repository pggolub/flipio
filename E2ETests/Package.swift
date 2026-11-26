// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "FlipioE2E",
    platforms: [.macOS(.v14)],
    targets: [
        .target(name: "E2EKit"),
        .testTarget(name: "FlipioE2ETests", dependencies: ["E2EKit"]),
    ],
    swiftLanguageModes: [.v5]
)
