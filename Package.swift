// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "KairoMacPerception",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "KairoMacPerception", targets: ["KairoMacPerception"]),
        .library(name: "KairoControlProtocol", targets: ["KairoControlProtocol"]),
        .executable(name: "KairoControlLab", targets: ["KairoControlLab"])
    ],
    targets: [
        .target(name: "KairoMacPerception"),
        .target(name: "KairoControlProtocol"),
        .executableTarget(name: "KairoControlLab", dependencies: ["KairoMacPerception", "KairoControlProtocol"]),
        .testTarget(name: "KairoMacPerceptionTests", dependencies: ["KairoMacPerception", "KairoControlProtocol"])
    ]
)
