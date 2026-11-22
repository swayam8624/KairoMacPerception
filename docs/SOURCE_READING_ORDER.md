# Teaching source map — KairoMacPerception
**Worked source walkthrough:** [Screen/Vision observation → approval → verified reversible control](PERCEPTION_TO_APPROVED_CONTROL.md).

Swift/macOS perception adapters providing structured observations, not arbitrary OS control.

Read these source links in order, identify the caller and callee for each public API, then check the error/ownership contract and its tests.

## Reading order

1. [`README.md`](../README.md)
2. [`Package.swift`](../Package.swift)
3. [`Sources`](../Sources)
4. [`Tests`](../Tests)
5. [`CompanionApp`](../CompanionApp)
6. [`project.yml`](../project.yml)
7. [`research`](../research)

## Repository integration and API contracts

ScreenCaptureKit/Vision adapters generate observations; KairoAI intent routing proposes approved actions. Check macOS permissions and test devices; fake input is not native authorization.

## Teaching standards

- Comments explain invariants, decision reasons, lifetime, prerequisites and cross-file effects; they do not narrate obvious statements.
- Follow upstream interfaces before implementation details; distinguish implemented, host-verified and planned features.
- Run available tests at a pinned commit and consult [STATUS.md](../STATUS.md) / [STATUS.yaml](../STATUS.yaml) before declaring completion.
- Reuse original contributions under [LICENSE](../LICENSE), subject to third-party code and asset terms.


## Complete source-file inventory

After the curated teaching path, follow this deterministic inventory of first-party source, scripts, shaders, and tests. Grouping is a suggested learning order, not an indication that every function is already annotated. Vendored dependencies, ROMs, binaries, data, media, and generated evidence are excluded.

### Entry points and build (1)

1. [`Package.swift`](../Package.swift)

### Implementation and other source (5)

1. [`CompanionApp/KairoCompanionApp.swift`](../CompanionApp/KairoCompanionApp.swift)
2. [`Sources/KairoControlLab/KairoControlLabApp.swift`](../Sources/KairoControlLab/KairoControlLabApp.swift)
3. [`Sources/KairoControlProtocol/ControlPacketChannel.swift`](../Sources/KairoControlProtocol/ControlPacketChannel.swift)
4. [`Sources/KairoControlProtocol/KairoControlProtocol.swift`](../Sources/KairoControlProtocol/KairoControlProtocol.swift)
5. [`Sources/KairoMacPerception/KairoMacPerception.swift`](../Sources/KairoMacPerception/KairoMacPerception.swift)

### Verification and tests (1)

1. [`Tests/KairoMacPerceptionTests/KairoMacPerceptionTests.swift`](../Tests/KairoMacPerceptionTests/KairoMacPerceptionTests.swift)

Snapshot totals: 7 first-party source/build/test files, 17 tracked files overall. Re-audit when files are renamed or added.
