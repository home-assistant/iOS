#if os(macOS)
import AppKit
import SwiftUI

// The native macOS app shares its models, icons and SwiftUI screens with the iOS app. Those files describe
// colors, images, fonts and insets with the UIKit value types, so on macOS the same names resolve to their
// AppKit counterparts and the small API differences between the two are filled in below. This keeps the
// shared code free of per-platform branches; anything that is a real view or controller is written against
// AppKit or SwiftUI directly rather than routed through this file.

public typealias UIColor = NSColor
public typealias UIImage = NSImage
public typealias UIFont = NSFont
public typealias UIEdgeInsets = NSEdgeInsets
public typealias UIBezierPath = NSBezierPath

// MARK: - Insets

public extension NSEdgeInsets {
    static var zero: NSEdgeInsets { NSEdgeInsetsZero }
}

public extension CGRect {
    func inset(by insets: NSEdgeInsets) -> CGRect {
        CGRect(
            x: origin.x + insets.left,
            y: origin.y + insets.top,
            width: size.width - insets.left - insets.right,
            height: size.height - insets.top - insets.bottom
        )
    }
}

// MARK: - Fonts

public extension NSFont {
    static var familyNames: [String] { NSFontManager.shared.availableFontFamilies }

    static func preferredFont(forTextStyle style: NSFont.TextStyle) -> NSFont {
        preferredFont(forTextStyle: style, options: [:])
    }

    var lineHeight: CGFloat {
        NSLayoutManager().defaultLineHeight(for: self)
    }
}

// MARK: - Images

public extension NSImage {
    enum RenderingMode {
        case automatic
        case alwaysOriginal
        case alwaysTemplate
    }

    /// The scale bitmaps are rendered at: the densest screen attached, so an image stays sharp when its
    /// window moves between screens of different densities.
    static var defaultRenderingScale: CGFloat {
        NSScreen.screens.map(\.backingScaleFactor).max() ?? 2
    }

    var scale: CGFloat {
        guard let representation = representations.first, size.width > 0 else { return 1 }
        return CGFloat(representation.pixelsWide) / size.width
    }

    var cgImage: CGImage? {
        cgImage(forProposedRect: nil, context: nil, hints: nil)
    }

    convenience init(cgImage: CGImage) {
        self.init(cgImage: cgImage, size: .zero)
    }

    convenience init?(systemName: String) {
        self.init(systemSymbolName: systemName, accessibilityDescription: nil)
    }

    func withRenderingMode(_ renderingMode: RenderingMode) -> NSImage {
        guard let copy = copy() as? NSImage else { return self }
        switch renderingMode {
        case .automatic: break
        case .alwaysOriginal: copy.isTemplate = false
        case .alwaysTemplate: copy.isTemplate = true
        }
        return copy
    }

    func pngData() -> Data? {
        bitmapRepresentation?.representation(using: .png, properties: [:])
    }

    func jpegData(compressionQuality: CGFloat) -> Data? {
        bitmapRepresentation?.representation(using: .jpeg, properties: [.compressionFactor: compressionQuality])
    }

    private var bitmapRepresentation: NSBitmapImageRep? {
        if let bitmap = representations.compactMap({ $0 as? NSBitmapImageRep }).first {
            return bitmap
        }
        guard let cgImage else { return nil }
        return NSBitmapImageRep(cgImage: cgImage)
    }
}

// MARK: - Colors

public extension NSColor {
    /// The color resolved against the current appearance and converted to extended sRGB, the space UIKit's
    /// `getRed` reports in, or nil for a color that has no component representation (a pattern color).
    /// Reading components straight off a catalog or dynamic `NSColor` raises, so every component read goes
    /// through here.
    var resolvedSRGB: NSColor? {
        usingColorSpace(.extendedSRGB)
    }
}

// MARK: - System colors

/// The UIKit semantic colors, mapped to the AppKit color that plays the same role.
public extension NSColor {
    static var label: NSColor { .labelColor }
    static var secondaryLabel: NSColor { .secondaryLabelColor }
    static var tertiaryLabel: NSColor { .tertiaryLabelColor }
    static var quaternaryLabel: NSColor { .quaternaryLabelColor }
    static var placeholderText: NSColor { .placeholderTextColor }
    static var link: NSColor { .linkColor }
    static var separator: NSColor { .separatorColor }
    static var opaqueSeparator: NSColor { .gridColor }

    /// The page is the window; what sits on it is lighter than the window in the dark and white in the
    /// light, as a grouped form's cards are, so a card does not vanish into the page.
    static var systemBackground: NSColor { .windowBackgroundColor }
    static var secondarySystemBackground: NSColor { .dynamic(light: gray(255, 255, 255), dark: gray(50, 50, 52)) }
    static var tertiarySystemBackground: NSColor { .dynamic(light: gray(245, 245, 247), dark: gray(64, 64, 66)) }
    static var systemGroupedBackground: NSColor { .windowBackgroundColor }
    static var secondarySystemGroupedBackground: NSColor { secondarySystemBackground }
    static var tertiarySystemGroupedBackground: NSColor { tertiarySystemBackground }

    static var systemGray2: NSColor { .dynamic(light: gray(174, 174, 178), dark: gray(99, 99, 102)) }
    static var systemGray3: NSColor { .dynamic(light: gray(199, 199, 204), dark: gray(72, 72, 74)) }
    static var systemGray4: NSColor { .dynamic(light: gray(209, 209, 214), dark: gray(58, 58, 60)) }
    static var systemGray5: NSColor { .dynamic(light: gray(229, 229, 234), dark: gray(44, 44, 46)) }
    static var systemGray6: NSColor { .dynamic(light: gray(242, 242, 247), dark: gray(28, 28, 30)) }

    private static func gray(_ red: CGFloat, _ green: CGFloat, _ blue: CGFloat) -> NSColor {
        NSColor(srgbRed: red / 255, green: green / 255, blue: blue / 255, alpha: 1)
    }
}

// MARK: - SwiftUI

public extension Color {
    init(uiColor: NSColor) {
        self.init(nsColor: uiColor)
    }
}

public extension Image {
    init(uiImage: NSImage) {
        self.init(nsImage: uiImage)
    }
}

// MARK: - Bitmap rendering

public func UIRectFill(_ rect: CGRect) {
    rect.fill()
}
#endif
