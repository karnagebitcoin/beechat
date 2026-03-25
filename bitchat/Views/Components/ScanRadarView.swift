import SwiftUI

struct ChatScanningPlaceholderView: View {
    let accentColor: Color
    let surfaceColor: Color
    let textColor: Color
    let secondaryTextColor: Color
    let modeLabel: String
    let countLabel: String?
    let title: String
    let subtitle: String

    var body: some View {
        ZStack {
            ScanningStreetMapBackdrop(tint: accentColor)
                .mask(
                    LinearGradient(
                        colors: [.white, .white.opacity(0.55), .clear],
                        startPoint: .top,
                        endPoint: .center
                    )
                )
                .padding(.top, 8)

            VStack(spacing: 18) {
                HStack(spacing: 8) {
                    pill(label: modeLabel, emphasized: true)

                    if let countLabel {
                        pill(label: countLabel, emphasized: false)
                    }
                }

                RadarHeroView(
                    accentColor: accentColor,
                    surfaceColor: surfaceColor,
                    secondaryTint: secondaryTextColor
                )

                VStack(spacing: 8) {
                    Text(title)
                        .font(.bitchatSystem(size: 23, weight: .bold, design: .rounded))
                        .foregroundColor(textColor)

                    Text(subtitle)
                        .font(.bitchatSystem(size: 15, weight: .medium))
                        .foregroundColor(secondaryTextColor)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: 360)
                }
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 36)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func pill(label: String, emphasized: Bool) -> some View {
        Text(label)
            .font(.bitchatSystem(size: 12, weight: .semibold, design: .rounded))
            .foregroundColor(emphasized ? textColor : secondaryTextColor)
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background(
                Capsule(style: .continuous)
                    .fill(emphasized ? accentColor.opacity(0.18) : secondaryTextColor.opacity(0.09))
            )
            .overlay(
                Capsule(style: .continuous)
                    .stroke(
                        emphasized ? accentColor.opacity(0.28) : secondaryTextColor.opacity(0.18),
                        lineWidth: 1
                    )
            )
    }
}

struct HeaderRadarIndicatorView: View {
    let tint: Color

    @State private var isSweeping = false
    @State private var isPulsing = false

    var body: some View {
        ZStack {
            Circle()
                .fill(tint.opacity(0.12))

            Circle()
                .stroke(tint.opacity(0.26), lineWidth: 1)

            RadarSweepSector(startAngle: .degrees(-24), endAngle: .degrees(28))
                .fill(
                    LinearGradient(
                        colors: [tint.opacity(0.26), tint.opacity(0.03)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .rotationEffect(.degrees(isSweeping ? 360 : 0))
                .clipShape(Circle())
                .animation(.linear(duration: 3.8).repeatForever(autoreverses: false), value: isSweeping)

            Circle()
                .stroke(tint.opacity(0.65), lineWidth: 1)
                .scaleEffect(isPulsing ? 1.25 : 0.68)
                .opacity(isPulsing ? 0.0 : 0.85)
                .animation(.easeOut(duration: 1.6).repeatForever(autoreverses: false), value: isPulsing)

            Circle()
                .fill(tint)
                .frame(width: 4, height: 4)
        }
        .frame(width: 14, height: 14)
        .onAppear {
            isSweeping = true
            isPulsing = true
        }
    }
}

private struct RadarHeroView: View {
    let accentColor: Color
    let surfaceColor: Color
    let secondaryTint: Color

    @State private var isSweeping = false
    @State private var isPulsing = false

    var body: some View {
        ZStack {
            Circle()
                .fill(
                    RadialGradient(
                        colors: [accentColor.opacity(0.18), .clear],
                        center: .center,
                        startRadius: 6,
                        endRadius: 112
                    )
                )
                .frame(width: 224, height: 224)

            ForEach(0..<3, id: \.self) { index in
                Circle()
                    .stroke(accentColor.opacity(0.24), lineWidth: 1)
                    .frame(width: 92, height: 92)
                    .scaleEffect(isPulsing ? 1.95 : 0.72)
                    .opacity(isPulsing ? 0.0 : 0.78)
                    .animation(
                        .easeOut(duration: 3.0)
                            .repeatForever(autoreverses: false)
                            .delay(Double(index) * 0.72),
                        value: isPulsing
                    )
            }

            ForEach([92.0, 126.0, 160.0], id: \.self) { size in
                Circle()
                    .stroke(secondaryTint.opacity(0.15), lineWidth: 1)
                    .frame(width: size, height: size)
            }

            RadarSweepSector(startAngle: .degrees(-24), endAngle: .degrees(34))
                .fill(
                    LinearGradient(
                        colors: [accentColor.opacity(0.34), accentColor.opacity(0.03)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 174, height: 174)
                .rotationEffect(.degrees(isSweeping ? 360 : 0))
                .clipShape(Circle())
                .blur(radius: 1.5)
                .animation(.linear(duration: 4.8).repeatForever(autoreverses: false), value: isSweeping)

            Circle()
                .stroke(accentColor.opacity(0.24), lineWidth: 1)
                .frame(width: 174, height: 174)

            Circle()
                .fill(surfaceColor.opacity(0.94))
                .frame(width: 88, height: 88)

            Circle()
                .stroke(accentColor.opacity(0.3), lineWidth: 1)
                .frame(width: 88, height: 88)

            Image(systemName: "antenna.radiowaves.left.and.right")
                .font(.system(size: 30, weight: .semibold))
                .foregroundColor(accentColor)
        }
        .frame(width: 240, height: 240)
        .onAppear {
            isSweeping = true
            isPulsing = true
        }
    }
}

private struct ScanningStreetMapBackdrop: View {
    let tint: Color

    var body: some View {
        GeometryReader { geometry in
            Canvas { context, size in
                let stroke = StrokeStyle(lineWidth: 1.1, lineCap: .round, lineJoin: .round)

                var primary = Path()
                primary.move(to: CGPoint(x: -18, y: size.height * 0.12))
                primary.addLine(to: CGPoint(x: size.width * 0.18, y: size.height * 0.12))
                primary.addLine(to: CGPoint(x: size.width * 0.18, y: size.height * 0.34))
                primary.addLine(to: CGPoint(x: size.width * 0.34, y: size.height * 0.34))
                primary.addLine(to: CGPoint(x: size.width * 0.34, y: size.height * 0.22))
                primary.addLine(to: CGPoint(x: size.width * 0.48, y: size.height * 0.22))

                primary.move(to: CGPoint(x: size.width + 18, y: size.height * 0.16))
                primary.addLine(to: CGPoint(x: size.width * 0.82, y: size.height * 0.16))
                primary.addLine(to: CGPoint(x: size.width * 0.82, y: size.height * 0.38))
                primary.addLine(to: CGPoint(x: size.width * 0.66, y: size.height * 0.38))
                primary.addLine(to: CGPoint(x: size.width * 0.66, y: size.height * 0.26))
                primary.addLine(to: CGPoint(x: size.width * 0.54, y: size.height * 0.26))

                var secondary = Path()
                secondary.move(to: CGPoint(x: size.width * 0.06, y: size.height * 0.03))
                secondary.addLine(to: CGPoint(x: size.width * 0.06, y: size.height * 0.22))
                secondary.addLine(to: CGPoint(x: size.width * 0.22, y: size.height * 0.22))
                secondary.addLine(to: CGPoint(x: size.width * 0.22, y: size.height * 0.08))
                secondary.addLine(to: CGPoint(x: size.width * 0.4, y: size.height * 0.08))

                secondary.move(to: CGPoint(x: size.width * 0.94, y: size.height * 0.04))
                secondary.addLine(to: CGPoint(x: size.width * 0.94, y: size.height * 0.24))
                secondary.addLine(to: CGPoint(x: size.width * 0.78, y: size.height * 0.24))
                secondary.addLine(to: CGPoint(x: size.width * 0.78, y: size.height * 0.1))
                secondary.addLine(to: CGPoint(x: size.width * 0.62, y: size.height * 0.1))

                var diagonals = Path()
                diagonals.move(to: CGPoint(x: size.width * 0.14, y: size.height * 0.42))
                diagonals.addLine(to: CGPoint(x: size.width * 0.26, y: size.height * 0.28))
                diagonals.addLine(to: CGPoint(x: size.width * 0.38, y: size.height * 0.42))

                diagonals.move(to: CGPoint(x: size.width * 0.86, y: size.height * 0.44))
                diagonals.addLine(to: CGPoint(x: size.width * 0.74, y: size.height * 0.3))
                diagonals.addLine(to: CGPoint(x: size.width * 0.62, y: size.height * 0.44))

                context.stroke(primary, with: .color(tint.opacity(0.17)), style: stroke)
                context.stroke(secondary, with: .color(tint.opacity(0.12)), style: stroke)
                context.stroke(diagonals, with: .color(tint.opacity(0.09)), style: stroke)

                for point in [
                    CGPoint(x: size.width * 0.18, y: size.height * 0.12),
                    CGPoint(x: size.width * 0.34, y: size.height * 0.34),
                    CGPoint(x: size.width * 0.82, y: size.height * 0.16),
                    CGPoint(x: size.width * 0.66, y: size.height * 0.38),
                    CGPoint(x: size.width * 0.22, y: size.height * 0.22),
                    CGPoint(x: size.width * 0.78, y: size.height * 0.24)
                ] {
                    context.fill(
                        Path(ellipseIn: CGRect(x: point.x - 2, y: point.y - 2, width: 4, height: 4)),
                        with: .color(tint.opacity(0.18))
                    )
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }
}

private struct RadarSweepSector: Shape {
    let startAngle: Angle
    let endAngle: Angle

    func path(in rect: CGRect) -> Path {
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let radius = min(rect.width, rect.height) / 2

        var path = Path()
        path.move(to: center)
        path.addArc(center: center, radius: radius, startAngle: startAngle, endAngle: endAngle, clockwise: false)
        path.closeSubpath()
        return path
    }
}
