import SwiftUI

struct GeohashPeopleList: View {
    @ObservedObject var viewModel: ChatViewModel
    let textColor: Color
    let secondaryTextColor: Color
    let onTapPerson: () -> Void
    @Environment(\.colorScheme) var colorScheme
    @State private var orderedIDs: [String] = []

    private enum Strings {
        static let noneNearby: LocalizedStringKey = "geohash_people.none_nearby"
        static let youSuffix: LocalizedStringKey = "geohash_people.you_suffix"
        static let blockedTooltip = String(localized: "geohash_people.tooltip.blocked", comment: "Tooltip shown next to users blocked in geohash channels")
        static let unblock: LocalizedStringKey = "geohash_people.action.unblock"
        static let block: LocalizedStringKey = "geohash_people.action.block"
    }

    var body: some View {
        if viewModel.visibleGeohashPeople().isEmpty {
            emptyStateCard
        } else {
            let myHex: String? = {
                if case .location(let ch) = LocationChannelManager.shared.selectedChannel,
                   let id = try? viewModel.idBridge.deriveIdentity(forGeohash: ch.geohash) {
                    return id.publicKeyHex.lowercased()
                }
                return nil
            }()
            let people = viewModel.visibleGeohashPeople()
            let currentIDs = people.map { $0.id }

            let teleportedSet = Set(viewModel.teleportedGeo.map { $0.lowercased() })
            let isTeleportedID: (String) -> Bool = { id in
                if teleportedSet.contains(id.lowercased()) { return true }
                if let me = myHex, id == me, LocationChannelManager.shared.teleported { return true }
                return false
            }

            let displayIDs = orderedIDs.filter { currentIDs.contains($0) } + currentIDs.filter { !orderedIDs.contains($0) }
            let nonTele = displayIDs.filter { !isTeleportedID($0) }
            let tele = displayIDs.filter { isTeleportedID($0) }
            let finalOrder: [String] = nonTele + tele
            let personByID = Dictionary(uniqueKeysWithValues: people.map { ($0.id, $0) })

            LazyVStack(spacing: 12) {
                ForEach(finalOrder.filter { personByID[$0] != nil }, id: \.self) { pid in
                    let person = personByID[pid]!
                    geohashPersonRow(person: person, myHex: myHex)
                }
            }
            .onAppear {
                orderedIDs = currentIDs
            }
            .onChange(of: currentIDs) { ids in
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

    private var emptyStateCard: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(BitchatTheme.accentSoft(for: colorScheme))
                    .frame(width: 46, height: 46)

                Image(systemName: "person.crop.circle.badge.questionmark")
                    .font(.bitchatSystem(size: 18, weight: .semibold))
                    .foregroundColor(BitchatTheme.accent(for: colorScheme))
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("No one in this area yet")
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

    private func geohashPersonRow(person: GeoPerson, myHex: String?) -> some View {
        let isMe = (person.id == myHex)
        let teleported = viewModel.teleportedGeo.contains(person.id.lowercased()) || (isMe && LocationChannelManager.shared.teleported)
        let accentColor = BitchatTheme.accent(for: colorScheme)
        let rowTint = teleported ? BitchatTheme.locationAccent(for: colorScheme) : BitchatTheme.meshAccent(for: colorScheme)
        let titleColor = isMe ? accentColor : textColor
        let (base, suffix) = person.displayName.splitSuffix()
        let blocked = myHex != nil && person.id != myHex && viewModel.isGeohashUserBlocked(pubkeyHexLowercased: person.id)

        return HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(rowTint.opacity(colorScheme == .dark ? 0.18 : 0.12))
                    .frame(width: 46, height: 46)

                Image(systemName: teleported ? "face.dashed.fill" : "mappin.circle.fill")
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
                        statusBadge(text: youBadgeText, tint: accentColor, filled: true)
                    } else if teleported {
                        statusBadge(text: "Custom area", tint: rowTint)
                    }
                }

                HStack(spacing: 8) {
                    Text(geohashPersonStatusText(isMe: isMe, teleported: teleported))
                        .font(.bitchatSystem(size: 13, weight: .medium))
                        .foregroundColor(secondaryTextColor)
                        .lineLimit(2)

                    if blocked {
                        Image(systemName: "nosign")
                            .font(.bitchatSystem(size: 12, weight: .semibold))
                            .foregroundColor(BitchatTheme.danger(for: colorScheme))
                            .help(Strings.blockedTooltip)
                    }
                }
            }

            Spacer(minLength: 0)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(BitchatTheme.listRowFill(for: colorScheme))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(BitchatTheme.border(for: colorScheme), lineWidth: 1)
        )
        .shadow(color: BitchatTheme.shadow(for: colorScheme).opacity(0.45), radius: 12, x: 0, y: 6)
        .contentShape(Rectangle())
        .onTapGesture {
            if person.id != myHex {
                viewModel.startGeohashDM(withPubkeyHex: person.id)
                onTapPerson()
            }
        }
        .contextMenu {
            if let me = myHex, person.id == me {
                EmptyView()
            } else {
                if viewModel.isGeohashUserBlocked(pubkeyHexLowercased: person.id) {
                    Button(Strings.unblock) {
                        viewModel.unblockGeohashUser(pubkeyHexLowercased: person.id, displayName: person.displayName)
                    }
                } else {
                    Button(Strings.block) {
                        viewModel.blockGeohashUser(pubkeyHexLowercased: person.id, displayName: person.displayName)
                    }
                }
            }
        }
    }

    private var youBadgeText: String {
        String(localized: "geohash_people.you_suffix", comment: "Suffix used to identify the current user in geohash people lists")
            .trimmingCharacters(in: CharacterSet(charactersIn: " ()"))
            .localizedCapitalized
    }

    private func geohashPersonStatusText(isMe: Bool, teleported: Bool) -> String {
        if isMe {
            return teleported ? "You jumped into this area" : "You are chatting from this area"
        }

        return teleported ? "Sharing from a custom area" : "Tap to start a local direct message"
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
}
