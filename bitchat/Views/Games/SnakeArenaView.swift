import SwiftUI

struct SnakeArenaView: View {
    @Environment(\.colorScheme) private var colorScheme
    @ObservedObject var runtime: SnakeRuntimeController
    @State private var didTriggerSwipeTurn = false

    var body: some View {
        GeometryReader { proxy in
            let size = proxy.size

            ZStack {
                BitchatTheme.appBackground(for: colorScheme)
                    .ignoresSafeArea()

                VStack(spacing: 20) {
                    header
                    board(size: size)
                    controls
                    footer
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 18)
            }
        }
    }
}

private extension SnakeArenaView {
    var header: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Snake Arena")
                    .font(.bitchatWordmark(size: 24, weight: .bold))
                    .foregroundStyle(BitchatTheme.primaryText(for: colorScheme))

                Text(runtime.isBotMatch ? "Practice mode against the bot" : "Swipe or use the controls to steer your snake")
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
            width: min(size.width - 40, 920),
            height: min(max(340, size.height - 270), 620)
        )

        return ZStack {
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(BitchatTheme.secondarySurface(for: colorScheme))

            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .stroke(BitchatTheme.border(for: colorScheme), lineWidth: 1)

            Canvas { context, canvasSize in
                let columns = 28.0
                let rows = 18.0
                let cellWidth = canvasSize.width / columns
                let cellHeight = canvasSize.height / rows

                for column in 0...Int(columns) {
                    let x = CGFloat(column) * cellWidth
                    var path = Path()
                    path.move(to: CGPoint(x: x, y: 0))
                    path.addLine(to: CGPoint(x: x, y: canvasSize.height))
                    context.stroke(path, with: .color(BitchatTheme.border(for: colorScheme).opacity(0.15)), lineWidth: 1)
                }

                for row in 0...Int(rows) {
                    let y = CGFloat(row) * cellHeight
                    var path = Path()
                    path.move(to: CGPoint(x: 0, y: y))
                    path.addLine(to: CGPoint(x: canvasSize.width, y: y))
                    context.stroke(path, with: .color(BitchatTheme.border(for: colorScheme).opacity(0.15)), lineWidth: 1)
                }

                for food in runtime.state.foods {
                    let rect = CGRect(
                        x: CGFloat(food.x) * cellWidth + cellWidth * 0.22,
                        y: CGFloat(food.y) * cellHeight + cellHeight * 0.22,
                        width: cellWidth * 0.56,
                        height: cellHeight * 0.56
                    )
                    context.fill(Path(ellipseIn: rect), with: .color(BitchatTheme.accent(for: colorScheme)))
                }

                for player in runtime.state.players {
                    let fill = snakeColor(index: player.colorIndex)
                    let stroke = fill.opacity(0.45)

                    for (index, segment) in player.segments.enumerated() {
                        let inset = index == 0 ? 0.1 : 0.16
                        let rect = CGRect(
                            x: CGFloat(segment.x) * cellWidth + cellWidth * inset,
                            y: CGFloat(segment.y) * cellHeight + cellHeight * inset,
                            width: cellWidth * (1 - inset * 2),
                            height: cellHeight * (1 - inset * 2)
                        )

                        let path = Path(roundedRect: rect, cornerRadius: min(cellWidth, cellHeight) * 0.22)
                        let opacity = player.isAlive ? 1.0 : 0.35
                        context.fill(path, with: .color(fill.opacity(opacity)))
                        context.stroke(path, with: .color(stroke.opacity(opacity)), lineWidth: 1)
                    }
                }
            }
            .padding(18)
            .contentShape(Rectangle())
            .highPriorityGesture(swipeGesture)

            VStack {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(Array(runtime.state.players.enumerated()), id: \.element.peerID) { _, player in
                            playerBadge(player)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 20)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

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
                        .padding(.bottom, 26)
                }
            }
        }
        .frame(width: boardSize.width, height: boardSize.height)
        .frame(maxWidth: .infinity)
    }

    var controls: some View {
        VStack(spacing: 10) {
            controlButton(systemName: "arrow.up", direction: .up)

            HStack(spacing: 10) {
                controlButton(systemName: "arrow.left", direction: .left)
                controlButton(systemName: "arrow.down", direction: .down)
                controlButton(systemName: "arrow.right", direction: .right)
            }
        }
    }

    var swipeGesture: some Gesture {
        DragGesture(minimumDistance: 8)
            .onChanged { value in
                guard !didTriggerSwipeTurn else { return }
                guard let direction = swipeDirection(for: value.translation) else { return }
                runtime.queueDirection(direction)
                didTriggerSwipeTurn = true
            }
            .onEnded { value in
                if !didTriggerSwipeTurn, let direction = swipeDirection(for: value.translation) {
                    runtime.queueDirection(direction)
                }
                didTriggerSwipeTurn = false
            }
    }

    var footer: some View {
        HStack {
            Text(runtime.isBotMatch ? "You are playing locally against the bot" : "Last snake standing wins")
                .font(.bitchatSystem(size: 13, weight: .medium))
                .foregroundStyle(BitchatTheme.secondaryText(for: colorScheme))

            Spacer()

            if runtime.isBotMatch {
                Button("Restart") {
                    runtime.restartBotMatch()
                }
                .buttonStyle(.plain)
                .font(.bitchatSystem(size: 14, weight: .semibold))
                .foregroundStyle(BitchatTheme.primaryText(for: colorScheme))
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(
                    Capsule(style: .continuous)
                        .fill(BitchatTheme.secondarySurface(for: colorScheme))
                )
                .overlay(
                    Capsule(style: .continuous)
                        .stroke(BitchatTheme.border(for: colorScheme), lineWidth: 1)
                )
            }

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

    func controlButton(systemName: String, direction: SnakeDirection) -> some View {
        Button {
            runtime.queueDirection(direction)
        } label: {
            Image(systemName: systemName)
                .font(.bitchatSystem(size: 15, weight: .bold))
                .foregroundStyle(BitchatTheme.primaryText(for: colorScheme))
                .frame(width: 50, height: 44)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(BitchatTheme.secondarySurface(for: colorScheme))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(BitchatTheme.border(for: colorScheme), lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
    }

    func playerBadge(_ player: SnakeSnapshotPlayer) -> some View {
        HStack(spacing: 8) {
            Circle()
                .fill(snakeColor(index: player.colorIndex))
                .frame(width: 8, height: 8)

            Text(player.nickname)
                .font(.bitchatSystem(size: 13, weight: .semibold))
                .foregroundStyle(BitchatTheme.primaryText(for: colorScheme))
                .lineLimit(1)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(
            Capsule(style: .continuous)
                .fill(BitchatTheme.surface(for: colorScheme).opacity(0.92))
        )
        .overlay(
            Capsule(style: .continuous)
                .stroke(BitchatTheme.border(for: colorScheme).opacity(0.7), lineWidth: 1)
        )
        .opacity(player.isAlive ? 1 : 0.52)
    }

    func swipeDirection(for translation: CGSize) -> SnakeDirection? {
        let horizontal = abs(translation.width)
        let vertical = abs(translation.height)
        guard max(horizontal, vertical) >= 10 else { return nil }

        if horizontal > vertical {
            return translation.width >= 0 ? .right : .left
        }
        return translation.height >= 0 ? .down : .up
    }

    func snakeColor(index: Int) -> Color {
        let palette: [Color] = [
            Color(red: 0.22, green: 0.74, blue: 0.95),
            Color(red: 0.96, green: 0.24, blue: 0.44),
            Color(red: 0.55, green: 0.36, blue: 0.96),
            Color(red: 0.06, green: 0.73, blue: 0.51),
            Color(red: 0.39, green: 0.47, blue: 0.98),
            Color(red: 0.84, green: 0.27, blue: 0.89)
        ]
        return palette[index % palette.count]
    }
}
