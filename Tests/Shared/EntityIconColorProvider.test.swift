@testable import Shared
import SwiftUI
import Testing
import UIKit

struct EntityIconColorProviderTests {
    private func color(
        domain: Domain,
        state: String,
        colorMode: String? = nil,
        rgb: [Int]? = nil,
        hs: [Double]? = nil
    ) -> Color {
        EntityIconColorProvider.iconColor(
            domain: domain,
            state: state,
            colorMode: colorMode,
            rgbColor: rgb,
            hsColor: hs
        )
    }

    @Test func lockStatesUseFrontendPalette() {
        #expect(color(domain: .lock, state: "locked") == EntityIconColorProvider.lockLockedColor)
        #expect(color(domain: .lock, state: "unlocked") == EntityIconColorProvider.lockUnlockedColor)
        #expect(color(domain: .lock, state: "jammed") == EntityIconColorProvider.lockUnlockedColor)
        #expect(color(domain: .lock, state: "locking") == EntityIconColorProvider.lockTransitionColor)
        #expect(color(domain: .lock, state: "unlocking") == EntityIconColorProvider.lockTransitionColor)
    }

    @Test func inactiveStatesAreGray() {
        #expect(color(domain: .light, state: "off") == .gray)
        #expect(color(domain: .switch, state: "off") == .gray)
    }

    @Test func unavailableIsTreatedAsProblem() {
        #expect(color(domain: .light, state: "unavailable") == .red)
        #expect(color(domain: .lock, state: "unavailable") == .red)
    }

    @Test func liveColorWinsWhenActive() {
        let live = color(domain: .light, state: "on", colorMode: "rgb", rgb: [255, 140, 0])
        #expect(live == Color(red: 255.0 / 255.0, green: 140.0 / 255.0, blue: 0))
    }

    @Test func activeWithoutDomainAccentFallsBackToFrontendActiveColor() {
        #expect(color(domain: .inputBoolean, state: "on") == EntityIconColorProvider.activeColor)
        #expect(Domain.humidifier.accentColor == EntityIconColorProvider.activeColor)
    }

    @Test func frontendPaletteValues() throws {
        // Pinned to color.globals.ts in home-assistant/frontend — the source of truth.
        let expected: [(Color, String)] = [
            (EntityIconColorProvider.activeColor, "#FFC107"),
            (EntityIconColorProvider.lockLockedColor, "#4CAF50"),
            (EntityIconColorProvider.lockUnlockedColor, "#F44336"),
            (EntityIconColorProvider.lockTransitionColor, "#FF9800"),
        ]
        for (paletteColor, hex) in expected {
            let reference = try #require(UIColor(rgbaString: hex))
            for (actual, wanted) in zip(rgba(UIColor(paletteColor)), rgba(reference)) {
                #expect(abs(actual - wanted) < 0.001, "Palette color should be \(hex)")
            }
        }
    }

    private func rgba(_ color: UIColor) -> [CGFloat] {
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0
        color.getRed(&red, green: &green, blue: &blue, alpha: &alpha)
        return [red, green, blue, alpha]
    }
}
