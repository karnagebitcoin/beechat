import Foundation

extension ChatViewModel {
    @MainActor
    func startSnakeInvite() {
        guard selectedPrivateChatPeer == nil, activeChannel == .mesh else {
            addSystemMessage("snake is only available in the public mesh chat")
            return
        }

        let me = currentPublicSender()
        guard !hasActiveSnakeConflict(for: me.peerID) else {
            addSystemMessage("finish your current game before starting Snake Arena")
            return
        }

        let host = SnakeParticipant(peerID: me.peerID, nickname: me.name)
        let session = SnakeSession(
            id: UUID().uuidString,
            createdAt: Date(),
            host: host,
            players: [host],
            status: .waiting,
            winnerPeerID: nil,
            winnerName: nil
        )

        snakeSessions[session.id] = session
        insertSnakeInviteMessage(for: session)

        let envelope = SnakePublicEnvelope(
            type: .invite,
            sessionID: session.id,
            hostPeerID: session.host.peerID,
            hostName: session.host.nickname,
            players: session.players,
            createdAt: session.createdAt
        )
        sendSnakePublicEnvelope(envelope)
    }

    @MainActor
    func startSnakeBotMatch() {
        let me = currentPublicSender()
        guard !hasActiveSnakeConflict(for: me.peerID) else {
            addSystemMessage("finish your current game before starting Snake Arena")
            return
        }

        let host = SnakeParticipant(peerID: me.peerID, nickname: me.name)
        let bot = SnakeParticipant(peerID: PeerID(str: "bot_snake"), nickname: "Bot")
        let session = SnakeSession(
            id: "snake-bot-" + UUID().uuidString,
            createdAt: Date(),
            host: host,
            players: [host, bot],
            status: .running,
            winnerPeerID: nil,
            winnerName: nil
        )

        launchSnakeRuntimeIfNeeded(for: session, isBotMatch: true)
    }

    @MainActor
    func joinSnakeSession(sessionID: String) {
        guard var session = snakeSessions[sessionID] else { return }
        let me = currentPublicSender()
        let participant = SnakeParticipant(peerID: me.peerID, nickname: me.name)

        guard !hasActiveSnakeConflict(for: me.peerID) else {
            addSystemMessage("finish your current game before joining Snake Arena")
            return
        }
        guard session.host.peerID != me.peerID else { return }
        guard !session.contains(me.peerID) else { return }
        guard !session.isFull else {
            addSystemMessage("that Snake Arena is already full")
            return
        }
        guard !session.isExpired() else {
            addSystemMessage("that Snake Arena already expired")
            return
        }

        session.players.append(participant)
        snakeSessions[sessionID] = session

        let envelope = SnakePublicEnvelope(
            type: .join,
            sessionID: session.id,
            hostPeerID: session.host.peerID,
            hostName: session.host.nickname,
            players: session.players,
            createdAt: session.createdAt
        )
        sendSnakePublicEnvelope(envelope)
    }

    @MainActor
    func cancelSnakeInvite(sessionID: String) {
        guard let session = snakeSessions[sessionID] else { return }
        guard session.host.peerID == meshService.myPeerID else { return }
        guard session.status == .waiting else { return }

        let envelope = SnakePublicEnvelope(
            type: .cancel,
            sessionID: session.id,
            hostPeerID: session.host.peerID,
            hostName: session.host.nickname,
            players: session.players,
            createdAt: session.createdAt
        )
        sendSnakePublicEnvelope(envelope)
        removeSnakeSession(sessionID: session.id)
    }

    @MainActor
    func startSnakeSession(sessionID: String) {
        guard var session = snakeSessions[sessionID] else { return }
        guard session.host.peerID == meshService.myPeerID else { return }
        guard session.status == .waiting else { return }
        guard session.players.count >= SnakeSession.minimumPlayers else { return }

        session.status = .running
        snakeSessions[sessionID] = session

        let envelope = SnakePublicEnvelope(
            type: .start,
            sessionID: session.id,
            hostPeerID: session.host.peerID,
            hostName: session.host.nickname,
            players: session.players,
            createdAt: session.createdAt
        )
        sendSnakePublicEnvelope(envelope)
        launchSnakeRuntimeIfNeeded(for: session)
    }

    @MainActor
    func openSnakeSession(sessionID: String) {
        guard let session = snakeSessions[sessionID] else { return }
        guard session.status == .running else { return }
        guard session.contains(meshService.myPeerID) else { return }
        launchSnakeRuntimeIfNeeded(for: session)
    }

    @MainActor
    func snakeSession(forInviteMessageID messageID: String) -> SnakeSession? {
        guard let sessionID = snakeInviteMessageIDs[messageID],
              let session = snakeSessions[sessionID] else {
            return nil
        }
        return session
    }

    @MainActor
    func receiveSnakePublicContent(
        _ content: String,
        from peerID: PeerID,
        nickname: String,
        timestamp: Date
    ) -> Bool {
        guard let envelope = SnakeWireCodec.decodePublic(content) else { return false }

        switch envelope.type {
        case .invite:
            let host = SnakeParticipant(peerID: envelope.hostPeerID, nickname: envelope.hostName)
            let session = SnakeSession(
                id: envelope.sessionID,
                createdAt: envelope.createdAt,
                host: host,
                players: mergedSnakePlayers(host: host, players: envelope.players),
                status: .waiting,
                winnerPeerID: nil,
                winnerName: nil
            )
            snakeSessions[session.id] = snakeSessions[session.id] ?? session
            insertSnakeInviteMessage(for: snakeSessions[session.id] ?? session, timestamp: timestamp)
        case .join:
            guard var session = snakeSessions[envelope.sessionID] else { return true }
            session.players = mergedSnakePlayers(host: session.host, players: envelope.players)
            snakeSessions[session.id] = session

            if session.host.peerID == meshService.myPeerID, session.players.count >= SnakeSession.maxPlayers {
                startSnakeSession(sessionID: session.id)
            }
        case .start:
            guard var session = snakeSessions[envelope.sessionID] else { return true }
            session.players = mergedSnakePlayers(host: session.host, players: envelope.players)
            session.status = .running
            snakeSessions[session.id] = session
            launchSnakeRuntimeIfNeeded(for: session)
        case .result:
            guard var session = snakeSessions[envelope.sessionID] else { return true }
            session.status = .finished
            session.winnerPeerID = envelope.winnerPeerID
            session.winnerName = envelope.winnerName
            snakeSessions[session.id] = session

            if let runtime = activeSnakeRuntime, runtime.sessionID == session.id {
                runtime.applyPublicResult(winnerName: envelope.winnerName)
            }
        case .cancel:
            removeSnakeSession(sessionID: envelope.sessionID)
        }

        return true
    }

    @MainActor
    func receiveSnakeControlMessage(_ content: String, from peerID: PeerID) -> Bool {
        guard let envelope = SnakeWireCodec.decodeControl(content) else { return false }
        guard let runtime = activeSnakeRuntime, runtime.sessionID == envelope.sessionID else { return true }
        runtime.receive(envelope)
        return true
    }

    @MainActor
    func dismissActiveSnakeRuntime() {
        activeSnakeRuntime?.leaveMatch()
    }
}

private extension ChatViewModel {
    @MainActor
    func hasActiveSnakeConflict(for peerID: PeerID) -> Bool {
        if activeSnakeRuntime != nil || activePongRuntime != nil {
            return true
        }

        let activeSnakeSession = snakeSessions.values.contains { session in
            !session.isExpired() && session.status != .finished && session.contains(peerID)
        }
        if activeSnakeSession {
            return true
        }

        return pongSessions.values.contains { session in
            !session.isExpired() && session.status != .finished && session.contains(peerID)
        }
    }

    @MainActor
    func mergedSnakePlayers(host: SnakeParticipant, players: [SnakeParticipant]) -> [SnakeParticipant] {
        var ordered = [host]
        for player in players where !ordered.contains(where: { $0.peerID == player.peerID }) {
            ordered.append(player)
        }
        return Array(ordered.prefix(SnakeSession.maxPlayers))
    }

    @MainActor
    func insertSnakeInviteMessage(for session: SnakeSession, timestamp: Date = Date()) {
        let inviteMessage = BitchatMessage(
            id: session.inviteMessageID,
            sender: session.host.nickname,
            content: "[snake-session \(session.id)]",
            timestamp: timestamp,
            isRelay: false,
            originalSender: nil,
            isPrivate: false,
            recipientNickname: nil,
            senderPeerID: session.host.peerID,
            mentions: nil
        )
        snakeInviteMessageIDs[inviteMessage.id] = session.id
        handlePublicMessage(inviteMessage)
    }

    @MainActor
    func removeSnakeSession(sessionID: String) {
        guard let session = snakeSessions.removeValue(forKey: sessionID) else { return }
        snakeInviteMessageIDs = snakeInviteMessageIDs.filter { $0.value != sessionID }
        removeMessage(withID: session.inviteMessageID)
        if activeSnakeRuntime?.sessionID == sessionID {
            activeSnakeRuntime?.stop()
            activeSnakeRuntime = nil
        }
    }

    @MainActor
    func launchSnakeRuntimeIfNeeded(for session: SnakeSession, isBotMatch: Bool = false) {
        guard session.status == .running else { return }
        guard session.contains(meshService.myPeerID) else { return }

        if let runtime = activeSnakeRuntime, runtime.sessionID == session.id {
            return
        }

        activeSnakeRuntime?.stop()

        let runtime = SnakeRuntimeController(
            session: session,
            localPeerID: meshService.myPeerID,
            isBotMatch: isBotMatch,
            sendControl: { [weak self] peerID, envelope in
                self?.sendSnakeControlEnvelope(envelope, to: peerID)
            },
            publishResult: { [weak self] winnerPeerID, winnerName in
                Task { @MainActor in
                    if isBotMatch { return }
                    self?.publishSnakeResult(
                        sessionID: session.id,
                        winnerPeerID: winnerPeerID,
                        winnerName: winnerName
                    )
                }
            },
            onDismiss: { [weak self] in
                self?.activeSnakeRuntime = nil
            }
        )

        activeSnakeRuntime = runtime
        runtime.start()
    }

    @MainActor
    func publishSnakeResult(sessionID: String, winnerPeerID: PeerID?, winnerName: String?) {
        guard var session = snakeSessions[sessionID] else { return }
        guard session.status != .finished else { return }

        session.status = .finished
        session.winnerPeerID = winnerPeerID
        session.winnerName = winnerName
        snakeSessions[session.id] = session

        let envelope = SnakePublicEnvelope(
            type: .result,
            sessionID: session.id,
            hostPeerID: session.host.peerID,
            hostName: session.host.nickname,
            players: session.players,
            winnerPeerID: winnerPeerID,
            winnerName: winnerName,
            createdAt: session.createdAt
        )
        sendSnakePublicEnvelope(envelope)
    }

    @MainActor
    func sendSnakePublicEnvelope(_ envelope: SnakePublicEnvelope) {
        guard let payload = SnakeWireCodec.encodePublic(envelope) else { return }
        meshService.sendMessage(
            payload,
            mentions: [],
            messageID: UUID().uuidString,
            timestamp: Date()
        )
    }

    @MainActor
    func sendSnakeControlEnvelope(_ envelope: SnakeControlEnvelope, to peerID: PeerID) {
        guard let payload = SnakeWireCodec.encodeControl(envelope) else { return }
        guard meshService.isPeerConnected(peerID) || meshService.isPeerReachable(peerID) else { return }
        meshService.sendPrivateMessage(
            payload,
            to: peerID,
            recipientNickname: nicknameForPeer(peerID),
            messageID: UUID().uuidString
        )
    }
}
