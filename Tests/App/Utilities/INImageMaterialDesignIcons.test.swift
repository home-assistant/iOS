import Foundation
import Intents
@testable import Shared
import Testing
import UIKit

struct INImageMaterialDesignIconsTests {
    /// `INImage` keeps its pixels to itself, but it archives the data it was made from, so the PNG the
    /// renderer drew is what the archive carries.
    @Test func drawsTheIconIntoAPNG() throws {
        let image = INImage(icon: .homeIcon, foreground: .white, background: .blue)

        let archive = try NSKeyedArchiver.archivedData(withRootObject: image, requiringSecureCoding: true)
        let pngSignature = Data([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A])
        #expect(archive.range(of: pngSignature) != nil)
    }
}
