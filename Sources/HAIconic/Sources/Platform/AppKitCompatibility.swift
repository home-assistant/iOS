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

// MARK: - Corners

public struct UIRectCorner: OptionSet, Sendable {
    public let rawValue: UInt

    public init(rawValue: UInt) {
        self.rawValue = rawValue
    }

    public static let topLeft = UIRectCorner(rawValue: 1 << 0)
    public static let topRight = UIRectCorner(rawValue: 1 << 1)
    public static let bottomLeft = UIRectCorner(rawValue: 1 << 2)
    public static let bottomRight = UIRectCorner(rawValue: 1 << 3)
    public static let allCorners: UIRectCorner = [.topLeft, .topRight, .bottomLeft, .bottomRight]
}

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

    /// The scale bitmaps are rendered at. AppKit images are resolution independent, so this is the scale of
    /// the screen they are most likely to be drawn on.
    static var defaultRenderingScale: CGFloat { NSScreen.main?.backingScaleFactor ?? 2 }

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
    /// The color resolved against the current appearance and converted to sRGB, or nil for a color that has
    /// no component representation (a pattern color). Reading components straight off a catalog or dynamic
    /// `NSColor` raises, so every component read goes through here.
    var resolvedSRGB: NSColor? {
        var resolved: NSColor?
        NSAppearance.currentDrawing().performAsCurrentDrawingAppearance {
            resolved = usingColorSpace(.sRGB)
        }
        return resolved
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

    static var systemBackground: NSColor { .windowBackgroundColor }
    static var secondarySystemBackground: NSColor { .controlBackgroundColor }
    static var tertiarySystemBackground: NSColor { .underPageBackgroundColor }
    static var systemGroupedBackground: NSColor { .windowBackgroundColor }
    static var secondarySystemGroupedBackground: NSColor { .controlBackgroundColor }
    static var tertiarySystemGroupedBackground: NSColor { .underPageBackgroundColor }

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

public final class UIGraphicsImageRendererContext {
    public let cgContext: CGContext

    init(cgContext: CGContext) {
        self.cgContext = cgContext
    }
}

/// Draws into a bitmap with a top-left origin, like its UIKit namesake, so drawing code written for iOS
/// lays out the same way. The drawing runs once, up front, rather than each time the image is displayed.
public final class UIGraphicsImageRenderer {
    private let size: CGSize
    private let scale: CGFloat

    public init(size: CGSize, scale: CGFloat = NSImage.defaultRenderingScale) {
        self.size = size
        self.scale = scale
    }

    public func image(actions: (UIGraphicsImageRendererContext) -> Void) -> NSImage {
        let pixelsWide = Int((size.width * scale).rounded(.up))
        let pixelsHigh = Int((size.height * scale).rounded(.up))

        guard pixelsWide > 0, pixelsHigh > 0, let bitmap = NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: pixelsWide,
            pixelsHigh: pixelsHigh,
            bitsPerSample: 8,
            samplesPerPixel: 4,
            hasAlpha: true,
            isPlanar: false,
            colorSpaceName: .deviceRGB,
            bytesPerRow: 0,
            bitsPerPixel: 0
        ) else {
            return NSImage(size: size)
        }
        bitmap.size = size

        guard let bitmapContext = NSGraphicsContext(bitmapImageRep: bitmap) else {
            return NSImage(size: size)
        }

        let cgContext = bitmapContext.cgContext
        cgContext.translateBy(x: 0, y: size.height)
        cgContext.scaleBy(x: 1, y: -1)

        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(cgContext: cgContext, flipped: true)
        actions(UIGraphicsImageRendererContext(cgContext: cgContext))
        NSGraphicsContext.restoreGraphicsState()

        let image = NSImage(size: size)
        image.addRepresentation(bitmap)
        return image
    }

    public func pngData(actions: (UIGraphicsImageRendererContext) -> Void) -> Data {
        image(actions: actions).pngData() ?? Data()
    }
}

// MARK: - Pasteboard

/// The general pasteboard, under the name and shape the shared screens already use to copy text.
public final class UIPasteboard {
    public static let general = UIPasteboard()

    private init() {}

    public var string: String? {
        get {
            NSPasteboard.general.string(forType: .string)
        }
        set {
            NSPasteboard.general.clearContents()
            if let newValue {
                NSPasteboard.general.setString(newValue, forType: .string)
            }
        }
    }
}

// MARK: - Haptics

/// A Mac has one kind of haptic, played by a Force Touch trackpad, so every notification type feels alike.
public final class UINotificationFeedbackGenerator {
    public enum FeedbackType {
        case success
        case warning
        case error
    }

    public init() {}

    public func prepare() {}

    public func notificationOccurred(_ notificationType: FeedbackType) {
        NSHapticFeedbackManager.defaultPerformer.perform(.levelChange, performanceTime: .default)
    }
}

/// The tick a Force Touch trackpad plays as something snaps into alignment.
public final class UISelectionFeedbackGenerator {
    public init() {}

    public func prepare() {}

    public func selectionChanged() {
        NSHapticFeedbackManager.defaultPerformer.perform(.alignment, performanceTime: .default)
    }
}

/// A Mac has one kind of haptic, played by a Force Touch trackpad, so every impact style feels alike.
public final class UIImpactFeedbackGenerator {
    public enum FeedbackStyle {
        case light
        case medium
        case heavy
        case soft
        case rigid
    }

    public init(style: FeedbackStyle = .medium) {}

    public func prepare() {}

    public func impactOccurred() {
        NSHapticFeedbackManager.defaultPerformer.perform(.generic, performanceTime: .default)
    }
}
#endif
