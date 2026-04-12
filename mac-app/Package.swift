// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "PediatricsRAGMacApp",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "PediatricsRAGMacApp", targets: ["PediatricsRAGMacApp"]),
    ],
    targets: [
        .executableTarget(
            name: "PediatricsRAGMacApp",
            path: "Sources/PediatricsRAGMacApp"
        ),
    ]
)
