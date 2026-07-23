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

## Integration

The host converts a recognized stable rectangle into KairoAI evidence, routes
it through `Kairo.AI.DeviceAgent`, asks for exact approval via
`Kairo.AI.ToolPolicy`, then invokes this preview-only action. The resulting
receipt and verification are stored through KairoAI replay contracts.
