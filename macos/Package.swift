// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "UltraWTiling",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "UltraWTiling", targets: ["UltraWTiling"])
    ],
    targets: [
        .executableTarget(
            name: "UltraWTiling",
            path: "Sources/UltraWTiling"
        )
    ]
)
