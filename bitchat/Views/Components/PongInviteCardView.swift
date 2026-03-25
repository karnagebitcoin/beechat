import SwiftUI

struct PongInviteCardView: View {
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject private var viewModel: ChatViewModel

    let session: PongSession

    var body: some View {
        HStack(alignment: .center, spacing: 10) {
            ZStack {
                Circle()
                    .fill(BitchatTheme.accentSoft(for: colorScheme))
                    .frame(width: 28, height: 28)

                Image(systemName: "gamecontroller.fill")
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

private extension PongInviteCardView {
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
            return "\(session.host.nickname)'s pong invite expired"
        }

        switch session.status {
        case .waiting:
            return "\(session.host.nickname) opened a Pong match"
        case .ready:
            if let guest = session.guest {
                return "\(session.host.nickname) vs \(guest.nickname) starting..."
            }
            return "\(session.host.nickname) is starting Pong"
        case .running:
            if let guest = session.guest {
                return "\(session.host.nickname) vs \(guest.nickname) • \(session.hostScore)-\(session.guestScore)"
            }
            return "\(session.host.nickname) is playing Pong"
        case .finished:
            if let guest = session.guest, let winner = session.winnerName {
                return "\(winner) won Pong against \(winner == session.host.nickname ? guest.nickname : session.host.nickname)"
            }
            return "Pong match finished"
        }
    }

    var primaryAction: InlineAction? {
        if session.isExpired() { return nil }

        switch session.status {
        case .waiting:
            if isHost && session.guest == nil {
                return InlineAction(title: "Cancel") {
                    viewModel.cancelPongInvite(sessionID: session.id)
                }
            }
            if !isParticipant && session.guest == nil {
                return InlineAction(title: "Join") {
                    viewModel.joinPongSession(sessionID: session.id)
                }
            }
            return nil
        case .ready, .running:
            if isParticipant {
                return InlineAction(title: "Open") {
                    viewModel.openPongSession(sessionID: session.id)
                }
            }
            return nil
        case .finished:
            return nil
        }
    }
}
