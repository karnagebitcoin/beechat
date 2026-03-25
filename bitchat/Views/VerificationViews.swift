import SwiftUI
import CoreImage
import CoreImage.CIFilterBuiltins
#if os(iOS)
import UIKit
#else
import AppKit
#endif

/// Placeholder view to display the user's verification QR payload as text.
struct MyQRView: View {
    let qrString: String
    @Environment(\.colorScheme) var colorScheme
    @State private var showDetails = false
    @State private var didCopyCode = false

    private var panelColor: Color { BitchatTheme.elevatedSurface(for: colorScheme) }
    private var stageColor: Color { BitchatTheme.secondarySurface(for: colorScheme) }
    private var borderColor: Color { BitchatTheme.border(for: colorScheme) }
    private var accentColor: Color { BitchatTheme.accent(for: colorScheme) }
    private var textColor: Color { BitchatTheme.primaryText(for: colorScheme) }
    private var secondaryTextColor: Color { BitchatTheme.secondaryText(for: colorScheme) }
    private var shadowColor: Color { BitchatTheme.shadow(for: colorScheme) }

    #if os(iOS)
    private var qrSize: CGFloat { 216 }
    #else
    private var qrSize: CGFloat { 232 }
    #endif

    private enum Strings {
        static let title: LocalizedStringKey = "verification.my_qr.title"
        static let accessibilityLabel = String(localized: "verification.my_qr.accessibility_label", comment: "Accessibility label describing the verification QR code")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 6) {
                Text(Strings.title)
                    .font(.bitchatSystem(size: 20, weight: .bold, design: .rounded))
                    .foregroundColor(textColor)

                Text("Let someone nearby scan this code to confirm they're really chatting with you.")
                    .font(.bitchatSystem(size: 14))
                    .foregroundColor(secondaryTextColor)
                    .fixedSize(horizontal: false, vertical: true)
            }

            VStack(spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 28, style: .continuous)
                        .fill(Color.white)

                    RoundedRectangle(cornerRadius: 28, style: .continuous)
                        .stroke(borderColor.opacity(colorScheme == .dark ? 0.75 : 1), lineWidth: 1)

                    QRCodeImage(data: qrString, size: qrSize)
                        .accessibilityLabel(Strings.accessibilityLabel)
                }
                .padding(18)
                .frame(maxWidth: .infinity)
                .background(
                    RoundedRectangle(cornerRadius: 30, style: .continuous)
                        .fill(stageColor)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 30, style: .continuous)
                        .stroke(borderColor, lineWidth: 1)
                )

                HStack(spacing: 10) {
                    verificationPillButton(
                        title: didCopyCode ? "Copied" : "Copy code",
                        icon: didCopyCode ? "checkmark" : "doc.on.doc",
                        filled: true,
                        tint: accentColor
                    ) {
                        copyCodeToClipboard()
                    }

                    verificationPillButton(
                        title: showDetails ? "Hide details" : "Show details",
                        icon: showDetails ? "chevron.up" : "chevron.down",
                        filled: false,
                        tint: accentColor
                    ) {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            showDetails.toggle()
                        }
                    }
                }

                if showDetails {
                    ScrollView {
                        Text(qrString)
                            .font(.bitchatSystem(size: 11, design: .monospaced))
                            .foregroundColor(textColor)
                            .textSelection(.enabled)
                            .multilineTextAlignment(.leading)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .frame(maxHeight: 140)
                    .padding(12)
                    .background(
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .fill(stageColor)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .stroke(borderColor, lineWidth: 1)
                    )
                    .transition(.move(edge: .top).combined(with: .opacity))
                }
            }
            .padding(20)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 30, style: .continuous)
                    .fill(panelColor)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 30, style: .continuous)
                    .stroke(borderColor, lineWidth: 1)
            )
            .shadow(color: shadowColor, radius: 16, x: 0, y: 8)
        }
    }

    private func verificationPillButton(
        title: String,
        icon: String,
        filled: Bool,
        tint: Color,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Label(title, systemImage: icon)
                .font(.bitchatSystem(size: 13, weight: .semibold))
                .foregroundColor(filled ? BitchatTheme.primaryText(for: colorScheme) : tint)
                .frame(maxWidth: .infinity)
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(
                    Capsule(style: .continuous)
                        .fill(filled ? tint.opacity(colorScheme == .dark ? 0.24 : 0.14) : stageColor)
                )
                .overlay(
                    Capsule(style: .continuous)
                        .stroke(filled ? tint.opacity(colorScheme == .dark ? 0.3 : 0.18) : borderColor, lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
    }

    private func copyCodeToClipboard() {
        #if os(iOS)
        UIPasteboard.general.string = qrString
        #else
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(qrString, forType: .string)
        #endif
        didCopyCode = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.6) {
            didCopyCode = false
        }
    }
}

// Render a QR code image for a given string using CoreImage
struct QRCodeImage: View {
    let data: String
    let size: CGFloat

    private let context = CIContext()
    private let filter = CIFilter.qrCodeGenerator()

    private enum Strings {
        static let unavailable: LocalizedStringKey = "verification.my_qr.unavailable"
    }

    var body: some View {
        Group {
            if let image = generateImage() {
                ImageWrapper(image: image)
                    .frame(width: size, height: size)
            } else {
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.gray.opacity(0.5), lineWidth: 1)
                    .frame(width: size, height: size)
                    .overlay(
                        Text(Strings.unavailable)
                            .font(.bitchatSystem(size: 12, design: .monospaced))
                            .foregroundColor(.gray)
                    )
            }
        }
    }

    private func generateImage() -> CGImage? {
        let inputData = Data(data.utf8)
        filter.message = inputData
        filter.correctionLevel = "M"
        guard let outputImage = filter.outputImage else { return nil }
        let scale = max(1, Int(size / 32))
        let transformed = outputImage.transformed(by: CGAffineTransform(scaleX: CGFloat(scale), y: CGFloat(scale)))
        return context.createCGImage(transformed, from: transformed.extent)
    }
}

// Platform-specific wrapper to display CGImage in SwiftUI
struct ImageWrapper: View {
    let image: CGImage
    var body: some View {
        #if os(iOS)
        let ui = UIImage(cgImage: image)
        return Image(uiImage: ui)
            .interpolation(.none)
            .resizable()
        #else
        let ns = NSImage(cgImage: image, size: .zero)
        return Image(nsImage: ns)
            .interpolation(.none)
            .resizable()
        #endif
    }
}

/// Placeholder scanner UI; real camera scanning will be added later.
struct QRScanView: View {
    @EnvironmentObject var viewModel: ChatViewModel
    @Environment(\.colorScheme) var colorScheme
    var isActive: Bool = true
    var onSuccess: (() -> Void)? = nil  // Called when verification succeeds
    @State private var input = ""
    @State private var result: String = "" // not shown for iOS scanner
    @State private var lastValid: String = ""

    private var panelColor: Color { BitchatTheme.elevatedSurface(for: colorScheme) }
    private var stageColor: Color { BitchatTheme.secondarySurface(for: colorScheme) }
    private var borderColor: Color { BitchatTheme.border(for: colorScheme) }
    private var accentColor: Color { BitchatTheme.accent(for: colorScheme) }
    private var textColor: Color { BitchatTheme.primaryText(for: colorScheme) }
    private var secondaryTextColor: Color { BitchatTheme.secondaryText(for: colorScheme) }
    private var shadowColor: Color { BitchatTheme.shadow(for: colorScheme) }

    private enum Strings {
        static let pastePrompt: LocalizedStringKey = "verification.scan.paste_prompt"
        static let validate: LocalizedStringKey = "verification.scan.validate"
        static func requested(_ nickname: String) -> String {
            String(
                format: String(localized: "verification.scan.status.requested", comment: "Status text when verification is requested for a nickname"),
                locale: .current,
                nickname
            )
        }
        static let notFound = String(localized: "verification.scan.status.no_peer", comment: "Status when no matching peer is found for a verification request")
        static let invalid = String(localized: "verification.scan.status.invalid", comment: "Status when a scanned QR payload is invalid")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Scan someone's QR")
                    .font(.bitchatSystem(size: 20, weight: .bold, design: .rounded))
                    .foregroundColor(textColor)

                Text("Point your camera at their code and verification will start automatically.")
                    .font(.bitchatSystem(size: 14))
                    .foregroundColor(secondaryTextColor)
                    .fixedSize(horizontal: false, vertical: true)
            }

            #if os(iOS)
            ZStack {
                CameraScannerView(isActive: isActive) { code in
                    // Deduplicate: ignore if we just processed this exact QR code
                    guard code != lastValid else { return }

                    if let qr = VerificationService.shared.verifyScannedQR(code) {
                        let ok = viewModel.beginQRVerification(with: qr)
                        if ok {
                            // Successfully initiated verification; remember this QR to prevent re-scanning
                            lastValid = code
                            // Close scanner and return to "My QR" view
                            onSuccess?()
                        }
                        // If !ok, peer not found or already pending - don't set lastValid so user can retry
                    } else {
                        // ignore invalid reads; continue scanning
                    }
                }
                .frame(height: 320)
                .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))

                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .stroke(borderColor, lineWidth: 1)

                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .stroke(accentColor.opacity(0.45), style: StrokeStyle(lineWidth: 2, dash: [10, 8]))
                    .frame(width: 210, height: 210)

                VStack {
                    Spacer()
                    Text("Scanning runs automatically")
                        .font(.bitchatSystem(size: 12, weight: .medium))
                        .foregroundColor(BitchatTheme.primaryText(for: colorScheme))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(
                            Capsule(style: .continuous)
                                .fill(stageColor.opacity(0.94))
                        )
                        .overlay(
                            Capsule(style: .continuous)
                                .stroke(borderColor, lineWidth: 1)
                        )
                        .padding(.bottom, 16)
                }
            }
            #else
            Text(Strings.pastePrompt)
                .font(.bitchatSystem(size: 14, weight: .medium))
                .foregroundColor(secondaryTextColor)
            TextEditor(text: $input)
                .frame(height: 100)
                .padding(8)
                .background(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(stageColor)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(borderColor, lineWidth: 1)
                )
            Button(Strings.validate) {
                // Deduplicate: ignore if we just processed this exact QR
                guard input != lastValid else {
                    result = Strings.requested("")  // Already processed
                    return
                }

                if let qr = VerificationService.shared.verifyScannedQR(input) {
                    let ok = viewModel.beginQRVerification(with: qr)
                    if ok {
                        result = Strings.requested(qr.nickname)
                        lastValid = input
                        // Close scanner and return to "My QR" view
                        onSuccess?()
                    } else {
                        result = Strings.notFound
                    }
                } else {
                    result = Strings.invalid
                }
            }
            .font(.bitchatSystem(size: 13, weight: .semibold))
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(
                Capsule(style: .continuous)
                    .fill(accentColor.opacity(colorScheme == .dark ? 0.24 : 0.14))
            )
            .overlay(
                Capsule(style: .continuous)
                    .stroke(accentColor.opacity(colorScheme == .dark ? 0.32 : 0.2), lineWidth: 1)
            )
            .buttonStyle(.plain)
            #endif
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 30, style: .continuous)
                .fill(panelColor)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 30, style: .continuous)
                .stroke(borderColor, lineWidth: 1)
        )
        .shadow(color: shadowColor, radius: 16, x: 0, y: 8)
    }
}

#if os(iOS)
import AVFoundation

struct CameraScannerView: UIViewRepresentable {
    typealias UIViewType = PreviewView
    var isActive: Bool
    var onCode: (String) -> Void

    func makeUIView(context: Context) -> PreviewView {
        let view = PreviewView()
        context.coordinator.setup(sessionOwner: view, onCode: onCode)
        context.coordinator.setActive(isActive)
        return view
    }

    func updateUIView(_ uiView: PreviewView, context: Context) {
        context.coordinator.setActive(isActive)
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    final class Coordinator: NSObject, AVCaptureMetadataOutputObjectsDelegate {
        private var onCode: ((String) -> Void)?
        private weak var owner: PreviewView?
        private let session = AVCaptureSession()
        private var isRunning = false
        private var permissionGranted = false
        private var desiredActive = false

        func setup(sessionOwner: PreviewView, onCode: @escaping (String) -> Void) {
            self.owner = sessionOwner
            self.onCode = onCode
            session.beginConfiguration()
            session.sessionPreset = .high
            guard let device = AVCaptureDevice.default(for: .video),
                  let input = try? AVCaptureDeviceInput(device: device),
                  session.canAddInput(input) else { return }
            session.addInput(input)
            let output = AVCaptureMetadataOutput()
            guard session.canAddOutput(output) else { return }
            session.addOutput(output)
            output.setMetadataObjectsDelegate(self, queue: DispatchQueue.main)
            if output.availableMetadataObjectTypes.contains(.qr) {
                output.metadataObjectTypes = [.qr]
            }
            session.commitConfiguration()
            sessionOwner.videoPreviewLayer.session = session
            // Request permission and start
            AVCaptureDevice.requestAccess(for: .video) { granted in
                self.permissionGranted = granted
                if granted && self.desiredActive && !self.isRunning {
                    self.setActive(true)
                }
            }
        }

        func setActive(_ active: Bool) {
            desiredActive = active
            guard permissionGranted else { return }
            if active && !isRunning {
                isRunning = true
                DispatchQueue.global(qos: .userInitiated).async {
                    if !self.session.isRunning { self.session.startRunning() }
                }
            } else if !active && isRunning {
                isRunning = false
                DispatchQueue.global(qos: .userInitiated).async {
                    if self.session.isRunning { self.session.stopRunning() }
                }
            }
        }

        func metadataOutput(_ output: AVCaptureMetadataOutput, didOutput metadataObjects: [AVMetadataObject], from connection: AVCaptureConnection) {
            for obj in metadataObjects {
                guard let m = obj as? AVMetadataMachineReadableCodeObject,
                      m.type == .qr,
                      let str = m.stringValue else { continue }
                onCode?(str)
            }
        }
    }

    final class PreviewView: UIView {
        override class var layerClass: AnyClass { AVCaptureVideoPreviewLayer.self }
        var videoPreviewLayer: AVCaptureVideoPreviewLayer { layer as! AVCaptureVideoPreviewLayer }
        override init(frame: CGRect) {
            super.init(frame: frame)
            videoPreviewLayer.videoGravity = .resizeAspectFill
        }
        required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    }
}
#endif

// Combined sheet: shows my QR by default with a button to scan instead
struct VerificationSheetView: View {
    @EnvironmentObject var viewModel: ChatViewModel
    @Binding var isPresented: Bool
    @State private var showingScanner = false
    @Environment(\.colorScheme) var colorScheme

    private var backgroundColor: Color { BitchatTheme.appBackground(for: colorScheme) }
    private var accentColor: Color { BitchatTheme.accent(for: colorScheme) }
    private var elevatedSurfaceColor: Color { BitchatTheme.elevatedSurface(for: colorScheme) }
    private var secondarySurfaceColor: Color { BitchatTheme.secondarySurface(for: colorScheme) }
    private var textColor: Color { BitchatTheme.primaryText(for: colorScheme) }
    private var secondaryTextColor: Color { BitchatTheme.secondaryText(for: colorScheme) }
    private var borderColor: Color { BitchatTheme.border(for: colorScheme) }
    private var shadowColor: Color { BitchatTheme.shadow(for: colorScheme) }

    private func myQRString() -> String {
        let npub = try? viewModel.idBridge.getCurrentNostrIdentity()?.npub
        return VerificationService.shared.buildMyQRString(nickname: viewModel.nickname, npub: npub) ?? ""
    }

    private var heroIconName: String {
        showingScanner ? "camera.viewfinder" : "checkmark.shield"
    }

    private var heroTitle: String {
        showingScanner ? "Verify someone nearby" : "Verification"
    }

    private var heroDescription: String {
        showingScanner
            ? "Scan a nearby person's QR code to confirm you are really chatting with them."
            : "Share your QR code or scan someone else's to verify your conversation."
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                heroCard

                HStack(spacing: 8) {
                    verificationModeButton(
                        title: "My code",
                        icon: "qrcode",
                        selected: !showingScanner
                    ) {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            showingScanner = false
                        }
                    }

                    verificationModeButton(
                        title: "Scan",
                        icon: "camera.viewfinder",
                        selected: showingScanner
                    ) {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            showingScanner = true
                        }
                    }
                }

                Group {
                    if showingScanner {
                        #if os(iOS)
                        QRScanView(isActive: showingScanner, onSuccess: {
                            showingScanner = false
                        })
                        .environmentObject(viewModel)
                        #else
                        QRScanView(onSuccess: {
                            showingScanner = false
                        })
                        .environmentObject(viewModel)
                        #endif
                    } else {
                        MyQRView(qrString: myQRString())
                    }
                }

                if let pid = viewModel.selectedPrivateChatPeer,
                   let fp = viewModel.getFingerprint(for: pid),
                   viewModel.verifiedFingerprints.contains(fp) {
                    Button(action: { viewModel.unverifyFingerprint(for: pid) }) {
                        Label("remove verification", systemImage: "minus.circle")
                            .font(.bitchatSystem(size: 12, weight: .semibold))
                            .foregroundColor(BitchatTheme.danger(for: colorScheme))
                            .frame(maxWidth: .infinity)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 12)
                            .background(
                                Capsule(style: .continuous)
                                    .fill(BitchatTheme.dangerSoft(for: colorScheme))
                            )
                            .overlay(
                                Capsule(style: .continuous)
                                    .stroke(BitchatTheme.danger(for: colorScheme).opacity(0.2), lineWidth: 1)
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(16)
        }
        .background(backgroundColor.ignoresSafeArea())
        .onDisappear { showingScanner = false }
    }

    private var heroCard: some View {
        HStack(alignment: .top, spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(accentColor.opacity(colorScheme == .dark ? 0.18 : 0.12))
                    .frame(width: 58, height: 58)

                Image(systemName: heroIconName)
                    .font(.bitchatSystem(size: 24, weight: .semibold))
                    .foregroundColor(accentColor)
            }

            VStack(alignment: .leading, spacing: 6) {
                Text(heroTitle)
                    .font(.bitchatSystem(size: 24, weight: .bold, design: .rounded))
                    .foregroundColor(textColor)
                Text(heroDescription)
                    .font(.bitchatSystem(size: 14))
                    .foregroundColor(secondaryTextColor)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer()

            Button(action: {
                showingScanner = false
                isPresented = false
            }) {
                Image(systemName: "xmark")
                    .font(.bitchatSystem(size: 14, weight: .semibold))
                    .foregroundColor(textColor)
                    .frame(width: 38, height: 38)
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
            .accessibilityLabel(String(localized: "common.close", comment: "Accessibility label for close buttons"))
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 30, style: .continuous)
                .fill(elevatedSurfaceColor)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 30, style: .continuous)
                .stroke(borderColor, lineWidth: 1)
        )
        .shadow(color: shadowColor, radius: 16, x: 0, y: 8)
    }

    private func verificationModeButton(
        title: String,
        icon: String,
        selected: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Label(title, systemImage: icon)
                .font(.bitchatSystem(size: 13, weight: .semibold))
                .foregroundColor(selected ? BitchatTheme.primaryText(for: colorScheme) : accentColor)
                .frame(maxWidth: .infinity)
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(
                    Capsule(style: .continuous)
                        .fill(selected ? accentColor.opacity(colorScheme == .dark ? 0.24 : 0.14) : secondarySurfaceColor)
                )
                .overlay(
                    Capsule(style: .continuous)
                        .stroke(selected ? accentColor.opacity(colorScheme == .dark ? 0.32 : 0.2) : borderColor, lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
    }
}
