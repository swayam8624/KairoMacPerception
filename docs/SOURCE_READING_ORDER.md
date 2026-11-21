# KairoMacPerception — safe control and perception source reading guide

This Swift package separates **observing a display**, **proposing a reversible action**, **independent approval**, and **executing a preview**. It is not an unattended system-control agent. The macOS host retains action authority; the companion app is a control surface, and a prepared pairing code or queued UI request is not evidence of an established authenticated network channel.

## Read in this order

1. [README](../README.md) and [Package.swift](../Package.swift) — build targets, macOS frameworks and tests.
2. [Sources/KairoMacPerception/KairoMacPerception.swift](../Sources/KairoMacPerception/KairoMacPerception.swift) — `HandPose`, gesture decisions, `RectangleGestureRecognizer`, display enumeration/screen capture, in-memory preview store, authorized execution receipt and discard.
3. [Sources/KairoControlProtocol/KairoControlProtocol.swift](../Sources/KairoControlProtocol/KairoControlProtocol.swift) — typed peer roles, host status, `CompanionRequest`, control envelope, pairing/authentication-related protocol structures and frame encoding.
4. [Sources/KairoControlProtocol/ControlPacketChannel.swift](../Sources/KairoControlProtocol/ControlPacketChannel.swift) — `NWConnection` byte framing and callbacks. The channel does not itself decide approval.
5. [Sources/KairoControlLab/KairoControlLabApp.swift](../Sources/KairoControlLab/KairoControlLabApp.swift) — local SwiftUI prototype host, proposal state, user approval, preview verification/discard.
6. [CompanionApp/KairoCompanionApp.swift](../CompanionApp/KairoCompanionApp.swift) — companion UI for preparing pairing codes and queuing requests, *not* a claim that complete host pairing/transmission is implemented.
7. [CompanionApp/Info.plist](../CompanionApp/Info.plist) and [project.yml](../project.yml) — platform app identity and configuration.
8. [Tests/KairoMacPerceptionTests/KairoMacPerceptionTests.swift](../Tests/KairoMacPerceptionTests/KairoMacPerceptionTests.swift) — synthetic gestures and generated frame fixtures without requesting desktop Screen Recording permission.

## Host data and authorization flow

Vision hand points → `HandPoseFrame` → stability-gated gesture interpretation → normalized rectangle → explicit user-facing proposal → host-owned approval from [KairoAI ToolPolicy](https://github.com/swayam8624/KairoAI/blob/main/AIToolPolicy.cppm) → `PreviewActionExecutor` → in-memory `CapturePreviewStore` → verification / undo by discard. Valid rectangles need bounded normalized coordinates; confidence and repeated frames suppress accidental gestures.

## Companion protocol flow

Typed `CompanionRequest` → validation of command-specific arguments → encoded `ControlWirePacket` → `ControlPacketChannel` network framing → macOS host checks proposal identity and authorization. An iPad/companion request cannot supply arbitrary executable commands or grant itself action authority. Transport integrity and **user approval** are separate layers.

## Exercises

1. Show why one frame containing two pinches should not trigger a capture.
2. Test a rectangle with out-of-range coordinates and explain nil/invalid behavior.
3. Trace a proposed preview through approval, receipt, verification and discard.
4. Identify which data is kept only in memory, and what is never written to disk.
5. Explain why a UI message stating "queued" is not proof of a sent, authenticated request.

## Rights

The [MIT license](../LICENSE) is proposed for original source and documentation. macOS SDKs, Apple frameworks and third-party assets remain subject to their own terms. Source review does not override macOS privacy or Screen Recording permissions.
