// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "MemoryBar",
    platforms: [.macOS(.v13)],
    products: [.executable(name: "MemoryBar", targets: ["MemoryBar"])],
    targets: [
        .target(name: "MetricsCore"),
        .executableTarget(name: "MemoryBar", dependencies: ["MetricsCore"]),
        .testTarget(name: "MetricsCoreTests", dependencies: ["MetricsCore"])
    ]
)
