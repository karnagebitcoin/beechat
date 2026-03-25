//
// ContentView.swift
// bitchat
//
// This is free and unencumbered software released into the public domain.
// For more information, see <https://unlicense.org>
//

import SwiftUI
#if os(iOS)
import UIKit
#endif
#if os(macOS)
import AppKit
#endif
import UniformTypeIdentifiers
import BitLogger

// MARK: - Supporting Types

//

//

private struct MessageDisplayItem: Identifiable {
    let id: String
    let message: BitchatMessage
}

private struct ChatScrollContentHeightKey: PreferenceKey {
    static var defaultValue: CGFloat = 0

    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

private struct ChatScrollContentOffsetKey: PreferenceKey {
    static var defaultValue: CGFloat = 0

    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

// MARK: - Main Content View

struct ContentView: View {
    // MARK: - Properties
    
    @EnvironmentObject var viewModel: ChatViewModel
    @ObservedObject private var locationManager = LocationChannelManager.shared
    @ObservedObject private var bookmarks = GeohashBookmarksStore.shared
    @AppStorage(BitchatTheme.selectedPaletteKey) private var selectedPaletteRawValue = BitchatPalette.sky.rawValue
    @State private var messageText = ""
    @FocusState private var isTextFieldFocused: Bool
    @Environment(\.colorScheme) var colorScheme
    @Environment(\.dismiss) private var dismiss
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    #if os(iOS)
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    #endif
    @State private var showSidebar = false
    @State private var showAppInfo = false
    @State private var showMessageActions = false
    @State private var selectedMessageSender: String?
    @State private var selectedMessageSenderID: PeerID?
    @FocusState private var isNicknameFieldFocused: Bool
    @State private var isAtBottomPublic: Bool = true
    @State private var isAtBottomPrivate: Bool = true
    @State private var lastScrollTime: Date = .distantPast
    @State private var scrollThrottleTimer: Timer?
    @State private var autocompleteDebounceTimer: Timer?
    @State private var showLocationChannelsSheet = false
    @State private var showVerifySheet = false
    @State private var expandedMessageIDs: Set<String> = []
    @State private var showLocationNotes = false
    @State private var notesGeohash: String? = nil
    @State private var imagePreviewURL: URL? = nil
    @State private var recordingAlertMessage: String = ""
    @State private var showRecordingAlert = false
    @State private var isRecordingVoiceNote = false
    @State private var isPreparingVoiceNote = false
    @State private var recordingDuration: TimeInterval = 0
    @State private var recordingTimer: Timer?
    @State private var recordingStartDate: Date?
#if os(iOS)
    @State private var showImagePicker = false
    @State private var imagePickerSourceType: UIImagePickerController.SourceType = .camera
#else
    @State private var showMacImagePicker = false
#endif
    @ScaledMetric(relativeTo: .body) private var headerHeight: CGFloat = 44
    @ScaledMetric(relativeTo: .subheadline) private var headerPeerIconSize: CGFloat = 11
    @ScaledMetric(relativeTo: .subheadline) private var headerPeerCountFontSize: CGFloat = 12
    // Timer-based refresh removed; use LocationChannelManager live updates instead
    // Window sizes for rendering (infinite scroll up)
    @State private var windowCountPublic: Int = 300
    @State private var windowCountPrivate: [PeerID: Int] = [:]
    @State private var publicScrollViewportHeight: CGFloat = 1
    @State private var publicScrollContentHeight: CGFloat = 1
    @State private var publicScrollContentOffset: CGFloat = 0
    @State private var privateScrollViewportHeight: CGFloat = 1
    @State private var privateScrollContentHeight: CGFloat = 1
    @State private var privateScrollContentOffset: CGFloat = 0
    
    // MARK: - Computed Properties
    
    private var backgroundColor: Color {
        BitchatTheme.surface(for: colorScheme)
    }

    private var appBackgroundColor: Color {
        BitchatTheme.appBackground(for: colorScheme)
    }

    private var chatCanvasColor: Color {
        colorScheme == .dark ? backgroundColor : .white
    }

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

    private var meshAccentColor: Color {
        BitchatTheme.meshAccent(for: colorScheme)
    }

    private var locationAccentColor: Color {
        BitchatTheme.locationAccent(for: colorScheme)
    }

    private var shadowColor: Color {
        BitchatTheme.shadow(for: colorScheme)
    }

    private var messageScrollThumbColor: Color {
        colorScheme == .dark ? Color.white.opacity(0.18) : accentColor.opacity(0.18)
    }

    private var messageScrollTrackColor: Color {
        colorScheme == .dark ? Color.white.opacity(0.035) : accentColor.opacity(0.05)
    }

    private var usesNativeMacScroller: Bool {
        #if os(macOS)
        true
        #else
        false
        #endif
    }

    private var headerLineLimit: Int? {
        dynamicTypeSize.isAccessibilitySize ? 2 : 1
    }

    private var usesCompactHeaderLayout: Bool {
        #if os(iOS)
        horizontalSizeClass == .compact && !dynamicTypeSize.isAccessibilitySize
        #else
        false
        #endif
    }

    private var usesCompactChatTypography: Bool {
        #if os(iOS)
        horizontalSizeClass == .compact && !dynamicTypeSize.isAccessibilitySize
        #else
        false
        #endif
    }

    private var usesCompactPeopleSheetLayout: Bool {
        #if os(iOS)
        horizontalSizeClass == .compact && !dynamicTypeSize.isAccessibilitySize
        #else
        false
        #endif
    }

    private var headerWordmarkSize: CGFloat {
        usesCompactHeaderLayout ? 18 : 22
    }

    private var peopleSheetHeroSpacing: CGFloat {
        usesCompactPeopleSheetLayout ? 12 : 14
    }

    private var peopleSheetIconContainerSize: CGFloat {
        usesCompactPeopleSheetLayout ? 50 : 58
    }

    private var peopleSheetIconGlyphSize: CGFloat {
        usesCompactPeopleSheetLayout ? 20 : 24
    }

    private var peopleSheetTitleFontSize: CGFloat {
        usesCompactPeopleSheetLayout ? 22 : 26
    }

    private var peopleSheetDescriptionFontSize: CGFloat {
        usesCompactPeopleSheetLayout ? 13.5 : 15
    }

    private var peopleSheetActionButtonSize: CGFloat {
        usesCompactPeopleSheetLayout ? 34 : 38
    }

    private var peopleSheetActionIconSize: CGFloat {
        usesCompactPeopleSheetLayout ? 13 : 14
    }

    private var peopleSheetActionSpacing: CGFloat {
        usesCompactPeopleSheetLayout ? 8 : 10
    }

    private var peopleSheetHeroPadding: CGFloat {
        usesCompactPeopleSheetLayout ? 16 : 20
    }

    private var peopleSheetBadgeFontSize: CGFloat {
        usesCompactPeopleSheetLayout ? 12 : 13
    }

    private var peopleSheetBadgeIconSize: CGFloat {
        usesCompactPeopleSheetLayout ? 11 : 12
    }

    private var peopleSheetBadgeHorizontalPadding: CGFloat {
        usesCompactPeopleSheetLayout ? 10 : 12
    }

    private var peopleSheetBadgeVerticalPadding: CGFloat {
        usesCompactPeopleSheetLayout ? 7 : 8
    }

    private var headerRowSpacing: CGFloat {
        usesCompactHeaderLayout ? 8 : 10
    }

    private var headerCapsuleHorizontalPadding: CGFloat {
        usesCompactHeaderLayout ? 10 : 14
    }

    private var headerCapsuleVerticalPadding: CGFloat {
        usesCompactHeaderLayout ? 7 : 8
    }

    private var headerCountSpacing: CGFloat {
        usesCompactHeaderLayout ? 5 : 6
    }

    private var compactHeaderPeerIconSize: CGFloat {
        usesCompactHeaderLayout ? 10 : headerPeerIconSize
    }

    private var compactHeaderPeerCountFontSize: CGFloat {
        usesCompactHeaderLayout ? 11 : headerPeerCountFontSize
    }

    private var headerNicknamePrefixFontSize: CGFloat {
        usesCompactHeaderLayout ? 13 : 14
    }

    private var headerNicknameFontSize: CGFloat {
        usesCompactHeaderLayout ? 13 : 14
    }

    private var headerNicknameMaxWidth: CGFloat {
        usesCompactHeaderLayout ? 64 : 100
    }

    private var headerOuterHorizontalPadding: CGFloat {
        usesCompactHeaderLayout ? 12 : 16
    }

    private var headerOuterVerticalPadding: CGFloat {
        usesCompactHeaderLayout ? 10 : 12
    }

    private var headerBadgeFontSize: CGFloat {
        usesCompactHeaderLayout ? 13 : 14
    }

    private var headerSpacerMinLength: CGFloat {
        usesCompactHeaderLayout ? 6 : 10
    }

    private var peopleSheetTitle: String {
        switch locationManager.selectedChannel {
        case .mesh:
            return "People nearby"
        case .location:
            return "People in this area"
        }
    }

    private var peopleSheetDescription: String {
        switch locationManager.selectedChannel {
        case .mesh:
            return "Start a private chat, save favorites, or verify someone nearby."
        case .location:
            return "See who is active here right now and tap a name to start a local direct message."
        }
    }

    private var peopleSheetSubtitle: String {
        switch locationManager.selectedChannel {
        case .mesh:
            return "Bluetooth mesh"
        case .location(let channel):
            return "#\(channel.geohash.lowercased())"
        }
    }

    private var peopleSheetAccentColor: Color {
        switch locationManager.selectedChannel {
        case .mesh:
            return meshAccentColor
        case .location:
            return locationAccentColor
        }
    }

    private var peopleSheetIconName: String {
        switch locationManager.selectedChannel {
        case .mesh:
            return "person.2.circle.fill"
        case .location:
            return "mappin.circle.fill"
        }
    }

    private var peopleSheetActiveText: String {
        let count = peopleSheetActiveCount
        return count == 1 ? "1 active now" : "\(count) active now"
    }

    private var currentChannelPeopleCount: Int {
        switch locationManager.selectedChannel {
        case .location:
            return viewModel.visibleGeohashPeople().count
        case .mesh:
            return channelPeopleCountAndColor().0
        }
    }

    private var peopleSheetActionBackground: Color {
        colorScheme == .dark ? Color.white.opacity(0.06) : accentColor.opacity(0.08)
    }

    private var peopleSheetActionBorder: Color {
        colorScheme == .dark ? Color.white.opacity(0.08) : accentColor.opacity(0.18)
    }

    private var peopleSheetIconBackground: Color {
        peopleSheetAccentColor.opacity(colorScheme == .dark ? 0.18 : 0.12)
    }

    private var peopleSheetIconForeground: Color {
        colorScheme == .dark ? peopleSheetAccentColor : peopleSheetAccentColor.opacity(0.92)
    }

    private var peopleSheetListBackground: Color {
        colorScheme == .dark ? BitchatTheme.surface(for: colorScheme) : BitchatTheme.elevatedSurface(for: colorScheme)
    }

    private var peopleSheetListBorder: Color {
        colorScheme == .dark ? borderColor : peopleSheetAccentColor.opacity(0.14)
    }

    @ViewBuilder
    private func peopleSheetBadge(icon: String? = nil, text: String, tint: Color, filled: Bool = false) -> some View {
        HStack(spacing: 6) {
            if let icon {
                Image(systemName: icon)
                    .font(.bitchatSystem(size: peopleSheetBadgeIconSize, weight: .semibold))
            }
            Text(text)
                .font(.bitchatSystem(size: peopleSheetBadgeFontSize, weight: .semibold))
                .lineLimit(1)
        }
        .foregroundColor(filled ? BitchatTheme.primaryText(for: colorScheme) : tint)
        .padding(.horizontal, peopleSheetBadgeHorizontalPadding)
        .padding(.vertical, peopleSheetBadgeVerticalPadding)
        .background(
            Capsule(style: .continuous)
                .fill(filled ? tint.opacity(colorScheme == .dark ? 0.22 : 0.14) : secondarySurfaceColor)
        )
        .overlay(
            Capsule(style: .continuous)
                .stroke(filled ? tint.opacity(colorScheme == .dark ? 0.28 : 0.18) : peopleSheetListBorder, lineWidth: 1)
        )
    }

    private func peopleSheetActionButton(
        icon: String,
        accessibilityLabel: String,
        helpText: String? = nil,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.bitchatSystem(size: peopleSheetActionIconSize, weight: .semibold))
                .foregroundColor(textColor)
                .frame(width: peopleSheetActionButtonSize, height: peopleSheetActionButtonSize)
                .background(
                    Circle()
                        .fill(peopleSheetActionBackground)
                )
                .overlay(
                    Circle()
                        .stroke(peopleSheetActionBorder, lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(accessibilityLabel)
        .help(helpText ?? accessibilityLabel)
    }

    private var peopleSheetActiveCount: Int {
        switch locationManager.selectedChannel {
        case .mesh:
            return viewModel.allPeers.filter { $0.peerID != viewModel.meshService.myPeerID }.count
        case .location:
            return viewModel.visibleGeohashPeople().count
        }
    }
    
    
    private struct PrivateHeaderContext {
        let headerPeerID: PeerID
        let peer: BitchatPeer?
        let displayName: String
        let isNostrAvailable: Bool
    }

// MARK: - Body

    var body: some View {
        ZStack {
            BitchatTheme.backgroundGradient(for: colorScheme)
                .ignoresSafeArea()

            VStack(spacing: 14) {
                mainHeaderView
                    .onAppear {
                        viewModel.currentColorScheme = colorScheme
                        #if os(macOS)
                        // Focus message input on macOS launch, not nickname field
                        DispatchQueue.main.async {
                            isNicknameFieldFocused = false
                            isTextFieldFocused = true
                        }
                        #endif
                    }
                    .onChange(of: colorScheme) { newValue in
                        viewModel.currentColorScheme = newValue
                    }

                GeometryReader { geometry in
                    VStack(spacing: 0) {
                        messagesView(privatePeer: nil, isAtBottom: $isAtBottomPublic)
                            .background(chatCanvasColor)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                    .frame(width: geometry.size.width, height: geometry.size.height)
                    .background(
                        RoundedRectangle(cornerRadius: 28, style: .continuous)
                            .fill(chatCanvasColor)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 28, style: .continuous)
                            .stroke(borderColor, lineWidth: 1)
                    )
                    .shadow(color: shadowColor, radius: 22, x: 0, y: 12)
                }

                if viewModel.selectedPrivateChatPeer == nil {
                    inputView
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
        }
        .foregroundColor(textColor)
        #if os(macOS)
        .frame(minWidth: 600, minHeight: 400)
        #endif
        .onChange(of: viewModel.selectedPrivateChatPeer) { newValue in
            if newValue != nil {
                showSidebar = true
            }
        }
        .sheet(
            isPresented: Binding(
                get: { showSidebar || viewModel.selectedPrivateChatPeer != nil },
                set: { isPresented in
                    if !isPresented {
                        showSidebar = false
                        viewModel.endPrivateChat()
                    }
                }
            )
        ) {
            peopleSheetView
        }
        .sheet(isPresented: $showAppInfo) {
            AppInfoView()
                .environmentObject(viewModel)
                .onAppear { viewModel.isAppInfoPresented = true }
                .onDisappear { viewModel.isAppInfoPresented = false }
        }
        .sheet(isPresented: Binding(
            get: { viewModel.showingFingerprintFor != nil },
            set: { _ in viewModel.showingFingerprintFor = nil }
        )) {
            if let peerID = viewModel.showingFingerprintFor {
                FingerprintView(viewModel: viewModel, peerID: peerID)
                    .environmentObject(viewModel)
            }
        }
#if os(iOS)
        .fullScreenCover(item: $viewModel.activeSnakeRuntime) { runtime in
            SnakeArenaView(runtime: runtime)
                .interactiveDismissDisabled(true)
        }
#else
        .sheet(item: $viewModel.activeSnakeRuntime) { runtime in
            SnakeArenaView(runtime: runtime)
                .frame(minWidth: 980, minHeight: 760)
        }
#endif
#if os(iOS)
        .fullScreenCover(item: $viewModel.activePongRuntime) { runtime in
            PongMatchView(runtime: runtime)
                .interactiveDismissDisabled(true)
        }
#else
        .sheet(item: $viewModel.activePongRuntime) { runtime in
            PongMatchView(runtime: runtime)
                .frame(minWidth: 920, minHeight: 640)
        }
#endif
#if os(iOS)
        // Only present image picker from main view when NOT in a sheet
        .fullScreenCover(isPresented: Binding(
            get: { showImagePicker && !showSidebar && viewModel.selectedPrivateChatPeer == nil },
            set: { newValue in
                if !newValue {
                    showImagePicker = false
                }
            }
        )) {
            ImagePickerView(sourceType: imagePickerSourceType) { image in
                showImagePicker = false
                if let image = image {
                    Task {
                        do {
                            let processedURL = try ImageUtils.processImage(image)
                            await MainActor.run {
                                viewModel.sendImage(from: processedURL)
                            }
                        } catch {
                            SecureLogger.error("Image processing failed: \(error)", category: .session)
                        }
                    }
                }
            }
            .environmentObject(viewModel)
            .ignoresSafeArea()
        }
#endif
#if os(macOS)
        // Only present Mac image picker from main view when NOT in a sheet
        .sheet(isPresented: Binding(
            get: { showMacImagePicker && !showSidebar && viewModel.selectedPrivateChatPeer == nil },
            set: { newValue in
                if !newValue {
                    showMacImagePicker = false
                }
            }
        )) {
            MacImagePickerView { url in
                showMacImagePicker = false
                if let url = url {
                    Task {
                        do {
                            let processedURL = try ImageUtils.processImage(at: url)
                            await MainActor.run {
                                viewModel.sendImage(from: processedURL)
                            }
                        } catch {
                            SecureLogger.error("Image processing failed: \(error)", category: .session)
                        }
                    }
                }
            }
            .environmentObject(viewModel)
        }
#endif
        .sheet(isPresented: Binding(
            get: { imagePreviewURL != nil },
            set: { presenting in if !presenting { imagePreviewURL = nil } }
        )) {
            if let url = imagePreviewURL {
                ImagePreviewView(url: url)
                    .environmentObject(viewModel)
            }
        }
        .alert("Recording Error", isPresented: $showRecordingAlert, actions: {
            Button("OK", role: .cancel) {}
        }, message: {
            Text(recordingAlertMessage)
        })
        .confirmationDialog(
            selectedMessageSender.map { "@\($0)" } ?? String(localized: "content.actions.title", comment: "Fallback title for the message action sheet"),
            isPresented: $showMessageActions,
            titleVisibility: .visible
        ) {
            Button("content.actions.mention") {
                if let sender = selectedMessageSender {
                    // Pre-fill the input with an @mention and focus the field
                    messageText = "@\(sender) "
                    isTextFieldFocused = true
                }
            }

            Button("content.actions.direct_message") {
                if let peerID = selectedMessageSenderID {
                    if peerID.isGeoChat {
                        if let full = viewModel.fullNostrHex(forSenderPeerID: peerID) {
                            viewModel.startGeohashDM(withPubkeyHex: full)
                        }
                    } else {
                        viewModel.startPrivateChat(with: peerID)
                    }
                    withAnimation(.easeInOut(duration: TransportConfig.uiAnimationMediumSeconds)) {
                        showSidebar = true
                    }
                }
            }

            Button("content.actions.hug") {
                if let sender = selectedMessageSender {
                    viewModel.sendMessage("/hug @\(sender)")
                }
            }

            Button("content.actions.slap") {
                if let sender = selectedMessageSender {
                    viewModel.sendMessage("/slap @\(sender)")
                }
            }

            Button("content.actions.block", role: .destructive) {
                // Prefer direct geohash block when we have a Nostr sender ID
                if let peerID = selectedMessageSenderID, peerID.isGeoChat,
                   let full = viewModel.fullNostrHex(forSenderPeerID: peerID),
                   let sender = selectedMessageSender {
                    viewModel.blockGeohashUser(pubkeyHexLowercased: full, displayName: sender)
                } else if let sender = selectedMessageSender {
                    viewModel.sendMessage("/block \(sender)")
                }
            }

            Button("common.cancel", role: .cancel) {}
        }
        .alert("content.alert.bluetooth_required.title", isPresented: $viewModel.showBluetoothAlert) {
            Button("content.alert.bluetooth_required.settings") {
                #if os(iOS)
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
                #endif
            }
            Button("common.ok", role: .cancel) {}
        } message: {
            Text(viewModel.bluetoothAlertMessage)
        }
        .onDisappear {
            // Clean up timers
            scrollThrottleTimer?.invalidate()
            autocompleteDebounceTimer?.invalidate()
        }
    }
    
    // MARK: - Message List View
    
    private func messagesView(privatePeer: PeerID?, isAtBottom: Binding<Bool>) -> some View {
        let messages: [BitchatMessage] = {
            if let peerID = privatePeer {
                return viewModel.getPrivateChatMessages(for: peerID)
            }
            return viewModel.messages
        }()

        let currentWindowCount: Int = {
            if let peer = privatePeer {
                return windowCountPrivate[peer] ?? TransportConfig.uiWindowInitialCountPrivate
            }
            return windowCountPublic
        }()

        let windowedMessages: [BitchatMessage] = Array(messages.suffix(currentWindowCount))

        let contextKey: String = {
            if let peer = privatePeer { return "dm:\(peer)" }
            switch locationManager.selectedChannel {
            case .mesh: return "mesh"
            case .location(let ch): return "geo:\(ch.geohash)"
            }
        }()

        let messageItems: [MessageDisplayItem] = windowedMessages.compactMap { message in
            let trimmed = message.content.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { return nil }
            return MessageDisplayItem(id: "\(contextKey)|\(message.id)", message: message)
        }

        let nearbyPeopleCount = privatePeer == nil ? currentChannelPeopleCount : 0
        let shouldShowScanningPlaceholder = privatePeer == nil && messageItems.isEmpty
        let scanningModeLabel: String = {
            switch locationManager.selectedChannel {
            case .mesh:
                return "Mesh"
            case .location(let channel):
                return "#\(channel.geohash.lowercased())"
            }
        }()
        let scanningCountLabel: String? = nearbyPeopleCount > 0 ? "\(nearbyPeopleCount) nearby" : nil
        let scanningAccentColor: Color = {
            switch locationManager.selectedChannel {
            case .mesh:
                return meshAccentColor
            case .location:
                return locationAccentColor
            }
        }()
        let scanningTitle: String = {
            switch locationManager.selectedChannel {
            case .mesh:
                if nearbyPeopleCount == 0 {
                    return "Scanning nearby"
                }
                return nearbyPeopleCount == 1 ? "1 person nearby" : "\(nearbyPeopleCount) people nearby"
            case .location(let channel):
                if nearbyPeopleCount == 0 {
                    return "Watching #\(channel.geohash.lowercased())"
                }
                return nearbyPeopleCount == 1 ? "1 person in this area" : "\(nearbyPeopleCount) people in this area"
            }
        }()
        let scanningSubtitle: String = {
            switch locationManager.selectedChannel {
            case .mesh:
                if nearbyPeopleCount == 0 {
                    return "Bluetooth mesh is listening for nearby people and the first message."
                }
                return "Someone is around. Say hi to get the chat moving while the radar keeps scanning."
            case .location:
                if nearbyPeopleCount == 0 {
                    return "This area is quiet for now. Stay open and the channel will light up when someone joins."
                }
                return "The room is open and people are here. Send the first message when you're ready."
            }
        }()

        let scrollViewportHeight = privatePeer == nil ? $publicScrollViewportHeight : $privateScrollViewportHeight
        let scrollContentHeight = privatePeer == nil ? $publicScrollContentHeight : $privateScrollContentHeight
        let scrollContentOffset = privatePeer == nil ? $publicScrollContentOffset : $privateScrollContentOffset
        let scrollSpaceName = privatePeer == nil ? "chat-scroll-public" : "chat-scroll-private"

        return ScrollViewReader { proxy in
            ScrollView(.vertical, showsIndicators: usesNativeMacScroller) {
                LazyVStack(alignment: .leading, spacing: 0) {
                    ForEach(messageItems) { item in
                        let message = item.message
                        messageRow(for: message)
                            .onAppear {
                                if message.id == windowedMessages.last?.id {
                                    isAtBottom.wrappedValue = true
                                }
                                if message.id == windowedMessages.first?.id,
                                   messages.count > windowedMessages.count {
                                    expandWindow(
                                        ifNeededFor: message,
                                        allMessages: messages,
                                        privatePeer: privatePeer,
                                        proxy: proxy
                                    )
                                }
                            }
                            .onDisappear {
                                if message.id == windowedMessages.last?.id {
                                    isAtBottom.wrappedValue = false
                                }
                            }
                            .contentShape(Rectangle())
                            .onTapGesture {
                                if message.sender != "system" {
                                    messageText = "@\(message.sender) "
                                    isTextFieldFocused = true
                                }
                            }
                            .contextMenu {
                                Button("content.message.copy") {
                                    #if os(iOS)
                                    UIPasteboard.general.string = message.content
                                    #else
                                    let pb = NSPasteboard.general
                                    pb.clearContents()
                                    pb.setString(message.content, forType: .string)
                                    #endif
                                }
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 1)
                    }
                }
                .transaction { tx in if viewModel.isBatchingPublic { tx.disablesAnimations = true } }
                .padding(.vertical, 2)
                .background {
                    #if os(macOS)
                    MacOverlayScrollerConfigurator(colorScheme: colorScheme)
                        .frame(width: 0, height: 0)
                    #endif
                }
                .background(
                    GeometryReader { geometry in
                        Color.clear
                            .preference(key: ChatScrollContentHeightKey.self, value: geometry.size.height)
                    }
                )
                .background(
                    GeometryReader { geometry in
                        Color.clear
                            .preference(
                                key: ChatScrollContentOffsetKey.self,
                                value: geometry.frame(in: .named(scrollSpaceName)).minY
                            )
                    }
                )
            }
            .coordinateSpace(name: scrollSpaceName)
            .background(
                GeometryReader { geometry in
                    Color.clear
                        .onAppear { scrollViewportHeight.wrappedValue = geometry.size.height }
                        .onChange(of: geometry.size.height) { newHeight in
                            scrollViewportHeight.wrappedValue = newHeight
                        }
                }
            )
            .onPreferenceChange(ChatScrollContentHeightKey.self) { newHeight in
                scrollContentHeight.wrappedValue = newHeight
            }
            .onPreferenceChange(ChatScrollContentOffsetKey.self) { newOffset in
                scrollContentOffset.wrappedValue = newOffset
            }
            .overlay {
                if shouldShowScanningPlaceholder {
                    ChatScanningPlaceholderView(
                        accentColor: scanningAccentColor,
                        surfaceColor: chatCanvasColor,
                        textColor: textColor,
                        secondaryTextColor: secondaryTextColor,
                        modeLabel: scanningModeLabel,
                        countLabel: scanningCountLabel,
                        title: scanningTitle,
                        subtitle: scanningSubtitle
                    )
                    .padding(.horizontal, 24)
                    .padding(.vertical, 20)
                    .allowsHitTesting(false)
                    .transition(.opacity)
                }
            }
            #if !os(macOS)
            .overlay(alignment: .trailing) {
                GeometryReader { geometry in
                    let trackHeight = max(geometry.size.height - 18, 0)
                    let overflow = max(scrollContentHeight.wrappedValue - scrollViewportHeight.wrappedValue, 0)
                    let rawThumbHeight = trackHeight * (scrollViewportHeight.wrappedValue / max(scrollContentHeight.wrappedValue, scrollViewportHeight.wrappedValue))
                    let thumbHeight = min(trackHeight, max(32, rawThumbHeight))
                    let progress = overflow > 0 ? min(max(-scrollContentOffset.wrappedValue / overflow, 0), 1) : 0
                    let thumbOffset = progress * max(trackHeight - thumbHeight, 0)

                    if overflow > 1, trackHeight > thumbHeight {
                        ZStack(alignment: .topTrailing) {
                            Capsule(style: .continuous)
                                .fill(messageScrollTrackColor)
                                .frame(width: 2, height: trackHeight)
                                .padding(.top, 9)

                            Capsule(style: .continuous)
                                .fill(messageScrollThumbColor)
                                .frame(width: 4, height: thumbHeight)
                                .padding(.top, 9 + thumbOffset)
                        }
                        .padding(.trailing, 4)
                    }
                }
                .allowsHitTesting(false)
            }
            #endif
            .animation(.easeOut(duration: 0.25), value: shouldShowScanningPlaceholder)
            .background(chatCanvasColor)
            .onOpenURL { handleOpenURL($0) }
            .onTapGesture(count: 3) {
                viewModel.sendMessage("/clear")
            }
            .onAppear {
                scrollToBottom(on: proxy, privatePeer: privatePeer, isAtBottom: isAtBottom)
            }
            .onChange(of: privatePeer) { _ in
                scrollToBottom(on: proxy, privatePeer: privatePeer, isAtBottom: isAtBottom)
            }
            .onChange(of: viewModel.messages.count) { _ in
                if privatePeer == nil && !viewModel.messages.isEmpty {
                    // If the newest message is from me, always scroll to bottom
                    let lastMsg = viewModel.messages.last!
                    let isFromSelf = (lastMsg.sender == viewModel.nickname) || lastMsg.sender.hasPrefix(viewModel.nickname + "#")
                    if !isFromSelf {
                        // Only autoscroll when user is at/near bottom
                        guard isAtBottom.wrappedValue else { return }
                    } else {
                        // Ensure we consider ourselves at bottom for subsequent messages
                        isAtBottom.wrappedValue = true
                    }
                    // Throttle scroll animations to prevent excessive UI updates
                    let now = Date()
                    if now.timeIntervalSince(lastScrollTime) > TransportConfig.uiScrollThrottleSeconds {
                        // Immediate scroll if enough time has passed
                        lastScrollTime = now
                        let contextKey: String = {
                            switch locationManager.selectedChannel {
                            case .mesh: return "mesh"
                            case .location(let ch): return "geo:\(ch.geohash)"
                            }
                        }()
                        let count = windowCountPublic
                        let target = viewModel.messages.suffix(count).last.map { "\(contextKey)|\($0.id)" }
                        DispatchQueue.main.async {
                            if let target = target { proxy.scrollTo(target, anchor: .bottom) }
                        }
                    } else {
                        // Schedule a delayed scroll
                        scrollThrottleTimer?.invalidate()
                        scrollThrottleTimer = Timer.scheduledTimer(withTimeInterval: TransportConfig.uiScrollThrottleSeconds, repeats: false) { [weak viewModel] _ in
                            Task { @MainActor in
                                lastScrollTime = Date()
                                let contextKey: String = {
                                    switch locationManager.selectedChannel {
                                    case .mesh: return "mesh"
                                    case .location(let ch): return "geo:\(ch.geohash)"
                                    }
                                }()
                                let count = windowCountPublic
                                let target = viewModel?.messages.suffix(count).last.map { "\(contextKey)|\($0.id)" }
                                if let target = target { proxy.scrollTo(target, anchor: .bottom) }
                            }
                        }
                    }
                }
            }
            .onChange(of: viewModel.privateChats) { _ in
                if let peerID = privatePeer,
                   let messages = viewModel.privateChats[peerID],
                   !messages.isEmpty {
                    // If the newest private message is from me, always scroll
                    let lastMsg = messages.last!
                    let isFromSelf = (lastMsg.sender == viewModel.nickname) || lastMsg.sender.hasPrefix(viewModel.nickname + "#")
                    if !isFromSelf {
                        // Only autoscroll when user is at/near bottom
                        guard isAtBottom.wrappedValue else { return }
                    } else {
                        isAtBottom.wrappedValue = true
                    }
                    // Same throttling for private chats
                    let now = Date()
                    if now.timeIntervalSince(lastScrollTime) > TransportConfig.uiScrollThrottleSeconds {
                        lastScrollTime = now
                        let contextKey = "dm:\(peerID)"
                        let count = windowCountPrivate[peerID] ?? 300
                        let target = messages.suffix(count).last.map { "\(contextKey)|\($0.id)" }
                        DispatchQueue.main.async {
                            if let target = target { proxy.scrollTo(target, anchor: .bottom) }
                        }
                    } else {
                        scrollThrottleTimer?.invalidate()
                        scrollThrottleTimer = Timer.scheduledTimer(withTimeInterval: TransportConfig.uiScrollThrottleSeconds, repeats: false) { _ in
                            lastScrollTime = Date()
                            let contextKey = "dm:\(peerID)"
                            let count = windowCountPrivate[peerID] ?? 300
                            let target = messages.suffix(count).last.map { "\(contextKey)|\($0.id)" }
                            DispatchQueue.main.async {
                                if let target = target { proxy.scrollTo(target, anchor: .bottom) }
                            }
                        }
                    }
                }
            }
            .onChange(of: locationManager.selectedChannel) { newChannel in
                // When switching to a new geohash channel, scroll to the bottom
                guard privatePeer == nil else { return }
                switch newChannel {
                case .mesh:
                    break
                case .location(let ch):
                    // Reset window size
                    windowCountPublic = TransportConfig.uiWindowInitialCountPublic
                    let contextKey = "geo:\(ch.geohash)"
                    let last = viewModel.messages.suffix(windowCountPublic).last?.id
                    let target = last.map { "\(contextKey)|\($0)" }
                    isAtBottom.wrappedValue = true
                    DispatchQueue.main.async {
                        if let target = target { proxy.scrollTo(target, anchor: .bottom) }
                    }
                }
            }
            .onAppear {
                // Also check when view appears
                if let peerID = privatePeer {
                    // Try multiple times to ensure read receipts are sent
                    viewModel.markPrivateMessagesAsRead(from: peerID)
                    
                    DispatchQueue.main.asyncAfter(deadline: .now() + TransportConfig.uiReadReceiptRetryShortSeconds) {
                        viewModel.markPrivateMessagesAsRead(from: peerID)
                    }
                    
                    DispatchQueue.main.asyncAfter(deadline: .now() + TransportConfig.uiReadReceiptRetryLongSeconds) {
                        viewModel.markPrivateMessagesAsRead(from: peerID)
                    }
                }
            }
        }
        .environment(\.openURL, OpenURLAction { url in
            // Intercept custom cashu: links created in attributed text
            if let scheme = url.scheme?.lowercased(), scheme == "cashu" || scheme == "lightning" {
                #if os(iOS)
                UIApplication.shared.open(url)
                return .handled
                #else
                // On non-iOS platforms, let the system handle or ignore
                return .systemAction
                #endif
            }
            return .systemAction
        })
    }
    
    // MARK: - Input View

    @ViewBuilder
    private var inputView: some View {
        VStack(alignment: .leading, spacing: 10) {
            // @mentions autocomplete
            if viewModel.showAutocomplete && !viewModel.autocompleteSuggestions.isEmpty {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(Array(viewModel.autocompleteSuggestions.prefix(4)), id: \.self) { suggestion in
                        Button(action: {
                            _ = viewModel.completeNickname(suggestion, in: &messageText)
                        }) {
                            HStack {
                                Text(suggestion)
                                    .font(.bitchatSystem(size: 11, design: .monospaced))
                                    .foregroundColor(textColor)
                                    .fontWeight(.medium)
                                Spacer()
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 3)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .buttonStyle(.plain)
                        .padding(.horizontal, 4)
                        .padding(.vertical, 2)
                        .background(secondarySurfaceColor)
                    }
                }
                .padding(6)
                .background(elevatedSurfaceColor)
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(borderColor, lineWidth: 1)
                )
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            }

            CommandSuggestionsView(
                messageText: $messageText,
                textColor: textColor,
                backgroundColor: elevatedSurfaceColor,
                secondaryTextColor: secondaryTextColor
            )

            // Recording indicator
            if isPreparingVoiceNote || isRecordingVoiceNote {
                recordingIndicator
            }

            HStack(alignment: .center, spacing: 8) {
                TextField(
                    "",
                    text: $messageText,
                    prompt: Text(
                        String(localized: "content.input.message_placeholder", comment: "Placeholder shown in the chat composer")
                    )
                    .foregroundColor(secondaryTextColor.opacity(0.6))
                )
                .textFieldStyle(.plain)
                .font(.bitchatSystem(size: 15, weight: .medium))
                .foregroundColor(textColor)
                .focused($isTextFieldFocused)
                .autocorrectionDisabled(true)
#if os(iOS)
                .textInputAutocapitalization(.sentences)
#endif
                .submitLabel(.send)
                .onSubmit { sendMessage() }
                .padding(.vertical, 12)
                .padding(.horizontal, 14)
                .background(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(secondarySurfaceColor)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(borderColor.opacity(0.9), lineWidth: 1)
                )
                .frame(maxWidth: .infinity, alignment: .leading)
                .onChange(of: messageText) { newValue in
                    autocompleteDebounceTimer?.invalidate()
                    autocompleteDebounceTimer = Timer.scheduledTimer(withTimeInterval: 0.15, repeats: false) { [weak viewModel] _ in
                        let cursorPosition = newValue.count
                        Task { @MainActor in
                            viewModel?.updateAutocomplete(for: newValue, cursorPosition: cursorPosition)
                        }
                    }
                }

                HStack(alignment: .center, spacing: 8) {
                    if shouldShowMediaControls {
                        attachmentButton
                    }

                    sendOrMicButton
                }
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(elevatedSurfaceColor)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(borderColor, lineWidth: 1)
        )
        .shadow(color: shadowColor, radius: 18, x: 0, y: 8)
    }

    private func headerUtilityButton(
        icon: String,
        foregroundColor: Color,
        backgroundColor: Color,
        _ accessibilityLabel: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.bitchatSystem(size: usesCompactHeaderLayout ? 11 : 12, weight: .semibold))
                .foregroundColor(foregroundColor)
                .frame(width: usesCompactHeaderLayout ? 28 : 32, height: usesCompactHeaderLayout ? 28 : 32)
                .background(
                    Circle()
                        .fill(backgroundColor)
                )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(accessibilityLabel)
    }
    
    private func handleOpenURL(_ url: URL) {
        guard BitchatApp.supportsURLScheme(url.scheme) else { return }
        switch url.host {
        case "user":
            let id = url.path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
            let peerID = PeerID(str: id.removingPercentEncoding ?? id)
            selectedMessageSenderID = peerID

            if peerID.isGeoDM || peerID.isGeoChat {
                selectedMessageSender = viewModel.geohashDisplayName(for: peerID)
            } else if let name = viewModel.meshService.peerNickname(peerID: peerID) {
                selectedMessageSender = name
            } else {
                selectedMessageSender = viewModel.messages.last(where: { $0.senderPeerID == peerID && $0.sender != "system" })?.sender
            }

            if viewModel.isSelfSender(peerID: peerID, displayName: selectedMessageSender) {
                selectedMessageSender = nil
                selectedMessageSenderID = nil
            } else {
                showMessageActions = true
            }

        case "geohash":
            let gh = url.path.trimmingCharacters(in: CharacterSet(charactersIn: "/")).lowercased()
            let allowed = Set("0123456789bcdefghjkmnpqrstuvwxyz")
            guard (2...12).contains(gh.count), gh.allSatisfy({ allowed.contains($0) }) else { return }

            func levelForLength(_ len: Int) -> GeohashChannelLevel {
                switch len {
                case 0...2: return .region
                case 3...4: return .province
                case 5: return .city
                case 6: return .neighborhood
                case 7: return .block
                default: return .block
                }
            }

            let level = levelForLength(gh.count)
            let channel = GeohashChannel(level: level, geohash: gh)

            let inRegional = LocationChannelManager.shared.availableChannels.contains { $0.geohash == gh }
            if !inRegional && !LocationChannelManager.shared.availableChannels.isEmpty {
                LocationChannelManager.shared.markTeleported(for: gh, true)
            }
            LocationChannelManager.shared.select(ChannelID.location(channel))

        default:
            return
        }
    }

    private func scrollToBottom(on proxy: ScrollViewProxy,
                                privatePeer: PeerID?,
                                isAtBottom: Binding<Bool>) {
        let targetID: String? = {
            if let peer = privatePeer,
               let last = viewModel.getPrivateChatMessages(for: peer).suffix(300).last?.id {
                return "dm:\(peer)|\(last)"
            }
            let contextKey: String = {
                switch locationManager.selectedChannel {
                case .mesh: return "mesh"
                case .location(let ch): return "geo:\(ch.geohash)"
                }
            }()
            if let last = viewModel.messages.suffix(300).last?.id {
                return "\(contextKey)|\(last)"
            }
            return nil
        }()

        isAtBottom.wrappedValue = true

        DispatchQueue.main.async {
            if let targetID {
                proxy.scrollTo(targetID, anchor: .bottom)
            }
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            let secondTarget: String? = {
                if let peer = privatePeer,
                   let last = viewModel.getPrivateChatMessages(for: peer).suffix(300).last?.id {
                    return "dm:\(peer)|\(last)"
                }
                let contextKey: String = {
                    switch locationManager.selectedChannel {
                    case .mesh: return "mesh"
                    case .location(let ch): return "geo:\(ch.geohash)"
                    }
                }()
                if let last = viewModel.messages.suffix(300).last?.id {
                    return "\(contextKey)|\(last)"
                }
                return nil
            }()

            if let secondTarget {
                proxy.scrollTo(secondTarget, anchor: .bottom)
            }
        }
    }
    // MARK: - Actions
    
    private func sendMessage() {
        let trimmed = trimmedMessageText
        guard !trimmed.isEmpty else { return }

        // Clear input immediately for instant feedback
        messageText = ""

        // Defer actual send to next runloop to avoid blocking
        DispatchQueue.main.async {
            self.viewModel.sendMessage(trimmed)
        }
    }
    
    // MARK: - Sheet Content
    
    private var peopleSheetView: some View {
        ZStack {
            BitchatTheme.backgroundGradient(for: colorScheme)
                .ignoresSafeArea()

            Group {
                if viewModel.selectedPrivateChatPeer != nil {
                    privateChatSheetView
                } else {
                    peopleListSheetView
                }
            }
            .padding(12)
        }
        .foregroundColor(textColor)
        #if os(macOS)
        .frame(minWidth: 420, minHeight: 520)
        #endif
        // Present image picker from sheet context when IN a sheet (parent-child pattern)
        #if os(iOS)
        .fullScreenCover(isPresented: Binding(
            get: { showImagePicker && (showSidebar || viewModel.selectedPrivateChatPeer != nil) },
            set: { newValue in
                if !newValue {
                    showImagePicker = false
                }
            }
        )) {
            ImagePickerView(sourceType: imagePickerSourceType) { image in
                showImagePicker = false
                if let image = image {
                    Task {
                        do {
                            let processedURL = try ImageUtils.processImage(image)
                            await MainActor.run {
                                viewModel.sendImage(from: processedURL)
                            }
                        } catch {
                            SecureLogger.error("Image processing failed: \(error)", category: .session)
                        }
                    }
                }
            }
            .environmentObject(viewModel)
            .ignoresSafeArea()
        }
        #endif
        #if os(macOS)
        .sheet(isPresented: $showMacImagePicker) {
            MacImagePickerView { url in
                showMacImagePicker = false
                if let url = url {
                    Task {
                        do {
                            let processedURL = try ImageUtils.processImage(at: url)
                            await MainActor.run {
                                viewModel.sendImage(from: processedURL)
                            }
                        } catch {
                            SecureLogger.error("Image processing failed: \(error)", category: .session)
                        }
                    }
                }
            }
            .environmentObject(viewModel)
        }
        #endif
    }
    
    // MARK: - People Sheet Views
    
    private var peopleListSheetView: some View {
        VStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 16) {
                Group {
                    if usesCompactPeopleSheetLayout {
                        ZStack(alignment: .topTrailing) {
                            HStack(alignment: .top, spacing: peopleSheetHeroSpacing) {
                                ZStack {
                                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                                        .fill(peopleSheetIconBackground)
                                        .frame(width: peopleSheetIconContainerSize, height: peopleSheetIconContainerSize)

                                    Image(systemName: peopleSheetIconName)
                                        .font(.bitchatSystem(size: peopleSheetIconGlyphSize, weight: .semibold))
                                        .foregroundColor(peopleSheetIconForeground)
                                }

                                VStack(alignment: .leading, spacing: 6) {
                                    Text(peopleSheetTitle)
                                        .font(.bitchatSystem(size: peopleSheetTitleFontSize, weight: .bold, design: .rounded))
                                        .foregroundColor(textColor)
                                        .lineLimit(1)
                                        .minimumScaleFactor(0.82)
                                    Text(peopleSheetDescription)
                                        .font(.bitchatSystem(size: peopleSheetDescriptionFontSize))
                                        .foregroundColor(secondaryTextColor)
                                        .lineLimit(3)
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                                .padding(.trailing, peopleSheetActionButtonSize * (locationManager.selectedChannel == .mesh ? 2.4 : 1.3))

                                Spacer(minLength: 0)
                            }

                            HStack(spacing: peopleSheetActionSpacing) {
                                if case .mesh = locationManager.selectedChannel {
                                    peopleSheetActionButton(
                                        icon: "qrcode",
                                        accessibilityLabel: String(localized: "content.help.verification", comment: "Accessibility label for verification button"),
                                        helpText: String(localized: "content.help.verification", comment: "Help text for verification button")
                                    ) {
                                        showVerifySheet = true
                                    }
                                }
                                peopleSheetActionButton(icon: "xmark", accessibilityLabel: String(localized: "common.close", comment: "Accessibility label for close buttons")) {
                                    withAnimation(.easeInOut(duration: TransportConfig.uiAnimationMediumSeconds)) {
                                        dismiss()
                                        showSidebar = false
                                        showVerifySheet = false
                                        viewModel.endPrivateChat()
                                    }
                                }
                            }
                        }
                    } else {
                        HStack(alignment: .top, spacing: peopleSheetHeroSpacing) {
                            ZStack {
                                RoundedRectangle(cornerRadius: 20, style: .continuous)
                                    .fill(peopleSheetIconBackground)
                                    .frame(width: peopleSheetIconContainerSize, height: peopleSheetIconContainerSize)

                                Image(systemName: peopleSheetIconName)
                                    .font(.bitchatSystem(size: peopleSheetIconGlyphSize, weight: .semibold))
                                    .foregroundColor(peopleSheetIconForeground)
                            }

                            VStack(alignment: .leading, spacing: 8) {
                                Text(peopleSheetTitle)
                                    .font(.bitchatSystem(size: peopleSheetTitleFontSize, weight: .bold, design: .rounded))
                                    .foregroundColor(textColor)
                                Text(peopleSheetDescription)
                                    .font(.bitchatSystem(size: peopleSheetDescriptionFontSize))
                                    .foregroundColor(secondaryTextColor)
                                    .fixedSize(horizontal: false, vertical: true)
                            }

                            Spacer()

                            HStack(spacing: peopleSheetActionSpacing) {
                                if case .mesh = locationManager.selectedChannel {
                                    peopleSheetActionButton(
                                        icon: "qrcode",
                                        accessibilityLabel: String(localized: "content.help.verification", comment: "Accessibility label for verification button"),
                                        helpText: String(localized: "content.help.verification", comment: "Help text for verification button")
                                    ) {
                                        showVerifySheet = true
                                    }
                                }
                                peopleSheetActionButton(icon: "xmark", accessibilityLabel: String(localized: "common.close", comment: "Accessibility label for close buttons")) {
                                    withAnimation(.easeInOut(duration: TransportConfig.uiAnimationMediumSeconds)) {
                                        dismiss()
                                        showSidebar = false
                                        showVerifySheet = false
                                        viewModel.endPrivateChat()
                                    }
                                }
                            }
                        }
                    }
                }

                HStack(spacing: 8) {
                    peopleSheetBadge(text: peopleSheetSubtitle, tint: peopleSheetAccentColor, filled: true)
                    peopleSheetBadge(icon: "person.2.fill", text: peopleSheetActiveText, tint: secondaryTextColor)
                }
            }
            .padding(peopleSheetHeroPadding)
            .background(
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .fill(elevatedSurfaceColor)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .stroke(borderColor, lineWidth: 1)
            )
            .shadow(color: shadowColor, radius: 18, x: 0, y: 8)

            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    if case .location = locationManager.selectedChannel {
                        GeohashPeopleList(
                            viewModel: viewModel,
                            textColor: textColor,
                            secondaryTextColor: secondaryTextColor,
                            onTapPerson: {
                                showSidebar = true
                            }
                        )
                    } else {
                        MeshPeerList(
                            viewModel: viewModel,
                            textColor: textColor,
                            secondaryTextColor: secondaryTextColor,
                            onTapPeer: { peerID in
                                viewModel.startPrivateChat(with: peerID)
                                showSidebar = true
                            },
                            onToggleFavorite: { peerID in
                                viewModel.toggleFavorite(peerID: peerID)
                            },
                            onShowFingerprint: { peerID in
                                viewModel.showFingerprint(for: peerID)
                            }
                        )
                    }
                }
                .padding(14)
                .id(viewModel.allPeers.map { "\($0.peerID)-\($0.isConnected)" }.joined())
            }
            .background(
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .fill(peopleSheetListBackground)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .stroke(peopleSheetListBorder, lineWidth: 1)
            )
            .shadow(color: shadowColor.opacity(0.65), radius: 16, x: 0, y: 8)
        }
    }
    
    // MARK: - View Components

    private var privateChatSheetView: some View {
        VStack(spacing: 14) {
            if let privatePeerID = viewModel.selectedPrivateChatPeer {
                let headerContext = makePrivateHeaderContext(for: privatePeerID)

                HStack(spacing: 12) {
                    Button(action: {
                        withAnimation(.easeInOut(duration: TransportConfig.uiAnimationMediumSeconds)) {
                            viewModel.endPrivateChat()
                        }
                    }) {
                        Image(systemName: "chevron.left")
                            .font(.bitchatSystem(size: 12))
                            .foregroundColor(textColor)
                            .frame(width: 44, height: 44)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(
                        String(localized: "content.accessibility.back_to_main_chat", comment: "Accessibility label for returning to main chat")
                    )

                    Spacer(minLength: 0)

                    HStack(spacing: 8) {
                        privateHeaderInfo(context: headerContext, privatePeerID: privatePeerID)
                        let isFavorite = viewModel.isFavorite(peerID: headerContext.headerPeerID)

                        if !privatePeerID.isGeoDM {
                            Button(action: {
                                viewModel.toggleFavorite(peerID: headerContext.headerPeerID)
                            }) {
                                Image(systemName: isFavorite ? "star.fill" : "star")
                                    .font(.bitchatSystem(size: 14))
                                    .foregroundColor(isFavorite ? accentColor : textColor)
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel(
                                isFavorite
                                ? String(localized: "content.accessibility.remove_favorite", comment: "Accessibility label to remove a favorite")
                                : String(localized: "content.accessibility.add_favorite", comment: "Accessibility label to add a favorite")
                            )
                        }
                    }
                    .frame(maxWidth: .infinity)

                    Spacer(minLength: 0)

                    Button(action: {
                        withAnimation(.easeInOut(duration: TransportConfig.uiAnimationMediumSeconds)) {
                            viewModel.endPrivateChat()
                            showSidebar = true
                        }
                    }) {
                        Image(systemName: "xmark")
                            .font(.bitchatSystem(size: 12, weight: .semibold, design: .monospaced))
                            .frame(width: 32, height: 32)
                    }
                
                    .buttonStyle(.plain)
                    .accessibilityLabel("Close")
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .fill(elevatedSurfaceColor)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .stroke(borderColor, lineWidth: 1)
                )
            }

            messagesView(privatePeer: viewModel.selectedPrivateChatPeer, isAtBottom: $isAtBottomPrivate)
                .background(chatCanvasColor)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(
                    RoundedRectangle(cornerRadius: 28, style: .continuous)
                        .fill(chatCanvasColor)
                )
                .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 28, style: .continuous)
                        .stroke(borderColor, lineWidth: 1)
                )
            inputView
        }
        .foregroundColor(textColor)
        .highPriorityGesture(
            DragGesture(minimumDistance: 25, coordinateSpace: .local)
                .onEnded { value in
                    let horizontal = value.translation.width
                    let vertical = abs(value.translation.height)
                    guard horizontal > 80, vertical < 60 else { return }
                    withAnimation(.easeInOut(duration: TransportConfig.uiAnimationMediumSeconds)) {
                        showSidebar = true
                        viewModel.endPrivateChat()
                    }
                }
        )
    }

    private func privateHeaderInfo(context: PrivateHeaderContext, privatePeerID: PeerID) -> some View {
        Button(action: {
            viewModel.showFingerprint(for: context.headerPeerID)
        }) {
            HStack(spacing: 6) {
                if let connectionState = context.peer?.connectionState {
                    switch connectionState {
                    case .bluetoothConnected:
                        Image(systemName: "dot.radiowaves.left.and.right")
                            .font(.bitchatSystem(size: 14))
                            .foregroundColor(textColor)
                            .accessibilityLabel(String(localized: "content.accessibility.connected_mesh", comment: "Accessibility label for mesh-connected peer indicator"))
                    case .meshReachable:
                        Image(systemName: "point.3.filled.connected.trianglepath.dotted")
                            .font(.bitchatSystem(size: 14))
                            .foregroundColor(textColor)
                            .accessibilityLabel(String(localized: "content.accessibility.reachable_mesh", comment: "Accessibility label for mesh-reachable peer indicator"))
                    case .nostrAvailable:
                        Image(systemName: "globe")
                            .font(.bitchatSystem(size: 14))
                            .foregroundColor(locationAccentColor)
                            .accessibilityLabel(String(localized: "content.accessibility.available_nostr", comment: "Accessibility label for Nostr-available peer indicator"))
                    case .offline:
                        EmptyView()
                    }
                } else if viewModel.meshService.isPeerReachable(context.headerPeerID) {
                    Image(systemName: "point.3.filled.connected.trianglepath.dotted")
                        .font(.bitchatSystem(size: 14))
                        .foregroundColor(textColor)
                        .accessibilityLabel(String(localized: "content.accessibility.reachable_mesh", comment: "Accessibility label for mesh-reachable peer indicator"))
                } else if context.isNostrAvailable {
                    Image(systemName: "globe")
                        .font(.bitchatSystem(size: 14))
                        .foregroundColor(locationAccentColor)
                        .accessibilityLabel(String(localized: "content.accessibility.available_nostr", comment: "Accessibility label for Nostr-available peer indicator"))
                } else if viewModel.meshService.isPeerConnected(context.headerPeerID) || viewModel.connectedPeers.contains(context.headerPeerID) {
                    Image(systemName: "dot.radiowaves.left.and.right")
                        .font(.bitchatSystem(size: 14))
                        .foregroundColor(textColor)
                        .accessibilityLabel(String(localized: "content.accessibility.connected_mesh", comment: "Accessibility label for mesh-connected peer indicator"))
                }

                Text(context.displayName)
                    .font(.bitchatSystem(size: 16, weight: .semibold, design: .rounded))
                    .foregroundColor(textColor)

                if !privatePeerID.isGeoDM {
                    let statusPeerID = viewModel.getShortIDForNoiseKey(privatePeerID)
                    let encryptionStatus = viewModel.getEncryptionStatus(for: statusPeerID)
                    if let icon = encryptionStatus.icon {
                        Image(systemName: icon)
                            .font(.bitchatSystem(size: 14))
                            .foregroundColor(encryptionStatus == .noiseVerified ? textColor :
                                             encryptionStatus == .noiseSecured ? textColor :
                                             BitchatTheme.danger(for: colorScheme))
                            .accessibilityLabel(
                                String(
                                    format: String(localized: "content.accessibility.encryption_status", comment: "Accessibility label announcing encryption status"),
                                    locale: .current,
                                    encryptionStatus.accessibilityDescription
                                )
                            )
                    }
                }
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(
            String(
                format: String(localized: "content.accessibility.private_chat_header", comment: "Accessibility label describing the private chat header"),
                locale: .current,
                context.displayName
            )
        )
        .accessibilityHint(
            String(localized: "content.accessibility.view_fingerprint_hint", comment: "Accessibility hint for viewing encryption fingerprint")
        )
        .frame(height: headerHeight)
    }

    private func makePrivateHeaderContext(for privatePeerID: PeerID) -> PrivateHeaderContext {
        let headerPeerID = viewModel.getShortIDForNoiseKey(privatePeerID)
        let peer = viewModel.getPeer(byID: headerPeerID)

        let displayName: String = {
            if privatePeerID.isGeoDM, case .location(let ch) = locationManager.selectedChannel {
                let disp = viewModel.geohashDisplayName(for: privatePeerID)
                return "#\(ch.geohash)/@\(disp)"
            }
            if let name = peer?.displayName { return name }
            if let name = viewModel.meshService.peerNickname(peerID: headerPeerID) { return name }
            if let fav = FavoritesPersistenceService.shared.getFavoriteStatus(for: Data(hexString: headerPeerID.id) ?? Data()),
               !fav.peerNickname.isEmpty { return fav.peerNickname }
            if headerPeerID.id.count == 16 {
                let candidates = viewModel.identityManager.getCryptoIdentitiesByPeerIDPrefix(headerPeerID)
                if let id = candidates.first,
                   let social = viewModel.identityManager.getSocialIdentity(for: id.fingerprint) {
                    if let pet = social.localPetname, !pet.isEmpty { return pet }
                    if !social.claimedNickname.isEmpty { return social.claimedNickname }
                }
            } else if let keyData = headerPeerID.noiseKey {
                let fp = keyData.sha256Fingerprint()
                if let social = viewModel.identityManager.getSocialIdentity(for: fp) {
                    if let pet = social.localPetname, !pet.isEmpty { return pet }
                    if !social.claimedNickname.isEmpty { return social.claimedNickname }
                }
            }
            return String(localized: "common.unknown", comment: "Fallback label for unknown peer")
        }()

        let isNostrAvailable: Bool = {
            guard let connectionState = peer?.connectionState else {
                if let noiseKey = Data(hexString: headerPeerID.id),
                   let favoriteStatus = FavoritesPersistenceService.shared.getFavoriteStatus(for: noiseKey),
                   favoriteStatus.isMutual {
                    return true
                }
                return false
            }
            return connectionState == .nostrAvailable
        }()

        return PrivateHeaderContext(
            headerPeerID: headerPeerID,
            peer: peer,
            displayName: displayName,
            isNostrAvailable: isNostrAvailable
        )
    }

    // Compute channel-aware people count and color for toolbar (cross-platform)
    private func channelPeopleCountAndColor() -> (Int, Color) {
        switch locationManager.selectedChannel {
        case .location:
            let n = viewModel.geohashPeople.count
            return (n, n > 0 ? locationAccentColor : secondaryTextColor)
        case .mesh:
            let counts = viewModel.allPeers.reduce(into: (others: 0, mesh: 0)) { counts, peer in
                guard peer.peerID != viewModel.meshService.myPeerID else { return }
                if peer.isConnected { counts.mesh += 1; counts.others += 1 }
                else if peer.isReachable { counts.others += 1 }
            }
            let color: Color = counts.mesh > 0 ? meshAccentColor : secondaryTextColor
            return (counts.others, color)
        }
    }

    
    private var mainHeaderView: some View {
        let cc = channelPeopleCountAndColor()
        let headerCountColor: Color = cc.1
        let headerOtherPeersCount = currentChannelPeopleCount
        let badgeText: String = {
            switch locationManager.selectedChannel {
            case .mesh: return usesCompactHeaderLayout ? "mesh" : "#mesh"
            case .location(let ch): return usesCompactHeaderLayout ? ch.geohash : "#\(ch.geohash)"
            }
        }()
        let badgeColor: Color = {
            switch locationManager.selectedChannel {
            case .mesh:
                return meshAccentColor
            case .location:
                return locationAccentColor
            }
        }()

        return HStack(alignment: .center, spacing: headerRowSpacing) {
            Text(verbatim: "beechat")
                .font(.bitchatWordmark(size: headerWordmarkSize, weight: .bold))
                .tracking(-0.3)
                .foregroundColor(textColor)
                .lineLimit(1)
                .minimumScaleFactor(0.72)
                .layoutPriority(1)
                .contentShape(Rectangle())
                .onTapGesture(count: 3) {
                    viewModel.panicClearAllData()
                }
                .onTapGesture(count: 1) {
                    showAppInfo = true
                }

            Button(action: { showLocationChannelsSheet = true }) {
                HStack(spacing: 8) {
                    HeaderRadarIndicatorView(tint: badgeColor)
                        .accessibilityHidden(true)

                    Text(badgeText)
                        .font(.bitchatSystem(size: headerBadgeFontSize, weight: .semibold, design: .rounded))
                        .foregroundColor(badgeColor)
                        .lineLimit(headerLineLimit)
                }
                .fixedSize(horizontal: true, vertical: false)
                .padding(.horizontal, headerCapsuleHorizontalPadding)
                .padding(.vertical, headerCapsuleVerticalPadding)
                .background(
                    Capsule(style: .continuous)
                        .fill(badgeColor.opacity(colorScheme == .dark ? 0.16 : 0.12))
                )
                .overlay(
                    Capsule(style: .continuous)
                        .stroke(badgeColor.opacity(colorScheme == .dark ? 0.48 : 0.26), lineWidth: 1)
                )
            }
            .buttonStyle(.plain)
            .accessibilityLabel(
                String(localized: "content.accessibility.location_channels", comment: "Accessibility label for the location channels button")
            )

            Button(action: {
                withAnimation(.easeInOut(duration: TransportConfig.uiAnimationMediumSeconds)) {
                    showSidebar.toggle()
                }
            }) {
                HStack(spacing: headerCountSpacing) {
                    Image(systemName: "person.2.fill")
                        .font(.system(size: compactHeaderPeerIconSize, weight: .semibold))
                        .accessibilityHidden(true)
                    Text("\(headerOtherPeersCount)")
                        .font(.system(size: compactHeaderPeerCountFontSize, weight: .semibold, design: .rounded))
                        .accessibilityHidden(true)
                }
                .foregroundColor(headerCountColor)
                .padding(.horizontal, headerCapsuleHorizontalPadding)
                .padding(.vertical, headerCapsuleVerticalPadding)
                .background(
                    Capsule(style: .continuous)
                        .fill(secondarySurfaceColor)
                )
                .overlay(
                    Capsule(style: .continuous)
                        .stroke(borderColor, lineWidth: 1)
                )
            }
            .buttonStyle(.plain)
            .accessibilityLabel(
                String(
                    format: String(localized: "content.accessibility.people_count", comment: "Accessibility label announcing number of people in header"),
                    locale: .current,
                    headerOtherPeersCount
                )
            )

            Spacer(minLength: headerSpacerMinLength)

            HStack(alignment: .center, spacing: usesCompactHeaderLayout ? 6 : 8) {
                if viewModel.hasAnyUnreadMessages {
                    headerUtilityButton(
                        icon: "envelope.fill",
                        foregroundColor: accentColor,
                        backgroundColor: BitchatTheme.accentSoft(for: colorScheme),
                        String(localized: "content.accessibility.open_unread_private_chat", comment: "Accessibility label for the unread private chat button")
                    ) {
                        viewModel.openMostRelevantPrivateChat()
                    }
                }

                if case .mesh = locationManager.selectedChannel, locationManager.permissionState == .authorized {
                    headerUtilityButton(
                        icon: "note.text",
                        foregroundColor: accentColor,
                        backgroundColor: BitchatTheme.accentSoft(for: colorScheme),
                        String(localized: "content.accessibility.location_notes", comment: "Accessibility label for location notes button")
                    ) {
                        LocationChannelManager.shared.enableLocationChannels()
                        LocationChannelManager.shared.refreshChannels()
                        notesGeohash = LocationChannelManager.shared.availableChannels.first(where: { $0.level == .building })?.geohash
                        showLocationNotes = true
                    }
                }

                if case .location(let ch) = locationManager.selectedChannel {
                    headerUtilityButton(
                        icon: bookmarks.isBookmarked(ch.geohash) ? "bookmark.fill" : "bookmark",
                        foregroundColor: bookmarks.isBookmarked(ch.geohash) ? accentColor : secondaryTextColor,
                        backgroundColor: secondarySurfaceColor,
                        String(
                            format: String(localized: "content.accessibility.toggle_bookmark", comment: "Accessibility label for toggling a geohash bookmark"),
                            locale: .current,
                            ch.geohash
                        )
                    ) {
                        bookmarks.toggle(ch.geohash)
                    }
                }

                HStack(spacing: 8) {
                    Text(verbatim: "@")
                        .font(.bitchatSystem(size: headerNicknamePrefixFontSize, weight: .semibold))
                        .foregroundColor(accentColor)

                    TextField("content.input.nickname_placeholder", text: $viewModel.nickname)
                        .textFieldStyle(.plain)
                        .font(.bitchatSystem(size: headerNicknameFontSize, weight: .medium))
                        .frame(maxWidth: headerNicknameMaxWidth)
                        .foregroundColor(textColor)
                        .focused($isNicknameFieldFocused)
                        .autocorrectionDisabled(true)
                        #if os(iOS)
                        .textInputAutocapitalization(.never)
                        #endif
                        .onChange(of: isNicknameFieldFocused) { isFocused in
                            if !isFocused {
                                viewModel.validateAndSaveNickname()
                            }
                        }
                        .onSubmit {
                            viewModel.validateAndSaveNickname()
                        }
                }
                .padding(.horizontal, usesCompactHeaderLayout ? 10 : 12)
                .padding(.vertical, headerCapsuleVerticalPadding)
                .background(
                    Capsule(style: .continuous)
                        .fill(secondarySurfaceColor)
                )
                .overlay(
                    Capsule(style: .continuous)
                        .stroke(borderColor, lineWidth: 1)
                )
            }
        }
        .padding(.horizontal, headerOuterHorizontalPadding)
        .padding(.vertical, headerOuterVerticalPadding)
        .background(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(elevatedSurfaceColor)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .stroke(borderColor, lineWidth: 1)
        )
        .sheet(isPresented: $showVerifySheet) {
            VerificationSheetView(isPresented: $showVerifySheet)
                .environmentObject(viewModel)
        }
        .sheet(isPresented: $showLocationChannelsSheet) {
            LocationChannelsSheet(isPresented: $showLocationChannelsSheet)
                .environmentObject(viewModel)
                .onAppear { viewModel.isLocationChannelsSheetPresented = true }
                .onDisappear { viewModel.isLocationChannelsSheetPresented = false }
        }
        .sheet(isPresented: $showLocationNotes, onDismiss: {
            notesGeohash = nil
        }) {
            Group {
                if let gh = notesGeohash ?? LocationChannelManager.shared.availableChannels.first(where: { $0.level == .building })?.geohash {
                    LocationNotesView(geohash: gh)
                        .environmentObject(viewModel)
                } else {
                    VStack(spacing: 12) {
                        HStack {
                            Text("content.notes.title")
                                .font(.bitchatSystem(size: 16, weight: .bold, design: .monospaced))
                            Spacer()
                            Button(action: { showLocationNotes = false }) {
                                Image(systemName: "xmark")
                                    .font(.bitchatSystem(size: 13, weight: .semibold, design: .monospaced))
                                    .foregroundColor(textColor)
                                    .frame(width: 32, height: 32)
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel(String(localized: "common.close", comment: "Accessibility label for close buttons"))
                        }
                        .frame(height: headerHeight)
                        .padding(.horizontal, 12)
                        .background(backgroundColor.opacity(0.95))
                        Text("content.notes.location_unavailable")
                            .font(.bitchatSystem(size: 14, design: .monospaced))
                            .foregroundColor(secondaryTextColor)
                        Button("content.location.enable") {
                            LocationChannelManager.shared.enableLocationChannels()
                            LocationChannelManager.shared.refreshChannels()
                        }
                        .buttonStyle(.bordered)
                        Spacer()
                    }
                    .background(backgroundColor)
                    .foregroundColor(textColor)
                    // per-sheet global onChange added below
                }
            }
            .onAppear {
                // Ensure we are authorized and start live location updates (distance-filtered)
                LocationChannelManager.shared.enableLocationChannels()
                LocationChannelManager.shared.beginLiveRefresh()
            }
            .onDisappear {
                LocationChannelManager.shared.endLiveRefresh()
            }
            .onChange(of: locationManager.availableChannels) { channels in
                if let current = channels.first(where: { $0.level == .building })?.geohash,
                    notesGeohash != current {
                    notesGeohash = current
                    #if os(iOS)
                    // Light taptic when geohash changes while the sheet is open
                    let generator = UIImpactFeedbackGenerator(style: .light)
                    generator.prepare()
                    generator.impactOccurred()
                    #endif
                }
            }
        }
        .onAppear {
            if case .mesh = locationManager.selectedChannel,
               locationManager.permissionState == .authorized,
               LocationChannelManager.shared.availableChannels.isEmpty {
                LocationChannelManager.shared.refreshChannels()
            }
        }
        .onChange(of: locationManager.selectedChannel) { _ in
            if case .mesh = locationManager.selectedChannel,
               locationManager.permissionState == .authorized,
               LocationChannelManager.shared.availableChannels.isEmpty {
                LocationChannelManager.shared.refreshChannels()
            }
        }
        .onChange(of: locationManager.permissionState) { _ in
            if case .mesh = locationManager.selectedChannel,
               locationManager.permissionState == .authorized,
               LocationChannelManager.shared.availableChannels.isEmpty {
                LocationChannelManager.shared.refreshChannels()
            }
        }
        .alert("content.alert.screenshot.title", isPresented: $viewModel.showScreenshotPrivacyWarning) {
            Button("common.ok", role: .cancel) {}
        } message: {
            Text("content.alert.screenshot.message")
        }
        .background(appBackgroundColor)
    }

}

// MARK: - Helper Views

// Rounded payment chip button
//

private enum MessageMedia {
    case voice(URL)
    case image(URL)

    var url: URL {
        switch self {
        case .voice(let url), .image(let url):
            return url
        }
    }
}

private extension ContentView {
    func mediaAttachment(for message: BitchatMessage) -> MessageMedia? {
        guard let baseDirectory = applicationFilesDirectory() else { return nil }

        // Extract filename from message content
        func url(from prefix: String, subdirectory: String) -> URL? {
            guard message.content.hasPrefix(prefix) else { return nil }
            let filename = String(message.content.dropFirst(prefix.count)).trimmingCharacters(in: .whitespacesAndNewlines)
            guard !filename.isEmpty else { return nil }

            // Construct URL directly without fileExists check (avoids blocking disk I/O in view body)
            // Files are checked during playback/display, so missing files fail gracefully
            let directory = baseDirectory.appendingPathComponent(subdirectory, isDirectory: true)
            return directory.appendingPathComponent(filename)
        }

        // Try outgoing first (most common for sent media), fall back to incoming
        if message.content.hasPrefix("[voice] ") {
            let filename = String(message.content.dropFirst("[voice] ".count)).trimmingCharacters(in: .whitespacesAndNewlines)
            guard !filename.isEmpty else { return nil }
            // Check outgoing first for sent messages, incoming for received
            let subdir = message.sender == viewModel.nickname ? "voicenotes/outgoing" : "voicenotes/incoming"
            let url = baseDirectory.appendingPathComponent(subdir, isDirectory: true).appendingPathComponent(filename)
            return .voice(url)
        }
        if message.content.hasPrefix("[image] ") {
            let filename = String(message.content.dropFirst("[image] ".count)).trimmingCharacters(in: .whitespacesAndNewlines)
            guard !filename.isEmpty else { return nil }
            let subdir = message.sender == viewModel.nickname ? "images/outgoing" : "images/incoming"
            let url = baseDirectory.appendingPathComponent(subdir, isDirectory: true).appendingPathComponent(filename)
            return .image(url)
        }
        return nil
    }

    func mediaSendState(for message: BitchatMessage, mediaURL: URL) -> (isSending: Bool, progress: Double?, canCancel: Bool) {
        var isSending = false
        var progress: Double?
        if let status = message.deliveryStatus {
            switch status {
            case .sending:
                isSending = true
                progress = 0
            case .partiallyDelivered(let reached, let total):
                if total > 0 {
                    isSending = true
                    progress = Double(reached) / Double(total)
                }
            case .sent, .read, .delivered, .failed:
                break
            }
        }
        let isOutgoing = mediaURL.path.contains("/outgoing/")
        let canCancel = isSending && isOutgoing
        let clamped = progress.map { max(0, min(1, $0)) }
        return (isSending, isSending ? clamped : nil, canCancel)
    }

    @ViewBuilder
    private func messageRow(for message: BitchatMessage) -> some View {
        if let session = viewModel.snakeSession(forInviteMessageID: message.id) {
            SnakeInviteCardView(session: session)
        } else if let session = viewModel.pongSession(forInviteMessageID: message.id) {
            PongInviteCardView(session: session)
        } else if message.sender == "system" {
            systemMessageRow(message)
        } else if let media = mediaAttachment(for: message) {
            mediaMessageRow(message: message, media: media)
        } else {
            TextMessageView(message: message, expandedMessageIDs: $expandedMessageIDs)
        }
    }

    @ViewBuilder
    private func systemMessageRow(_ message: BitchatMessage) -> some View {
        Text(viewModel.formatMessageAsText(message, colorScheme: colorScheme))
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(BitchatTheme.systemFill(for: colorScheme))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(borderColor.opacity(0.8), lineWidth: 1)
            )
    }

    @ViewBuilder
    private func mediaMessageRow(message: BitchatMessage, media: MessageMedia) -> some View {
        let mediaURL = media.url
        let state = mediaSendState(for: message, mediaURL: mediaURL)
        let isOutgoing = mediaURL.path.contains("/outgoing/")
        let isAuthoredByUs = isOutgoing || (message.senderPeerID == viewModel.meshService.myPeerID)
        let shouldBlurImage = !isAuthoredByUs
        let cancelAction: (() -> Void)? = state.canCancel ? { viewModel.cancelMediaSend(messageID: message.id) } : nil
        let bubbleFill = BitchatTheme.messageFill(for: colorScheme, isSelf: isAuthoredByUs)

        VStack(alignment: .leading, spacing: 2) {
            HStack(alignment: .center, spacing: 4) {
                Text(viewModel.formatMessageHeader(message, colorScheme: colorScheme, compactPhone: usesCompactChatTypography))
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
                if message.isPrivate && message.sender == viewModel.nickname,
                   let status = message.deliveryStatus {
                    DeliveryStatusView(status: status)
                        .padding(.leading, 4)
                }
            }

            Group {
                switch media {
                case .voice(let url):
                    VoiceNoteView(
                        url: url,
                        isSending: state.isSending,
                        sendProgress: state.progress,
                        onCancel: cancelAction
                    )
                case .image(let url):
                    BlockRevealImageView(
                        url: url,
                        revealProgress: state.progress,
                        isSending: state.isSending,
                        onCancel: cancelAction,
                        initiallyBlurred: shouldBlurImage,
                        onOpen: {
                            if !state.isSending {
                                imagePreviewURL = url
                            }
                        },
                        onDelete: shouldBlurImage ? {
                            viewModel.deleteMediaMessage(messageID: message.id)
                        } : nil
                    )
                    .frame(maxWidth: 280)
                }
            }
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(bubbleFill)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(borderColor.opacity(0.9), lineWidth: isAuthoredByUs ? 0 : 1)
        )
        .padding(.vertical, 4)
    }

    private func expandWindow(ifNeededFor message: BitchatMessage,
                              allMessages: [BitchatMessage],
                              privatePeer: PeerID?,
                              proxy: ScrollViewProxy) {
        let step = TransportConfig.uiWindowStepCount
        let contextKey: String = {
            if let peer = privatePeer { return "dm:\(peer)" }
            switch locationManager.selectedChannel {
            case .mesh: return "mesh"
            case .location(let ch): return "geo:\(ch.geohash)"
            }
        }()
        let preserveID = "\(contextKey)|\(message.id)"

        if let peer = privatePeer {
            let current = windowCountPrivate[peer] ?? TransportConfig.uiWindowInitialCountPrivate
            let newCount = min(allMessages.count, current + step)
            guard newCount != current else { return }
            windowCountPrivate[peer] = newCount
            DispatchQueue.main.async {
                proxy.scrollTo(preserveID, anchor: .top)
            }
        } else {
            let current = windowCountPublic
            let newCount = min(allMessages.count, current + step)
            guard newCount != current else { return }
            windowCountPublic = newCount
            DispatchQueue.main.async {
                proxy.scrollTo(preserveID, anchor: .top)
            }
        }
    }

    var recordingIndicator: some View {
        HStack(spacing: 12) {
            Image(systemName: "waveform.circle.fill")
                .foregroundColor(accentColor)
                .font(.bitchatSystem(size: 20))
            Text("recording \(formattedRecordingDuration())", comment: "Voice note recording duration indicator")
                .font(.bitchatSystem(size: 13, weight: .semibold))
                .foregroundColor(textColor)
            Spacer()
            Button(action: cancelVoiceRecording) {
                Label("Cancel", systemImage: "xmark.circle")
                    .labelStyle(.iconOnly)
                    .font(.bitchatSystem(size: 18))
                    .foregroundColor(accentColor)
            }
            .buttonStyle(.plain)
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(BitchatTheme.accentSoft(for: colorScheme))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(borderColor, lineWidth: 1)
        )
    }

    private var trimmedMessageText: String {
        messageText.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var shouldShowMediaControls: Bool {
        if let peer = viewModel.selectedPrivateChatPeer, !(peer.isGeoDM || peer.isGeoChat) {
            return true
        }
        switch locationManager.selectedChannel {
        case .mesh:
            return true
        case .location:
            return false
        }
    }

    private var shouldShowVoiceControl: Bool {
        if let peer = viewModel.selectedPrivateChatPeer, !(peer.isGeoDM || peer.isGeoChat) {
            return true
        }
        switch locationManager.selectedChannel {
        case .mesh:
            return true
        case .location:
            return false
        }
    }

    private var composerAccentColor: Color {
        accentColor
    }

    private var composerButtonIconColor: Color {
        Color.white.opacity(0.98)
    }

    private func composerIconButton(
        systemName: String,
        foregroundColor: Color,
        backgroundColor: Color,
        iconSize: CGFloat = 16
    ) -> some View {
        Image(systemName: systemName)
            .font(.bitchatSystem(size: iconSize, weight: .semibold))
            .foregroundColor(foregroundColor)
            .frame(width: 36, height: 36)
            .background(
                Circle()
                    .fill(backgroundColor)
            )
            .contentShape(Circle())
    }

    var attachmentButton: some View {
        #if os(iOS)
        composerIconButton(
            systemName: "camera.fill",
            foregroundColor: composerButtonIconColor,
            backgroundColor: composerAccentColor
        )
            .onTapGesture {
                // Tap = Photo Library
                imagePickerSourceType = .photoLibrary
                showImagePicker = true
            }
            .onLongPressGesture(minimumDuration: 0.3) {
                // Long press = Camera
                imagePickerSourceType = .camera
                showImagePicker = true
            }
            .accessibilityLabel("Tap for library, long press for camera")
        #else
        Button(action: { showMacImagePicker = true }) {
            composerIconButton(
                systemName: "photo.fill",
                foregroundColor: composerButtonIconColor,
                backgroundColor: composerAccentColor
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Choose photo")
        #endif
    }

    @ViewBuilder
    var sendOrMicButton: some View {
        let hasText = !trimmedMessageText.isEmpty
        if shouldShowVoiceControl {
            ZStack {
                micButtonView
                    .opacity(hasText ? 0 : 1)
                    .allowsHitTesting(!hasText)
                sendButtonView(enabled: hasText)
                    .opacity(hasText ? 1 : 0)
                    .allowsHitTesting(hasText)
            }
            .frame(width: 36, height: 36)
        } else {
            sendButtonView(enabled: hasText)
                .frame(width: 36, height: 36)
        }
    }

    private var micButtonView: some View {
        let tint = (isRecordingVoiceNote || isPreparingVoiceNote)
            ? BitchatTheme.danger(for: colorScheme)
            : composerAccentColor

        return composerIconButton(
            systemName: "mic.fill",
            foregroundColor: (isRecordingVoiceNote || isPreparingVoiceNote) ? Color.white.opacity(0.98) : composerButtonIconColor,
            backgroundColor: tint
        )
            .overlay(
                Color.clear
                    .contentShape(Circle())
                    .gesture(
                        DragGesture(minimumDistance: 0)
                            .onChanged { _ in startVoiceRecording() }
                            .onEnded { _ in finishVoiceRecording(send: true) }
                    )
            )
            .accessibilityLabel("Hold to record a voice note")
    }

    private func sendButtonView(enabled: Bool) -> some View {
        let activeColor = composerAccentColor
        return Button(action: sendMessage) {
            composerIconButton(
                systemName: "arrow.up",
                foregroundColor: enabled ? composerButtonIconColor : secondaryTextColor.opacity(0.78),
                backgroundColor: enabled ? activeColor : secondarySurfaceColor,
                iconSize: 15
            )
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
        .accessibilityLabel(
            String(localized: "content.accessibility.send_message", comment: "Accessibility label for the send message button")
        )
        .accessibilityHint(
            enabled
            ? String(localized: "content.accessibility.send_hint_ready", comment: "Hint prompting the user to send the message")
            : String(localized: "content.accessibility.send_hint_empty", comment: "Hint prompting the user to enter a message")
        )
    }

    func formattedRecordingDuration() -> String {
        let clamped = max(0, recordingDuration)
        let totalMilliseconds = Int((clamped * 1000).rounded())
        let minutes = totalMilliseconds / 60_000
        let seconds = (totalMilliseconds % 60_000) / 1_000
        let centiseconds = (totalMilliseconds % 1_000) / 10
        return String(format: "%02d:%02d.%02d", minutes, seconds, centiseconds)
    }

    func startVoiceRecording() {
        guard shouldShowVoiceControl else { return }
        guard !isRecordingVoiceNote && !isPreparingVoiceNote else { return }
        isPreparingVoiceNote = true
        Task { @MainActor in
            let granted = await VoiceRecorder.shared.requestPermission()
            guard granted else {
                isPreparingVoiceNote = false
                recordingAlertMessage = "Microphone access is required to record voice notes."
                showRecordingAlert = true
                return
            }
            do {
                _ = try VoiceRecorder.shared.startRecording()
                recordingDuration = 0
                recordingStartDate = Date()
                recordingTimer?.invalidate()
                recordingTimer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { _ in
                    if let start = recordingStartDate {
                        recordingDuration = Date().timeIntervalSince(start)
                    }
                }
                if let timer = recordingTimer {
                    RunLoop.main.add(timer, forMode: .common)
                }
                isPreparingVoiceNote = false
                isRecordingVoiceNote = true
            } catch {
                SecureLogger.error("Voice recording failed to start: \(error)", category: .session)
                recordingAlertMessage = "Could not start recording."
                showRecordingAlert = true
                VoiceRecorder.shared.cancelRecording()
                isPreparingVoiceNote = false
                isRecordingVoiceNote = false
                recordingStartDate = nil
            }
        }
    }

    func finishVoiceRecording(send: Bool) {
        if isPreparingVoiceNote {
            isPreparingVoiceNote = false
            VoiceRecorder.shared.cancelRecording()
            return
        }
        guard isRecordingVoiceNote else { return }
        isRecordingVoiceNote = false
        recordingTimer?.invalidate()
        recordingTimer = nil
        if let start = recordingStartDate {
            recordingDuration = Date().timeIntervalSince(start)
        }
        recordingStartDate = nil
        if send {
            let minimumDuration: TimeInterval = 1.0
            VoiceRecorder.shared.stopRecording { url in
                DispatchQueue.main.async {
                    guard
                        let url = url,
                        let attributes = try? FileManager.default.attributesOfItem(atPath: url.path),
                        let fileSize = attributes[.size] as? NSNumber,
                        fileSize.intValue > 0,
                        recordingDuration >= minimumDuration
                    else {
                        if let url = url {
                            try? FileManager.default.removeItem(at: url)
                        }
                        recordingAlertMessage = recordingDuration < minimumDuration
                            ? "Recording is too short."
                            : "Recording failed to save."
                        showRecordingAlert = true
                        return
                    }
                    viewModel.sendVoiceNote(at: url)
                }
            }
        } else {
            VoiceRecorder.shared.cancelRecording()
        }
    }

    func cancelVoiceRecording() {
        if isPreparingVoiceNote || isRecordingVoiceNote {
            finishVoiceRecording(send: false)
        }
    }

    func handleImportResult(_ result: Result<[URL], Error>, handler: @escaping (URL) async -> Void) {
        switch result {
        case .success(let urls):
            guard let url = urls.first else { return }
            let needsStop = url.startAccessingSecurityScopedResource()
            Task {
                defer {
                    if needsStop {
                        url.stopAccessingSecurityScopedResource()
                    }
                }
                await handler(url)
            }
        case .failure(let error):
            SecureLogger.error("Media import failed: \(error)", category: .session)
        }
    }


    func applicationFilesDirectory() -> URL? {
        // Cache the directory lookup to avoid repeated FileManager calls during view rendering
        struct Cache {
            static var cachedURL: URL?
            static var didAttempt = false
        }

        if Cache.didAttempt {
            return Cache.cachedURL
        }

        do {
            let base = try FileManager.default.url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
            let filesDir = base.appendingPathComponent("files", isDirectory: true)
            try FileManager.default.createDirectory(at: filesDir, withIntermediateDirectories: true, attributes: nil)
            Cache.cachedURL = filesDir
            Cache.didAttempt = true
            return filesDir
        } catch {
            SecureLogger.error("Failed to resolve application files directory: \(error)", category: .session)
            Cache.didAttempt = true
            return nil
        }
    }
}

//

struct ImagePreviewView: View {
    let url: URL

    @Environment(\.dismiss) private var dismiss
    #if os(iOS)
    @State private var showExporter = false
    @State private var platformImage: UIImage?
    #else
    @State private var platformImage: NSImage?
    #endif

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            VStack {
                Spacer()
                if let image = platformImage {
                    #if os(iOS)
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .padding()
                    #else
                    Image(nsImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .padding()
                    #endif
                } else {
                    ProgressView()
                        .progressViewStyle(.circular)
                        .tint(.white)
                }
                Spacer()
                HStack {
                    Button(action: { dismiss() }) {
                        Text("close", comment: "Button to dismiss fullscreen media viewer")
                            .font(.bitchatSystem(size: 15, weight: .semibold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(RoundedRectangle(cornerRadius: 12).stroke(Color.white.opacity(0.5), lineWidth: 1))
                    }
                    Spacer()
                    Button(action: saveCopy) {
                        Text("save", comment: "Button to save media to device")
                            .font(.bitchatSystem(size: 15, weight: .semibold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(RoundedRectangle(cornerRadius: 12).fill(BitchatTheme.accent(for: .dark).opacity(0.82)))
                    }
                }
                .padding([.horizontal, .bottom], 24)
            }
        }
        .onAppear(perform: loadImage)
        #if os(iOS)
        .sheet(isPresented: $showExporter) {
            FileExportWrapper(url: url)
        }
        #endif
    }

    private func loadImage() {
        DispatchQueue.global(qos: .userInitiated).async {
            #if os(iOS)
            guard let image = UIImage(contentsOfFile: url.path) else { return }
            #else
            guard let image = NSImage(contentsOf: url) else { return }
            #endif
            DispatchQueue.main.async {
                self.platformImage = image
            }
        }
    }

    private func saveCopy() {
        #if os(iOS)
        showExporter = true
        #else
        Task { @MainActor in
            let panel = NSSavePanel()
            panel.canCreateDirectories = true
            panel.nameFieldStringValue = url.lastPathComponent
            panel.prompt = "save"
            if panel.runModal() == .OK, let destination = panel.url {
                do {
                    if FileManager.default.fileExists(atPath: destination.path) {
                        try FileManager.default.removeItem(at: destination)
                    }
                    try FileManager.default.copyItem(at: url, to: destination)
                } catch {
                    SecureLogger.error("Failed to save image preview copy: \(error)", category: .session)
                }
            }
        }
        #endif
    }

    #if os(iOS)
    private struct FileExportWrapper: UIViewControllerRepresentable {
        let url: URL

        func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
            let controller = UIDocumentPickerViewController(forExporting: [url])
            controller.shouldShowFileExtensions = true
            return controller
        }

        func updateUIViewController(_ uiViewController: UIDocumentPickerViewController, context: Context) {}
    }
#endif
}

#if os(iOS)
// MARK: - Image Picker (Camera or Photo Library)
struct ImagePickerView: UIViewControllerRepresentable {
    let sourceType: UIImagePickerController.SourceType
    let completion: (UIImage?) -> Void

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = sourceType
        picker.delegate = context.coordinator
        picker.allowsEditing = false

        // Use standard full screen - iOS handles safe areas automatically
        picker.modalPresentationStyle = .fullScreen

        // Force dark mode to make safe area bars black instead of white
        picker.overrideUserInterfaceStyle = .dark

        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(completion: completion)
    }

    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let completion: (UIImage?) -> Void

        init(completion: @escaping (UIImage?) -> Void) {
            self.completion = completion
        }

        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            let image = info[.originalImage] as? UIImage
            completion(image)
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            completion(nil)
        }
    }
}
#endif

#if os(macOS)
// MARK: - macOS Image Picker
struct MacImagePickerView: View {
    let completion: (URL?) -> Void
    @Environment(\.colorScheme) private var colorScheme

    private var surfaceColor: Color { BitchatTheme.elevatedSurface(for: colorScheme) }
    private var cardColor: Color { BitchatTheme.secondarySurface(for: colorScheme) }
    private var borderColor: Color { BitchatTheme.border(for: colorScheme) }
    private var shadowColor: Color { BitchatTheme.shadow(for: colorScheme) }
    private var accentColor: Color { BitchatTheme.accent(for: colorScheme) }
    private var accentSoftColor: Color { BitchatTheme.accentSoft(for: colorScheme) }
    private var textColor: Color { BitchatTheme.primaryText(for: colorScheme) }
    private var secondaryTextColor: Color { BitchatTheme.secondaryText(for: colorScheme) }

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            HStack(alignment: .center, spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(accentSoftColor)
                        .frame(width: 56, height: 56)

                    Image(systemName: "photo.on.rectangle.angled")
                        .font(.system(size: 24, weight: .semibold))
                        .foregroundColor(accentColor)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("Choose an image")
                        .font(.bitchatSystem(size: 27, weight: .bold, design: .rounded))
                        .foregroundColor(textColor)

                    Text("Pick a photo to share with this chat.")
                        .font(.bitchatSystem(size: 15, weight: .medium))
                        .foregroundColor(secondaryTextColor)
                }

                Spacer(minLength: 0)
            }

            HStack(alignment: .center, spacing: 10) {
                Image(systemName: "sparkles.tv")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(accentColor)

                Text("PNG, JPEG, and HEIC images are supported.")
                    .font(.bitchatSystem(size: 14, weight: .medium))
                    .foregroundColor(secondaryTextColor)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(cardColor)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(borderColor, lineWidth: 1)
            )

            HStack(spacing: 12) {
                Button(action: { completion(nil) }) {
                    Text("Cancel")
                        .font(.bitchatSystem(size: 15, weight: .semibold))
                        .foregroundColor(textColor)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .fill(cardColor)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .stroke(borderColor, lineWidth: 1)
                        )
                }
                .buttonStyle(.plain)
                .keyboardShortcut(.cancelAction)

                Button(action: openImagePanel) {
                    Label("Select Image", systemImage: "photo")
                        .font(.bitchatSystem(size: 15, weight: .semibold))
                        .foregroundColor(colorScheme == .dark ? .black : .white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .fill(accentColor)
                        )
                }
                .buttonStyle(.plain)
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(28)
        .frame(width: 460)
        .background(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(surfaceColor)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .stroke(borderColor, lineWidth: 1)
        )
        .shadow(color: shadowColor, radius: 18, x: 0, y: 10)
        .padding(20)
    }

    private func openImagePanel() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.allowedContentTypes = [.image, .png, .jpeg, .heic]
        panel.message = "Choose an image to send"
        completion(panel.runModal() == .OK ? panel.url : nil)
    }
}
#endif
