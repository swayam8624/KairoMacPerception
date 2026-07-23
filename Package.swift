// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "KairoMacPerception",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "KairoMacPerception", targets: ["KairoMacPerception"])
    ],
    targets: [
        .target(name: "KairoMacPerception"),
        .testTarget(name: "KairoMacPerceptionTests", dependencies: ["KairoMacPerception"])
    ]
)
