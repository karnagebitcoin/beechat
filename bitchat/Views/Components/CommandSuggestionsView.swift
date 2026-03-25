//
//  CommandSuggestionsView.swift
//  bitchat
//
//  Created by Islam on 29/10/2025.
//

import SwiftUI

struct CommandSuggestionsView: View {
    @EnvironmentObject private var viewModel: ChatViewModel
    @ObservedObject private var locationManager = LocationChannelManager.shared
    
    @Binding var messageText: String
    
    let textColor: Color
    let backgroundColor: Color
    let secondaryTextColor: Color
    
    private var filteredCommands: [CommandInfo] {
        guard messageText.hasPrefix("/") && !messageText.contains(" ") else { return [] }
        let isGeoPublic = locationManager.selectedChannel.isLocation
        let isGeoDM = viewModel.selectedPrivateChatPeer?.isGeoDM == true
        return CommandInfo.all(isGeoPublic: isGeoPublic, isGeoDM: isGeoDM).filter { command in
            command.alias.starts(with: messageText.lowercased())
        }
    }
    
    var body: some View {
        Group {
            if filteredCommands.isEmpty {
                EmptyView()
            } else {
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(filteredCommands) { command in
                        Button {
                            messageText = command.alias + " "
                        } label: {
                            buttonRow(for: command)
                        }
                        .buttonStyle(.plain)
                        .background(secondaryTextColor.opacity(0.08))
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    }
                }
                .padding(6)
                .background(backgroundColor)
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(secondaryTextColor.opacity(0.22), lineWidth: 1)
                )
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            }
        }
    }
    
    private func buttonRow(for command: CommandInfo) -> some View {
        HStack {
            Text(command.alias)
                .font(.bitchatSystem(size: 11, design: .monospaced))
                .foregroundColor(textColor)
                .fontWeight(.medium)
            
            if let placeholder = command.placeholder {
                Text(placeholder)
                    .font(.bitchatSystem(size: 10, design: .monospaced))
                    .foregroundColor(secondaryTextColor.opacity(0.8))
            }

            Spacer()
            
            Text(command.description)
                .font(.bitchatSystem(size: 10, design: .monospaced))
                .foregroundColor(secondaryTextColor)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

#if canImport(PreviewsMacros)
@available(iOS 17, macOS 14, *)
#Preview {
    @Previewable @State var messageText: String = "/"
    let keychain = KeychainManager()
    let viewModel = ChatViewModel(
        keychain: keychain,
        idBridge: NostrIdentityBridge(),
        identityManager: SecureIdentityStateManager(keychain)
    )
    
    CommandSuggestionsView(
        messageText: $messageText,
        textColor: .green,
        backgroundColor: .primary,
        secondaryTextColor: .secondary
    )
    .environmentObject(viewModel)
}
#endif
