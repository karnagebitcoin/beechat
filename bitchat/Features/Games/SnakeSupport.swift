import Foundation

enum SnakeSessionStatus: String, Codable {
    case waiting
    case running
    case finished
}

struct SnakeParticipant: Codable, Equatable, Hashable {
    let peerID: PeerID
    let nickname: String
}

struct SnakeGridPoint: Codable, Equatable, Hashable {
    let x: Int
    let y: Int
}

enum SnakeDirection: String, Codable {
    case up
    case down
    case left
    case right

    var opposite: SnakeDirection {
        switch self {
        case .up:
            return .down
        case .down:
            return .up
        case .left:
            return .right
        case .right:
            return .left
        }
    }
}

struct SnakeSnapshotPlayer: Codable, Equatable {
    let peerID: PeerID
    let nickname: String
    let colorIndex: Int
    let segments: [SnakeGridPoint]
    let direction: SnakeDirection
    let isAlive: Bool
    let score: Int
}

struct SnakeSession: Identifiable, Equatable {
    static let maxPlayers = 6
    static let minimumPlayers = 2
    static let expiryWindow: TimeInterval = 60

    let id: String
    let createdAt: Date
    let host: SnakeParticipant
    var players: [SnakeParticipant]
    var status: SnakeSessionStatus
    var winnerPeerID: PeerID?
    var winnerName: String?

    var inviteMessageID: String { "snake-invite-\(id)" }
    var expiresAt: Date { createdAt.addingTimeInterval(Self.expiryWindow) }
    var isFull: Bool { players.count >= Self.maxPlayers }

    func contains(_ peerID: PeerID) -> Bool {
        players.contains { $0.peerID == peerID }
    }

    func isExpired(at now: Date = Date()) -> Bool {
        status == .waiting && now >= expiresAt
    }

    var summaryText: String {
        switch status {
        case .waiting:
            if isExpired() {
                return "Expired"
            }
            return "\(players.count)/\(Self.maxPlayers) nearby"
        case .running:
            return "Match live"
        case .finished:
            if let winnerName {
                return "\(winnerName) wins"
            }
            return "Finished"
        }
    }
}

enum SnakePublicEventType: String, Codable {
    case invite
    case join
    case start
    case result
    case cancel
}

struct SnakePublicEnvelope: Codable {
    let version: Int
    let type: SnakePublicEventType
    let sessionID: String
    let hostPeerID: PeerID
    let hostName: String
    let players: [SnakeParticipant]
    let winnerPeerID: PeerID?
    let winnerName: String?
    let createdAtMs: Int64

    init(
        type: SnakePublicEventType,
        sessionID: String,
        hostPeerID: PeerID,
        hostName: String,
        players: [SnakeParticipant],
        winnerPeerID: PeerID? = nil,
        winnerName: String? = nil,
        createdAt: Date
    ) {
        self.version = 1
        self.type = type
        self.sessionID = sessionID
        self.hostPeerID = hostPeerID
        self.hostName = hostName
        self.players = players
        self.winnerPeerID = winnerPeerID
        self.winnerName = winnerName
        self.createdAtMs = Int64(createdAt.timeIntervalSince1970 * 1000)
    }

    var createdAt: Date {
        Date(timeIntervalSince1970: TimeInterval(createdAtMs) / 1000)
    }
}

enum SnakeControlType: String, Codable {
    case input
    case state
    case leave
}

struct SnakeControlEnvelope: Codable {
    let version: Int
    let sessionID: String
    let type: SnakeControlType
    let senderPeerID: PeerID
    let direction: SnakeDirection?
    let players: [SnakeSnapshotPlayer]?
    let foods: [SnakeGridPoint]?
    let winnerPeerID: PeerID?
    let winnerName: String?
    let tick: Int?

    init(
        sessionID: String,
        type: SnakeControlType,
        senderPeerID: PeerID,
        direction: SnakeDirection? = nil,
        players: [SnakeSnapshotPlayer]? = nil,
        foods: [SnakeGridPoint]? = nil,
        winnerPeerID: PeerID? = nil,
        winnerName: String? = nil,
        tick: Int? = nil
    ) {
        self.version = 1
        self.sessionID = sessionID
        self.type = type
        self.senderPeerID = senderPeerID
        self.direction = direction
        self.players = players
        self.foods = foods
        self.winnerPeerID = winnerPeerID
        self.winnerName = winnerName
        self.tick = tick
    }
}

enum SnakeWireCodec {
    static let publicPrefix = "::snake-public "
    static let controlPrefix = "::snake-ctrl "

    private static let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        return encoder
    }()

    private static let decoder = JSONDecoder()

    static func encodePublic(_ envelope: SnakePublicEnvelope) -> String? {
        guard let data = try? encoder.encode(envelope),
              let json = String(data: data, encoding: .utf8) else {
            return nil
        }
        return publicPrefix + json
    }

    static func decodePublic(_ content: String) -> SnakePublicEnvelope? {
        guard content.hasPrefix(publicPrefix) else { return nil }
        let json = String(content.dropFirst(publicPrefix.count))
        guard let data = json.data(using: .utf8) else { return nil }
        return try? decoder.decode(SnakePublicEnvelope.self, from: data)
    }

    static func encodeControl(_ envelope: SnakeControlEnvelope) -> String? {
        guard let data = try? encoder.encode(envelope),
              let json = String(data: data, encoding: .utf8) else {
            return nil
        }
        return controlPrefix + json
    }

    static func decodeControl(_ content: String) -> SnakeControlEnvelope? {
        guard content.hasPrefix(controlPrefix) else { return nil }
        let json = String(content.dropFirst(controlPrefix.count))
        guard let data = json.data(using: .utf8) else { return nil }
        return try? decoder.decode(SnakeControlEnvelope.self, from: data)
    }
}
