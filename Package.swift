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
        .testTarget(
            name: "colmTests",
            dependencies: ["colm"],
            path: "Tests/colmTests"
        ),
    ]
)
