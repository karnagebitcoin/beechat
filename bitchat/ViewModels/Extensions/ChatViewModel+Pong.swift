import Foundation

extension ChatViewModel {
    @MainActor
    func startPongInvite() {
        guard selectedPrivateChatPeer == nil, activeChannel == .mesh else {
            addSystemMessage("pong is only available in the public mesh chat")
            return
        }

        let me = currentPublicSender()
        if hasActivePongConflict(for: me.peerID) {
            addSystemMessage("finish your current pong match before starting another one")
            return
        }

        let session = PongSession(
            id: UUID().uuidString,
            createdAt: Date(),
            host: PongParticipant(peerID: me.peerID, nickname: me.name),
            guest: nil,
            status: .waiting,
            hostScore: 0,
            guestScore: 0,
            winnerPeerID: nil,
            winnerName: nil
        )

        pongSessions[session.id] = session
        insertPongInviteMessage(for: session)

        let envelope = PongPublicEnvelope(
            type: .invite,
            sessionID: session.id,
            hostPeerID: session.host.peerID,
            hostName: session.host.nickname,
            createdAt: session.createdAt
        )
        sendPongPublicEnvelope(envelope)
    }

    @MainActor
    func startPongBotMatch() {
        let me = currentPublicSender()
        guard !hasActivePongConflict(for: me.peerID) else {
            addSystemMessage("finish your current pong match before starting another one")
            return
        }

        let session = PongSession(
            id: "pong-bot-" + UUID().uuidString,
            createdAt: Date(),
            host: PongParticipant(peerID: me.peerID, nickname: me.name),
            guest: PongParticipant(peerID: PeerID(str: "bot_pong"), nickname: "Bot"),
            status: .running,
            hostScore: 0,
            guestScore: 0,
            winnerPeerID: nil,
            winnerName: nil
        )

        launchPongRuntimeIfNeeded(for: session, isBotMatch: true)
    }

    @MainActor
    func joinPongSession(sessionID: String) {
        guard var session = pongSessions[sessionID] else { return }
        let me = currentPublicSender()

        guard !hasActivePongConflict(for: me.peerID) else {
            addSystemMessage("finish your current pong match before joining another one")
            return
        }

        guard session.host.peerID != me.peerID else { return }
        guard session.guest == nil else { return }
        guard !session.isExpired() else {
            addSystemMessage("that pong invite already expired")
            return
        }

        session.guest = PongParticipant(peerID: me.peerID, nickname: me.name)
        session.status = .ready
        pongSessions[sessionID] = session

        let envelope = PongPublicEnvelope(
            type: .join,
            sessionID: session.id,
            hostPeerID: session.host.peerID,
            hostName: session.host.nickname,
            guestPeerID: me.peerID,
            guestName: me.name,
            createdAt: session.createdAt
        )
        sendPongPublicEnvelope(envelope)
    }

    @MainActor
    func cancelPongInvite(sessionID: String) {
        guard let session = pongSessions[sessionID] else { return }
        guard session.host.peerID == meshService.myPeerID else { return }
        guard session.status == .waiting, session.guest == nil else { return }

        let envelope = PongPublicEnvelope(
            type: .cancel,
            sessionID: session.id,
            hostPeerID: session.host.peerID,
            hostName: session.host.nickname,
            createdAt: session.createdAt
        )
        sendPongPublicEnvelope(envelope)
        removePongSession(sessionID: session.id)
    }

    @MainActor
    func openPongSession(sessionID: String) {
        guard let session = pongSessions[sessionID] else { return }
        guard session.guest != nil else { return }
        guard session.contains(meshService.myPeerID) else { return }
        launchPongRuntimeIfNeeded(for: session)
    }

    @MainActor
    func pongSession(forInviteMessageID messageID: String) -> PongSession? {
        guard let sessionID = pongInviteMessageIDs[messageID],
              let session = pongSessions[sessionID] else {
            return nil
        }
        return session
    }

    @MainActor
    func receivePongPublicContent(
        _ content: String,
        from peerID: PeerID,
        nickname: String,
        timestamp: Date
    ) -> Bool {
        guard let envelope = PongWireCodec.decodePublic(content) else { return false }

        switch envelope.type {
        case .invite:
            let host = PongParticipant(peerID: envelope.hostPeerID, nickname: envelope.hostName)
            let session = PongSession(
                id: envelope.sessionID,
                createdAt: envelope.createdAt,
                host: host,
                guest: nil,
                status: .waiting,
                hostScore: 0,
                guestScore: 0,
                winnerPeerID: nil,
                winnerName: nil
            )
            pongSessions[session.id] = pongSessions[session.id] ?? session
            insertPongInviteMessage(for: pongSessions[session.id] ?? session, timestamp: timestamp)
        case .join:
            guard var session = pongSessions[envelope.sessionID],
                  let guestPeerID = envelope.guestPeerID,
                  let guestName = envelope.guestName else {
                return true
            }
            session.guest = PongParticipant(peerID: guestPeerID, nickname: guestName)
            session.status = .ready
            pongSessions[session.id] = session

            if session.host.peerID == meshService.myPeerID {
                startPongSession(sessionID: session.id)
            }
        case .start:
            guard var session = pongSessions[envelope.sessionID],
                  let guestPeerID = envelope.guestPeerID,
                  let guestName = envelope.guestName else {
                return true
            }
            session.guest = session.guest ?? PongParticipant(peerID: guestPeerID, nickname: guestName)
            session.status = .running
            pongSessions[session.id] = session
            launchPongRuntimeIfNeeded(for: session)
        case .result:
            guard var session = pongSessions[envelope.sessionID] else { return true }
            session.status = .finished
            session.hostScore = envelope.hostScore ?? session.hostScore
            session.guestScore = envelope.guestScore ?? session.guestScore
            session.winnerPeerID = envelope.winnerPeerID
            session.winnerName = envelope.winnerName
            pongSessions[session.id] = session

            if let runtime = activePongRuntime, runtime.sessionID == session.id,
               let winnerName = envelope.winnerName,
               let winnerPeerID = envelope.winnerPeerID {
                runtime.applyPublicResult(
                    winnerName: winnerName,
                    winnerPeerID: winnerPeerID,
                    hostScore: session.hostScore,
                    guestScore: session.guestScore
                )
            }
        case .cancel:
            removePongSession(sessionID: envelope.sessionID)
        }

        return true
    }

    @MainActor
    func receivePongControlMessage(_ content: String, from peerID: PeerID) -> Bool {
        guard let envelope = PongWireCodec.decodeControl(content) else { return false }
        guard let runtime = activePongRuntime, runtime.sessionID == envelope.sessionID else { return true }
        runtime.receive(envelope)
        return true
    }

    @MainActor
    func dismissActivePongRuntime() {
        activePongRuntime?.leaveMatch()
    }
}

private extension ChatViewModel {
    @MainActor
    func hasActivePongConflict(for peerID: PeerID) -> Bool {
        if activePongRuntime != nil || activeSnakeRuntime != nil {
            return true
        }

        if currentPongSession(for: peerID) != nil {
            return true
        }

        return snakeSessions.values.contains { session in
            !session.isExpired() && session.status != .finished && session.contains(peerID)
        }
    }

    @MainActor
    func currentPongSession(for peerID: PeerID) -> PongSession? {
        pongSessions.values.first { session in
            guard !session.isExpired() else { return false }
            return session.status != .finished && session.contains(peerID)
        }
    }

    @MainActor
    func insertPongInviteMessage(for session: PongSession, timestamp: Date = Date()) {
        let inviteMessage = BitchatMessage(
            id: session.inviteMessageID,
            sender: session.host.nickname,
            content: "[pong-session \(session.id)]",
            timestamp: timestamp,
            isRelay: false,
            originalSender: nil,
            isPrivate: false,
            recipientNickname: nil,
            senderPeerID: session.host.peerID,
            mentions: nil
        )
        pongInviteMessageIDs[inviteMessage.id] = session.id
        handlePublicMessage(inviteMessage)
    }

    @MainActor
    func removePongSession(sessionID: String) {
        guard let session = pongSessions.removeValue(forKey: sessionID) else { return }
        pongInviteMessageIDs = pongInviteMessageIDs.filter { $0.value != sessionID }
        removeMessage(withID: session.inviteMessageID)
        if activePongRuntime?.sessionID == sessionID {
            activePongRuntime?.stop()
            activePongRuntime = nil
        }
    }

    @MainActor
    func startPongSession(sessionID: String) {
        guard var session = pongSessions[sessionID], let guest = session.guest else { return }
        session.status = .running
        pongSessions[session.id] = session

        let envelope = PongPublicEnvelope(
            type: .start,
            sessionID: session.id,
            hostPeerID: session.host.peerID,
            hostName: session.host.nickname,
            guestPeerID: guest.peerID,
            guestName: guest.nickname,
            createdAt: session.createdAt
        )
        sendPongPublicEnvelope(envelope)
        launchPongRuntimeIfNeeded(for: session, isBotMatch: false)
    }

    @MainActor
    func launchPongRuntimeIfNeeded(for session: PongSession, isBotMatch: Bool = false) {
        guard session.guest != nil else { return }
        guard session.contains(meshService.myPeerID) else { return }

        if let runtime = activePongRuntime, runtime.sessionID == session.id {
            return
        }

        activePongRuntime?.stop()

        let runtime = PongRuntimeController(
            session: session,
            localPeerID: meshService.myPeerID,
            isBotMatch: isBotMatch,
            sendControl: { [weak self] peerID, envelope in
                self?.sendPongControlEnvelope(envelope, to: peerID)
            },
            publishResult: { [weak self] hostScore, guestScore, winnerPeerID in
                Task { @MainActor in
                    if isBotMatch { return }
                    self?.publishPongResult(
                        sessionID: session.id,
                        hostScore: hostScore,
                        guestScore: guestScore,
                        winnerPeerID: winnerPeerID
                    )
                }
            },
            onDismiss: { [weak self] in
                self?.activePongRuntime = nil
            }
        )
        activePongRuntime = runtime
        runtime.start()
    }

    @MainActor
    func publishPongResult(sessionID: String, hostScore: Int, guestScore: Int, winnerPeerID: PeerID) {
        guard var session = pongSessions[sessionID] else { return }
        guard session.status != .finished else { return }

        session.status = .finished
        session.hostScore = hostScore
        session.guestScore = guestScore
        session.winnerPeerID = winnerPeerID
        session.winnerName = winnerPeerID == session.host.peerID ? session.host.nickname : session.guest?.nickname
        pongSessions[session.id] = session

        let envelope = PongPublicEnvelope(
            type: .result,
            sessionID: session.id,
            hostPeerID: session.host.peerID,
            hostName: session.host.nickname,
            guestPeerID: session.guest?.peerID,
            guestName: session.guest?.nickname,
            hostScore: hostScore,
            guestScore: guestScore,
            winnerPeerID: winnerPeerID,
            winnerName: session.winnerName,
            createdAt: session.createdAt
        )
        sendPongPublicEnvelope(envelope)
    }

    @MainActor
    func sendPongPublicEnvelope(_ envelope: PongPublicEnvelope) {
        guard let payload = PongWireCodec.encodePublic(envelope) else { return }
        meshService.sendMessage(
            payload,
            mentions: [],
            messageID: UUID().uuidString,
            timestamp: Date()
        )
    }

    @MainActor
    func sendPongControlEnvelope(_ envelope: PongControlEnvelope, to peerID: PeerID) {
        guard let payload = PongWireCodec.encodeControl(envelope) else { return }
        guard meshService.isPeerConnected(peerID) || meshService.isPeerReachable(peerID) else { return }
        meshService.sendPrivateMessage(
            payload,
            to: peerID,
            recipientNickname: nicknameForPeer(peerID),
            messageID: UUID().uuidString
        )
    }
}
