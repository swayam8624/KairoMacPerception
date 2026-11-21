# KairoMacPerception — linked learning order

Study privacy-preserving perception/contracts before platform capture and user-controlled actions. macOS ScreenCaptureKit and Vision are system APIs, not a general cross-platform computer vision backend; observation, verification and action authorization should be separate.

## Public APIs and interactions

ScreenCaptureKit provides bounded screen frames; Vision provides observation/recognition; control packets are typed intent data, and host approval gates actual actions. Learn permissions, capture lifetime, thread callbacks, reversible preview and non-persistent private imagery. Explain where the model does NOT have authority to click/act.

## Read every tracked source in this order (7 files)

1. [`Package.swift`](Package.swift) — inspect the public API, state ownership, input validation, cross-file calls, and its matching tests.
2. [`Sources/KairoMacPerception/KairoMacPerception.swift`](Sources/KairoMacPerception/KairoMacPerception.swift) — inspect the public API, state ownership, input validation, cross-file calls, and its matching tests.
3. [`Sources/KairoControlProtocol/KairoControlProtocol.swift`](Sources/KairoControlProtocol/KairoControlProtocol.swift) — inspect the public API, state ownership, input validation, cross-file calls, and its matching tests.
4. [`Sources/KairoControlProtocol/ControlPacketChannel.swift`](Sources/KairoControlProtocol/ControlPacketChannel.swift) — inspect the public API, state ownership, input validation, cross-file calls, and its matching tests.
5. [`Sources/KairoControlLab/KairoControlLabApp.swift`](Sources/KairoControlLab/KairoControlLabApp.swift) — inspect the public API, state ownership, input validation, cross-file calls, and its matching tests.
6. [`CompanionApp/KairoCompanionApp.swift`](CompanionApp/KairoCompanionApp.swift) — inspect the public API, state ownership, input validation, cross-file calls, and its matching tests.
7. [`Tests/KairoMacPerceptionTests/KairoMacPerceptionTests.swift`](Tests/KairoMacPerceptionTests/KairoMacPerceptionTests.swift) — inspect the public API, state ownership, input validation, cross-file calls, and its matching tests.

For further work, implement small tests for normal, invalid and boundary conditions instead of relying only on documentation. Original code is available under the [MIT license](LICENSE) for study and extension. Third-party libraries, frameworks, datasets and fixtures retain their rights. Per-function source-level comments and CI/host verification are separate passes.
