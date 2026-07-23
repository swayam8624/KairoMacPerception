# KairoMacPerception

`KairoMacPerception` is the macOS-native Phase 2 and Phase 3 adapter for the
Kairo device agent. It uses Apple frameworks instead of reimplementing screen
capture or hand landmarks.

## Scope

- ScreenCaptureKit one-shot display capture, subject to macOS Screen Recording
  permission.
- Vision hand-pose landmarks mapped to Kairo-owned normalized evidence values.
- A deterministic two-pinch, stable-frame rectangle gesture recognizer.
- In-memory cropped capture previews with explicit discard.
- Externally authorized preview execution, verification, and unconditional undo.
- A transport-neutral control protocol ready for the Phase 4 Mac/iPad companion.

The package does not record continuously, write files, change device settings,
click UI, edit Premiere projects, or execute application commands.

## Reversibility

The Phase 3 action creates only an in-memory `CapturePreview`. It remains in
the `CapturePreviewStore` until `discard(id:)` removes it. Export/save is not
implemented, so this package cannot overwrite or delete user data.

`PreviewActionExecutor` requires an `ApprovedPreviewRequest` from a host that
has already passed the exact proposal through KairoAI policy. It rejects stale
state and its `undo` operation only discards the in-memory preview.

## Build

```sh
swift test
```

Tests use synthetic hand points and a generated image. They never request
Screen Recording access or capture the desktop.

## Mac Control Lab

`KairoControlLab` is a SwiftUI host for the first reversible workflow. It lists
shareable displays, requires an explicit proposal and approval, creates an
in-memory center crop, verifies it, and discards it on request. It has no save,
export, accessibility, Premiere, Finder, or system-settings command.

```sh
swift run KairoControlLab
```

The first real capture asks for macOS Screen Recording access. That permission
is required for the host to see a display and can be revoked in System Settings.

## iPad Companion

Generate the installable iPadOS project and open it in Xcode:

```sh
xcodegen generate
open KairoCompanion.xcodeproj
```

The target declares local-network and Bonjour usage and shares the control
contract with the Mac. Pairing derives a short-lived per-session key from an
explicitly confirmed six-digit code and device nonces; every envelope carries a
session identifier, a monotonic sequence, and an HMAC-SHA256 tag. Tampered,
stale, and replayed messages are rejected before command validation. The host
must rate-limit pairing attempts and remain the only execution authority.

The current app deliberately queues only typed preview/approve/reject/discard
requests. Network.framework discovery and the host bridge will be enabled only
when the host can map each request to a live, exact KairoAI approval and a
reversible action receipt. It cannot send arbitrary action arguments.

`KairoControlProtocol` now also supplies the byte-stream boundary for that
bridge: length-prefixed JSON packets are capped at 1 MiB and decoded
incrementally, so fragmented TCP receives do not change semantics or cause an
unauthenticated peer to force unbounded buffering. Both companion commands and
host status updates are authenticated after pairing; only the initial pairing
offer and companion nonce travel before a session key exists.

## Integration

The host converts a recognized stable rectangle into KairoAI evidence, routes
it through `Kairo.AI.DeviceAgent`, asks for exact approval via
`Kairo.AI.ToolPolicy`, then invokes this preview-only action. The resulting
receipt and verification are stored through KairoAI replay contracts.
