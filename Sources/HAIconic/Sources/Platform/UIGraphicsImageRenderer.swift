#if os(macOS)
import AppKit

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
#endif
