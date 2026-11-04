import CoreGraphics
@testable import Shared
import Testing
import UIKit

struct FrontendIconTests {
    @Test("The names the frontend bundles itself resolve to the vendored logo")
    func resolvesBrandIcons() {
        #expect(FrontendIcon(serversideValueNamed: "mdi:matter", fallback: .puzzleIcon) == .brand(.matter))
        #expect(
            FrontendIcon(serversideValueNamed: "mdi:music-assistant", fallback: .puzzleIcon) == .brand(.musicAssistant)
        )
        #expect(FrontendIcon(serversideValueNamed: "mdi:esphome", fallback: .puzzleIcon) == .brand(.esphome))
        #expect(FrontendIcon(serversideValueNamed: "mdi:mqtt", fallback: .puzzleIcon) == .brand(.mqtt))
    }

    @Test("Every prefix Material Design Icons answers to reaches the logos, and no other one does")
    func resolvesBrandIconsPerPrefix() {
        // `MDI_PREFIXES` in the frontend's `data/iconsets.ts`; the brand logos sit behind that gate.
        #expect(FrontendIcon(serversideValueNamed: "hass:matter", fallback: .puzzleIcon) == .brand(.matter))
        #expect(FrontendIcon(serversideValueNamed: "hassio:matter", fallback: .puzzleIcon) == .brand(.matter))
        #expect(FrontendIcon(serversideValueNamed: "hademo:matter", fallback: .puzzleIcon) == .brand(.matter))
        #expect(FrontendIcon(serversideValueNamed: "hacs:matter", fallback: .puzzleIcon) == .material(.puzzleIcon))
    }

    @Test("Everything else stays a Material Design icon")
    func resolvesMaterialDesignIcons() {
        #expect(FrontendIcon(serversideValueNamed: "mdi:zigbee", fallback: .puzzleIcon) == .material(.zigbeeIcon))
        #expect(FrontendIcon(serversideValueNamed: "hass:cog", fallback: .puzzleIcon) == .material(.cogIcon))
        #expect(FrontendIcon(serversideValueNamed: "hassio:cog", fallback: .puzzleIcon) == .material(.cogIcon))
        #expect(FrontendIcon(serversideValueNamed: "hacs:hacs", fallback: .puzzleIcon) == .material(.puzzleIcon))
    }

    @Test("A brand logo draws")
    func brandIconDraws() {
        let image = BrandIcon.matter.image(ofSize: CGSize(width: 24, height: 24), color: .black)
        #expect(image.size == CGSize(width: 24, height: 24))
        #expect(image.hasOpaquePixels)
    }
}

private extension UIImage {
    /// True when anything was actually drawn, so an icon that silently fails to parse is a failure.
    var hasOpaquePixels: Bool {
        guard let cgImage, let data = cgImage.dataProvider?.data as Data? else { return false }
        return data.enumerated().contains { index, byte in index % 4 == 3 && byte > 0 }
    }
}
