import SwiftUI

#if os(macOS)
import AppKit

struct MacOverlayScrollerConfigurator: NSViewRepresentable {
    let colorScheme: ColorScheme

    func makeNSView(context: Context) -> NSView {
        NSView(frame: .zero)
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        DispatchQueue.main.async {
            guard let scrollView = enclosingScrollView(from: nsView) else { return }
            scrollView.hasVerticalScroller = true
            scrollView.scrollerStyle = .overlay
            scrollView.scrollerKnobStyle = colorScheme == .dark ? .light : .dark
            scrollView.autohidesScrollers = false
            scrollView.drawsBackground = false
            scrollView.verticalScroller?.controlSize = .small
            scrollView.verticalScroller?.alphaValue = colorScheme == .dark ? 0.72 : 0.55
        }
    }

    private func enclosingScrollView(from view: NSView) -> NSScrollView? {
        var current: NSView? = view
        while let candidate = current {
            if let scrollView = candidate as? NSScrollView {
                return scrollView
            }
            current = candidate.superview
        }
        return nil
    }
}
#endif
