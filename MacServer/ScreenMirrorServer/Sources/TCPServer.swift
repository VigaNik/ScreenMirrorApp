import Foundation
import Network

class TCPServer {
    private let port: UInt16
    private var listener: NWListener?
    private var connections: [NWConnection] = []
    private let queue = DispatchQueue(label: "com.screenmirror.tcpserver")
    private var isRunning = false

    // Store SPS and PPS to send to new clients
    private var spsData: Data?
    private var ppsData: Data?

    init(port: UInt16 = 5000) {
        self.port = port
    }

    func start(onClientConnected: @escaping () -> Void) throws {
        let parameters = NWParameters.tcp

        // Configure for low latency
        parameters.allowLocalEndpointReuse = true
        parameters.acceptLocalOnly = false

        if let tcpOptions = parameters.defaultProtocolStack.transportProtocol as? NWProtocolTCP.Options {
            tcpOptions.noDelay = true  // Disable Nagle's algorithm
            tcpOptions.enableKeepalive = true
            tcpOptions.keepaliveIdle = 2
        }

        listener = try NWListener(using: parameters, on: NWEndpoint.Port(integerLiteral: port))

        listener?.stateUpdateHandler = { [weak self] state in
            switch state {
            case .ready:
                print("✓ TCP Server listening on port \(self?.port ?? 0)")
                self?.isRunning = true
            case .failed(let error):
                print("✗ TCP Server failed: \(error)")
                self?.isRunning = false
            case .cancelled:
                print("✓ TCP Server cancelled")
                self?.isRunning = false
            default:
                break
            }
        }

        listener?.newConnectionHandler = { [weak self] newConnection in
            guard let self = self else { return }

            print("✓ New client connected from \(newConnection.endpoint)")

            self.setupConnection(newConnection)
            self.connections.append(newConnection)

            // Send SPS and PPS to new client immediately
            if let sps = self.spsData, let pps = self.ppsData {
                print("→ Sending SPS (\(sps.count) bytes) and PPS (\(pps.count) bytes) to new client")
                self.send(data: sps, to: newConnection)
                self.send(data: pps, to: newConnection)
            }

            onClientConnected()
        }

        listener?.start(queue: queue)
    }

    private func setupConnection(_ connection: NWConnection) {
        connection.stateUpdateHandler = { [weak self, weak connection] state in
            switch state {
            case .ready:
                print("✓ Connection ready")
            case .failed(let error):
                print("✗ Connection failed: \(error)")
                if let conn = connection {
                    self?.removeConnection(conn)
                }
            case .cancelled:
                print("✓ Connection cancelled")
                if let conn = connection {
                    self?.removeConnection(conn)
                }
            default:
                break
            }
        }

        connection.start(queue: queue)
    }

    func storeSPSPPS(sps: Data, pps: Data) {
        self.spsData = sps
        self.ppsData = pps
        print("✓ Stored SPS (\(sps.count) bytes) and PPS (\(pps.count) bytes)")
    }

    func broadcast(data: Data) {
        guard isRunning else { return }

        // Remove dead connections
        connections.removeAll { $0.state == .cancelled || $0.state == .failed(NWError.posix(.ECONNRESET)) }

        guard !connections.isEmpty else { return }

        for connection in connections {
            send(data: data, to: connection)
        }
    }

    private func send(data: Data, to connection: NWConnection) {
        connection.send(
            content: data,
            completion: .contentProcessed { error in
                if let error = error {
                    print("✗ Send error: \(error)")
                }
            }
        )
    }

    private func removeConnection(_ connection: NWConnection) {
        connection.cancel()
        connections.removeAll { $0 === connection }
        print("✓ Connection removed. Active connections: \(connections.count)")
    }

    func stop() {
        isRunning = false
        connections.forEach { $0.cancel() }
        connections.removeAll()
        listener?.cancel()
        listener = nil
        print("✓ TCP Server stopped")
    }

    var clientCount: Int {
        connections.count
    }
}
