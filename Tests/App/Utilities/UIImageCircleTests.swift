@testable import HomeAssistant
import Testing
import UIKit

struct UIImageCircleTests {
    @Test func cropsTheCornersAwayAndKeepsTheCenter() throws {
        let size = CGSize(width: 40, height: 40)
        let square = UIGraphicsImageRenderer(size: size).image { context in
            UIColor.red.setFill()
            context.fill(CGRect(origin: .zero, size: size))
        }

        let circle = square.croppedToCircle()

        #expect(circle.size == size)
        let pixels = try #require(circle.cgImage.flatMap(Self.alphaChannel))
        #expect(pixels(1, 1) == 0)
        #expect(pixels(20, 20) == 255)
    }

    /// Reads the alpha of a pixel from a copy of the image drawn into an alpha-only context.
    private static func alphaChannel(of image: CGImage) -> ((Int, Int) -> UInt8)? {
        let width = image.width, height = image.height
        var data = [UInt8](repeating: 0, count: width * height)
        guard let context = CGContext(
            data: &data,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: width,
            space: CGColorSpaceCreateDeviceGray(),
            bitmapInfo: CGImageAlphaInfo.alphaOnly.rawValue
        ) else { return nil }
        context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
        let scale = width / 40
        return { x, y in data[(height - 1 - y * scale) * width + x * scale] }
    }
}
