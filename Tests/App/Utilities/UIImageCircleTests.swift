@testable import HomeAssistant
import Testing
import UIKit

/// Cropping an image to a circle draws a new image of the same size.
struct UIImageCircleTests {
    @Test func croppingDrawsANewImageOfTheSameSize() {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let square = UIGraphicsImageRenderer(size: CGSize(width: 20, height: 20), format: format).image { context in
            UIColor.red.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 20, height: 20))
        }

        let circle = square.croppedToCircle()

        #expect(circle.size == square.size)
        #expect(circle !== square)
        #expect(circle.cgImage != nil)
    }
}
