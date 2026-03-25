import SwiftUI

struct MeshPeerList: View {
    @ObservedObject var viewModel: ChatViewModel
    let textColor: Color
    let secondaryTextColor: Color
    let onTapPeer: (PeerID) -> Void
    let onToggleFavorite: (PeerID) -> Void
    let onShowFingerprint: (PeerID) -> Void
    @Environment(\.colorScheme) var colorScheme

    @State private var orderedIDs: [String] = []

    private enum Strings {
        static let noneNearby: LocalizedStringKey = "geohash_people.none_nearby"
        static let blockedTooltip = String(localized: "geohash_people.tooltip.blocked", comment: "Tooltip shown next to a blocked peer indicator")
        static let newMessagesTooltip = String(localized: "mesh_peers.tooltip.new_messages", comment: "Tooltip for the unread messages indicator")
    }

    var body: some View {
        let myPeerID = viewModel.meshService.myPeerID
        let mapped: [(peer: BitchatPeer, isMe: Bool, hasUnread: Bool, enc: EncryptionStatus)] = viewModel.allPeers.map { peer in
            let isMe = peer.peerID == myPeerID
            let hasUnread = viewModel.hasUnreadMessages(for: peer.peerID)
            let enc = viewModel.getEncryptionStatus(for: peer.peerID)
            return (peer, isMe, hasUnread, enc)
        }

        let currentIDs = mapped.map { $0.peer.peerID.id }
        let displayIDs = orderedIDs.filter { currentIDs.contains($0) } + currentIDs.filter { !orderedIDs.contains($0) }
        let peers: [(peer: BitchatPeer, isMe: Bool, hasUnread: Bool, enc: EncryptionStatus)] = displayIDs.compactMap { id in
            mapped.first(where: { $0.peer.peerID.id == id })
        }

        Group {
            if viewModel.allPeers.isEmpty {
                emptyStateCard
            } else {
                LazyVStack(spacing: 12) {
                    ForEach(Array(peers.enumerated()), id: \.element.peer.peerID.id) { _, item in
                        meshPeerRow(item)
                    }
                }
                .onAppear {
                    orderedIDs = currentIDs
                }
                .onChange(of: mapped.map { $0.peer.peerID.id }) { ids in
                    var newOrder = orderedIDs
                    newOrder.removeAll { !ids.contains($0) }
                    for id in ids where !newOrder.contains(id) {
                        newOrder.append(id)
                    }
                    if newOrder != orderedIDs {
                        orderedIDs = newOrder
                    }
                }
            }
        }
    }

    private var emptyStateCard: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(BitchatTheme.accentSoft(for: colorScheme))
                    .frame(width: 46, height: 46)

                Image(systemName: "person.2.slash")
                    .font(.bitchatSystem(size: 18, weight: .semibold))
                    .foregroundColor(BitchatTheme.accent(for: colorScheme))
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("Nobody nearby yet")
                    .font(.bitchatSystem(size: 17, weight: .semibold, design: .rounded))
                    .foregroundColor(textColor)
                Text(Strings.noneNearby)
                    .font(.bitchatSystem(size: 14))
                    .foregroundColor(secondaryTextColor)
            }

            Spacer(minLength: 0)
        }
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(BitchatTheme.listRowFill(for: colorScheme))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(BitchatTheme.border(for: colorScheme), lineWidth: 1)
        )
    }

    private func meshPeerRow(_ item: (peer: BitchatPeer, isMe: Bool, hasUnread: Bool, enc: EncryptionStatus)) -> some View {
        let peer = item.peer
        let isMe = item.isMe
        let accentColor = BitchatTheme.accent(for: colorScheme)
        let rowTint = meshPeerTint(for: peer, isMe: isMe)
        let titleColor = isMe ? accentColor : textColor
        let statusColor = item.hasUnread ? accentColor : secondaryTextColor
        let displayName = isMe ? viewModel.nickname : peer.displayName
        let (base, suffix) = displayName.splitSuffix()

        return HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(rowTint.opacity(colorScheme == .dark ? 0.18 : 0.12))
                    .frame(width: 46, height: 46)

                Image(systemName: meshPeerIcon(for: peer, isMe: isMe))
                    .font(.bitchatSystem(size: 18, weight: .semibold))
                    .foregroundColor(rowTint)
            }

            VStack(alignment: .leading, spacing: 7) {
                HStack(spacing: 8) {
                    HStack(spacing: 0) {
                        Text(base)
                            .font(.bitchatSystem(size: 17, weight: .semibold, design: .rounded))
                            .foregroundColor(titleColor)
                            .lineLimit(1)
                        if !suffix.isEmpty {
                            Text(suffix)
                                .font(.bitchatSystem(size: 17, weight: .semibold, design: .rounded))
                                .foregroundColor(isMe ? accentColor.opacity(0.7) : secondaryTextColor)
                                .lineLimit(1)
                        }
                    }

                    if isMe {
                        statusBadge(text: "You", tint: accentColor, filled: true)
                    } else if item.hasUnread {
                        statusBadge(text: "New", tint: accentColor, filled: true)
                            .help(Strings.newMessagesTooltip)
                    }
                }

                HStack(spacing: 8) {
                    Text(meshPeerStatusText(peer: peer, isMe: isMe))
                        .font(.bitchatSystem(size: 13, weight: .medium))
                        .foregroundColor(statusColor)
                        .lineLimit(2)

                    if !isMe, let icon = item.enc.icon {
                        Image(systemName: icon)
                            .font(.bitchatSystem(size: 12, weight: .semibold))
                            .foregroundColor(rowTint)
                    }

                    if !isMe, viewModel.isPeerBlocked(peer.peerID) {
                        Image(systemName: "nosign")
                            .font(.bitchatSystem(size: 12, weight: .semibold))
                            .foregroundColor(BitchatTheme.danger(for: colorScheme))
                            .help(Strings.blockedTooltip)
                    }
                }
            }

            Spacer(minLength: 0)

            if !isMe {
                Button(action: { onToggleFavorite(peer.peerID) }) {
                    Image(systemName: (peer.favoriteStatus?.isFavorite ?? false) ? "star.fill" : "star")
                        .font(.bitchatSystem(size: 14, weight: .semibold))
                        .foregroundColor((peer.favoriteStatus?.isFavorite ?? false) ? accentColor : secondaryTextColor)
                        .frame(width: 36, height: 36)
                        .background(
                            Circle()
                                .fill(BitchatTheme.secondarySurface(for: colorScheme))
                        )
                        .overlay(
                            Circle()
                                .stroke(BitchatTheme.border(for: colorScheme), lineWidth: 1)
                        )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(BitchatTheme.listRowFill(for: colorScheme, emphasized: item.hasUnread))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(BitchatTheme.border(for: colorScheme), lineWidth: 1)
        )
        .shadow(color: BitchatTheme.shadow(for: colorScheme).opacity(item.hasUnread ? 0.8 : 0.45), radius: 12, x: 0, y: 6)
        .contentShape(Rectangle())
        .onTapGesture {
            if !isMe {
                onTapPeer(peer.peerID)
            }
        }
        .onTapGesture(count: 2) {
            if !isMe {
                onShowFingerprint(peer.peerID)
            }
        }
    }

    private func statusBadge(text: String, tint: Color, filled: Bool = false) -> some View {
        Text(text)
            .font(.bitchatSystem(size: 12, weight: .semibold))
            .foregroundColor(filled ? BitchatTheme.primaryText(for: colorScheme) : tint)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(
                Capsule(style: .continuous)
                    .fill(filled ? tint.opacity(colorScheme == .dark ? 0.24 : 0.16) : BitchatTheme.secondarySurface(for: colorScheme))
            )
            .overlay(
                Capsule(style: .continuous)
                    .stroke(tint.opacity(colorScheme == .dark ? 0.24 : 0.16), lineWidth: 1)
            )
    }

    private func meshPeerIcon(for peer: BitchatPeer, isMe: Bool) -> String {
        if isMe {
            return "person.fill"
        }

        switch peer.connectionState {
        case .bluetoothConnected:
            return "antenna.radiowaves.left.and.right"
        case .meshReachable:
            return "point.3.filled.connected.trianglepath.dotted"
        case .nostrAvailable:
            return "globe.americas.fill"
        case .offline:
            return "person.crop.circle"
        }
    }

    private func meshPeerTint(for peer: BitchatPeer, isMe: Bool) -> Color {
        if isMe {
            return BitchatTheme.accent(for: colorScheme)
        }

        switch peer.connectionState {
        case .bluetoothConnected:
            return BitchatTheme.meshAccent(for: colorScheme)
        case .meshReachable:
            return BitchatTheme.locationAccent(for: colorScheme)
        case .nostrAvailable:
            return BitchatTheme.accent(for: colorScheme)
        case .offline:
            return secondaryTextColor
        }
    }

    private func meshPeerStatusText(peer: BitchatPeer, isMe: Bool) -> String {
        if isMe {
            return "This is your current device"
        }

        switch peer.connectionState {
        case .bluetoothConnected:
            return "Connected directly nearby"
        case .meshReachable:
            return "Reachable through the mesh"
        case .nostrAvailable:
            return "Available through favorites"
        case .offline:
            return "Not reachable right now"
        }
    }
}
