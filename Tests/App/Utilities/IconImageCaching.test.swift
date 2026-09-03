@testable import Shared
import Testing
import UIKit

/// Runs in the app-hosted Tests-App target: rasterizing a glyph needs the Material Design icon font, which
/// the hostless Tests-Shared target cannot load.
@MainActor
struct IconImageCachingTests {
    private let size = CGSize(width: 20, height: 20)

    @Test func repeatedRequestsForTheSameGlyphReuseOneBitmap() {
        MaterialDesignIcons.register()

        let first = MaterialDesignIcons.lightbulbIcon.image(ofSize: size, color: .white)
        let second = MaterialDesignIcons.lightbulbIcon.image(ofSize: size, color: .white)

        #expect(first === second)
    }

    @Test func iconColorAndSizeEachChangeTheBitmap() {
        MaterialDesignIcons.register()
        let larger = CGSize(width: 24, height: 24)

        let white = MaterialDesignIcons.lightbulbIcon.image(ofSize: size, color: .white)

        #expect(white !== MaterialDesignIcons.lightbulbIcon.image(ofSize: size, color: .black))
        #expect(white !== MaterialDesignIcons.lightbulbIcon.image(ofSize: larger, color: .white))
        #expect(white !== MaterialDesignIcons.thermometerIcon.image(ofSize: size, color: .white))
    }

    /// A dynamic color draws as a different color per appearance, so a light-mode bitmap must not be the one
    /// handed back in dark mode.
    @Test func aDynamicColorIsNotSharedAcrossAppearances() {
        MaterialDesignIcons.register()
        var light: UIImage?
        var dark: UIImage?

        UITraitCollection(userInterfaceStyle: .light).performAsCurrent {
            light = MaterialDesignIcons.lightbulbIcon.image(ofSize: size, color: .label)
        }
        UITraitCollection(userInterfaceStyle: .dark).performAsCurrent {
            dark = MaterialDesignIcons.lightbulbIcon.image(ofSize: size, color: .label)
        }

        #expect(light !== dark)
        #expect(light?.pngData() != dark?.pngData())
    }

    @Test func edgeInsetsChangeTheBitmap() {
        MaterialDesignIcons.register()

        let flush = MaterialDesignIcons.lightbulbIcon.image(ofSize: size, color: .white, edgeInsets: .zero)
        let inset = MaterialDesignIcons.lightbulbIcon.image(
            ofSize: size,
            color: .white,
            edgeInsets: .init(top: 2, left: 2, bottom: 2, right: 2)
        )

        #expect(flush !== inset)
        #expect(flush.size != inset.size)
    }
}
