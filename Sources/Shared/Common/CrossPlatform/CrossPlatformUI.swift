// Cross-platform UI shim — native macOS (AppKit) only.
//
// When `Shared` builds against the native macOS SDK (target Shared-macOS),
// UIKit is unavailable and only AppKit exists. This file bridges the *resource
// layer* (colors, fonts, images, insets, haptics) so the large body of
// resource-handling code in `Shared` compiles on macOS with minimal churn.
//
// IMPORTANT: This intentionally does NOT alias the view-hierarchy types
// (UIView / UIViewController / UIButton / …). Those APIs diverge too much
// between UIKit and AppKit to alias safely; mac equivalents are SwiftUI.
//
// Active only on native macOS: `canImport(AppKit) && !canImport(UIKit)`.
// On iOS and Mac Catalyst, UIKit is present and this file compiles to nothing,
// so the iOS targets are unaffected even though the file is a member of
// Shared-macOS only.

#if canImport(AppKit) && !canImport(UIKit)
import AppKit

// MARK: - Resource type bridges

public typealias UIColor = NSColor
public typealias UIFont = NSFont
public typealias UIImage = NSImage
public typealias UIBezierPath = NSBezierPath
public typealias UIEdgeInsets = NSEdgeInsets

// MARK: - UIKit-named semantic colors

public extension NSColor {
    static var label: NSColor { .labelColor }
    static var secondaryLabel: NSColor { .secondaryLabelColor }
    static var tertiaryLabel: NSColor { .tertiaryLabelColor }
    static var quaternaryLabel: NSColor { .quaternaryLabelColor }
    static var placeholderText: NSColor { .placeholderTextColor }
    static var separator: NSColor { .separatorColor }
    static var link: NSColor { .linkColor }

    // AppKit has no `systemBackground` family; map to the closest window/control roles.
    static var systemBackground: NSColor { .windowBackgroundColor }
    static var secondarySystemBackground: NSColor { .underPageBackgroundColor }
    static var tertiarySystemBackground: NSColor { .controlBackgroundColor }
    static var systemGroupedBackground: NSColor { .windowBackgroundColor }
    static var secondarySystemGroupedBackground: NSColor { .controlBackgroundColor }

    // `systemGrayN` shades don't exist on AppKit; approximate from `systemGray`.
    static var systemGray: NSColor { NSColor(white: 0.56, alpha: 1) }
    static var systemGray2: NSColor { NSColor(white: 0.62, alpha: 1) }
    static var systemGray3: NSColor { NSColor(white: 0.78, alpha: 1) }
    static var systemGray4: NSColor { NSColor(white: 0.82, alpha: 1) }
    static var systemGray5: NSColor { NSColor(white: 0.90, alpha: 1) }
    static var systemGray6: NSColor { NSColor(white: 0.95, alpha: 1) }
}

// MARK: - NSEdgeInsets parity with UIEdgeInsets

public extension NSEdgeInsets {
    static var zero: NSEdgeInsets { NSEdgeInsets(top: 0, left: 0, bottom: 0, right: 0) }
}

// MARK: - Haptic feedback stubs (no haptics on macOS)

public enum UIImpactFeedbackStyle: Int {
    case light, medium, heavy, soft, rigid
}

public final class UIImpactFeedbackGenerator {
    public init() {}
    public init(style: UIImpactFeedbackStyle) {}
    public func prepare() {}
    public func impactOccurred() {}
    public func impactOccurred(intensity: CGFloat) {}
}

public final class UINotificationFeedbackGenerator {
    public enum FeedbackType: Int { case success, warning, error }
    public init() {}
    public func prepare() {}
    public func notificationOccurred(_ type: FeedbackType) {}
}

public final class UISelectionFeedbackGenerator {
    public init() {}
    public func prepare() {}
    public func selectionChanged() {}
}

#endif
