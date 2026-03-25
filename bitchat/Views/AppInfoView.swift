import SwiftUI

struct AppInfoView: View {
    @Environment(\.dismiss) var dismiss
    @Environment(\.colorScheme) var colorScheme
    @AppStorage(BitchatTheme.selectedPaletteKey) private var selectedPaletteRawValue = BitchatPalette.sky.rawValue
    @State private var showThemePicker = false

    private var elevatedSurfaceColor: Color {
        BitchatTheme.elevatedSurface(for: colorScheme)
    }

    private var secondarySurfaceColor: Color {
        BitchatTheme.secondarySurface(for: colorScheme)
    }

    private var textColor: Color {
        BitchatTheme.primaryText(for: colorScheme)
    }

    private var secondaryTextColor: Color {
        BitchatTheme.secondaryText(for: colorScheme)
    }

    private var borderColor: Color {
        BitchatTheme.border(for: colorScheme)
    }

    private var accentColor: Color {
        BitchatTheme.accent(for: colorScheme)
    }

    private var shadowColor: Color {
        BitchatTheme.shadow(for: colorScheme)
    }

    private var selectedPalette: BitchatPalette {
        BitchatPalette(rawValue: selectedPaletteRawValue) ?? .sky
    }

    private var closeButtonFill: Color {
        secondarySurfaceColor
    }

    private var closeButtonBorder: Color {
        borderColor
    }

    // MARK: - Constants
    private enum Strings {
        static let appName: LocalizedStringKey = "app_info.app_name"
        static let tagline: LocalizedStringKey = "app_info.tagline"

        enum Features {
            static let title: LocalizedStringKey = "app_info.features.title"
            static let all: [AppInfoFeatureInfo] = [
                AppInfoFeatureInfo(
                    icon: "wifi.slash",
                    title: "app_info.features.offline.title",
                    description: "app_info.features.offline.description"
                ),
                AppInfoFeatureInfo(
                    icon: "lock.shield",
                    title: "app_info.features.encryption.title",
                    description: "app_info.features.encryption.description"
                ),
                AppInfoFeatureInfo(
                    icon: "antenna.radiowaves.left.and.right",
                    title: "app_info.features.extended_range.title",
                    description: "app_info.features.extended_range.description"
                ),
                AppInfoFeatureInfo(
                    icon: "star.fill",
                    title: "app_info.features.favorites.title",
                    description: "app_info.features.favorites.description"
                ),
                AppInfoFeatureInfo(
                    icon: "number",
                    title: "app_info.features.geohash.title",
                    description: "app_info.features.geohash.description"
                ),
                AppInfoFeatureInfo(
                    icon: "at",
                    title: "app_info.features.mentions.title",
                    description: "app_info.features.mentions.description"
                )
            ]
        }

        enum Privacy {
            static let title: LocalizedStringKey = "app_info.privacy.title"
            static let all: [AppInfoFeatureInfo] = [
                AppInfoFeatureInfo(
                    icon: "eye.slash",
                    title: "app_info.privacy.no_tracking.title",
                    description: "app_info.privacy.no_tracking.description"
                ),
                AppInfoFeatureInfo(
                    icon: "shuffle",
                    title: "app_info.privacy.ephemeral.title",
                    description: "app_info.privacy.ephemeral.description"
                ),
                AppInfoFeatureInfo(
                    icon: "hand.raised.fill",
                    title: "app_info.privacy.panic.title",
                    description: "app_info.privacy.panic.description"
                )
            ]
        }

        enum HowToUse {
            static let title: LocalizedStringKey = "app_info.how_to_use.title"
            static let instructions: [LocalizedStringResource] = [
                "app_info.how_to_use.set_nickname",
                "app_info.how_to_use.change_channels",
                "app_info.how_to_use.open_sidebar",
                "app_info.how_to_use.start_dm",
                "app_info.how_to_use.clear_chat",
                "app_info.how_to_use.commands"
            ]
        }
    }

    var body: some View {
        ZStack {
            BitchatTheme.backgroundGradient(for: colorScheme)
                .ignoresSafeArea()

            ThemedVerticalScrollView {
                infoContent
            }
            #if os(macOS)
            .frame(width: 600, height: 700)
            #endif
        }
        .sheet(isPresented: $showThemePicker) {
            ThemePickerSheet(selectedPaletteRawValue: $selectedPaletteRawValue)
            #if os(iOS)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
            #endif
        }
    }

    private var infoContent: some View {
        VStack(alignment: .leading, spacing: 14) {
            heroCard
            themeSummaryCard

            compactSectionCard {
                CompactSectionHeader(Strings.HowToUse.title)

                VStack(alignment: .leading, spacing: 0) {
                    ForEach(Array(Strings.HowToUse.instructions.enumerated()), id: \.offset) { index, instruction in
                        HStack(alignment: .top, spacing: 12) {
                            Text("\(index + 1)")
                                .font(.bitchatSystem(size: 13, weight: .bold, design: .rounded))
                                .foregroundColor(accentColor)
                                .frame(width: 16, alignment: .leading)

                            Text(String(localized: instruction).bitchatTrimmingLeadingBullet())
                                .font(.bitchatSystem(size: 14, weight: .medium))
                                .foregroundColor(textColor)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .padding(.vertical, 10)

                        if index < Strings.HowToUse.instructions.count - 1 {
                            Divider()
                                .overlay(borderColor.opacity(0.7))
                                .padding(.leading, 28)
                        }
                    }
                }
            }

            compactSectionCard {
                CompactSectionHeader(Strings.Features.title)
                CompactFeatureList(items: Strings.Features.all)
            }

            compactSectionCard {
                CompactSectionHeader(Strings.Privacy.title)
                CompactFeatureList(items: Strings.Privacy.all)
            }
        }
        .padding(16)
    }

    private var heroCard: some View {
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .center, spacing: 14) {
                heroCopy
                Spacer(minLength: 12)
                closeButton
            }

            VStack(alignment: .leading, spacing: 14) {
                heroCopy

                HStack {
                    Spacer()
                    closeButton
                }
            }
        }
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(elevatedSurfaceColor)
                .shadow(color: shadowColor, radius: 18, x: 0, y: 8)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(borderColor, lineWidth: 1)
        )
    }

    private var heroCopy: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(verbatim: "beechat")
                .font(.bitchatWordmark(size: 30, weight: .bold))
                .tracking(-0.4)
                .foregroundColor(textColor)
                .lineLimit(1)

            Text(Strings.tagline)
                .font(.bitchatSystem(size: 15, weight: .medium, design: .rounded))
                .foregroundColor(secondaryTextColor)
                .lineLimit(2)
        }
    }

    private var themeSummaryCard: some View {
        compactSectionCard {
            ViewThatFits(in: .horizontal) {
                HStack(alignment: .center, spacing: 16) {
                    themeSummaryCopy
                    Spacer(minLength: 12)
                    themeSummaryButton
                }

                VStack(alignment: .leading, spacing: 12) {
                    themeSummaryCopy
                    themeSummaryButton
                }
            }
        }
    }

    private var themeSummaryCopy: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Theme")
                .font(.bitchatSystem(size: 17, weight: .bold, design: .rounded))
                .foregroundColor(textColor)

            Text("Accent color for your handle and highlights.")
                .font(.bitchatSystem(size: 13, weight: .medium))
                .foregroundColor(secondaryTextColor)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var themeSummaryButton: some View {
        Button(action: { showThemePicker = true }) {
            HStack(spacing: 10) {
                ThemeSwatchPair(palette: selectedPalette)

                VStack(alignment: .leading, spacing: 2) {
                    Text(selectedPalette.displayName)
                        .font(.bitchatSystem(size: 14, weight: .semibold, design: .rounded))
                        .foregroundColor(textColor)

                    Text("Change")
                        .font(.bitchatSystem(size: 12, weight: .medium))
                        .foregroundColor(secondaryTextColor)
                }

                Spacer(minLength: 0)

                Image(systemName: "chevron.up.chevron.down")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(secondaryTextColor)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(secondarySurfaceColor)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(borderColor, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Open theme picker")
    }

    private var closeButton: some View {
        Button(action: { dismiss() }) {
            Image(systemName: "xmark")
                .font(.bitchatSystem(size: 13, weight: .semibold))
                .foregroundColor(textColor)
                .frame(width: 36, height: 36)
                .background(
                    Circle()
                        .fill(closeButtonFill)
                )
                .overlay(
                    Circle()
                        .stroke(closeButtonBorder, lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(String(localized: "app_info.close", comment: "Accessibility label for close buttons"))
    }

    private func compactSectionCard<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            content()
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
}

struct AppInfoFeatureInfo {
    let icon: String
    let title: LocalizedStringKey
    let description: LocalizedStringKey
}

private extension String {
    func bitchatTrimmingLeadingBullet() -> String {
        let bulletCharacters = CharacterSet(charactersIn: "•·●○▪◦-–—")
        var result = trimmingCharacters(in: .whitespacesAndNewlines)

        while let scalar = result.unicodeScalars.first, bulletCharacters.contains(scalar) {
            result.removeFirst()
            result = result.trimmingCharacters(in: .whitespacesAndNewlines)
        }

        return result
    }
}

struct CompactSectionHeader: View {
    let title: LocalizedStringKey
    @Environment(\.colorScheme) var colorScheme

    private var textColor: Color {
        BitchatTheme.primaryText(for: colorScheme)
    }

    init(_ title: LocalizedStringKey) {
        self.title = title
    }

    var body: some View {
        Text(title)
            .font(.bitchatSystem(size: 17, weight: .bold, design: .rounded))
            .foregroundColor(textColor)
    }
}

struct CompactFeatureList: View {
    let items: [AppInfoFeatureInfo]
    @Environment(\.colorScheme) private var colorScheme

    private var borderColor: Color {
        BitchatTheme.border(for: colorScheme)
    }

    var body: some View {
        VStack(spacing: 0) {
            ForEach(Array(items.enumerated()), id: \.offset) { index, item in
                CompactFeatureRow(info: item)

                if index < items.count - 1 {
                    Divider()
                        .overlay(borderColor.opacity(0.7))
                        .padding(.leading, 44)
                }
            }
        }
    }
}

struct CompactFeatureRow: View {
    let info: AppInfoFeatureInfo
    @Environment(\.colorScheme) var colorScheme

    private var textColor: Color {
        BitchatTheme.primaryText(for: colorScheme)
    }

    private var secondaryTextColor: Color {
        BitchatTheme.secondaryText(for: colorScheme)
    }

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            ZStack {
                Circle()
                    .fill(BitchatTheme.accentSoft(for: colorScheme))
                    .frame(width: 30, height: 30)

                Image(systemName: info.icon)
                    .font(.bitchatSystem(size: 14, weight: .semibold))
                    .foregroundColor(BitchatTheme.accent(for: colorScheme))
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(info.title)
                    .font(.bitchatSystem(size: 14, weight: .semibold, design: .rounded))
                    .foregroundColor(textColor)

                Text(info.description)
                    .font(.bitchatSystem(size: 12, weight: .medium))
                    .foregroundColor(secondaryTextColor)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)
        }
        .padding(.vertical, 10)
    }
}

struct ThemeSwatchPair: View {
    let palette: BitchatPalette
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(BitchatTheme.accent(for: colorScheme, palette: palette))
                .frame(width: 14, height: 14)

            Circle()
                .fill(BitchatTheme.accentSoft(for: colorScheme, palette: palette))
                .frame(width: 14, height: 14)
                .overlay(
                    Circle()
                        .stroke(BitchatTheme.accent(for: colorScheme, palette: palette).opacity(0.45), lineWidth: 1)
                )
        }
    }
}

struct ThemePickerSheet: View {
    @Binding var selectedPaletteRawValue: String
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme

    private var elevatedSurfaceColor: Color {
        BitchatTheme.elevatedSurface(for: colorScheme)
    }

    private var secondarySurfaceColor: Color {
        BitchatTheme.secondarySurface(for: colorScheme)
    }

    private var textColor: Color {
        BitchatTheme.primaryText(for: colorScheme)
    }

    private var secondaryTextColor: Color {
        BitchatTheme.secondaryText(for: colorScheme)
    }

    private var borderColor: Color {
        BitchatTheme.border(for: colorScheme)
    }

    private var shadowColor: Color {
        BitchatTheme.shadow(for: colorScheme)
    }

    private var selectedPalette: BitchatPalette {
        BitchatPalette(rawValue: selectedPaletteRawValue) ?? .sky
    }

    private var gridColumns: [GridItem] {
        [GridItem(.adaptive(minimum: 150, maximum: 220), spacing: 12)]
    }

    var body: some View {
        ZStack {
            BitchatTheme.backgroundGradient(for: colorScheme)
                .ignoresSafeArea()

            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .top, spacing: 12) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Accent color")
                            .font(.bitchatSystem(size: 22, weight: .bold, design: .rounded))
                            .foregroundColor(textColor)

                        Text("Choose the palette used for your handle and highlights.")
                            .font(.bitchatSystem(size: 14, weight: .medium))
                            .foregroundColor(secondaryTextColor)
                    }

                    Spacer(minLength: 0)

                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark")
                            .font(.bitchatSystem(size: 13, weight: .semibold))
                            .foregroundColor(textColor)
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
                    .accessibilityLabel(String(localized: "app_info.close", comment: "Accessibility label for close buttons"))
                }

                ThemedVerticalScrollView {
                    LazyVGrid(columns: gridColumns, alignment: .leading, spacing: 12) {
                        ForEach(BitchatPalette.allCases) { palette in
                            ThemePaletteCard(
                                palette: palette,
                                isSelected: palette == selectedPalette,
                                colorScheme: colorScheme,
                                textColor: textColor,
                                secondarySurfaceColor: secondarySurfaceColor,
                                borderColor: borderColor
                            ) {
                                selectedPaletteRawValue = palette.rawValue
                            }
                        }
                    }
                    .padding(.vertical, 2)
                }
            }
            .padding(18)
            .background(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(elevatedSurfaceColor)
                    .shadow(color: shadowColor, radius: 18, x: 0, y: 8)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .stroke(borderColor, lineWidth: 1)
            )
            .padding(16)
            #if os(macOS)
            .frame(width: 420, height: 460)
            #endif
        }
    }
}

private struct ThemePaletteCard: View {
    let palette: BitchatPalette
    let isSelected: Bool
    let colorScheme: ColorScheme
    let textColor: Color
    let secondarySurfaceColor: Color
    let borderColor: Color
    let action: () -> Void

    private var accentColor: Color {
        BitchatTheme.accent(for: colorScheme, palette: palette)
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                ThemeSwatchPair(palette: palette)

                Text(palette.displayName)
                    .font(.bitchatSystem(size: 15, weight: .semibold, design: .rounded))
                    .foregroundColor(textColor)

                Spacer(minLength: 0)

                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(accentColor)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 13)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(secondarySurfaceColor)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(isSelected ? accentColor : borderColor, lineWidth: isSelected ? 2 : 1)
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(palette.displayName) theme")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

private struct ThemedVerticalScrollView<Content: View>: View {
    @Environment(\.colorScheme) private var colorScheme

    let content: Content

    @State private var viewportHeight: CGFloat = 1
    @State private var contentHeight: CGFloat = 1
    @State private var contentOffset: CGFloat = 0

    private let scrollSpaceName = "themed-vertical-scroll"

    private var accentColor: Color {
        BitchatTheme.accent(for: colorScheme)
    }

    private var trackColor: Color {
        colorScheme == .dark ? Color.white.opacity(0.05) : accentColor.opacity(0.08)
    }

    private var thumbColor: Color {
        colorScheme == .dark ? Color.white.opacity(0.22) : accentColor.opacity(0.22)
    }

    private var usesNativeMacScroller: Bool {
        #if os(macOS)
        true
        #else
        false
        #endif
    }

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        ScrollView(.vertical, showsIndicators: usesNativeMacScroller) {
            VStack(spacing: 0) {
                content
            }
            .frame(maxWidth: .infinity, alignment: .topLeading)
            .background {
                #if os(macOS)
                MacOverlayScrollerConfigurator(colorScheme: colorScheme)
                    .frame(width: 0, height: 0)
                #endif
            }
                .background(
                    GeometryReader { geometry in
                        Color.clear
                            .preference(key: ThemedScrollContentHeightKey.self, value: geometry.size.height)
                    }
                )
                .background(
                    GeometryReader { geometry in
                        Color.clear
                            .preference(
                                key: ThemedScrollContentOffsetKey.self,
                                value: geometry.frame(in: .named(scrollSpaceName)).minY
                            )
                    }
                )
        }
        .coordinateSpace(name: scrollSpaceName)
        .background(
            GeometryReader { geometry in
                Color.clear
                    .onAppear { viewportHeight = geometry.size.height }
                    .onChange(of: geometry.size.height) { newHeight in
                        viewportHeight = newHeight
                    }
            }
        )
        .onPreferenceChange(ThemedScrollContentHeightKey.self) { newHeight in
            contentHeight = newHeight
        }
        .onPreferenceChange(ThemedScrollContentOffsetKey.self) { newOffset in
            contentOffset = newOffset
        }
        #if !os(macOS)
        .overlay(alignment: .trailing) {
            GeometryReader { geometry in
                let trackHeight = max(geometry.size.height - 20, 0)
                let overflow = max(contentHeight - viewportHeight, 0)
                let rawThumbHeight = trackHeight * (viewportHeight / max(contentHeight, viewportHeight))
                let thumbHeight = min(trackHeight, max(44, rawThumbHeight))
                let progress = overflow > 0 ? min(max(-contentOffset / overflow, 0), 1) : 0
                let thumbOffset = progress * max(trackHeight - thumbHeight, 0)

                if overflow > 1, trackHeight > thumbHeight {
                    ZStack(alignment: .topTrailing) {
                        Capsule(style: .continuous)
                            .fill(trackColor)
                            .frame(width: 3, height: trackHeight)
                            .padding(.top, 10)

                        Capsule(style: .continuous)
                            .fill(thumbColor)
                            .frame(width: 5, height: thumbHeight)
                            .padding(.top, 10 + thumbOffset)
                    }
                    .padding(.trailing, 5)
                }
            }
            .allowsHitTesting(false)
        }
        #endif
    }
}

private struct ThemedScrollContentHeightKey: PreferenceKey {
    static var defaultValue: CGFloat = 0

    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

private struct ThemedScrollContentOffsetKey: PreferenceKey {
    static var defaultValue: CGFloat = 0

    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

#if canImport(PreviewsMacros)
#Preview("Default") {
    AppInfoView()
}

#Preview("Dynamic Type XXL") {
    AppInfoView()
        .environment(\.sizeCategory, .accessibilityExtraExtraExtraLarge)
}

#Preview("Dynamic Type XS") {
    AppInfoView()
        .environment(\.sizeCategory, .extraSmall)
}
#endif
