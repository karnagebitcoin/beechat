import Foundation
import SwiftUI
import CoreText

/// Provides Dynamic Type aware font helpers that map existing fixed sizes onto
/// preferred text styles so the UI scales with user accessibility settings.
extension Font {
    static func bitchatSystem(size: CGFloat, weight: Font.Weight = .regular, design: Font.Design = .default) -> Font {
        let style = Font.TextStyle.bitchatPreferredStyle(for: size)
        var font = Font.system(style, design: design.bitchatNormalized)
        if weight != .regular {
            font = font.weight(weight)
        }
        return font
    }

    static func bitchatWordmark(size: CGFloat, weight: BitchatWordmarkWeight = .bold) -> Font {
        if BitchatWordmarkFontRegistry.registerIfNeeded() {
            return .custom(weight.postScriptName, size: size)
        }
        return bitchatSystem(size: size, weight: weight.fontWeight)
    }
}

enum BitchatWordmarkWeight {
    case regular
    case bold

    fileprivate var postScriptName: String {
        switch self {
        case .regular:
            return "PixelifySans-Regular"
        case .bold:
            return "PixelifySans-Bold"
        }
    }

    fileprivate var fontWeight: Font.Weight {
        switch self {
        case .regular:
            return .regular
        case .bold:
            return .bold
        }
    }
}

private enum BitchatWordmarkFontRegistry {
    static func registerIfNeeded() -> Bool {
        registrationSucceeded
    }

    private static let registrationSucceeded: Bool = {
        registerFont(named: "PixelifySans-Regular") && registerFont(named: "PixelifySans-Bold")
    }()

    private static func registerFont(named name: String) -> Bool {
        guard let url = fontURL(named: name) else { return false }

        var error: Unmanaged<CFError>?
        let succeeded = CTFontManagerRegisterFontsForURL(url as CFURL, .process, &error)
        if succeeded {
            return true
        }

        guard let registrationError = error?.takeRetainedValue() as Error? else {
            return false
        }

        let nsError = registrationError as NSError
        return nsError.domain == kCTFontManagerErrorDomain as String &&
            nsError.code == CTFontManagerError.alreadyRegistered.rawValue
    }

    private static func fontURL(named name: String) -> URL? {
        for bundle in candidateBundles() {
            if let url = bundle.url(forResource: name, withExtension: "ttf", subdirectory: "Fonts")
                ?? bundle.url(forResource: name, withExtension: "ttf") {
                return url
            }
        }

        return nil
    }

    private static func candidateBundles() -> [Bundle] {
        var bundles: [Bundle] = [Bundle.main]

        if let resourceURL = Bundle.main.resourceURL {
            for bundleName in ["bitchat_bitchat.bundle", "bitchat.bundle"] {
                let bundleURL = resourceURL.appendingPathComponent(bundleName)
                if let bundle = Bundle(url: bundleURL) {
                    bundles.append(bundle)
                }
            }
        }

        bundles.append(contentsOf: Bundle.allBundles)
        bundles.append(contentsOf: Bundle.allFrameworks)

        var seenPaths = Set<String>()
        return bundles.filter { bundle in
            seenPaths.insert(bundle.bundlePath).inserted
        }
    }
}

private extension Font.Design {
    var bitchatNormalized: Font.Design {
        switch self {
        case .monospaced:
            // Use the platform system UI font instead of the old terminal-like mono style.
            return .default
        default:
            return self
        }
    }
}

private extension Font.TextStyle {
    static func bitchatPreferredStyle(for size: CGFloat) -> Font.TextStyle {
        switch size {
        case ..<11.5:
            return .caption2
        case ..<13.0:
            return .caption
        case ..<13.75:
            return .footnote
        case ..<15.5:
            return .subheadline
        case ..<17.5:
            return .callout
        case ..<19.5:
            return .body
        case ..<22.5:
            return .title3
        case ..<27.5:
            return .title2
        case ..<34.0:
            return .title
        default:
            return .largeTitle
        }
    }
}
