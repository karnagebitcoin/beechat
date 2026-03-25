import SwiftUI

struct SnakeInviteCardView: View {
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject private var viewModel: ChatViewModel

    let session: SnakeSession

    var body: some View {
        HStack(alignment: .center, spacing: 10) {
            ZStack {
                Circle()
                    .fill(BitchatTheme.accentSoft(for: colorScheme))
                    .frame(width: 28, height: 28)

                Image(systemName: "apple.terminal")
                    .font(.bitchatSystem(size: 13, weight: .semibold))
                    .foregroundStyle(BitchatTheme.accent(for: colorScheme))
            }

            Text(summary)
                .font(.bitchatSystem(size: 14, weight: .medium))
                .foregroundStyle(BitchatTheme.primaryText(for: colorScheme))
                .frame(maxWidth: .infinity, alignment: .leading)

            if let action = primaryAction {
                Button(action.title) {
                    action.handler()
                }
                .buttonStyle(.plain)
                .font(.bitchatSystem(size: 13, weight: .semibold))
                .foregroundStyle(BitchatTheme.accent(for: colorScheme))
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(BitchatTheme.secondarySurface(for: colorScheme))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(BitchatTheme.border(for: colorScheme).opacity(0.7), lineWidth: 1)
        )
        .padding(.vertical, 2)
    }
}

private extension SnakeInviteCardView {
    struct InlineAction {
        let title: String
        let handler: () -> Void
    }

    var localPeerID: PeerID {
        viewModel.meshService.myPeerID
    }

    var isHost: Bool {
        session.host.peerID == localPeerID
    }

    var isParticipant: Bool {
        session.contains(localPeerID)
    }

    var summary: String {
        if session.isExpired() {
            return "\(session.host.nickname)'s Snake Arena expired"
        }

        switch session.status {
        case .waiting:
            return "\(session.host.nickname) opened Snake Arena • \(session.players.count)/\(SnakeSession.maxPlayers)"
        case .running:
            return "Snake Arena live • \(session.players.count) players"
        case .finished:
            if let winnerName = session.winnerName {
                return "\(winnerName) won Snake Arena"
            }
            return "Snake Arena finished"
        }
    }

    var primaryAction: InlineAction? {
        if session.isExpired() { return nil }

        switch session.status {
        case .waiting:
            if isHost {
                if session.players.count >= SnakeSession.minimumPlayers {
                    return InlineAction(title: "Start") {
                        viewModel.startSnakeSession(sessionID: session.id)
                    }
                }
                return InlineAction(title: "Cancel") {
                    viewModel.cancelSnakeInvite(sessionID: session.id)
                }
            }

            if !isParticipant && !session.isFull {
                return InlineAction(title: "Join") {
                    viewModel.joinSnakeSession(sessionID: session.id)
                }
            }

            return nil
        case .running:
            if isParticipant {
                return InlineAction(title: "Open") {
                    viewModel.openSnakeSession(sessionID: session.id)
                }
            }
            return nil
        case .finished:
            return nil
        }
    }
}
