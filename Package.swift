// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "Retrazo",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(
            name: "Retrazo",
            targets: ["Retrazo"]
        )
    ],
    dependencies: [],
    targets: [
        .executableTarget(
            name: "Retrazo",
            dependencies: [],
            path: "Sources/Retrazo",
            resources: [
                .process("Resources")
            ]
        )
    ]
)
