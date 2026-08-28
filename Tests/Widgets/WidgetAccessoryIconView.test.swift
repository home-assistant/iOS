import HADesignSystem
import HAIconic
import Testing
import UIKit

/// The lock screen draws a widget's archived view tree outside our extension, where a font the
/// extension registered at runtime does not exist — a glyph left as text comes out as a missing
/// character, which is what made the icon based lock screen widgets look empty on device while the
/// simulator drew them fine.
///
/// ``WidgetAccessoryIconView`` sidesteps that by rasterizing the glyph while the font is still
/// available. These check the rasterizing itself, which is the part a snapshot cannot: the
/// reference images are recorded in a simulator, where the font is registered either way.
struct WidgetAccessoryIconViewTests {
    @Test func rasterizesTheGlyphAtTheRequestedSize() {
        MaterialDesignIcons.register()
        let image = MaterialDesignIcons.lightbulbIcon.image(ofSize: .init(width: 36, height: 36), color: .white)

        #expect(image.size == CGSize(width: 36, height: 36))
        #expect(Self.inkedPixels(of: image) > 0, "the glyph should be drawn, not left as an empty canvas")
    }

    /// Two different glyphs have to come out as two different bitmaps. Without the icon font every
    /// private-use character falls back to the same missing-character box, which is exactly the
    /// failure this view exists to rule out.
    @Test func differentIconsRasterizeDifferently() {
        MaterialDesignIcons.register()
        let size = CGSize(width: 36, height: 36)
        let lightbulb = MaterialDesignIcons.lightbulbIcon.image(ofSize: size, color: .white)
        let thermometer = MaterialDesignIcons.thermometerIcon.image(ofSize: size, color: .white)

        #expect(lightbulb.pngData() != thermometer.pngData())
    }

    /// How many pixels the glyph actually painted.
    private static func inkedPixels(of image: UIImage) -> Int {
        guard let cgImage = image.cgImage else { return 0 }
        let width = cgImage.width
        let height = cgImage.height
        var pixels = [UInt8](repeating: 0, count: width * height * 4)
        guard let context = CGContext(
            data: &pixels,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: width * 4,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return 0 }
        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))

        var inked = 0
        for alpha in stride(from: 3, to: pixels.count, by: 4) where pixels[alpha] > 0 {
            inked += 1
        }
        return inked
    }
}
