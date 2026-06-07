// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "colm",
    platforms: [
        .macOS(.v13)
    ],
    targets: [
        .executableTarget(
            name: "colm",
            path: "Sources/colm"
        ),
        // Test target added in Phase 2 when first tests land.
    ]
)
