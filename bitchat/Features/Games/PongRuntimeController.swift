import Foundation
import SwiftUI

struct PongRenderState {
    var hostPaddleY: Double = 0.5
    var guestPaddleY: Double = 0.5
    var ballX: Double = 0.5
    var ballY: Double = 0.5
    var ballVX: Double = 0.44
    var ballVY: Double = 0.28
    var hostScore: Int = 0
    var guestScore: Int = 0
    var isFinished = false
    var winnerText: String?
}

@MainActor
final class PongRuntimeController: ObservableObject, Identifiable {
    let id: String
    let sessionID: String
    let host: PongParticipant
    let guest: PongParticipant
    let localPeerID: PeerID
    let remotePeerID: PeerID
    let isHost: Bool
    let isBotMatch: Bool

    @Published private(set) var state = PongRenderState()
    @Published private(set) var paddleImpactToken = 0

    private var timer: Timer?
    private var lastTickAt = Date()
    private var lastSnapshotAt = Date.distantPast
    private var lastInputAt = Date.distantPast
    private let winningScore = 5

    private let paddleHeight = 0.2
    private let ballRadius = 0.018
    private let leftPaddleX = 0.05
    private let rightPaddleX = 0.95
    private let stateSendInterval: TimeInterval = 1.0 / 8.0
    private let inputSendInterval: TimeInterval = 1.0 / 12.0

    private let sendControl: (PeerID, PongControlEnvelope) -> Void
    private let publishResult: (Int, Int, PeerID) -> Void
    private let onDismiss: () -> Void

    init(
        session: PongSession,
        localPeerID: PeerID,
        isBotMatch: Bool = false,
        sendControl: @escaping (PeerID, PongControlEnvelope) -> Void,
        publishResult: @escaping (Int, Int, PeerID) -> Void,
        onDismiss: @escaping () -> Void
    ) {
        guard let guest = session.guest else {
            fatalError("PongRuntimeController requires a full session")
        }

        self.id = session.id
        self.sessionID = session.id
        self.host = session.host
        self.guest = guest
        self.localPeerID = localPeerID
        self.remotePeerID = session.host.peerID == localPeerID ? guest.peerID : session.host.peerID
        self.isHost = session.host.peerID == localPeerID
        self.isBotMatch = isBotMatch
        self.sendControl = sendControl
        self.publishResult = publishResult
        self.onDismiss = onDismiss
        self.state.hostScore = session.hostScore
        self.state.guestScore = session.guestScore
    }

    deinit {
        timer?.invalidate()
    }

    func start() {
        guard timer == nil else { return }
        lastTickAt = Date()
        let timer = Timer(timeInterval: 1.0 / 30.0, repeats: true) { [weak self] _ in
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

    func setLocalPaddleY(_ rawValue: Double) {
        let clamped = clampPaddle(rawValue)
        if isHost {
            state.hostPaddleY = clamped
        } else {
            state.guestPaddleY = clamped
            sendGuestPaddleIfNeeded(force: false)
        }
    }

    func receive(_ envelope: PongControlEnvelope) {
        guard envelope.sessionID == sessionID else { return }

        switch envelope.type {
        case .paddle:
            if isHost, let paddleY = envelope.paddleY {
                state.guestPaddleY = clampPaddle(paddleY)
            }
        case .state:
            guard !isHost else { return }
            if let hostPaddleY = envelope.hostPaddleY { state.hostPaddleY = clampPaddle(hostPaddleY) }
            if let guestPaddleY = envelope.guestPaddleY { state.guestPaddleY = clampPaddle(guestPaddleY) }
            if let ballX = envelope.ballX { state.ballX = ballX }
            if let ballY = envelope.ballY { state.ballY = ballY }
            if let ballVX = envelope.ballVX { state.ballVX = ballVX }
            if let ballVY = envelope.ballVY { state.ballVY = ballVY }
            if let hostScore = envelope.hostScore { state.hostScore = hostScore }
            if let guestScore = envelope.guestScore { state.guestScore = guestScore }
        case .impact:
            triggerPaddleImpact()
        case .leave:
            if isHost {
                finish(winner: host.peerID, winnerText: "\(host.nickname) wins by forfeit")
            } else {
                state.isFinished = true
                state.winnerText = "\(host.nickname) left the match"
                stop()
            }
        }
    }

    func applyPublicResult(winnerName: String, winnerPeerID: PeerID, hostScore: Int, guestScore: Int) {
        state.hostScore = hostScore
        state.guestScore = guestScore
        finishLocally(text: "\(winnerName) wins \(hostScore)-\(guestScore)")
    }

    func leaveMatch() {
        if state.isFinished {
            dismiss()
            return
        }

        if isHost {
            finish(winner: guest.peerID, winnerText: "\(guest.nickname) wins by forfeit")
        } else {
            let envelope = PongControlEnvelope(
                sessionID: sessionID,
                type: .leave,
                senderPeerID: localPeerID
            )
            sendControl(remotePeerID, envelope)
            dismiss()
        }
    }
}

private extension PongRuntimeController {
    func tick() {
        let now = Date()
        let dt = min(now.timeIntervalSince(lastTickAt), 1.0 / 15.0)
        lastTickAt = now

        guard !state.isFinished else { return }

        if isHost {
            if isBotMatch {
                updateBotPaddle(by: dt)
            }
            advanceAuthoritativeState(by: dt)
            if !isBotMatch && now.timeIntervalSince(lastSnapshotAt) >= stateSendInterval {
                lastSnapshotAt = now
                let envelope = PongControlEnvelope(
                    sessionID: sessionID,
                    type: .state,
                    senderPeerID: localPeerID,
                    hostPaddleY: state.hostPaddleY,
                    guestPaddleY: state.guestPaddleY,
                    ballX: state.ballX,
                    ballY: state.ballY,
                    ballVX: state.ballVX,
                    ballVY: state.ballVY,
                    hostScore: state.hostScore,
                    guestScore: state.guestScore
                )
                sendControl(remotePeerID, envelope)
            }
        } else {
            state.ballX += state.ballVX * dt
            state.ballY += state.ballVY * dt
            if state.ballY < ballRadius {
                state.ballY = ballRadius
                state.ballVY = abs(state.ballVY)
            }
            if state.ballY > 1 - ballRadius {
                state.ballY = 1 - ballRadius
                state.ballVY = -abs(state.ballVY)
            }
        }
    }

    func advanceAuthoritativeState(by dt: TimeInterval) {
        state.ballX += state.ballVX * dt
        state.ballY += state.ballVY * dt

        if state.ballY <= ballRadius {
            state.ballY = ballRadius
            state.ballVY = abs(state.ballVY)
        } else if state.ballY >= 1 - ballRadius {
            state.ballY = 1 - ballRadius
            state.ballVY = -abs(state.ballVY)
        }

        let leftHitX = leftPaddleX + ballRadius
        let rightHitX = rightPaddleX - ballRadius

        if state.ballVX < 0 && state.ballX <= leftHitX {
            if abs(state.ballY - state.hostPaddleY) <= paddleHeight / 2 {
                let offset = (state.ballY - state.hostPaddleY) / (paddleHeight / 2)
                state.ballX = leftHitX
                state.ballVX = abs(state.ballVX) * 1.03
                state.ballVY = max(-0.7, min(0.7, state.ballVY + offset * 0.16))
                triggerPaddleImpact()
            } else if state.ballX < 0 {
                state.guestScore += 1
                if state.guestScore >= winningScore {
                    finish(winner: guest.peerID, winnerText: "\(guest.nickname) wins \(state.guestScore)-\(state.hostScore)")
                    return
                }
                resetBall(towardHost: false)
            }
        }

        if state.ballVX > 0 && state.ballX >= rightHitX {
            if abs(state.ballY - state.guestPaddleY) <= paddleHeight / 2 {
                let offset = (state.ballY - state.guestPaddleY) / (paddleHeight / 2)
                state.ballX = rightHitX
                state.ballVX = -abs(state.ballVX) * 1.03
                state.ballVY = max(-0.7, min(0.7, state.ballVY + offset * 0.16))
                if isBotMatch {
                    triggerPaddleImpact()
                } else {
                    let envelope = PongControlEnvelope(
                        sessionID: sessionID,
                        type: .impact,
                        senderPeerID: localPeerID
                    )
                    sendControl(remotePeerID, envelope)
                }
            } else if state.ballX > 1 {
                state.hostScore += 1
                if state.hostScore >= winningScore {
                    finish(winner: host.peerID, winnerText: "\(host.nickname) wins \(state.hostScore)-\(state.guestScore)")
                    return
                }
                resetBall(towardHost: true)
            }
        }
    }

    func resetBall(towardHost: Bool) {
        state.ballX = 0.5
        state.ballY = 0.5
        state.ballVX = towardHost ? -0.44 : 0.44
        let vertical: Double = Bool.random() ? 0.28 : -0.28
        state.ballVY = vertical
    }

    func finish(winner: PeerID, winnerText: String) {
        finishLocally(text: winnerText)
        publishResult(state.hostScore, state.guestScore, winner)
    }

    func finishLocally(text: String) {
        state.isFinished = true
        state.winnerText = text
        stop()
    }

    func triggerPaddleImpact() {
        paddleImpactToken &+= 1
    }

    func sendGuestPaddleIfNeeded(force: Bool) {
        guard !isHost, !isBotMatch else { return }
        let now = Date()
        guard force || now.timeIntervalSince(lastInputAt) >= inputSendInterval else { return }
        lastInputAt = now
        let envelope = PongControlEnvelope(
            sessionID: sessionID,
            type: .paddle,
            senderPeerID: localPeerID,
            paddleY: state.guestPaddleY
        )
        sendControl(remotePeerID, envelope)
    }

    func clampPaddle(_ value: Double) -> Double {
        min(1 - paddleHeight / 2, max(paddleHeight / 2, value))
    }

    func updateBotPaddle(by dt: TimeInterval) {
        let targetY: Double
        if state.ballVX > 0 {
            targetY = state.ballY + (state.ballVY * 0.06)
        } else {
            targetY = 0.5
        }
        let speed = 0.52
        let delta = targetY - state.guestPaddleY
        let step = max(-speed * dt, min(speed * dt, delta))
        state.guestPaddleY = clampPaddle(state.guestPaddleY + step)
    }
}
