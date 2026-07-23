import Foundation

/// Shared, transport-neutral messages for the future Mac host and iPad
/// companion. This target intentionally contains no networking, capture, or
/// execution code: the Mac host remains the only action authority.
public enum ControlPeerRole: String, Codable, Sendable {
    case macHost
    case iPadCompanion
}

public enum CompanionCommand: String, Codable, Sendable {
    case requestPreview
    case approveProposal
    case rejectProposal
    case discardPreview
}

public struct CompanionRequest: Codable, Sendable, Equatable {
    public let requestID: UUID
    public let command: CompanionCommand
    public let callID: String?
    public let displayID: UInt32?

    public init(requestID: UUID = UUID(), command: CompanionCommand, callID: String? = nil,
        displayID: UInt32? = nil) {
        self.requestID = requestID
        self.command = command
        self.callID = callID
        self.displayID = displayID
    }

    /// The iPad can request or approve a known proposal, but cannot provide
    /// arbitrary action arguments. The Mac still validates application state,
    /// exact KairoAI approval, and reversibility before it executes anything.
    public func validForCompanion() -> Bool {
        switch command {
        case .requestPreview: return displayID != nil && callID == nil
        case .approveProposal, .rejectProposal, .discardPreview: return callID?.isEmpty == false
        }
    }
}

public enum HostActionState: String, Codable, Sendable {
    case idle
    case proposalAwaitingApproval
    case previewCreated
    case previewVerified
    case previewDiscarded
    case refused
}

public struct HostStatus: Codable, Sendable, Equatable {
    public let callID: String?
    public let state: HostActionState
    public let detail: String
    public let reversible: Bool

    public init(callID: String? = nil, state: HostActionState, detail: String, reversible: Bool) {
        self.callID = callID
        self.state = state
        self.detail = detail
        self.reversible = reversible
    }
}
