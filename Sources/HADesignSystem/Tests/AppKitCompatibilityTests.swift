#if os(macOS)
import AppKit
import HAIconic
import XCTest

/// The AppKit stand-ins for the UIKit types the shared screens are written against.
final class AppKitCompatibilityTests: XCTestCase {
    /// The renderer's origin is the top-left corner, as UIKit's is, so drawing written for iOS lands in the
    /// same place: a fill of the top half of the image is in the top rows of the bitmap.
    func testRendererDrawsWithATopLeftOrigin() throws {
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: 2, height: 2), scale: 1)

        let image = renderer.image { _ in
            NSColor.red.setFill()
            UIRectFill(CGRect(x: 0, y: 0, width: 2, height: 1))
        }

        let bitmap = try XCTUnwrap(image.representations.first as? NSBitmapImageRep)
        XCTAssertEqual(bitmap.pixelsWide, 2)
        XCTAssertEqual(bitmap.pixelsHigh, 2)
        let top = try XCTUnwrap(bitmap.colorAt(x: 0, y: 0)?.rgbaComponents)
        let bottom = try XCTUnwrap(bitmap.colorAt(x: 0, y: 1)?.rgbaComponents)
        XCTAssertEqual(top.red, 1, accuracy: 0.01)
        XCTAssertEqual(top.alpha, 1, accuracy: 0.01)
        XCTAssertEqual(bottom.alpha, 0, accuracy: 0.01)
    }

    /// The renderer draws at the given scale, so the bitmap has that many pixels per point.
    func testRendererHonoursTheScale() throws {
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: 3, height: 2), scale: 2)

        let image = renderer.image { _ in }

        let bitmap = try XCTUnwrap(image.representations.first as? NSBitmapImageRep)
        XCTAssertEqual(bitmap.pixelsWide, 6)
        XCTAssertEqual(bitmap.pixelsHigh, 4)
        XCTAssertEqual(image.size, CGSize(width: 3, height: 2))
        XCTAssertEqual(image.scale, 2)
    }

    /// Reading components off a catalog color raises unless it is resolved first, which `rgbaComponents` does.
    func testCatalogColorHasComponents() throws {
        let components = try XCTUnwrap(NSColor.labelColor.rgbaComponents)

        for component in [components.red, components.green, components.blue, components.alpha] {
            XCTAssert((0 ... 1).contains(component))
        }
    }

    func testPatternColorHasNoComponents() {
        let pattern = NSColor(patternImage: NSImage(size: CGSize(width: 1, height: 1)))

        XCTAssertNil(pattern.rgbaComponents)
    }

    /// A dynamic color answers for whichever appearance is drawing.
    func testDynamicColorFollowsTheAppearance() throws {
        let color = NSColor.dynamic(light: .white, dark: .black)
        let aqua = try XCTUnwrap(NSAppearance(named: .aqua))
        let darkAqua = try XCTUnwrap(NSAppearance(named: .darkAqua))

        var light: CGFloat?
        aqua.performAsCurrentDrawingAppearance {
            light = color.rgbaComponents?.red
        }
        var dark: CGFloat?
        darkAqua.performAsCurrentDrawingAppearance {
            dark = color.rgbaComponents?.red
        }

        XCTAssertEqual(try XCTUnwrap(light), 1, accuracy: 0.01)
        XCTAssertEqual(try XCTUnwrap(dark), 0, accuracy: 0.01)
    }
}
#endif
