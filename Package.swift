// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "CodexStatusBar",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .library(name: "CodexBarCore", targets: ["CodexBarCore"]),
        .executable(name: "CodexStatusBar", targets: ["CodexStatusBar"]),
    ],
    targets: [
        .target(name: "CodexBarCore"),
        .executableTarget(
            name: "CodexStatusBar",
            dependencies: ["CodexBarCore"],
            path: "Sources/CodexBar",
            exclude: ["Resources"],
            linkerSettings: [
                .linkedFramework("AppKit"),
                .linkedFramework("ServiceManagement")
            ]
        ),
        .testTarget(
            name: "CodexBarCoreTests",
            dependencies: ["CodexBarCore"]
        ),
    ]
)
