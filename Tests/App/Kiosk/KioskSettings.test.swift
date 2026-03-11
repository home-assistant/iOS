import Foundation
@testable import HomeAssistant
import Testing

// MARK: - KioskSettings Codable Tests

struct KioskSettingsCodableTests {
    @Test func defaultSettingsRoundtrip() async throws {
        let original = KioskSettings()
        let encoded = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(KioskSettings.self, from: encoded)

        #expect(decoded == original)
    }

    @Test func customSettingsRoundtrip() async throws {
        var settings = KioskSettings()
        settings.isKioskModeEnabled = true
        settings.requireDeviceAuthentication = true
        settings.hideStatusBar = true
        settings.preventAutoLock = true
        settings.screensaverTimeout = 600
        settings.screensaverMode = .clock
        settings.clockStyle = .analog
        settings.manualBrightness = 0.9
        settings.pixelShiftAmount = 15
        settings.secretExitGestureCorner = .bottomLeft
        settings.secretExitGestureTaps = 5

        let encoded = try JSONEncoder().encode(settings)
        let decoded = try JSONDecoder().decode(KioskSettings.self, from: encoded)

        #expect(decoded == settings)
        #expect(decoded.isKioskModeEnabled == true)
        #expect(decoded.requireDeviceAuthentication == true)
        #expect(decoded.screensaverMode == .clock)
        #expect(decoded.clockStyle == .analog)
        #expect(decoded.secretExitGestureCorner == .bottomLeft)
        #expect(decoded.secretExitGestureTaps == 5)
    }
}

// MARK: - Enum Display Name Tests

struct EnumDisplayNameTests {
    @Test func screensaverModeDisplayNames() async throws {
        #expect(ScreensaverMode.blank.displayName == "Blank")
        #expect(ScreensaverMode.dim.displayName == "Dim")
        #expect(ScreensaverMode.clock.displayName == "Clock")
    }

    @Test func clockStyleDisplayNames() async throws {
        #expect(ClockStyle.large.displayName == "Large")
        #expect(ClockStyle.minimal.displayName == "Minimal")
        #expect(ClockStyle.analog.displayName == "Analog")
        #expect(ClockStyle.digital.displayName == "Digital")
    }

    @Test func screenCornerDisplayNames() async throws {
        #expect(ScreenCorner.topLeft.displayName == "Top Left")
        #expect(ScreenCorner.topRight.displayName == "Top Right")
        #expect(ScreenCorner.bottomLeft.displayName == "Bottom Left")
        #expect(ScreenCorner.bottomRight.displayName == "Bottom Right")
    }
}
