import CryptoKit
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

public struct PairingOffer: Codable, Sendable, Equatable {
    public let sessionID: UUID
    public let hostNonce: Data
    public let expiresAt: Date

    public init(sessionID: UUID = UUID(), hostNonce: Data, expiresAt: Date) {
        self.sessionID = sessionID
        self.hostNonce = hostNonce
        self.expiresAt = expiresAt
    }
}

public enum ControlSecurityError: Error, Sendable, Equatable {
    case invalidPairingCode
    case expiredPairingOffer
    case sessionMismatch
    case invalidAuthenticationTag
    case replayedSequence
    case invalidPayload
}

/// Derives a session key from a short-lived, physically confirmed pairing code
/// plus nonces from both devices. The host must rate-limit attempts and require
/// explicit local confirmation before constructing this material.
public enum PairingKeyDerivation {
    public static func derive(code: String, offer: PairingOffer, companionNonce: Data,
        now: Date = Date()) throws -> SymmetricKey {
        let normalized = code.trimmingCharacters(in: .whitespacesAndNewlines)
        guard normalized.count == 6, normalized.allSatisfy(\.isNumber) else {
            throw ControlSecurityError.invalidPairingCode
        }
        guard now <= offer.expiresAt, !offer.hostNonce.isEmpty, !companionNonce.isEmpty else {
            throw ControlSecurityError.expiredPairingOffer
        }
        let input = SymmetricKey(data: Data(normalized.utf8))
        return HKDF<SHA256>.deriveKey(inputKeyMaterial: input,
            salt: offer.hostNonce + companionNonce,
            info: Data(offer.sessionID.uuidString.utf8), outputByteCount: 32)
    }
}

public struct AuthenticatedControlEnvelope: Codable, Sendable, Equatable {
    public let sessionID: UUID
    public let sequence: UInt64
    public let payload: Data
    public let tag: Data
}

/// Stateful integrity boundary for the future Network.framework transport.
/// It signs only typed protocol payloads and rejects out-of-order/replayed
/// messages before the Mac host examines command semantics.
public struct ControlSessionAuthenticator: Sendable {
    private let sessionID: UUID
    private let key: SymmetricKey
    private var nextSendSequence: UInt64 = 1
    private var highestReceivedSequence: UInt64 = 0

    public init(sessionID: UUID, key: SymmetricKey) {
        self.sessionID = sessionID
        self.key = key
    }

    public mutating func seal(_ request: CompanionRequest) throws -> AuthenticatedControlEnvelope {
        let payload = try JSONEncoder().encode(request)
        let sequence = nextSendSequence
        nextSendSequence &+= 1
        return .init(sessionID: sessionID, sequence: sequence, payload: payload,
            tag: Data(HMAC<SHA256>.authenticationCode(for: signingData(sessionID: sessionID, sequence: sequence,
                payload: payload), using: key)))
    }

    public mutating func open(_ envelope: AuthenticatedControlEnvelope) throws -> CompanionRequest {
        guard envelope.sessionID == sessionID else { throw ControlSecurityError.sessionMismatch }
        guard envelope.sequence > highestReceivedSequence else { throw ControlSecurityError.replayedSequence }
        let signedPayload = signingData(sessionID: envelope.sessionID,
            sequence: envelope.sequence, payload: envelope.payload)
        guard HMAC<SHA256>.isValidAuthenticationCode(envelope.tag, authenticating: signedPayload, using: key) else {
            throw ControlSecurityError.invalidAuthenticationTag
        }
        let request: CompanionRequest
        do { request = try JSONDecoder().decode(CompanionRequest.self, from: envelope.payload) }
        catch { throw ControlSecurityError.invalidPayload }
        guard request.validForCompanion() else { throw ControlSecurityError.invalidPayload }
        highestReceivedSequence = envelope.sequence
        return request
    }

    private func signingData(sessionID: UUID, sequence: UInt64, payload: Data) -> Data {
        var data = Data(sessionID.uuidString.utf8)
        data.append(0)
        var bigEndianSequence = sequence.bigEndian
        withUnsafeBytes(of: &bigEndianSequence) { data.append(contentsOf: $0) }
        data.append(payload)
        return data
    }
}
