// TEACHING MODULE: This Network.framework layer frames and transports
// ControlWirePacket values over NWConnection. It does not perform pairing,
// verify human approval or execute the semantic action in each packet.
// Those trust decisions are above the byte channel in the control protocol.
//
// The decoder keeps partial packet state across arbitrary receive chunks.
// Handler registration and cancellation interact with the locked state and
// delegate queue; host code must not assume packets arrive on the UI thread.
// Transport success is not proof that the device executed an action.
import Foundation
import Network

/// A transport adapter for the authenticated control protocol. It owns only a
/// byte stream: pairing, approval, and action execution remain explicit host
/// responsibilities above this class.
// @unchecked Sendable places synchronization responsibility on this
// class. NSLock protects mutable handlers/decoder lifecycle; preserve
// the same ownership invariants when extending receive/error paths.
public final class ControlPacketChannel: @unchecked Sendable {
    public typealias PacketHandler = @Sendable (ControlWirePacket) -> Void
    public typealias FailureHandler = @Sendable (Error) -> Void

    private let connection: NWConnection
    private let queue: DispatchQueue
    private let lock = NSLock()
    private var decoder = ControlFrameDecoder()
    private var packetHandler: PacketHandler?
    private var failureHandler: FailureHandler?
    private var started = false

    public init(connection: NWConnection, queue: DispatchQueue = DispatchQueue(label: "dev.kairo.control.channel")) {
        self.connection = connection
        self.queue = queue
    }

    public convenience init(host: NWEndpoint.Host, port: NWEndpoint.Port) {
        self.init(connection: NWConnection(host: host, port: port, using: .tcp))
    }

    public func start(onPacket: @escaping PacketHandler, onFailure: @escaping FailureHandler) {
        lock.lock()
        guard !started else { lock.unlock(); return }
        started = true
        packetHandler = onPacket
        failureHandler = onFailure
        lock.unlock()

        connection.stateUpdateHandler = { [weak self] state in
            switch state {
            case .failed(let error): self?.fail(error)
            case .cancelled: break
            default: break
            }
        }
        connection.start(queue: queue)
        receiveNext()
    }

    public func send(_ packet: ControlWirePacket) {
        do {
            let frame = try ControlFrameCodec.encode(packet)
            connection.send(content: frame, completion: .contentProcessed { [weak self] error in
                if let error { self?.fail(error) }
            })
        } catch {
            fail(error)
        }
    }

    public func cancel() {
        connection.cancel()
    }

    private func receiveNext() {
        connection.receive(minimumIncompleteLength: 1,
            maximumLength: ControlFrameCodec.maximumPayloadBytes + MemoryLayout<UInt32>.size) { [weak self] data, _, complete, error in
            guard let self else { return }
            if let error { self.fail(error); return }
            if let data, !data.isEmpty {
                do {
                    self.lock.lock()
                    let packets = try self.decoder.append(data)
                    let handler = self.packetHandler
                    self.lock.unlock()
                    for packet in packets { handler?(packet) }
                } catch {
                    self.fail(error)
                    self.cancel()
                    return
                }
            }
            if complete { return }
            self.receiveNext()
        }
    }

    private func fail(_ error: Error) {
        lock.lock()
        let handler = failureHandler
        lock.unlock()
        handler?(error)
    }
}
