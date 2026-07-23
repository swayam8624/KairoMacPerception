import SwiftUI

@main
struct KairoCompanionApp: App {
    var body: some Scene {
        WindowGroup {
            CompanionView(model: CompanionModel())
        }
    }
}

@MainActor
final class CompanionModel: ObservableObject {
    @Published var pairingCode = ""
    @Published private(set) var status = "Not paired"
    @Published private(set) var hostState = HostActionState.idle
    @Published private(set) var queuedRequest: CompanionRequest?

    func beginPairing() {
        let normalized = pairingCode.trimmingCharacters(in: .whitespacesAndNewlines)
        guard normalized.count == 6, normalized.allSatisfy(\.isNumber) else {
            status = "Enter the six-digit code shown by your Mac host."
            return
        }
        status = "Pairing request prepared. The Mac host must confirm it."
    }

    func queue(_ command: CompanionCommand) {
        let request: CompanionRequest
        switch command {
        case .requestPreview:
            request = CompanionRequest(command: .requestPreview, displayID: 1)
        case .approveProposal, .rejectProposal, .discardPreview:
            request = CompanionRequest(command: command, callID: "host-proposal-required")
        }
        guard request.validForCompanion() else {
            status = "The request was rejected before transmission."
            return
        }
        queuedRequest = request
        status = "Queued \(command.rawValue). The paired Mac host validates state and policy before execution."
    }
}

struct CompanionView: View {
    @ObservedObject var model: CompanionModel

    var body: some View {
        NavigationSplitView {
            VStack(alignment: .leading, spacing: 16) {
                Text("Kairo Companion")
                    .font(.title.bold())
                Text("Paired control surface")
                    .foregroundStyle(.secondary)
                TextField("Pairing code", text: $model.pairingCode)
                    .keyboardType(.numberPad)
                    .textInputAutocapitalization(.never)
                Button("Pair With Mac") { model.beginPairing() }
                    .buttonStyle(.borderedProminent)
                Spacer()
                Text("The iPad never controls the desktop directly.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            .padding()
        } detail: {
            VStack(alignment: .leading, spacing: 24) {
                HStack {
                    VStack(alignment: .leading) {
                        Text("Host state").font(.headline)
                        Text(model.hostState.rawValue.capitalized).foregroundStyle(.secondary)
                    }
                    Spacer()
                    Label("Reversible only", systemImage: "arrow.uturn.backward.circle")
                        .foregroundStyle(.green)
                }
                .padding()
                .background(.quaternary, in: RoundedRectangle(cornerRadius: 10))

                Text("Controls").font(.headline)
                HStack(spacing: 12) {
                    Button("Request Preview") { model.queue(.requestPreview) }
                    Button("Approve") { model.queue(.approveProposal) }
                        .buttonStyle(.borderedProminent)
                    Button("Reject", role: .cancel) { model.queue(.rejectProposal) }
                    Button("Discard", role: .destructive) { model.queue(.discardPreview) }
                }
                Text(model.status)
                    .foregroundStyle(.secondary)
                Spacer()
            }
            .padding(24)
        }
    }
}
