// swift-tools-version: 6.0
// TEACHING MAP — Package.swift
// Swift Package manifest. Defines build targets and module dependencies between perception,
// control protocol, application/demo and tests; the Swift tools-version declaration must
// remain first.
// See READING_ORDER.md for the cross-target API, privacy and permission boundaries.

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
