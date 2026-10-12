@testable import HADesignSystem
import SwiftUI
import Testing

/// The kelvin-to-colour curve the light dialog paints its colour-temperature slider with. A gradient
/// looks warm-to-cool whether or not each stop is the colour the frontend computes, so the numbers
/// are pinned here against `temperature2rgb`.
struct HAColorTemperatureTests {
    @Test func warmWhiteIsOrange() {
        let rgb = HAColorTemperature.rgb(kelvin: 2000)
        #expect(rgb.red == 255)
        #expect(rgb.green == 137)
        #expect(rgb.blue == 14)
    }

    @Test func daylightIsNearlyWhite() {
        let rgb = HAColorTemperature.rgb(kelvin: 6500)
        #expect(rgb.red == 255)
        #expect(rgb.green == 254)
        #expect(rgb.blue == 250)
    }

    @Test func coolWhiteIsBlue() {
        let rgb = HAColorTemperature.rgb(kelvin: 10000)
        #expect(rgb.red == 202)
        #expect(rgb.green == 218)
        #expect(rgb.blue == 255)
    }

    @Test func veryWarmLightHasNoBlue() {
        #expect(HAColorTemperature.rgb(kelvin: 1500).blue == 0)
    }

    @Test func gradientHasElevenEvenStops() {
        let gradient = HAColorTemperature.gradient(minKelvin: 2000, maxKelvin: 6500)
        #expect(gradient.stops.count == 11)
        #expect(gradient.stops.first?.location == 0)
        #expect(gradient.stops.last?.location == 1)
    }

    @Test func tiltSlatsCoverTheWholeTrack() {
        let stops = HAStateControlSlider.slats(color: .red).stops
        #expect(stops.count == 24 * 4 - 1)
        #expect(stops.allSatisfy { (0 ... 1).contains($0.location) })
        #expect(zip(stops, stops.dropFirst()).allSatisfy { $0.location <= $1.location })
    }
}
