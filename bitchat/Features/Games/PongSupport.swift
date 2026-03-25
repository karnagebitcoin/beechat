import Foundation

enum PongSessionStatus: String, Codable {
    case waiting
    case ready
    case running
    case finished
}

struct PongParticipant: Codable, Equatable {
    let peerID: PeerID
    let nickname: String
}

struct PongSession: Identifiable, Equatable {
    let id: String
    let createdAt: Date
    let host: PongParticipant
    var guest: PongParticipant?
    var status: PongSessionStatus
    var hostScore: Int
    var guestScore: Int
    var winnerPeerID: PeerID?
    var winnerName: String?

    static let expiryWindow: TimeInterval = 45

    var inviteMessageID: String { "pong-invite-\(id)" }
    var expiresAt: Date { createdAt.addingTimeInterval(Self.expiryWindow) }
    var isFull: Bool { guest != nil }

    func contains(_ peerID: PeerID) -> Bool {
        host.peerID == peerID || guest?.peerID == peerID
    }

    func isExpired(at now: Date = Date()) -> Bool {
        status == .waiting && now >= expiresAt
    }

    var summaryText: String {
        switch status {
        case .waiting:
            return isExpired() ? "Expired" : "Waiting for an opponent"
        case .ready:
            return "Starting match..."
        case .running:
            return "\(hostScore) - \(guestScore)"
        case .finished:
            if let winnerName {
                return "\(winnerName) wins \(hostScore)-\(guestScore)"
            }
            return "Finished \(hostScore)-\(guestScore)"
        }
    }
}

enum PongPublicEventType: String, Codable {
    case invite
    case join
    case start
    case result
    case cancel
}

struct PongPublicEnvelope: Codable {
    let version: Int
    let type: PongPublicEventType
    let sessionID: String
    let hostPeerID: PeerID
    let hostName: String
    let guestPeerID: PeerID?
    let guestName: String?
    let hostScore: Int?
    let guestScore: Int?
    let winnerPeerID: PeerID?
    let winnerName: String?
    let createdAtMs: Int64

    init(
        type: PongPublicEventType,
        sessionID: String,
        hostPeerID: PeerID,
        hostName: String,
        guestPeerID: PeerID? = nil,
        guestName: String? = nil,
        hostScore: Int? = nil,
        guestScore: Int? = nil,
        winnerPeerID: PeerID? = nil,
        winnerName: String? = nil,
        createdAt: Date
    ) {
        self.version = 1
        self.type = type
        self.sessionID = sessionID
        self.hostPeerID = hostPeerID
        self.hostName = hostName
        self.guestPeerID = guestPeerID
        self.guestName = guestName
        self.hostScore = hostScore
        self.guestScore = guestScore
        self.winnerPeerID = winnerPeerID
        self.winnerName = winnerName
        self.createdAtMs = Int64(createdAt.timeIntervalSince1970 * 1000)
    }

    var createdAt: Date {
        Date(timeIntervalSince1970: TimeInterval(createdAtMs) / 1000)
    }
}

enum PongControlType: String, Codable {
    case paddle
    case state
    case impact
    case leave
}

struct PongControlEnvelope: Codable {
    let version: Int
    let sessionID: String
    let type: PongControlType
    let senderPeerID: PeerID
    let paddleY: Double?
    let hostPaddleY: Double?
    let guestPaddleY: Double?
    let ballX: Double?
    let ballY: Double?
    let ballVX: Double?
    let ballVY: Double?
    let hostScore: Int?
    let guestScore: Int?

    init(
        sessionID: String,
        type: PongControlType,
        senderPeerID: PeerID,
        paddleY: Double? = nil,
        hostPaddleY: Double? = nil,
        guestPaddleY: Double? = nil,
        ballX: Double? = nil,
        ballY: Double? = nil,
        ballVX: Double? = nil,
        ballVY: Double? = nil,
        hostScore: Int? = nil,
        guestScore: Int? = nil
    ) {
        self.version = 1
        self.sessionID = sessionID
        self.type = type
        self.senderPeerID = senderPeerID
        self.paddleY = paddleY
        self.hostPaddleY = hostPaddleY
        self.guestPaddleY = guestPaddleY
        self.ballX = ballX
        self.ballY = ballY
        self.ballVX = ballVX
        self.ballVY = ballVY
        self.hostScore = hostScore
        self.guestScore = guestScore
    }
}

enum PongWireCodec {
    static let publicPrefix = "::pong-public "
    static let controlPrefix = "::pong-ctrl "

    private static let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        return encoder
    }()

    private static let decoder = JSONDecoder()

    static func encodePublic(_ envelope: PongPublicEnvelope) -> String? {
        guard let data = try? encoder.encode(envelope),
              let json = String(data: data, encoding: .utf8) else {
            return nil
        }
        return publicPrefix + json
    }

    static func decodePublic(_ content: String) -> PongPublicEnvelope? {
        guard content.hasPrefix(publicPrefix) else { return nil }
        let json = String(content.dropFirst(publicPrefix.count))
        guard let data = json.data(using: .utf8) else { return nil }
        return try? decoder.decode(PongPublicEnvelope.self, from: data)
    }

    static func encodeControl(_ envelope: PongControlEnvelope) -> String? {
        guard let data = try? encoder.encode(envelope),
              let json = String(data: data, encoding: .utf8) else {
            return nil
        }
        return controlPrefix + json
    }

    static func decodeControl(_ content: String) -> PongControlEnvelope? {
        guard content.hasPrefix(controlPrefix) else { return nil }
        let json = String(content.dropFirst(controlPrefix.count))
        guard let data = json.data(using: .utf8) else { return nil }
        return try? decoder.decode(PongControlEnvelope.self, from: data)
    }
}
