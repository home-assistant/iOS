import HAWatchComplications
import SwiftUI
import Testing
import UIKit

/// A complication's icon arrives as a bitmap with its color already baked into the pixels, so the
/// rendering mode it is drawn with is what decides whether the user's color reaches the watch face.
/// Drawing every icon as a template is what made a configured color render correctly in the iPhone
/// builder preview and land on the face as plain white.
struct ComplicationIconRenderingTests {
    @Test("An icon the user gave a color keeps its own pixels")
    func customColorRendersOriginal() {
        #expect(isOriginal(ComplicationIconRendering.templateRenderingMode(usesCustomColor: true)))
    }

    @Test("An icon with no color of its own stays a template, so it tints with the face")
    func defaultIconRendersAsTemplate() {
        #expect(!isOriginal(ComplicationIconRendering.templateRenderingMode(usesCustomColor: false)))
    }

    /// The rendering mode is only a means to an end, so this draws the icon the way a complication
    /// does — green pixels under a red tint — and looks at what came out. A custom-colored icon has
    /// to stay green; the tint is what a white icon on the watch face was coming from.
    @MainActor
    @Test("Drawn under a tint, a custom-colored icon keeps its color and a default one takes the tint")
    func drawnIconHonorsTheConfiguredColor() throws {
        let custom = try #require(drawnCenterPixel(usesCustomColor: true))
        #expect(custom.green > custom.red)

        let plain = try #require(drawnCenterPixel(usesCustomColor: false))
        #expect(plain.red > plain.green)
    }

    // MARK: - Helpers

    /// Pattern-matched rather than compared: `Image.TemplateRenderingMode` makes no promise of
    /// `Equatable`, and this only needs to tell the two cases apart.
    private func isOriginal(_ mode: Image.TemplateRenderingMode) -> Bool {
        if case .original = mode { return true }
        return false
    }

    /// Draws a solid green icon tinted red and reads the middle of the result.
    @MainActor
    private func drawnCenterPixel(usesCustomColor: Bool) -> (red: UInt8, green: UInt8)? {
        let renderer = ImageRenderer(
            content: ComplicationIconRendering.image(greenSwatch(), usesCustomColor: usesCustomColor)
                .resizable()
                .frame(width: Self.swatchSide, height: Self.swatchSide)
                .foregroundStyle(Color.red)
        )
        renderer.scale = 1
        return renderer.cgImage.flatMap(centerPixel(of:))
    }

    private static let swatchSide: CGFloat = 8

    /// An opaque bitmap in a color nothing else in the pipeline would produce.
    private func greenSwatch() -> UIImage {
        let size = CGSize(width: Self.swatchSide, height: Self.swatchSide)
        return UIGraphicsImageRenderer(size: size).image { context in
            UIColor.green.setFill()
            context.fill(CGRect(origin: .zero, size: size))
        }
    }

    /// The red and green channels of the bitmap's middle pixel, which is inside the icon either way.
    private func centerPixel(of cgImage: CGImage) -> (red: UInt8, green: UInt8)? {
        var pixels = [UInt8](repeating: 0, count: cgImage.width * cgImage.height * 4)
        // The context writes through the borrowed pointer as it draws, so the drawing happens inside
        // the borrow — handing it `&pixels` would leave the pointer dangling.
        let drawn = pixels.withUnsafeMutableBytes { buffer -> Bool in
            guard let baseAddress = buffer.baseAddress, let context = CGContext(
                data: baseAddress,
                width: cgImage.width,
                height: cgImage.height,
                bitsPerComponent: 8,
                bytesPerRow: cgImage.width * 4,
                space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
            ) else { return false }
            context.draw(cgImage, in: CGRect(x: 0, y: 0, width: cgImage.width, height: cgImage.height))
            return true
        }
        guard drawn else { return nil }
        let offset = ((cgImage.height / 2) * cgImage.width + cgImage.width / 2) * 4
        guard offset + 1 < pixels.count else { return nil }
        return (red: pixels[offset], green: pixels[offset + 1])
    }
}
