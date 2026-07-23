import CoreGraphics
import XCTest
@testable import KairoMacPerception

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
}
