import Foundation
import SwiftUI

enum BitchatPalette: String, CaseIterable, Identifiable {
    case sky
    case cyan
    case blue
    case indigo
    case violet
    case purple
    case fuchsia
    case pink
    case rose
    case red
    case orange
    case amber
    case yellow
    case lime
    case green
    case emerald
    case teal

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .sky: return "Sky"
        case .cyan: return "Cyan"
        case .blue: return "Blue"
        case .indigo: return "Indigo"
        case .violet: return "Violet"
        case .purple: return "Purple"
        case .fuchsia: return "Fuchsia"
        case .pink: return "Pink"
        case .rose: return "Rose"
        case .red: return "Red"
        case .orange: return "Orange"
        case .amber: return "Amber"
        case .yellow: return "Yellow"
        case .lime: return "Lime"
        case .green: return "Green"
        case .emerald: return "Emerald"
        case .teal: return "Teal"
        }
    }
}

enum BitchatTheme {
    static let selectedPaletteKey = "bitchat.theme.palette"

    static func currentPalette() -> BitchatPalette {
        let stored = UserDefaults.standard.string(forKey: selectedPaletteKey) ?? BitchatPalette.sky.rawValue
        return BitchatPalette(rawValue: stored) ?? .sky
    }

    static func appBackground(for colorScheme: ColorScheme) -> Color {
        colorScheme == .dark ? .black : .white
    }

    static func backgroundGradient(for colorScheme: ColorScheme) -> LinearGradient {
        LinearGradient(
            colors: Array(repeating: appBackground(for: colorScheme), count: 3),
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    static func surface(for colorScheme: ColorScheme) -> Color {
        colorScheme == .dark ? neutral(950) : accentScale(for: currentPalette()).shade50
    }

    static func elevatedSurface(for colorScheme: ColorScheme) -> Color {
        colorScheme == .dark ? neutral(900) : accentScale(for: currentPalette()).shade50
    }

    static func secondarySurface(for colorScheme: ColorScheme) -> Color {
        colorScheme == .dark ? neutral(900) : accentScale(for: currentPalette()).shade50
    }

    static func primaryText(for colorScheme: ColorScheme) -> Color {
        colorScheme == .dark ? neutral(50) : neutral(900)
    }

    static func secondaryText(for colorScheme: ColorScheme) -> Color {
        colorScheme == .dark ? neutral(400) : neutral(500)
    }

    static func senderName(for colorScheme: ColorScheme, isSelf: Bool) -> Color {
        isSelf ? accent(for: colorScheme) : primaryText(for: colorScheme)
    }

    static func messageText(for colorScheme: ColorScheme) -> Color {
        primaryText(for: colorScheme)
    }

    static func accent(for colorScheme: ColorScheme) -> Color {
        accent(for: colorScheme, palette: currentPalette())
    }

    static func accent(for colorScheme: ColorScheme, palette: BitchatPalette) -> Color {
        let scale = accentScale(for: palette)
        return colorScheme == .dark ? scale.shade400 : scale.shade600
    }

    static func accentSoft(for colorScheme: ColorScheme) -> Color {
        accentSoft(for: colorScheme, palette: currentPalette())
    }

    static func accentSoft(for colorScheme: ColorScheme, palette: BitchatPalette) -> Color {
        let scale = accentScale(for: palette)
        return colorScheme == .dark ? scale.shade500.opacity(0.18) : scale.shade50
    }

    static func meshAccent(for colorScheme: ColorScheme) -> Color {
        let scale = accentScale(for: currentPalette())
        return colorScheme == .dark ? scale.shade300 : scale.shade500
    }

    static func locationAccent(for colorScheme: ColorScheme) -> Color {
        let scale = accentScale(for: currentPalette())
        return colorScheme == .dark ? scale.shade400 : scale.shade700
    }

    static func border(for colorScheme: ColorScheme) -> Color {
        colorScheme == .dark ? neutral(800) : accentScale(for: currentPalette()).shade200
    }

    static func shadow(for colorScheme: ColorScheme) -> Color {
        colorScheme == .dark ? Color.black.opacity(0.42) : accentScale(for: currentPalette()).shade700.opacity(0.08)
    }

    static func messageFill(for colorScheme: ColorScheme, isSelf: Bool) -> Color {
        if isSelf {
            return accentSoft(for: colorScheme)
        }
        return colorScheme == .dark ? neutral(900) : accentScale(for: currentPalette()).shade50
    }

    static func systemFill(for colorScheme: ColorScheme) -> Color {
        colorScheme == .dark ? neutral(900) : accentScale(for: currentPalette()).shade50
    }

    static func listRowFill(for colorScheme: ColorScheme, emphasized: Bool = false) -> Color {
        if emphasized {
            return accentSoft(for: colorScheme)
        }
        return colorScheme == .dark ? neutral(900) : accentScale(for: currentPalette()).shade50
    }

    static func success(for colorScheme: ColorScheme) -> Color {
        meshAccent(for: colorScheme)
    }

    static func warning(for colorScheme: ColorScheme) -> Color {
        accent(for: colorScheme)
    }

    static func danger(for colorScheme: ColorScheme) -> Color {
        colorScheme == .dark ? red(400) : red(600)
    }

    static func dangerSoft(for colorScheme: ColorScheme) -> Color {
        danger(for: colorScheme).opacity(colorScheme == .dark ? 0.18 : 0.10)
    }
}

private struct AccentScale {
    let shade50: Color
    let shade100: Color
    let shade200: Color
    let shade300: Color
    let shade400: Color
    let shade500: Color
    let shade600: Color
    let shade700: Color
}

private extension BitchatTheme {
    static func accentScale(for palette: BitchatPalette) -> AccentScale {
        switch palette {
        case .sky:
            return AccentScale(
                shade50: color(0xF0F9FF),
                shade100: color(0xE0F2FE),
                shade200: color(0xBAE6FD),
                shade300: color(0x7DD3FC),
                shade400: color(0x38BDF8),
                shade500: color(0x0EA5E9),
                shade600: color(0x0284C7),
                shade700: color(0x0369A1)
            )
        case .cyan:
            return AccentScale(
                shade50: color(0xECFEFF),
                shade100: color(0xCFFAFE),
                shade200: color(0xA5F3FC),
                shade300: color(0x67E8F9),
                shade400: color(0x22D3EE),
                shade500: color(0x06B6D4),
                shade600: color(0x0891B2),
                shade700: color(0x0E7490)
            )
        case .blue:
            return AccentScale(
                shade50: color(0xEFF6FF),
                shade100: color(0xDBEAFE),
                shade200: color(0xBFDBFE),
                shade300: color(0x93C5FD),
                shade400: color(0x60A5FA),
                shade500: color(0x3B82F6),
                shade600: color(0x2563EB),
                shade700: color(0x1D4ED8)
            )
        case .indigo:
            return AccentScale(
                shade50: color(0xEEF2FF),
                shade100: color(0xE0E7FF),
                shade200: color(0xC7D2FE),
                shade300: color(0xA5B4FC),
                shade400: color(0x818CF8),
                shade500: color(0x6366F1),
                shade600: color(0x4F46E5),
                shade700: color(0x4338CA)
            )
        case .violet:
            return AccentScale(
                shade50: color(0xF5F3FF),
                shade100: color(0xEDE9FE),
                shade200: color(0xDDD6FE),
                shade300: color(0xC4B5FD),
                shade400: color(0xA78BFA),
                shade500: color(0x8B5CF6),
                shade600: color(0x7C3AED),
                shade700: color(0x6D28D9)
            )
        case .purple:
            return AccentScale(
                shade50: color(0xFAF5FF),
                shade100: color(0xF3E8FF),
                shade200: color(0xE9D5FF),
                shade300: color(0xD8B4FE),
                shade400: color(0xC084FC),
                shade500: color(0xA855F7),
                shade600: color(0x9333EA),
                shade700: color(0x7E22CE)
            )
        case .fuchsia:
            return AccentScale(
                shade50: color(0xFDF4FF),
                shade100: color(0xFAE8FF),
                shade200: color(0xF5D0FE),
                shade300: color(0xF0ABFC),
                shade400: color(0xE879F9),
                shade500: color(0xD946EF),
                shade600: color(0xC026D3),
                shade700: color(0xA21CAF)
            )
        case .pink:
            return AccentScale(
                shade50: color(0xFDF2F8),
                shade100: color(0xFCE7F3),
                shade200: color(0xFBCFE8),
                shade300: color(0xF9A8D4),
                shade400: color(0xF472B6),
                shade500: color(0xEC4899),
                shade600: color(0xDB2777),
                shade700: color(0xBE185D)
            )
        case .rose:
            return AccentScale(
                shade50: color(0xFFF1F2),
                shade100: color(0xFFE4E6),
                shade200: color(0xFECDD3),
                shade300: color(0xFDA4AF),
                shade400: color(0xFB7185),
                shade500: color(0xF43F5E),
                shade600: color(0xE11D48),
                shade700: color(0xBE123C)
            )
        case .red:
            return AccentScale(
                shade50: color(0xFEF2F2),
                shade100: color(0xFEE2E2),
                shade200: color(0xFECACA),
                shade300: color(0xFCA5A5),
                shade400: color(0xF87171),
                shade500: color(0xEF4444),
                shade600: color(0xDC2626),
                shade700: color(0xB91C1C)
            )
        case .orange:
            return AccentScale(
                shade50: color(0xFFF7ED),
                shade100: color(0xFFEDD5),
                shade200: color(0xFED7AA),
                shade300: color(0xFDBA74),
                shade400: color(0xFB923C),
                shade500: color(0xF97316),
                shade600: color(0xEA580C),
                shade700: color(0xC2410C)
            )
        case .amber:
            return AccentScale(
                shade50: color(0xFFFBEB),
                shade100: color(0xFEF3C7),
                shade200: color(0xFDE68A),
                shade300: color(0xFCD34D),
                shade400: color(0xFBBF24),
                shade500: color(0xF59E0B),
                shade600: color(0xD97706),
                shade700: color(0xB45309)
            )
        case .yellow:
            return AccentScale(
                shade50: color(0xFEFCE8),
                shade100: color(0xFEF9C3),
                shade200: color(0xFEF08A),
                shade300: color(0xFDE047),
                shade400: color(0xFACC15),
                shade500: color(0xEAB308),
                shade600: color(0xCA8A04),
                shade700: color(0xA16207)
            )
        case .lime:
            return AccentScale(
                shade50: color(0xF7FEE7),
                shade100: color(0xECFCCB),
                shade200: color(0xD9F99D),
                shade300: color(0xBEF264),
                shade400: color(0xA3E635),
                shade500: color(0x84CC16),
                shade600: color(0x65A30D),
                shade700: color(0x4D7C0F)
            )
        case .green:
            return AccentScale(
                shade50: color(0xF0FDF4),
                shade100: color(0xDCFCE7),
                shade200: color(0xBBF7D0),
                shade300: color(0x86EFAC),
                shade400: color(0x4ADE80),
                shade500: color(0x22C55E),
                shade600: color(0x16A34A),
                shade700: color(0x15803D)
            )
        case .emerald:
            return AccentScale(
                shade50: color(0xECFDF5),
                shade100: color(0xD1FAE5),
                shade200: color(0xA7F3D0),
                shade300: color(0x6EE7B7),
                shade400: color(0x34D399),
                shade500: color(0x10B981),
                shade600: color(0x059669),
                shade700: color(0x047857)
            )
        case .teal:
            return AccentScale(
                shade50: color(0xF0FDFA),
                shade100: color(0xCCFBF1),
                shade200: color(0x99F6E4),
                shade300: color(0x5EEAD4),
                shade400: color(0x2DD4BF),
                shade500: color(0x14B8A6),
                shade600: color(0x0D9488),
                shade700: color(0x0F766E)
            )
        }
    }

    static func neutral(_ shade: Int) -> Color {
        switch shade {
        case 50: return color(0xFAFAFA)
        case 100: return color(0xF5F5F5)
        case 200: return color(0xE5E5E5)
        case 300: return color(0xD4D4D4)
        case 400: return color(0xA3A3A3)
        case 500: return color(0x737373)
        case 600: return color(0x525252)
        case 700: return color(0x404040)
        case 800: return color(0x262626)
        case 900: return color(0x171717)
        case 950: return color(0x0A0A0A)
        default: return color(0x737373)
        }
    }

    static func red(_ shade: Int) -> Color {
        switch shade {
        case 400: return color(0xF87171)
        case 500: return color(0xEF4444)
        case 600: return color(0xDC2626)
        default: return color(0xEF4444)
        }
    }

    static func color(_ hex: UInt32) -> Color {
        Color(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            opacity: 1
        )
    }
}
