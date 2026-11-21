# Teaching source map — KairoMacPerception

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
