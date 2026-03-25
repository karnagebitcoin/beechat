import Foundation
import SwiftUI

struct SnakeRenderState {
    var players: [SnakeSnapshotPlayer] = []
    var foods: [SnakeGridPoint] = []
    var tick: Int = 0
    var isFinished = false
    var winnerText: String?
}

@MainActor
final class SnakeRuntimeController: ObservableObject, Identifiable {
    let id: String
    let sessionID: String
    let host: SnakeParticipant
    let participants: [SnakeParticipant]
    let localPeerID: PeerID
    let isHost: Bool
    let isBotMatch: Bool

    @Published private(set) var state = SnakeRenderState()

    private var timer: Timer?
    private var playerStates: [PeerID: SnakePlayerState] = [:]
    private var foods: [SnakeGridPoint] = []
    private var lastInputAt = Date.distantPast
    private var tickCount = 0

    private let boardWidth = 28
    private let boardHeight = 18
    private let tickInterval: TimeInterval = 1.0 / 6.0
    private let inputSendInterval: TimeInterval = 1.0 / 15.0
    private let sendControl: (PeerID, SnakeControlEnvelope) -> Void
    private let publishResult: (PeerID?, String?) -> Void
    private let onDismiss: () -> Void

    init(
        session: SnakeSession,
        localPeerID: PeerID,
        isBotMatch: Bool = false,
        sendControl: @escaping (PeerID, SnakeControlEnvelope) -> Void,
        publishResult: @escaping (PeerID?, String?) -> Void,
        onDismiss: @escaping () -> Void
    ) {
        self.id = session.id
        self.sessionID = session.id
        self.host = session.host
        self.participants = session.players
        self.localPeerID = localPeerID
        self.isHost = session.host.peerID == localPeerID
        self.isBotMatch = isBotMatch
        self.sendControl = sendControl
        self.publishResult = publishResult
        self.onDismiss = onDismiss

        seedArena()
        refreshRenderState()
    }

    deinit {
        timer?.invalidate()
    }

    func start() {
        guard timer == nil else { return }
        guard isHost else { return }

        let timer = Timer(timeInterval: tickInterval, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.tick()
            }
        }
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    func dismiss() {
        stop()
        onDismiss()
    }

    func restartBotMatch() {
        guard isBotMatch else { return }
        stop()
        resetArena()
        start()
    }

    func queueDirection(_ direction: SnakeDirection) {
        guard !state.isFinished else { return }

        if isHost {
            applyInput(direction, for: localPeerID)
            return
        }

        if let localPlayer = playerStates[localPeerID], localPlayer.isAlive,
           direction != localPlayer.direction.opposite {
            playerStates[localPeerID]?.pendingDirection = direction
        }

        let now = Date()
        guard now.timeIntervalSince(lastInputAt) >= inputSendInterval else { return }
        lastInputAt = now

        let envelope = SnakeControlEnvelope(
            sessionID: sessionID,
            type: .input,
            senderPeerID: localPeerID,
            direction: direction
        )
        sendControl(host.peerID, envelope)
    }

    func receive(_ envelope: SnakeControlEnvelope) {
        guard envelope.sessionID == sessionID else { return }

        switch envelope.type {
        case .input:
            guard isHost, let direction = envelope.direction else { return }
            applyInput(direction, for: envelope.senderPeerID)
        case .state:
            guard !isHost,
                  let players = envelope.players,
                  let foods = envelope.foods else {
                return
            }
            updateFromSnapshot(players: players, foods: foods, tick: envelope.tick ?? state.tick)
            if let winnerName = envelope.winnerName {
                finishLocally(text: winnerName == "__draw__" ? "Draw" : "\(winnerName) wins Snake Arena")
            }
        case .leave:
            guard isHost else { return }
            eliminate(peerID: envelope.senderPeerID)
        }
    }

    func applyPublicResult(winnerName: String?) {
        if let winnerName {
            finishLocally(text: winnerName == "__draw__" ? "Draw" : "\(winnerName) wins Snake Arena")
        } else {
            finishLocally(text: "Match finished")
        }
    }

    func leaveMatch() {
        if state.isFinished {
            dismiss()
            return
        }

        if isBotMatch {
            dismiss()
            return
        }

        if isHost {
            let fallbackWinner = survivingParticipants(excluding: localPeerID).first
            finish(
                winnerPeerID: fallbackWinner?.peerID,
                winnerName: fallbackWinner?.nickname,
                localText: fallbackWinner.map { "\($0.nickname) wins by forfeit" } ?? "Match ended"
            )
        } else {
            let envelope = SnakeControlEnvelope(
                sessionID: sessionID,
                type: .leave,
                senderPeerID: localPeerID
            )
            sendControl(host.peerID, envelope)
            dismiss()
        }
    }
}

private extension SnakeRuntimeController {
    struct SnakePlayerState {
        let participant: SnakeParticipant
        let colorIndex: Int
        var segments: [SnakeGridPoint]
        var direction: SnakeDirection
        var pendingDirection: SnakeDirection?
        var isAlive: Bool
        var score: Int
    }

    func tick() {
        guard isHost, !state.isFinished else { return }

        tickCount += 1

        if isBotMatch {
            updateBotDirections()
        }

        for peerID in participants.map(\.peerID) {
            applyPendingDirection(for: peerID)
        }

        let occupied = Dictionary(grouping: liveOccupiedCells(), by: { $0 })
        var proposedHeads: [PeerID: SnakeGridPoint] = [:]
        var eliminated = Set<PeerID>()

        for participant in participants {
            guard let player = playerStates[participant.peerID], player.isAlive else { continue }
            let nextHead = advanced(point: player.segments[0], direction: player.direction)
            proposedHeads[participant.peerID] = nextHead

            if !isInsideBoard(nextHead) || occupied[nextHead] != nil {
                eliminated.insert(participant.peerID)
            }
        }

        let headCollisions = Dictionary(grouping: proposedHeads, by: { $0.value })
        for group in headCollisions.values where group.count > 1 {
            for collision in group {
                eliminated.insert(collision.key)
            }
        }

        for participant in participants {
            guard var player = playerStates[participant.peerID], player.isAlive else { continue }

            if eliminated.contains(participant.peerID) {
                player.isAlive = false
                playerStates[participant.peerID] = player
                continue
            }

            guard let nextHead = proposedHeads[participant.peerID] else { continue }
            player.segments.insert(nextHead, at: 0)

            if let foodIndex = foods.firstIndex(of: nextHead) {
                foods.remove(at: foodIndex)
                player.score += 1
            } else {
                player.segments.removeLast()
            }

            playerStates[participant.peerID] = player
        }

        refillFood()
        refreshRenderState()

        let living = livePlayers()
        if living.count <= 1 {
            let winner = living.first?.participant
            finish(
                winnerPeerID: winner?.peerID,
                winnerName: winner?.nickname,
                localText: winner.map { "\($0.nickname) wins Snake Arena" } ?? "Draw"
            )
            return
        }

        broadcastSnapshot()
    }

    func seedArena() {
        let spawnConfigs: [(SnakeGridPoint, SnakeDirection)] = [
            (SnakeGridPoint(x: 4, y: 4), .right),
            (SnakeGridPoint(x: boardWidth - 5, y: boardHeight - 5), .left),
            (SnakeGridPoint(x: 10, y: 3), .down),
            (SnakeGridPoint(x: boardWidth - 11, y: boardHeight - 4), .up),
            (SnakeGridPoint(x: 4, y: boardHeight - 5), .right),
            (SnakeGridPoint(x: boardWidth - 5, y: 4), .left)
        ]

        for (index, participant) in participants.enumerated() {
            let config = spawnConfigs[min(index, spawnConfigs.count - 1)]
            playerStates[participant.peerID] = SnakePlayerState(
                participant: participant,
                colorIndex: index,
                segments: makeSegments(head: config.0, direction: config.1),
                direction: config.1,
                pendingDirection: nil,
                isAlive: true,
                score: 0
            )
        }

        refillFood()
    }

    func resetArena() {
        playerStates.removeAll()
        foods.removeAll()
        lastInputAt = .distantPast
        tickCount = 0
        state = SnakeRenderState()
        seedArena()
        refreshRenderState()
    }

    func makeSegments(head: SnakeGridPoint, direction: SnakeDirection) -> [SnakeGridPoint] {
        let bodyDirection = direction.opposite
        return (0..<4).map { offset in
            SnakeGridPoint(
                x: head.x + delta(for: bodyDirection).x * offset,
                y: head.y + delta(for: bodyDirection).y * offset
            )
        }
    }

    func delta(for direction: SnakeDirection) -> (x: Int, y: Int) {
        switch direction {
        case .up:
            return (0, -1)
        case .down:
            return (0, 1)
        case .left:
            return (-1, 0)
        case .right:
            return (1, 0)
        }
    }

    func advanced(point: SnakeGridPoint, direction: SnakeDirection) -> SnakeGridPoint {
        let delta = delta(for: direction)
        return SnakeGridPoint(x: point.x + delta.x, y: point.y + delta.y)
    }

    func isInsideBoard(_ point: SnakeGridPoint) -> Bool {
        point.x >= 0 && point.y >= 0 && point.x < boardWidth && point.y < boardHeight
    }

    func liveOccupiedCells() -> [SnakeGridPoint] {
        playerStates.values
            .filter(\.isAlive)
            .flatMap(\.segments)
    }

    func livePlayers() -> [SnakePlayerState] {
        participants.compactMap { participant in
            guard let player = playerStates[participant.peerID], player.isAlive else { return nil }
            return player
        }
    }

    func survivingParticipants(excluding peerID: PeerID? = nil) -> [SnakeParticipant] {
        livePlayers()
            .filter { player in
                guard let peerID else { return true }
                return player.participant.peerID != peerID
            }
            .map(\.participant)
    }

    func applyInput(_ direction: SnakeDirection, for peerID: PeerID) {
        guard var player = playerStates[peerID], player.isAlive else { return }
        guard direction != player.direction.opposite else { return }
        if let pendingDirection = player.pendingDirection, direction == pendingDirection.opposite {
            return
        }
        player.pendingDirection = direction
        playerStates[peerID] = player
    }

    func applyPendingDirection(for peerID: PeerID) {
        guard var player = playerStates[peerID], player.isAlive else { return }
        if let pendingDirection = player.pendingDirection, pendingDirection != player.direction.opposite {
            player.direction = pendingDirection
        }
        player.pendingDirection = nil
        playerStates[peerID] = player
    }

    func eliminate(peerID: PeerID) {
        guard var player = playerStates[peerID], player.isAlive else { return }
        player.isAlive = false
        playerStates[peerID] = player
        refreshRenderState()

        let living = livePlayers()
        if living.count <= 1 {
            let winner = living.first?.participant
            finish(
                winnerPeerID: winner?.peerID,
                winnerName: winner?.nickname,
                localText: winner.map { "\($0.nickname) wins Snake Arena" } ?? "Draw"
            )
            return
        }

        broadcastSnapshot()
    }

    func refillFood() {
        let targetFoodCount = max(1, min(3, participants.count / 2 + 1))
        let occupied = Set(playerStates.values.flatMap(\.segments))

        while foods.count < targetFoodCount {
            let candidate = SnakeGridPoint(
                x: Int.random(in: 1..<(boardWidth - 1)),
                y: Int.random(in: 1..<(boardHeight - 1))
            )
            guard !occupied.contains(candidate), !foods.contains(candidate) else { continue }
            foods.append(candidate)
        }
    }

    func refreshRenderState() {
        state.players = participants.compactMap { participant in
            guard let player = playerStates[participant.peerID] else { return nil }
            return SnakeSnapshotPlayer(
                peerID: participant.peerID,
                nickname: participant.nickname,
                colorIndex: player.colorIndex,
                segments: player.segments,
                direction: player.direction,
                isAlive: player.isAlive,
                score: player.score
            )
        }
        state.foods = foods
        state.tick = tickCount
    }

    func updateFromSnapshot(players: [SnakeSnapshotPlayer], foods: [SnakeGridPoint], tick: Int) {
        for player in players {
            playerStates[player.peerID] = SnakePlayerState(
                participant: SnakeParticipant(peerID: player.peerID, nickname: player.nickname),
                colorIndex: player.colorIndex,
                segments: player.segments,
                direction: player.direction,
                pendingDirection: nil,
                isAlive: player.isAlive,
                score: player.score
            )
        }
        self.foods = foods
        tickCount = tick
        refreshRenderState()
    }

    func broadcastSnapshot(winnerPeerID: PeerID? = nil, winnerName: String? = nil) {
        guard !isBotMatch else { return }

        let envelope = SnakeControlEnvelope(
            sessionID: sessionID,
            type: .state,
            senderPeerID: localPeerID,
            players: state.players,
            foods: state.foods,
            winnerPeerID: winnerPeerID,
            winnerName: winnerName,
            tick: state.tick
        )

        for participant in participants where participant.peerID != localPeerID {
            sendControl(participant.peerID, envelope)
        }
    }

    func finish(winnerPeerID: PeerID?, winnerName: String?, localText: String) {
        guard !state.isFinished else { return }
        stop()
        state.isFinished = true
        state.winnerText = localText
        broadcastSnapshot(winnerPeerID: winnerPeerID, winnerName: winnerName ?? (winnerPeerID == nil ? "__draw__" : nil))
        if !isBotMatch {
            publishResult(winnerPeerID, winnerName)
        }
    }

    func finishLocally(text: String) {
        guard !state.isFinished else { return }
        stop()
        state.isFinished = true
        state.winnerText = text
    }

    func updateBotDirections() {
        let occupied = Set(liveOccupiedCells())
        let targets = foods

        for participant in participants where participant.peerID != localPeerID {
            guard var player = playerStates[participant.peerID], player.isAlive else { continue }

            let candidateDirections = [
                player.direction,
                turnLeft(from: player.direction),
                turnRight(from: player.direction)
            ]

            let safeDirections = candidateDirections.filter { direction in
                guard direction != player.direction.opposite else { return false }
                let next = advanced(point: player.segments[0], direction: direction)
                return isInsideBoard(next) && !occupied.contains(next)
            }

            guard let chosenDirection = bestBotDirection(from: player, choices: safeDirections, targets: targets) else {
                continue
            }

            player.pendingDirection = chosenDirection
            playerStates[participant.peerID] = player
        }
    }

    func bestBotDirection(
        from player: SnakePlayerState,
        choices: [SnakeDirection],
        targets: [SnakeGridPoint]
    ) -> SnakeDirection? {
        guard !choices.isEmpty else { return nil }
        guard let target = targets.min(by: { lhs, rhs in
            manhattanDistance(from: player.segments[0], to: lhs) < manhattanDistance(from: player.segments[0], to: rhs)
        }) else {
            return choices.first
        }

        return choices.min(by: { lhs, rhs in
            let lhsDistance = manhattanDistance(from: advanced(point: player.segments[0], direction: lhs), to: target)
            let rhsDistance = manhattanDistance(from: advanced(point: player.segments[0], direction: rhs), to: target)
            return lhsDistance < rhsDistance
        })
    }

    func manhattanDistance(from lhs: SnakeGridPoint, to rhs: SnakeGridPoint) -> Int {
        abs(lhs.x - rhs.x) + abs(lhs.y - rhs.y)
    }

    func turnLeft(from direction: SnakeDirection) -> SnakeDirection {
        switch direction {
        case .up:
            return .left
        case .down:
            return .right
        case .left:
            return .down
        case .right:
            return .up
        }
    }

    func turnRight(from direction: SnakeDirection) -> SnakeDirection {
        switch direction {
        case .up:
            return .right
        case .down:
            return .left
        case .left:
            return .up
        case .right:
            return .down
        }
    }
}
