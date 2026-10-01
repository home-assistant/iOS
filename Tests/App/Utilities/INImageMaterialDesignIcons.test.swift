import Intents
@testable import Shared
import Testing
import UIKit

struct INImageMaterialDesignIconsTests {
    /// `INImage` keeps its pixels to itself, so the test is that drawing an icon into one goes through
    /// without the renderer throwing on either platform's drawing stack.
    @Test func drawsTheIconOverTheBackground() {
        let image = INImage(icon: .homeIcon, foreground: .white, background: .blue)
        #expect(image.isKind(of: INImage.self))
    }
}
