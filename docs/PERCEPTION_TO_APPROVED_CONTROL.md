# macOS perception — from captured pixels to a verified, reversible control action

Read the [source-reading map](SOURCE_READING_ORDER.md) and
[`Sources/KairoMacPerception/KairoMacPerception.swift`](../Sources/KairoMacPerception/KairoMacPerception.swift)
alongside
[`Sources/KairoControlProtocol/KairoControlProtocol.swift`](../Sources/KairoControlProtocol/KairoControlProtocol.swift)
and
[`Sources/KairoControlProtocol/ControlPacketChannel.swift`](../Sources/KairoControlProtocol/ControlPacketChannel.swift).

The central distinction: **perception describes observations; it does not authorize control.** DeviceAgent proposes, the host approves, an adapter executes, and verification checks observable effects.

## 1. Read macOS platform permissions first

`ScreenCaptureProvider` wraps ScreenCaptureKit enumeration and display capture. The host is responsible for the macOS Screen Recording permission. Its native API may fail when permission is withheld, a display disappears, or the process lacks entitlement. A unit test with a synthetic CGImage cannot grant permission.

`CapturedFrame` identifies the source display, image and capture metadata. Consumers must keep coordinates tied to that frame's dimensions and age rather than apply stale positions to a new display or window configuration.

## 2. Vision generates evidence, not executable intent

`VisionHandPoseProvider::detect` runs hand landmark detection over a supplied CGImage. `HandPose` and `HandPoseFrame` represent confidence and normalized joint coordinates. `RectangleGestureRecognizer` combines points into a region proposal and must reject missing/low-confidence/invalid geometry.

Normalized rectangles are fractions of a particular frame. `CapturePreview.create` maps that region into a bounded crop and returns a preview for human review. A crop is not authority to click within another application or expose arbitrary captured content to external providers.

**Exercise:** feed an image where no hand is present, then a region at the edge of a display, and finally a stale frame whose dimensions change. Distinguish “no observation,” “invalid target” and “approved action.”

## 3. Approval, receipt, verification, undo

`ApprovedPreviewRequest` carries a proposed action identity and target. The execution adapter should only accept a request that a trusted host explicitly authorized for that action, not a free-form text instruction.

The `PreviewExecutionReceipt` records what was attempted and resulting state fingerprints. `execute` performs the approved narrow action, `verify` checks the observable effect under the declared verification contract, and `undo` reverses it only when the action is actually reversible.

A user-visible accepted preview is not automatically evidence that the operating system performed the intended control operation. A failed verification should remain a failure even when the UI preview looks correct.

## 4. Network control is a different trust boundary

`ControlPacketChannel` uses Apple's Network framework and a `ControlFrameDecoder` to transport framed `ControlWirePacket` values. It manages byte-stream assembly, packet handlers and cancellation over `NWConnection`.

This channel does **not** independently validate a pairing decision or perform device actions. The surrounding control protocol, session state, authenticated peer and host approval layer must reject unpaired/replayed/stale commands. Receiving a valid packet is not evidence the user authorized it.

The `@unchecked Sendable` class must maintain its own synchronization: `NSLock` protects mutable decoder/handler state; callbacks run on an explicitly chosen DispatchQueue, which is not necessarily the main actor.

## 5. Connecting perception to KairoAI

[KairoAI DeviceAgent](https://github.com/swayam8624/KairoAI/blob/docs/teaching-walkthrough-20261121/DeviceAgent.cppm) accepts host-provided typed gesture/speech/screen evidence. It matches active application, intent, required modalities and confidence before proposing a specific `ToolCall`.

[KairoAI ToolPolicy](https://github.com/swayam8624/KairoAI/blob/docs/teaching-walkthrough-20261121/AIToolPolicy.cppm) must still authorize that exact call ID, tool name and arguments. Credentials and side-effecting process/network actions remain controlled by the host. A model output should never be interpreted as a gesture-approval substitute.

## 6. Verification checklist

Read
[`Tests/KairoMacPerceptionTests/KairoMacPerceptionTests.swift`](../Tests/KairoMacPerceptionTests/KairoMacPerceptionTests.swift).
For native tests, record device/OS, Screen Recording permission, selected display, frame timestamp, Vision request, gesture confidence, proposed application/intent, approval ID, execution receipt, verification state and undo outcome.

Test permission denial, display removal, duplicate/fragmented network packets, callback cancellation, invalid preview region, wrong application binding and lack of user approval. Avoid storing raw screen images in persistent telemetry without explicit user consent.

*Evidence note: source-only teaching material; no new ScreenCaptureKit permission grant or live control action was performed.*
