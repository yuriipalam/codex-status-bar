// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "CodexBar",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .library(name: "CodexBarCore", targets: ["CodexBarCore"]),
        .executable(name: "CodexBar", targets: ["CodexBar"]),
    ],
    targets: [
        .target(name: "CodexBarCore"),
        .executableTarget(
            name: "CodexBar",
            dependencies: ["CodexBarCore"],
            exclude: ["Resources"],
            linkerSettings: [
                .linkedFramework("AppKit")
            ]
        ),
        .testTarget(
            name: "CodexBarCoreTests",
            dependencies: ["CodexBarCore"]
        ),
    ]
)
