import CoreGraphics
import Foundation
import ScreenCaptureKit
import Vision

public struct NormalizedPoint: Sendable, Equatable {
    public let x: CGFloat
    public let y: CGFloat

    public init(x: CGFloat, y: CGFloat) {
        self.x = x
        self.y = y
    }
}

public struct NormalizedRectangle: Sendable, Equatable {
    public let minX: CGFloat
    public let minY: CGFloat
    public let maxX: CGFloat
    public let maxY: CGFloat

    public init?(first: NormalizedPoint, second: NormalizedPoint) {
        let minX = min(first.x, second.x)
        let minY = min(first.y, second.y)
        let maxX = max(first.x, second.x)
        let maxY = max(first.y, second.y)
        guard minX >= 0, minY >= 0, maxX <= 1, maxY <= 1, minX < maxX, minY < maxY else { return nil }
        self.minX = minX
        self.minY = minY
        self.maxX = maxX
        self.maxY = maxY
    }
}

public struct HandPose: Sendable, Equatable {
    public let thumbTip: NormalizedPoint
    public let indexTip: NormalizedPoint
    public let confidence: Float

    public init(thumbTip: NormalizedPoint, indexTip: NormalizedPoint, confidence: Float) {
        self.thumbTip = thumbTip
        self.indexTip = indexTip
        self.confidence = confidence
    }

    public var pinchCenter: NormalizedPoint {
        .init(x: (thumbTip.x + indexTip.x) * 0.5, y: (thumbTip.y + indexTip.y) * 0.5)
    }

    public var pinchDistance: CGFloat {
        hypot(thumbTip.x - indexTip.x, thumbTip.y - indexTip.y)
    }
}

public struct HandPoseFrame: Sendable, Equatable {
    public let capturedAt: ContinuousClock.Instant
    public let hands: [HandPose]

    public init(capturedAt: ContinuousClock.Instant, hands: [HandPose]) {
        self.capturedAt = capturedAt
        self.hands = hands
    }
}

public enum GestureDecision: Sendable, Equatable {
    case waiting
    case rectangle(NormalizedRectangle)
    case rejected
}

/// Input: Vision landmark frames containing two pinched hands.
/// Output: a normalized rectangle only after the gesture holds stably.
/// Task: provide an interpretable, reversible-action gesture baseline without
/// training a custom model or treating one transient pose as a command.
public struct RectangleGestureRecognizer: Sendable {
    public var minimumConfidence: Float = 0.85
    public var maximumPinchDistance: CGFloat = 0.08
    public var minimumRectangleSpan: CGFloat = 0.08
    public var stableFrameCount: Int = 4

    private var previous: NormalizedRectangle?
    private var stableCount = 0

    public init() {}

    public mutating func consume(_ frame: HandPoseFrame) -> GestureDecision {
        let candidates = frame.hands.filter {
            $0.confidence >= minimumConfidence && $0.pinchDistance <= maximumPinchDistance
        }
        guard candidates.count == 2 else {
            stableCount = 0
            previous = nil
            return candidates.isEmpty ? .waiting : .rejected
        }
        guard let rectangle = NormalizedRectangle(first: candidates[0].pinchCenter, second: candidates[1].pinchCenter),
              rectangle.maxX - rectangle.minX >= minimumRectangleSpan,
              rectangle.maxY - rectangle.minY >= minimumRectangleSpan else {
            stableCount = 0
            previous = nil
            return .rejected
        }
        if let previous, approximatelyEqual(previous, rectangle) {
            stableCount += 1
        } else {
            self.previous = rectangle
            stableCount = 1
        }
        return stableCount >= stableFrameCount ? .rectangle(rectangle) : .waiting
    }

    private func approximatelyEqual(_ lhs: NormalizedRectangle, _ rhs: NormalizedRectangle) -> Bool {
        let tolerance: CGFloat = 0.025
        return abs(lhs.minX - rhs.minX) <= tolerance && abs(lhs.minY - rhs.minY) <= tolerance &&
            abs(lhs.maxX - rhs.maxX) <= tolerance && abs(lhs.maxY - rhs.maxY) <= tolerance
    }
}

public struct CapturedFrame: @unchecked Sendable {
    public let image: CGImage
    public let displayID: CGDirectDisplayID
    public let capturedAt: Date
}

/// ScreenCaptureKit adapter. It does not start a persistent recording stream,
/// write a file, or expose captured pixels outside the caller's process.
public struct ScreenCaptureProvider {
    public init() {}

    public func availableDisplays() async throws -> [CGDirectDisplayID] {
        let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
        return content.displays.map(\.displayID)
    }

    public func capture(displayID: CGDirectDisplayID) async throws -> CapturedFrame {
        let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
        guard let display = content.displays.first(where: { $0.displayID == displayID }) else {
            throw CaptureError.displayUnavailable
        }
        let filter = SCContentFilter(display: display, excludingApplications: [], exceptingWindows: [])
        let configuration = SCStreamConfiguration()
        configuration.width = display.width
        configuration.height = display.height
        configuration.showsCursor = false
        let image = try await SCScreenshotManager.captureImage(contentFilter: filter, configuration: configuration)
        return CapturedFrame(image: image, displayID: displayID, capturedAt: Date())
    }
}

public enum CaptureError: Error, Sendable {
    case displayUnavailable
    case invalidCrop
}

/// Vision is the Phase 2 landmark source. Kairo receives only normalized
/// points/confidence, keeping Apple framework objects out of its action policy.
public struct VisionHandPoseProvider {
    public init() {}

    public func detect(in image: CGImage, maximumHandCount: Int = 2) throws -> [HandPose] {
        let request = VNDetectHumanHandPoseRequest()
        request.maximumHandCount = maximumHandCount
        let handler = VNImageRequestHandler(cgImage: image)
        try handler.perform([request])
        return try (request.results ?? []).compactMap { observation in
            let thumb = try observation.recognizedPoint(.thumbTip)
            let index = try observation.recognizedPoint(.indexTip)
            let confidence = min(thumb.confidence, index.confidence)
            return HandPose(thumbTip: .init(x: thumb.location.x, y: thumb.location.y),
                indexTip: .init(x: index.location.x, y: index.location.y), confidence: confidence)
        }
    }
}

public struct CapturePreview: @unchecked Sendable {
    public let id: UUID
    public let image: CGImage
    public let sourceDisplayID: CGDirectDisplayID
    public let region: NormalizedRectangle
    public let createdAt: Date
}

/// Phase 3's sole action is creating an in-memory preview. It never changes
/// another application or an OS setting, and `discard` releases the only owned
/// reference. Saving/exporting is intentionally outside this phase.
public actor CapturePreviewStore {
    private var previews: [UUID: CapturePreview] = [:]

    public init() {}

    public func create(from frame: CapturedFrame, region: NormalizedRectangle) throws -> CapturePreview {
        let width = CGFloat(frame.image.width)
        let height = CGFloat(frame.image.height)
        let crop = CGRect(x: floor(region.minX * width), y: floor((1 - region.maxY) * height),
            width: ceil((region.maxX - region.minX) * width), height: ceil((region.maxY - region.minY) * height))
            .integral.intersection(CGRect(x: 0, y: 0, width: width, height: height))
        guard !crop.isNull, crop.width > 0, crop.height > 0, let image = frame.image.cropping(to: crop) else {
            throw CaptureError.invalidCrop
        }
        let preview = CapturePreview(id: UUID(), image: image, sourceDisplayID: frame.displayID,
            region: region, createdAt: Date())
        previews[preview.id] = preview
        return preview
    }

    public func preview(id: UUID) -> CapturePreview? { previews[id] }

    @discardableResult
    public func discard(id: UUID) -> Bool { previews.removeValue(forKey: id) != nil }

    public var count: Int { previews.count }
}

/// Opaque authorization material created by the host only after KairoAI has
/// validated an exact proposal and obtained the required approval. The native
/// adapter treats it as an identity binding, not as a replacement for policy.
public struct ApprovedPreviewRequest: Sendable, Equatable {
    public let callID: String
    public let approvalID: String
    public let activeApplicationID: String
    public let expectedStateFingerprint: String

    public init?(callID: String, approvalID: String, activeApplicationID: String,
        expectedStateFingerprint: String) {
        guard !callID.isEmpty, !approvalID.isEmpty, !activeApplicationID.isEmpty,
              !expectedStateFingerprint.isEmpty else { return nil }
        self.callID = callID
        self.approvalID = approvalID
        self.activeApplicationID = activeApplicationID
        self.expectedStateFingerprint = expectedStateFingerprint
    }
}

public enum PreviewExecutionDecision: Sendable, Equatable {
    case created
    case verified
    case discarded
    case staleState
    case missingPreview
}

public struct PreviewExecutionReceipt: Sendable, Equatable {
    public let callID: String
    public let approvalID: String
    public let previewID: UUID
    public let stateFingerprint: String
    public let decision: PreviewExecutionDecision
}

/// Reversible Phase 3 executor. A caller must provide an authorization issued
/// by the KairoAI host and the state fingerprint that was checked immediately
/// before execution. The only side effect is adding an image to an in-memory
/// store; `undo` always discards it.
public actor PreviewActionExecutor {
    private let store: CapturePreviewStore

    public init(store: CapturePreviewStore = CapturePreviewStore()) {
        self.store = store
    }

    public func execute(approved: ApprovedPreviewRequest, observedStateFingerprint: String,
        frame: CapturedFrame, region: NormalizedRectangle) async throws -> PreviewExecutionReceipt {
        guard observedStateFingerprint == approved.expectedStateFingerprint else {
            return .init(callID: approved.callID, approvalID: approved.approvalID, previewID: UUID(),
                stateFingerprint: observedStateFingerprint, decision: .staleState)
        }
        let preview = try await store.create(from: frame, region: region)
        return .init(callID: approved.callID, approvalID: approved.approvalID, previewID: preview.id,
            stateFingerprint: observedStateFingerprint, decision: .created)
    }

    public func verify(_ receipt: PreviewExecutionReceipt) async -> PreviewExecutionReceipt {
        guard receipt.decision == .created, await store.preview(id: receipt.previewID) != nil else {
            return .init(callID: receipt.callID, approvalID: receipt.approvalID, previewID: receipt.previewID,
                stateFingerprint: receipt.stateFingerprint, decision: .missingPreview)
        }
        return .init(callID: receipt.callID, approvalID: receipt.approvalID, previewID: receipt.previewID,
            stateFingerprint: receipt.stateFingerprint, decision: .verified)
    }

    public func undo(_ receipt: PreviewExecutionReceipt) async -> PreviewExecutionReceipt {
        guard await store.discard(id: receipt.previewID) else {
            return .init(callID: receipt.callID, approvalID: receipt.approvalID, previewID: receipt.previewID,
                stateFingerprint: receipt.stateFingerprint, decision: .missingPreview)
        }
        return .init(callID: receipt.callID, approvalID: receipt.approvalID, previewID: receipt.previewID,
            stateFingerprint: receipt.stateFingerprint, decision: .discarded)
    }
}
