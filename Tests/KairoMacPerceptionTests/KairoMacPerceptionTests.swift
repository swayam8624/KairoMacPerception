import CoreGraphics
import XCTest
@testable import KairoMacPerception
@testable import KairoControlProtocol

final class KairoMacPerceptionTests: XCTestCase {
    func testRectangleGestureRequiresStableTwoHandPinches() {
        var recognizer = RectangleGestureRecognizer()
        let clock = ContinuousClock()
        let left = HandPose(thumbTip: .init(x: 0.2, y: 0.2), indexTip: .init(x: 0.21, y: 0.21), confidence: 0.99)
        let right = HandPose(thumbTip: .init(x: 0.8, y: 0.8), indexTip: .init(x: 0.81, y: 0.81), confidence: 0.99)
        let frame = HandPoseFrame(capturedAt: clock.now, hands: [left, right])
        for _ in 0..<3 { XCTAssertEqual(recognizer.consume(frame), .waiting) }
        guard case let .rectangle(region) = recognizer.consume(frame) else { return XCTFail("Expected stable rectangle") }
        XCTAssertEqual(region.minX, 0.205, accuracy: 0.001)
        XCTAssertEqual(region.maxY, 0.805, accuracy: 0.001)
    }

    func testPreviewStoreKeepsCaptureOnlyInMemoryAndDiscardsIt() async throws {
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let context = CGContext(data: nil, width: 32, height: 32, bitsPerComponent: 8, bytesPerRow: 0,
            space: colorSpace, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
        context.setFillColor(CGColor(red: 0, green: 0, blue: 0, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: 32, height: 32))
        let image = context.makeImage()!
        let frame = CapturedFrame(image: image, displayID: 1, capturedAt: Date())
        let region = try XCTUnwrap(NormalizedRectangle(first: .init(x: 0.25, y: 0.25), second: .init(x: 0.75, y: 0.75)))
        let store = CapturePreviewStore()
        let preview = try await store.create(from: frame, region: region)
        let initialCount = await store.count
        let storedPreview = await store.preview(id: preview.id)
        let discarded = await store.discard(id: preview.id)
        let finalCount = await store.count
        let discardedPreview = await store.preview(id: preview.id)
        XCTAssertEqual(initialCount, 1)
        XCTAssertNotNil(storedPreview)
        XCTAssertTrue(discarded)
        XCTAssertEqual(finalCount, 0)
        XCTAssertNil(discardedPreview)
    }

    func testApprovedPreviewRejectsStaleStateAndCanAlwaysUndo() async throws {
        let image = try makeImage()
        let frame = CapturedFrame(image: image, displayID: 1, capturedAt: Date())
        let region = try XCTUnwrap(NormalizedRectangle(first: .init(x: 0.25, y: 0.25), second: .init(x: 0.75, y: 0.75)))
        let approved = try XCTUnwrap(ApprovedPreviewRequest(callID: "device.preview.1", approvalID: "approval.1",
            activeApplicationID: "com.example.host", expectedStateFingerprint: "state.42"))
        let executor = PreviewActionExecutor()
        let stale = try await executor.execute(approved: approved, observedStateFingerprint: "state.old", frame: frame, region: region)
        XCTAssertEqual(stale.decision, .staleState)

        let created = try await executor.execute(approved: approved, observedStateFingerprint: "state.42", frame: frame, region: region)
        let verified = await executor.verify(created)
        let discarded = await executor.undo(created)
        let missing = await executor.verify(created)
        XCTAssertEqual(created.decision, .created)
        XCTAssertEqual(verified.decision, .verified)
        XCTAssertEqual(discarded.decision, .discarded)
        XCTAssertEqual(missing.decision, .missingPreview)
    }

    func testCompanionProtocolCannotProvideArbitraryActionArguments() {
        XCTAssertTrue(CompanionRequest(command: .requestPreview, displayID: 1).validForCompanion())
        XCTAssertFalse(CompanionRequest(command: .requestPreview, callID: "unexpected", displayID: 1).validForCompanion())
        XCTAssertTrue(CompanionRequest(command: .approveProposal, callID: "device.preview.1").validForCompanion())
        XCTAssertFalse(CompanionRequest(command: .approveProposal).validForCompanion())
    }

    func testAuthenticatedCompanionMessagesRejectTamperingAndReplay() throws {
        let offer = PairingOffer(hostNonce: Data(repeating: 7, count: 16), expiresAt: Date().addingTimeInterval(60))
        let key = try PairingKeyDerivation.derive(code: "123456", offer: offer, companionNonce: Data(repeating: 9, count: 16))
        var sender = ControlSessionAuthenticator(sessionID: offer.sessionID, key: key)
        var receiver = ControlSessionAuthenticator(sessionID: offer.sessionID, key: key)
        let envelope = try sender.seal(CompanionRequest(command: .requestPreview, displayID: 1))
        XCTAssertEqual(try receiver.open(envelope).command, .requestPreview)
        XCTAssertThrowsError(try receiver.open(envelope)) { XCTAssertEqual($0 as? ControlSecurityError, .replayedSequence) }

        let second = try sender.seal(CompanionRequest(command: .requestPreview, displayID: 1))
        let tampered = AuthenticatedControlEnvelope(sessionID: second.sessionID, sequence: second.sequence,
            payload: Data("tampered".utf8), tag: second.tag)
        XCTAssertThrowsError(try receiver.open(tampered)) { XCTAssertEqual($0 as? ControlSecurityError, .invalidAuthenticationTag) }
    }

    private func makeImage() throws -> CGImage {
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let context = try XCTUnwrap(CGContext(data: nil, width: 32, height: 32, bitsPerComponent: 8, bytesPerRow: 0,
            space: colorSpace, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
        context.setFillColor(CGColor(red: 0, green: 0, blue: 0, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: 32, height: 32))
        return try XCTUnwrap(context.makeImage())
    }
}
