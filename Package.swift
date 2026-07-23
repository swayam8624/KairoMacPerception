// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "KairoMacPerception",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "KairoMacPerception", targets: ["KairoMacPerception"]),
        .library(name: "KairoControlProtocol", targets: ["KairoControlProtocol"])
    ],
    targets: [
        .target(name: "KairoMacPerception"),
        .target(name: "KairoControlProtocol"),
        .testTarget(name: "KairoMacPerceptionTests", dependencies: ["KairoMacPerception", "KairoControlProtocol"])
    ]
)
