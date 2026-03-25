import SwiftUI
#if os(iOS)
import UIKit
import AudioToolbox
#elseif os(macOS)
import AppKit
#endif

struct PongMatchView: View {
    @Environment(\.colorScheme) private var colorScheme
    @ObservedObject var runtime: PongRuntimeController

    var body: some View {
        GeometryReader { proxy in
            let size = proxy.size

            ZStack {
                BitchatTheme.appBackground(for: colorScheme)
                    .ignoresSafeArea()

                VStack(spacing: 24) {
                    header
                    board(size: size)
                    footer
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 18)
            }
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { gesture in
                        let normalized = Double(gesture.location.y / max(size.height, 1))
                        runtime.setLocalPaddleY(normalized)
                    }
            )
            .onChange(of: runtime.paddleImpactToken) { token in
                guard token > 0 else { return }
                performPaddleImpactCue()
            }
        }
    }
}

private extension PongMatchView {
    func performPaddleImpactCue() {
        #if os(iOS)
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.prepare()
        generator.impactOccurred(intensity: 0.55)
        AudioServicesPlaySystemSound(1104)
        #elseif os(macOS)
        NSHapticFeedbackManager.defaultPerformer.perform(.alignment, performanceTime: .now)
        if let sound = NSSound(named: NSSound.Name("Tink")) {
            sound.volume = 0.18
            sound.play()
        }
        #endif
    }

    var header: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Pong Battle")
                    .font(.bitchatWordmark(size: 24, weight: .bold))
                    .foregroundStyle(BitchatTheme.primaryText(for: colorScheme))

                Text(runtime.isBotMatch ? "Practice mode against the bot" : "Drag anywhere to move your paddle")
                    .font(.bitchatSystem(size: 13, weight: .medium))
                    .foregroundStyle(BitchatTheme.secondaryText(for: colorScheme))
            }

            Spacer()

            Button {
                runtime.leaveMatch()
            } label: {
                Image(systemName: "xmark")
                    .font(.bitchatSystem(size: 14, weight: .bold))
                    .foregroundStyle(BitchatTheme.primaryText(for: colorScheme))
                    .frame(width: 42, height: 42)
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

    func board(size: CGSize) -> some View {
        let boardSize = CGSize(
            width: min(size.width - 40, 880),
            height: min(max(320, size.height - 200), 560)
        )

        return ZStack {
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(BitchatTheme.secondarySurface(for: colorScheme))

            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .stroke(BitchatTheme.border(for: colorScheme), lineWidth: 1)

            Canvas { context, canvasSize in
                let width = canvasSize.width
                let height = canvasSize.height

                let lineColor = BitchatTheme.border(for: colorScheme).opacity(0.9)
                var centerPath = Path()
                let dashHeight = height / 16
                for index in stride(from: 0, to: height, by: dashHeight * 1.7) {
                    centerPath.addRoundedRect(in: CGRect(x: width / 2 - 2, y: index, width: 4, height: dashHeight), cornerSize: CGSize(width: 2, height: 2))
                }
                context.fill(centerPath, with: .color(lineColor))

                let paddleHeight = height * 0.2
                let paddleWidth = max(10, width * 0.018)

                let hostRect = CGRect(
                    x: width * 0.05 - paddleWidth / 2,
                    y: height * runtime.state.hostPaddleY - paddleHeight / 2,
                    width: paddleWidth,
                    height: paddleHeight
                )

                let guestRect = CGRect(
                    x: width * 0.95 - paddleWidth / 2,
                    y: height * runtime.state.guestPaddleY - paddleHeight / 2,
                    width: paddleWidth,
                    height: paddleHeight
                )

                let ballSide = max(12, width * 0.024)
                let ballRect = CGRect(
                    x: width * runtime.state.ballX - ballSide / 2,
                    y: height * runtime.state.ballY - ballSide / 2,
                    width: ballSide,
                    height: ballSide
                )

                context.fill(Path(roundedRect: hostRect, cornerRadius: 5), with: .color(BitchatTheme.accent(for: colorScheme)))
                context.fill(Path(roundedRect: guestRect, cornerRadius: 5), with: .color(BitchatTheme.primaryText(for: colorScheme)))
                context.fill(Path(ellipseIn: ballRect), with: .color(BitchatTheme.primaryText(for: colorScheme)))
            }
            .padding(18)

            VStack {
                HStack(alignment: .top) {
                    scoreBlock(name: runtime.host.nickname, score: runtime.state.hostScore, align: .leading)
                    Spacer()
                    scoreBlock(name: runtime.guest.nickname, score: runtime.state.guestScore, align: .trailing)
                }
                .padding(.horizontal, 26)
                .padding(.top, 26)

                Spacer()

                if let winnerText = runtime.state.winnerText {
                    Text(winnerText)
                        .font(.bitchatSystem(size: 18, weight: .semibold))
                        .foregroundStyle(BitchatTheme.primaryText(for: colorScheme))
                        .padding(.horizontal, 18)
                        .padding(.vertical, 12)
                        .background(
                            Capsule(style: .continuous)
                                .fill(BitchatTheme.surface(for: colorScheme))
                        )
                        .overlay(
                            Capsule(style: .continuous)
                                .stroke(BitchatTheme.border(for: colorScheme), lineWidth: 1)
                        )
                        .padding(.bottom, 30)
                }
            }
        }
        .frame(width: boardSize.width, height: boardSize.height)
        .frame(maxWidth: .infinity)
    }

    var footer: some View {
        HStack {
            Text(runtime.isBotMatch ? "You are on the left paddle" : (runtime.isHost ? "Hosting on the left paddle" : "You are on the right paddle"))
                .font(.bitchatSystem(size: 13, weight: .medium))
                .foregroundStyle(BitchatTheme.secondaryText(for: colorScheme))

            Spacer()

            if runtime.state.isFinished {
                Button("Close") {
                    runtime.dismiss()
                }
                .buttonStyle(.plain)
                .font(.bitchatSystem(size: 14, weight: .semibold))
                .foregroundStyle(Color.white)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(
                    Capsule(style: .continuous)
                        .fill(BitchatTheme.accent(for: colorScheme))
                )
            }
        }
    }

    func scoreBlock(name: String, score: Int, align: HorizontalAlignment) -> some View {
        VStack(alignment: align, spacing: 4) {
            Text(name)
                .font(.bitchatSystem(size: 13, weight: .medium))
                .foregroundStyle(BitchatTheme.secondaryText(for: colorScheme))

            Text("\(score)")
                .font(.bitchatWordmark(size: 30, weight: .bold))
                .foregroundStyle(BitchatTheme.primaryText(for: colorScheme))
        }
    }
}
