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
        settings.dayBrightness = 0.9
        settings.nightBrightness = 0.2
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

// MARK: - TimeOfDay Tests

struct TimeOfDayTests {
    @Test func isBeforeSameHourEarlierMinute() async throws {
        let earlier = TimeOfDay(hour: 10, minute: 15)
        let later = TimeOfDay(hour: 10, minute: 45)

        #expect(earlier.isBefore(later) == true)
        #expect(later.isBefore(earlier) == false)
    }

    @Test func isBeforeDifferentHours() async throws {
        let morning = TimeOfDay(hour: 7, minute: 30)
        let evening = TimeOfDay(hour: 19, minute: 30)

        #expect(morning.isBefore(evening) == true)
        #expect(evening.isBefore(morning) == false)
    }

    @Test func isBeforeSameTime() async throws {
        let time1 = TimeOfDay(hour: 12, minute: 0)
        let time2 = TimeOfDay(hour: 12, minute: 0)

        #expect(time1.isBefore(time2) == false)
        #expect(time2.isBefore(time1) == false)
    }

    @Test func isBeforeMidnightEdgeCases() async throws {
        let beforeMidnight = TimeOfDay(hour: 23, minute: 59)
        let afterMidnight = TimeOfDay(hour: 0, minute: 1)

        #expect(afterMidnight.isBefore(beforeMidnight) == true)
        #expect(beforeMidnight.isBefore(afterMidnight) == false)
    }

    @Test func asDateComponents() async throws {
        let time = TimeOfDay(hour: 14, minute: 30)
        let components = time.asDateComponents

        #expect(components.hour == 14)
        #expect(components.minute == 30)
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
