import Foundation
@testable import HomeAssistant
import Shared
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
        #expect(ScreensaverMode.blank.displayName == L10n.Kiosk.Screensaver.Mode.blank)
        #expect(ScreensaverMode.dim.displayName == L10n.Kiosk.Screensaver.Mode.dim)
        #expect(ScreensaverMode.clock.displayName == L10n.Kiosk.Screensaver.Mode.clock)
    }

    @Test func clockStyleDisplayNames() async throws {
        #expect(ClockStyle.large.displayName == L10n.Kiosk.Clock.Style.large)
        #expect(ClockStyle.minimal.displayName == L10n.Kiosk.Clock.Style.minimal)
        #expect(ClockStyle.analog.displayName == L10n.Kiosk.Clock.Style.analog)
        #expect(ClockStyle.digital.displayName == L10n.Kiosk.Clock.Style.digital)
    }

    @Test func screenCornerDisplayNames() async throws {
        #expect(ScreenCorner.topLeft.displayName == L10n.Kiosk.Corner.topLeft)
        #expect(ScreenCorner.topRight.displayName == L10n.Kiosk.Corner.topRight)
        #expect(ScreenCorner.bottomLeft.displayName == L10n.Kiosk.Corner.bottomLeft)
        #expect(ScreenCorner.bottomRight.displayName == L10n.Kiosk.Corner.bottomRight)
    }
}
