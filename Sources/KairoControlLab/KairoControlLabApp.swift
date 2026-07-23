import AppKit
import CoreGraphics
import KairoControlProtocol
import KairoMacPerception
import SwiftUI

@main
struct KairoControlLabApp: App {
    var body: some Scene {
        WindowGroup("Kairo Control Lab") {
            ControlLabView(model: ControlLabModel())
                .frame(minWidth: 960, minHeight: 640)
        }
    }
}

@MainActor
final class ControlLabModel: ObservableObject {
    @Published private(set) var displays: [CGDirectDisplayID] = []
    @Published var selectedDisplayID: CGDirectDisplayID?
    @Published private(set) var status = HostStatus(state: .idle,
        detail: "Select a display, then create a reversible preview proposal.", reversible: true)
    @Published private(set) var pendingCallID: String?
    @Published private(set) var previewImage: NSImage?
    @Published private(set) var canDiscard = false
    @Published private(set) var busy = false

    private let capture = ScreenCaptureProvider()
    private let store = CapturePreviewStore()
    private lazy var executor = PreviewActionExecutor(store: store)
    private var receipt: PreviewExecutionReceipt?

    func refreshDisplays() async {
        busy = true
        defer { busy = false }
        do {
            let found = try await capture.availableDisplays()
            displays = found
            if selectedDisplayID == nil { selectedDisplayID = found.first }
            status = HostStatus(state: .idle, detail: found.isEmpty ? "No shareable displays are available." : "Ready for a preview proposal.", reversible: true)
        } catch {
            status = HostStatus(state: .refused, detail: "Display discovery failed: \(error.localizedDescription)", reversible: true)
        }
    }

    func proposePreview() {
        guard let displayID = selectedDisplayID else {
            status = HostStatus(state: .refused, detail: "Select a display before proposing a preview.", reversible: true)
            return
        }
        let callID = "preview.display.\(displayID).\(UUID().uuidString.lowercased())"
        pendingCallID = callID
        status = HostStatus(callID: callID, state: .proposalAwaitingApproval,
            detail: "Preview proposal is waiting for explicit approval. It can only create an in-memory crop.", reversible: true)
    }

    func approvePreview() async {
        guard let displayID = selectedDisplayID, let callID = pendingCallID else { return }
        busy = true
        defer { busy = false }
        do {
            let stateFingerprint = "display-selected:\(displayID)"
            guard let approval = ApprovedPreviewRequest(callID: callID, approvalID: "lab.approval.\(UUID().uuidString.lowercased())",
                activeApplicationID: "dev.kairo.ControlLab", expectedStateFingerprint: stateFingerprint) else { return }
            let frame = try await capture.capture(displayID: displayID)
            guard let region = NormalizedRectangle(first: .init(x: 0.20, y: 0.20), second: .init(x: 0.80, y: 0.80)) else { return }
            let created = try await executor.execute(approved: approval, observedStateFingerprint: stateFingerprint, frame: frame, region: region)
            let verified = await executor.verify(created)
            guard verified.decision == .verified, let preview = await store.preview(id: verified.previewID) else {
                status = HostStatus(callID: callID, state: .refused, detail: "Preview verification failed.", reversible: true)
                return
            }
            receipt = verified
            previewImage = NSImage(cgImage: preview.image, size: NSSize(width: preview.image.width, height: preview.image.height))
            canDiscard = true
            pendingCallID = nil
            status = HostStatus(callID: callID, state: .previewVerified,
                detail: "Preview verified. Nothing has been written to disk or changed outside this app.", reversible: true)
        } catch {
            status = HostStatus(callID: callID, state: .refused, detail: "Preview capture failed: \(error.localizedDescription)", reversible: true)
        }
    }

    func rejectProposal() {
        guard let callID = pendingCallID else { return }
        pendingCallID = nil
        status = HostStatus(callID: callID, state: .refused, detail: "Preview proposal rejected. No capture action ran.", reversible: true)
    }

    func discardPreview() async {
        guard let receipt else { return }
        let result = await executor.undo(receipt)
        self.receipt = nil
        previewImage = nil
        canDiscard = false
        status = HostStatus(callID: result.callID, state: result.decision == .discarded ? .previewDiscarded : .refused,
            detail: result.decision == .discarded ? "Preview discarded from memory." : "No matching preview was available to discard.", reversible: true)
    }
}

struct ControlLabView: View {
    @ObservedObject var model: ControlLabModel

    var body: some View {
        HStack(spacing: 0) {
            controlSidebar
                .frame(width: 300)
            Divider()
            previewPanel
        }
        .task { await model.refreshDisplays() }
    }

    private var controlSidebar: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("Kairo Control Lab")
                .font(.title2.weight(.semibold))
            Text("Reversible preview workflow")
                .foregroundStyle(.secondary)

            VStack(alignment: .leading, spacing: 8) {
                Text("Display").font(.headline)
                Picker("Display", selection: $model.selectedDisplayID) {
                    Text("Select display").tag(CGDirectDisplayID?.none)
                    ForEach(model.displays, id: \.self) { display in
                        Text("Display \(display)").tag(CGDirectDisplayID?.some(display))
                    }
                }
                Button("Refresh Displays") { Task { await model.refreshDisplays() } }
                    .disabled(model.busy)
            }

            Divider()
            Text("Action").font(.headline)
            if model.pendingCallID == nil {
                Button("Propose Preview") { model.proposePreview() }
                    .disabled(model.selectedDisplayID == nil || model.busy)
            } else {
                Button("Approve Preview") { Task { await model.approvePreview() } }
                    .disabled(model.busy)
                Button("Reject Proposal", role: .cancel) { model.rejectProposal() }
                    .disabled(model.busy)
            }
            Button("Discard Preview", role: .destructive) { Task { await model.discardPreview() } }
                .disabled(!model.canDiscard || model.busy)

            Spacer()
            Text("No files are saved. No application or system setting is changed.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .padding(20)
    }

    private var previewPanel: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(model.status.state.rawValue.replacingOccurrences(of: "([A-Z])", with: " $1", options: .regularExpression).capitalized)
                        .font(.headline)
                    Text(model.status.detail).foregroundStyle(.secondary)
                }
                Spacer()
                if model.status.reversible {
                    Label("Reversible", systemImage: "arrow.uturn.backward.circle")
                        .foregroundStyle(.green)
                }
            }
            .padding(16)
            .background(.quaternary, in: RoundedRectangle(cornerRadius: 8))

            Group {
                if let image = model.previewImage {
                    Image(nsImage: image)
                        .resizable()
                        .scaledToFit()
                } else {
                    ContentUnavailableView("No Preview", systemImage: "rectangle.dashed",
                        description: Text("A verified preview appears here after approval."))
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(.black.opacity(0.06), in: RoundedRectangle(cornerRadius: 8))
        }
        .padding(24)
    }
}
