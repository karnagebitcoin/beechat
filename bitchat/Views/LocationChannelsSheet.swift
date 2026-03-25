import SwiftUI
import CoreLocation
#if os(iOS)
import UIKit
#else
import AppKit
#endif
struct LocationChannelsSheet: View {
    @Binding var isPresented: Bool
    @ObservedObject private var manager = LocationChannelManager.shared
    @ObservedObject private var bookmarks = GeohashBookmarksStore.shared
    @ObservedObject private var network = NetworkActivationService.shared
    @EnvironmentObject var viewModel: ChatViewModel
    @Environment(\.colorScheme) var colorScheme
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @State private var customGeohash: String = ""
    @State private var customError: String? = nil

    private var backgroundColor: Color { colorScheme == .dark ? .black : .white }
    private var surfaceColor: Color { BitchatTheme.surface(for: colorScheme) }
    private var elevatedSurfaceColor: Color { BitchatTheme.elevatedSurface(for: colorScheme) }
    private var secondarySurfaceColor: Color { BitchatTheme.secondarySurface(for: colorScheme) }
    private var textColor: Color { BitchatTheme.primaryText(for: colorScheme) }
    private var secondaryTextColor: Color { BitchatTheme.secondaryText(for: colorScheme) }
    private var borderColor: Color { BitchatTheme.border(for: colorScheme) }
    private var shadowColor: Color { BitchatTheme.shadow(for: colorScheme) }
    private var heroTitle: String { "Choose a chat" }
    private var heroSubtitle: String { "Stay in the nearby Bluetooth chat or switch to a broader local area." }
    private var heroPrivacyText: String { "Approximate area only" }
    private var nearbySectionTitle: String { "Nearby areas" }
    private var teleportSectionTitle: String { "Open a geohash" }
    private var teleportSectionDescription: String { "Paste a code if you want to visit another area." }
    private var settingsSectionTitle: String { "Privacy & routing" }
    private var isCompactPhoneLayout: Bool {
        #if os(iOS)
        horizontalSizeClass == .compact
        #else
        false
        #endif
    }
    private var heroCardPadding: CGFloat { isCompactPhoneLayout ? 16 : 20 }
    private var heroIconSize: CGFloat { isCompactPhoneLayout ? 52 : 58 }
    private var heroIconCornerRadius: CGFloat { isCompactPhoneLayout ? 18 : 20 }
    private var heroIconFontSize: CGFloat { isCompactPhoneLayout ? 22 : 24 }
    private var heroTitleFontSize: CGFloat { isCompactPhoneLayout ? 22 : 28 }
    private var heroSubtitleFontSize: CGFloat { isCompactPhoneLayout ? 13 : 15 }
    private var heroStackSpacing: CGFloat { isCompactPhoneLayout ? 12 : 14 }
    private var heroTextSpacing: CGFloat { isCompactPhoneLayout ? 6 : 8 }
    private var closeButtonSize: CGFloat { isCompactPhoneLayout ? 34 : 38 }
    private var closeButtonFontSize: CGFloat { isCompactPhoneLayout ? 13 : 14 }
    private var rowTitleFontSize: CGFloat { isCompactPhoneLayout ? 16 : 17 }
    private var rowSubtitleFontSize: CGFloat { isCompactPhoneLayout ? 12 : 13 }
    private var badgeFontSize: CGFloat { isCompactPhoneLayout ? 11 : 12 }
    private var badgeHorizontalPadding: CGFloat { isCompactPhoneLayout ? 8 : 10 }
    private var badgeVerticalPadding: CGFloat { isCompactPhoneLayout ? 5 : 6 }
    private var sectionHeaderFontSize: CGFloat { isCompactPhoneLayout ? 12 : 13 }
    private var sheetPadding: CGFloat { isCompactPhoneLayout ? 14 : 16 }

    private var compactSettingsButton: some View {
        Button(action: { openSystemLocationSettings() }) {
            HStack(spacing: 7) {
                Image(systemName: "gearshape.fill")
                    .font(.system(size: isCompactPhoneLayout ? 11 : 12, weight: .semibold))
                Text("Settings")
                    .font(.bitchatSystem(size: isCompactPhoneLayout ? 12 : 13, weight: .semibold))
            }
            .foregroundColor(textColor)
            .padding(.horizontal, isCompactPhoneLayout ? 11 : 13)
            .padding(.vertical, isCompactPhoneLayout ? 8 : 9)
            .background(
                Capsule(style: .continuous)
                    .fill(standardGreen.opacity(colorScheme == .dark ? 0.20 : 0.14))
            )
        }
        .buttonStyle(.plain)
    }

    private var bookmarkedSectionTitle: String {
        String(localized: "location_channels.bookmarked_section_title", comment: "Title for bookmarked geohash channels").localizedCapitalized
    }
    private var meshSubtitleText: String { "Bluetooth mesh • \(bluetoothRangeString())" }

    private enum Strings {
        static let title: LocalizedStringKey = "location_channels.title"
        static let description: LocalizedStringKey = "location_channels.description"
        static let requestPermissions: LocalizedStringKey = "location_channels.action.request_permissions"
        static let permissionDenied: LocalizedStringKey = "location_channels.permission_denied"
        static let openSettings: LocalizedStringKey = "location_channels.action.open_settings"
        static let loadingNearby: LocalizedStringKey = "location_channels.loading_nearby"
        static let teleport: LocalizedStringKey = "location_channels.action.teleport"
        static let bookmarked: LocalizedStringKey = "location_channels.bookmarked_section_title"
        static let removeAccess: LocalizedStringKey = "location_channels.action.remove_access"
        static let torTitle: LocalizedStringKey = "location_channels.tor.title"
        static let torSubtitle: LocalizedStringKey = "location_channels.tor.subtitle"
        static let toggleOn: LocalizedStringKey = "common.toggle.on"
        static let toggleOff: LocalizedStringKey = "common.toggle.off"

        static let invalidGeohash = String(localized: "location_channels.error.invalid_geohash", comment: "Error shown when a custom geohash is invalid")

        static func meshTitle(_ count: Int) -> String {
            let label = String(localized: "location_channels.mesh_label", comment: "Label for the mesh channel row")
            return rowTitle(label: label, count: count)
        }

        static func levelTitle(for level: GeohashChannelLevel, count: Int) -> String {
            // High-precision uncertainty: if count is 0 for high-precision levels,
            // show "?" because presence broadcasting is disabled for privacy.
            let isHighPrecision = (level == .neighborhood || level == .block || level == .building)
            if isHighPrecision && count == 0 {
                return String(
                    format: String(localized: "location_channels.row_title_unknown", defaultValue: "%@ [? people]"),
                    locale: .current,
                    level.displayName
                )
            }
            return rowTitle(label: level.displayName, count: count)
        }

        static func bookmarkTitle(geohash: String, count: Int) -> String {
            // Check precision for bookmarks too
            let len = geohash.count
            // Neighborhood=6, Block=7, Building=8+
            let isHighPrecision = (len >= 6)
            if isHighPrecision && count == 0 {
                return String(
                    format: String(localized: "location_channels.row_title_unknown", defaultValue: "%@ [? people]"),
                    locale: .current,
                    "#\(geohash)"
                )
            }
            return rowTitle(label: "#\(geohash)", count: count)
        }

        static func subtitlePrefix(geohash: String, coverage: String) -> String {
            String(
                format: String(localized: "location_channels.subtitle_prefix", comment: "Subtitle prefix showing geohash and coverage"),
                locale: .current,
                geohash, coverage
            )
        }

        static func subtitle(prefix: String, name: String?) -> String {
            guard let name, !name.isEmpty else { return prefix }
            return String(
                format: String(localized: "location_channels.subtitle_with_name", comment: "Subtitle combining prefix and resolved location name"),
                locale: .current,
                prefix, name
            )
        }

        private static func rowTitle(label: String, count: Int) -> String {
            String(
                format: String(localized: "location_channels.row_title", comment: "List row title with participant count"),
                locale: .current,
                label, count
            )
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 16) {
                HStack(alignment: .top, spacing: heroStackSpacing) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .fill(standardGreen.opacity(colorScheme == .dark ? 0.18 : 0.12))
                            .frame(width: heroIconSize, height: heroIconSize)

                        Image(systemName: "location.circle.fill")
                            .font(.bitchatSystem(size: heroIconFontSize, weight: .semibold))
                            .foregroundColor(standardGreen)
                    }
                    .clipShape(
                        RoundedRectangle(cornerRadius: heroIconCornerRadius, style: .continuous)
                    )

                    VStack(alignment: .leading, spacing: heroTextSpacing) {
                        Text(heroTitle)
                            .font(.bitchatSystem(size: heroTitleFontSize, weight: .bold, design: .rounded))
                            .foregroundColor(textColor)
                            .lineLimit(2)
                            .minimumScaleFactor(0.85)
                            .layoutPriority(1)
                        Text(heroSubtitle)
                            .font(.bitchatSystem(size: heroSubtitleFontSize))
                            .foregroundColor(secondaryTextColor)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    Spacer(minLength: 0)
                    closeButton
                }

                ViewThatFits(in: .horizontal) {
                    HStack(spacing: 8) {
                        sheetBadge(icon: "lock.fill", text: heroPrivacyText, tint: standardGreen, filled: true)
                        sheetBadge(icon: "globe", text: "Traffic routes over Tor", tint: secondaryTextColor)
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        sheetBadge(icon: "lock.fill", text: heroPrivacyText, tint: standardGreen, filled: true)
                        sheetBadge(icon: "globe", text: "Traffic routes over Tor", tint: secondaryTextColor)
                    }
                }
            }
            .padding(heroCardPadding)
            .background(
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .fill(elevatedSurfaceColor)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .stroke(borderColor, lineWidth: 1)
            )
            .shadow(color: shadowColor, radius: 18, x: 0, y: 8)

            permissionSection

            channelList
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .padding(.horizontal, sheetPadding)
        .padding(.vertical, sheetPadding)
        #if os(macOS)
        .frame(minWidth: 520, idealWidth: 680, minHeight: 520, idealHeight: 720)
        #endif
        .background(backgroundColor)
        .onAppear {
            // Refresh channels when opening
            if manager.permissionState == LocationChannelManager.PermissionState.authorized {
                manager.refreshChannels()
            }
            // Begin periodic refresh while sheet is open
            manager.beginLiveRefresh()
            // Geohash sampling is now managed by ChatViewModel globally
        }
        .onDisappear {
            manager.endLiveRefresh()
        }
        .onChange(of: manager.permissionState) { newValue in
            if newValue == LocationChannelManager.PermissionState.authorized {
                manager.refreshChannels()
            }
        }
        .onChange(of: manager.availableChannels) { _ in }
    }

    private var closeButton: some View {
        Button(action: { isPresented = false }) {
            Image(systemName: "xmark")
                .font(.bitchatSystem(size: closeButtonFontSize, weight: .semibold))
                .foregroundColor(textColor)
                .frame(width: closeButtonSize, height: closeButtonSize)
                .background(
                    Circle()
                        .fill(secondarySurfaceColor)
                )
                .overlay(
                    Circle()
                        .stroke(borderColor, lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Close")
    }

    @ViewBuilder
    private var permissionSection: some View {
        switch manager.permissionState {
        case LocationChannelManager.PermissionState.notDetermined:
            VStack(alignment: .leading, spacing: 12) {
                sectionHeader("Enable local chats")
                Text(Strings.description)
                    .font(.bitchatSystem(size: 14))
                    .foregroundColor(secondaryTextColor)
                    .fixedSize(horizontal: false, vertical: true)
                Button(action: { manager.enableLocationChannels() }) {
                    Text(Strings.requestPermissions)
                        .font(.bitchatSystem(size: 14, weight: .semibold))
                        .foregroundColor(textColor)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .fill(standardGreen.opacity(colorScheme == .dark ? 0.20 : 0.14))
                        )
                }
                .buttonStyle(.plain)
            }
            .padding(18)
            .background(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(elevatedSurfaceColor)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .stroke(borderColor, lineWidth: 1)
            )
        case LocationChannelManager.PermissionState.denied, LocationChannelManager.PermissionState.restricted:
            ViewThatFits(in: .horizontal) {
                HStack(alignment: .center, spacing: 14) {
                    ZStack {
                        Circle()
                            .fill(standardGreen.opacity(colorScheme == .dark ? 0.16 : 0.12))
                            .frame(width: 42, height: 42)

                        Image(systemName: "location.slash")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundColor(standardGreen)
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Location access is off")
                            .font(.bitchatSystem(size: 16, weight: .semibold))
                            .foregroundColor(textColor)
                            .lineLimit(1)

                        Text("Turn it on in Settings to unlock nearby chats.")
                            .font(.bitchatSystem(size: 14))
                            .foregroundColor(secondaryTextColor)
                            .lineLimit(2)
                    }

                    Spacer(minLength: 12)

                    compactSettingsButton
                }
                .padding(16)

                VStack(alignment: .leading, spacing: 12) {
                    HStack(spacing: 12) {
                        ZStack {
                            Circle()
                                .fill(standardGreen.opacity(colorScheme == .dark ? 0.16 : 0.12))
                                .frame(width: 40, height: 40)

                            Image(systemName: "location.slash")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(standardGreen)
                        }

                        VStack(alignment: .leading, spacing: 4) {
                            Text("Location access is off")
                                .font(.bitchatSystem(size: 16, weight: .semibold))
                                .foregroundColor(textColor)

                            Text("Turn it on in Settings to unlock nearby chats.")
                                .font(.bitchatSystem(size: 14))
                                .foregroundColor(secondaryTextColor)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }

                    HStack {
                        Spacer(minLength: 0)
                        compactSettingsButton
                    }
                }
                .padding(16)
            }
            .background(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(elevatedSurfaceColor)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .stroke(borderColor, lineWidth: 1)
            )
        case LocationChannelManager.PermissionState.authorized:
            EmptyView()
        }
    }

    private var channelList: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 16) {
                channelRow(
                    iconName: "antenna.radiowaves.left.and.right",
                    iconTint: standardBlue,
                    title: Strings.meshTitle(meshCount()),
                    subtitlePrefix: meshSubtitleText,
                    isSelected: isMeshSelected,
                    titleColor: textColor,
                    titleBold: true
                ) {
                    manager.select(ChannelID.mesh)
                    isPresented = false
                }

                let nearby = manager.availableChannels.filter { $0.level != .building }
                sectionHeader(nearbySectionTitle)
                if !nearby.isEmpty {
                    ForEach(nearby) { channel in
                        let coverage = coverageString(forPrecision: channel.geohash.count)
                        let nameBase = locationName(for: channel.level)
                        let namePart = nameBase.map { formattedNamePrefix(for: channel.level) + $0 }
                        let participantCount = viewModel.geohashParticipantCount(for: channel.geohash)
                        let subtitlePrefix = Strings.subtitlePrefix(geohash: channel.geohash, coverage: coverage)
                        let highlight = participantCount > 0
                        channelRow(
                            iconName: iconName(for: channel.level),
                            iconTint: highlight ? standardGreen : BitchatTheme.locationAccent(for: colorScheme),
                            title: Strings.levelTitle(for: channel.level, count: participantCount),
                            subtitlePrefix: subtitlePrefix,
                            subtitleName: namePart,
                            isSelected: isSelected(channel),
                            titleColor: textColor,
                            titleBold: highlight,
                            trailingAccessory: {
                                Button(action: { bookmarks.toggle(channel.geohash) }) {
                                    Image(systemName: bookmarks.isBookmarked(channel.geohash) ? "bookmark.fill" : "bookmark")
                                        .font(.bitchatSystem(size: 14, weight: .semibold))
                                        .foregroundColor(bookmarks.isBookmarked(channel.geohash) ? standardGreen : secondaryTextColor)
                                        .frame(width: 34, height: 34)
                                        .background(
                                            Circle()
                                                .fill(secondarySurfaceColor)
                                        )
                                        .overlay(
                                            Circle()
                                                .stroke(borderColor, lineWidth: 1)
                                        )
                                }
                                .buttonStyle(.plain)
                            }
                        ) {
                            manager.markTeleported(for: channel.geohash, false)
                            manager.select(ChannelID.location(channel))
                            isPresented = false
                        }
                    }
                } else {
                    HStack(spacing: 12) {
                        ProgressView()
                            .tint(standardGreen)
                        Text(Strings.loadingNearby)
                            .font(.bitchatSystem(size: 14, weight: .medium))
                            .foregroundColor(secondaryTextColor)
                    }
                    .padding(18)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(
                        RoundedRectangle(cornerRadius: 22, style: .continuous)
                            .fill(elevatedSurfaceColor)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 22, style: .continuous)
                            .stroke(borderColor, lineWidth: 1)
                    )
                }

                customTeleportSection

                let bookmarkedList = bookmarks.bookmarks
                if !bookmarkedList.isEmpty {
                    bookmarkedSection(bookmarkedList)
                }

                if manager.permissionState == LocationChannelManager.PermissionState.authorized {
                    sectionHeader(settingsSectionTitle)
                    torToggleSection
                    Button(action: {
                        openSystemLocationSettings()
                    }) {
                        Text(Strings.removeAccess)
                            .font(.bitchatSystem(size: 14, weight: .semibold))
                            .foregroundColor(BitchatTheme.danger(for: colorScheme))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(
                                RoundedRectangle(cornerRadius: 16, style: .continuous)
                                    .fill(BitchatTheme.dangerSoft(for: colorScheme))
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, 6)
            .background(backgroundColor)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(backgroundColor)
    }

    private var customTeleportSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader(teleportSectionTitle)
            Text(teleportSectionDescription)
                .font(.bitchatSystem(size: 14))
                .foregroundColor(secondaryTextColor)

            let normalized = customGeohash
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .lowercased()
                .replacingOccurrences(of: "#", with: "")
            let isValid = validateGeohash(normalized)

            HStack(spacing: 10) {
                HStack(spacing: 10) {
                    Image(systemName: "number")
                        .font(.bitchatSystem(size: 14, weight: .semibold))
                        .foregroundColor(secondaryTextColor)

                    TextField("Enter geohash", text: $customGeohash)
                        #if os(iOS)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled(true)
                        .keyboardType(.asciiCapable)
                        #endif
                        .font(.bitchatSystem(size: 15, weight: .medium))
                        .foregroundColor(textColor)
                        .onChange(of: customGeohash) { newValue in
                            let allowed = Set("0123456789bcdefghjkmnpqrstuvwxyz")
                            let filtered = newValue
                                .lowercased()
                                .replacingOccurrences(of: "#", with: "")
                                .filter { allowed.contains($0) }
                            if filtered.count > 12 {
                                customGeohash = String(filtered.prefix(12))
                            } else if filtered != newValue {
                                customGeohash = filtered
                            }
                        }
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(secondarySurfaceColor)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(borderColor, lineWidth: 1)
                )

                Button(action: {
                    let gh = normalized
                    guard isValid else { customError = Strings.invalidGeohash; return }
                    let level = levelForLength(gh.count)
                    let ch = GeohashChannel(level: level, geohash: gh)
                    manager.markTeleported(for: ch.geohash, true)
                    manager.select(ChannelID.location(ch))
                    isPresented = false
                }) {
                    HStack(spacing: 8) {
                        Image(systemName: "arrow.up.right")
                            .font(.bitchatSystem(size: 13, weight: .semibold))
                        Text(Strings.teleport)
                            .font(.bitchatSystem(size: 14, weight: .semibold))
                    }
                    .foregroundColor(textColor)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .fill(standardGreen.opacity(colorScheme == .dark ? 0.20 : 0.14))
                    )
                }
                .buttonStyle(.plain)
                .opacity(isValid ? 1.0 : 0.45)
                .disabled(!isValid)
            }

            if let err = customError {
                Text(err)
                    .font(.bitchatSystem(size: 13, weight: .medium))
                    .foregroundColor(BitchatTheme.danger(for: colorScheme))
            }
        }
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(elevatedSurfaceColor)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(borderColor, lineWidth: 1)
        )
    }

    private func bookmarkedSection(_ entries: [String]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader(bookmarkedSectionTitle)
            LazyVStack(spacing: 12) {
                ForEach(entries, id: \.self) { gh in
                    let level = levelForLength(gh.count)
                    let channel = GeohashChannel(level: level, geohash: gh)
                    let coverage = coverageString(forPrecision: gh.count)
                    let subtitle = Strings.subtitlePrefix(geohash: gh, coverage: coverage)
                    let name = bookmarks.bookmarkNames[gh]
                    let participantCount = viewModel.geohashParticipantCount(for: gh)
                    channelRow(
                        iconName: "bookmark.fill",
                        iconTint: standardGreen,
                        title: Strings.bookmarkTitle(geohash: gh, count: participantCount),
                        subtitlePrefix: subtitle,
                        subtitleName: name.map { formattedNamePrefix(for: level) + $0 },
                        isSelected: isSelected(channel),
                        titleColor: textColor,
                        trailingAccessory: {
                            Button(action: { bookmarks.toggle(gh) }) {
                                Image(systemName: bookmarks.isBookmarked(gh) ? "bookmark.fill" : "bookmark")
                                    .font(.bitchatSystem(size: 14, weight: .semibold))
                                    .foregroundColor(bookmarks.isBookmarked(gh) ? standardGreen : secondaryTextColor)
                                    .frame(width: 34, height: 34)
                                    .background(
                                        Circle()
                                            .fill(secondarySurfaceColor)
                                    )
                                    .overlay(
                                        Circle()
                                            .stroke(borderColor, lineWidth: 1)
                                    )
                            }
                            .buttonStyle(.plain)
                        }
                    ) {
                        let inRegional = manager.availableChannels.contains { $0.geohash == gh }
                        if !inRegional && !manager.availableChannels.isEmpty {
                            manager.markTeleported(for: gh, true)
                        } else {
                            manager.markTeleported(for: gh, false)
                        }
                        manager.select(ChannelID.location(channel))
                        isPresented = false
                    }
                    .onAppear { bookmarks.resolveBookmarkNameIfNeeded(for: gh) }
                }
            }
        }
    }


    private func isSelected(_ channel: GeohashChannel) -> Bool {
        if case .location(let ch) = manager.selectedChannel {
            return ch == channel
        }
        return false
    }

    private var isMeshSelected: Bool {
        if case .mesh = manager.selectedChannel { return true }
        return false
    }

    @ViewBuilder
    private func channelRow(
        iconName: String,
        iconTint: Color,
        title: String,
        subtitlePrefix: String,
        subtitleName: String? = nil,
        subtitleNameBold: Bool = false,
        isSelected: Bool,
        titleColor: Color? = nil,
        titleBold: Bool = false,
        @ViewBuilder trailingAccessory: () -> some View = { EmptyView() },
        action: @escaping () -> Void
    ) -> some View {
        let parts = splitTitleAndCount(title)
        let subtitleFull = Strings.subtitle(prefix: subtitlePrefix, name: subtitleName)

        HStack(alignment: .center, spacing: 14) {
            ZStack {
                Circle()
                    .fill(iconTint.opacity(colorScheme == .dark ? 0.18 : 0.12))
                    .frame(width: 44, height: 44)

                Image(systemName: iconName)
                    .font(.bitchatSystem(size: 18, weight: .semibold))
                    .foregroundColor(iconTint)
            }

            VStack(alignment: .leading, spacing: 7) {
                HStack(spacing: 8) {
                    Text(parts.base)
                        .font(.bitchatSystem(size: rowTitleFontSize, weight: titleBold ? .bold : .semibold, design: .rounded))
                        .foregroundColor(titleColor ?? textColor)
                        .lineLimit(1)

                    if let count = parts.countSuffix, !count.isEmpty {
                        sheetBadge(text: count.trimmingCharacters(in: CharacterSet(charactersIn: "[]")), tint: titleBold ? standardGreen : secondaryTextColor)
                    }
                }

                Text(subtitleFull)
                    .font(.bitchatSystem(size: rowSubtitleFontSize, weight: subtitleNameBold ? .semibold : .medium))
                    .foregroundColor(secondaryTextColor)
                    .lineLimit(2)
                    .truncationMode(.tail)
            }

            Spacer()

            if isSelected {
                Image(systemName: "checkmark.circle.fill")
                    .font(.bitchatSystem(size: 20, weight: .semibold))
                    .foregroundColor(standardGreen)
            }

            trailingAccessory()
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(elevatedSurfaceColor)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(borderColor, lineWidth: 1)
        )
        .shadow(color: shadowColor.opacity(isSelected ? 0.75 : 0.45), radius: 12, x: 0, y: 6)
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
        .onTapGesture(perform: action)
    }

    private func sheetBadge(icon: String? = nil, text: String, tint: Color, filled: Bool = false) -> some View {
        HStack(spacing: 6) {
            if let icon {
                Image(systemName: icon)
                    .font(.bitchatSystem(size: badgeFontSize, weight: .semibold))
            }
            Text(text)
                .font(.bitchatSystem(size: badgeFontSize, weight: .semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.85)
        }
        .foregroundColor(filled ? textColor : tint)
        .padding(.horizontal, badgeHorizontalPadding)
        .padding(.vertical, badgeVerticalPadding)
        .background(
            Capsule(style: .continuous)
                .fill(filled ? tint.opacity(colorScheme == .dark ? 0.22 : 0.14) : secondarySurfaceColor)
        )
        .overlay(
            Capsule(style: .continuous)
                .stroke((filled ? tint : borderColor).opacity(colorScheme == .dark ? 0.32 : 0.24), lineWidth: 1)
        )
    }

    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.bitchatSystem(size: sectionHeaderFontSize, weight: .semibold))
            .foregroundColor(secondaryTextColor)
    }

    private func iconName(for level: GeohashChannelLevel) -> String {
        switch level {
        case .region:
            return "globe.americas.fill"
        case .province:
            return "map.fill"
        case .city:
            return "building.2.fill"
        case .neighborhood:
            return "mappin.and.ellipse"
        case .block:
            return "square.grid.3x3.fill"
        case .building:
            return "house.fill"
        }
    }

    // Split a title like "#mesh [3 people]" into base and suffix "[3 people]"
    private func splitTitleAndCount(_ s: String) -> (base: String, countSuffix: String?) {
        guard let idx = s.lastIndex(of: "[") else { return (s, nil) }
        let prefix = String(s[..<idx]).trimmingCharacters(in: .whitespaces)
        let suffix = String(s[idx...])
        return (prefix, suffix)
    }

    // MARK: - Helpers for counts
    private func meshCount() -> Int {
        // Count mesh-connected OR mesh-reachable peers (exclude self)
        let myID = viewModel.meshService.myPeerID
        return viewModel.allPeers.reduce(0) { acc, peer in
            if peer.peerID != myID && (peer.isConnected || peer.isReachable) { return acc + 1 }
            return acc
        }
    }

    private func validateGeohash(_ s: String) -> Bool {
        let allowed = Set("0123456789bcdefghjkmnpqrstuvwxyz")
        guard !s.isEmpty, s.count <= 12 else { return false }
        return s.allSatisfy { allowed.contains($0) }
    }

    private func levelForLength(_ len: Int) -> GeohashChannelLevel {
        switch len {
        case 0...2: return .region
        case 3...4: return .province
        case 5: return .city
        case 6: return .neighborhood
        case 7: return .block
        case 8: return .building
        default: return .block
        }
    }
}

// MARK: - TOR Toggle & Standardized Colors
extension LocationChannelsSheet {
    private var torToggleBinding: Binding<Bool> {
        Binding(
            get: { network.userTorEnabled },
            set: { network.setUserTorEnabled($0) }
        )
    }

    private var torToggleSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Toggle(isOn: torToggleBinding) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(Strings.torTitle)
                        .font(.bitchatSystem(size: 15, weight: .semibold, design: .rounded))
                        .foregroundColor(textColor)
                    Text(Strings.torSubtitle)
                        .font(.bitchatSystem(size: 13))
                        .foregroundColor(secondaryTextColor)
                }
            }
            .toggleStyle(IRCToggleStyle(accent: standardGreen, onLabel: Strings.toggleOn, offLabel: Strings.toggleOff))
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(elevatedSurfaceColor)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(borderColor, lineWidth: 1)
        )
    }

    private var standardGreen: Color {
        BitchatTheme.accent(for: colorScheme)
    }
    private var standardBlue: Color {
        BitchatTheme.meshAccent(for: colorScheme)
    }
}

private struct IRCToggleStyle: ToggleStyle {
    let accent: Color
    let onLabel: LocalizedStringKey
    let offLabel: LocalizedStringKey

    func makeBody(configuration: Configuration) -> some View {
        Button(action: { configuration.isOn.toggle() }) {
            HStack(spacing: 12) {
                configuration.label
                Spacer()
                Text(configuration.isOn ? onLabel : offLabel)
                    .textCase(.uppercase)
                    .font(.bitchatSystem(size: 12, weight: .semibold, design: .monospaced))
                    .foregroundColor(configuration.isOn ? accent : .secondary)
                    .padding(.vertical, 4)
                    .padding(.horizontal, 10)
                    .background(
                        RoundedRectangle(cornerRadius: 6)
                            .fill(accent.opacity(configuration.isOn ? 0.18 : 0.08))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(accent.opacity(configuration.isOn ? 0.35 : 0.15), lineWidth: 1)
                    )
            }
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Coverage helpers
extension LocationChannelsSheet {
    private func coverageString(forPrecision len: Int) -> String {
        // Approximate max cell dimension at equator for a given geohash length.
        // Values sourced from common geohash dimension tables.
        let maxMeters: Double = {
            switch len {
            case 2: return 1_250_000
            case 3: return 156_000
            case 4: return 39_100
            case 5: return 4_890
            case 6: return 1_220
            case 7: return 153
            case 8: return 38.2
            case 9: return 4.77
            case 10: return 1.19
            default:
                if len <= 1 { return 5_000_000 }
                // For >10, scale down conservatively by ~1/4 each char
                let over = len - 10
                return 1.19 * pow(0.25, Double(over))
            }
        }()

        let usesMetric: Bool = {
            if #available(iOS 16.0, macOS 13.0, *) {
                return Locale.current.measurementSystem == .metric
            } else {
                return Locale.current.usesMetricSystem
            }
        }()
        if usesMetric {
            let km = maxMeters / 1000.0
            return "~\(formatDistance(km)) km"
        } else {
            let miles = maxMeters / 1609.344
            return "~\(formatDistance(miles)) mi"
        }
    }

    private func formatDistance(_ value: Double) -> String {
        if value >= 100 { return String(format: "%.0f", value.rounded()) }
        if value >= 10 { return String(format: "%.1f", value) }
        return String(format: "%.1f", value)
    }

    private func bluetoothRangeString() -> String {
        let usesMetric: Bool = {
            if #available(iOS 16.0, macOS 13.0, *) {
                return Locale.current.measurementSystem == .metric
            } else {
                return Locale.current.usesMetricSystem
            }
        }()
        // Approximate Bluetooth LE range for typical mobile devices; environment dependent
        return usesMetric ? "~10–50 m" : "~30–160 ft"
    }

    private func locationName(for level: GeohashChannelLevel) -> String? {
        manager.locationNames[level]
    }

    private func formattedNamePrefix(for level: GeohashChannelLevel) -> String {
        switch level {
        case .region:
            return ""
        case .building, .block, .neighborhood, .city, .province:
            return "~"
        }
    }
}

// MARK: - Open Settings helper
private func openSystemLocationSettings() {
    #if os(iOS)
    if let url = URL(string: UIApplication.openSettingsURLString) {
        UIApplication.shared.open(url)
    }
    #else
    if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_LocationServices") {
        NSWorkspace.shared.open(url)
    } else if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security") {
        NSWorkspace.shared.open(url)
    }
    #endif
}
