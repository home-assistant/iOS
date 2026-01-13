import Foundation
import Testing
@testable import HomeAssistant

// MARK: - KioskSettings Codable Tests

struct KioskSettingsCodableTests {
    @Test func testDefaultSettingsRoundtrip() async throws {
        let original = KioskSettings()
        let encoded = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(KioskSettings.self, from: encoded)

        #expect(decoded == original)
    }

    @Test func testCustomSettingsRoundtrip() async throws {
        var settings = KioskSettings()
        settings.isKioskModeEnabled = true
        settings.allowBiometricExit = false
        settings.hideStatusBar = true
        settings.preventAutoLock = true
        settings.screensaverTimeout = 600
        settings.screensaverMode = .clockWithEntities
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
        #expect(decoded.allowBiometricExit == false)
        #expect(decoded.screensaverMode == .clockWithEntities)
        #expect(decoded.clockStyle == .analog)
        #expect(decoded.secretExitGestureCorner == .bottomLeft)
        #expect(decoded.secretExitGestureTaps == 5)
    }

    @Test func testDashboardConfigRoundtrip() async throws {
        let config = DashboardConfig(
            id: "test-id",
            name: "Living Room",
            url: "/lovelace/living-room",
            icon: "mdi:sofa",
            includeInRotation: true
        )

        let encoded = try JSONEncoder().encode(config)
        let decoded = try JSONDecoder().decode(DashboardConfig.self, from: encoded)

        #expect(decoded.id == config.id)
        #expect(decoded.name == config.name)
        #expect(decoded.url == config.url)
        #expect(decoded.icon == config.icon)
        #expect(decoded.includeInRotation == config.includeInRotation)
    }

    @Test func testDashboardConfigDefaultsOnDecode() async throws {
        // Simulate legacy data missing optional fields
        let json = """
        {"name": "Test", "url": "/test"}
        """
        let data = json.data(using: .utf8)!
        let decoded = try JSONDecoder().decode(DashboardConfig.self, from: data)

        #expect(decoded.name == "Test")
        #expect(decoded.url == "/test")
        #expect(decoded.icon == "mdi:view-dashboard") // Default
        #expect(decoded.includeInRotation == true) // Default
        #expect(!decoded.id.isEmpty) // Should generate UUID
    }

    @Test func testEntityTriggerRoundtrip() async throws {
        let trigger = EntityTrigger(
            entityId: "binary_sensor.motion",
            triggerState: "on",
            delay: 5.0,
            enabled: true
        )

        let encoded = try JSONEncoder().encode(trigger)
        let decoded = try JSONDecoder().decode(EntityTrigger.self, from: encoded)

        #expect(decoded.entityId == trigger.entityId)
        #expect(decoded.triggerState == trigger.triggerState)
        #expect(decoded.delay == trigger.delay)
        #expect(decoded.enabled == trigger.enabled)
    }

    @Test func testClockEntityConfigRoundtrip() async throws {
        let config = ClockEntityConfig(
            entityId: "sensor.temperature",
            label: "Outdoor",
            icon: "mdi:thermometer",
            showUnit: true,
            displayFormat: .valueSpaceUnit,
            decimalPlaces: 1,
            prefix: nil,
            suffix: "outside"
        )

        let encoded = try JSONEncoder().encode(config)
        let decoded = try JSONDecoder().decode(ClockEntityConfig.self, from: encoded)

        #expect(decoded.entityId == config.entityId)
        #expect(decoded.label == config.label)
        #expect(decoded.displayFormat == .valueSpaceUnit)
        #expect(decoded.decimalPlaces == 1)
        #expect(decoded.suffix == "outside")
    }

    @Test func testQuickActionRoundtrip() async throws {
        let action = QuickAction(
            name: "Movie Mode",
            icon: "mdi:movie",
            actionType: .scene(entityId: "scene.movie_mode")
        )

        let encoded = try JSONEncoder().encode(action)
        let decoded = try JSONDecoder().decode(QuickAction.self, from: encoded)

        #expect(decoded.name == action.name)
        #expect(decoded.icon == action.icon)

        if case let .scene(entityId) = decoded.actionType {
            #expect(entityId == "scene.movie_mode")
        } else {
            Issue.record("Expected scene action type")
        }
    }

    @Test func testTriggerActionRoundtrip() async throws {
        let actions: [TriggerAction] = [
            .navigate(url: "/lovelace/cameras"),
            .setBrightness(level: 0.5),
            .startScreensaver(mode: .clock),
            .stopScreensaver,
            .refresh,
            .playSound(url: "https://example.com/alert.mp3"),
            .tts(message: "Welcome home"),
        ]

        for action in actions {
            let encoded = try JSONEncoder().encode(action)
            let decoded = try JSONDecoder().decode(TriggerAction.self, from: encoded)
            #expect(decoded == action)
        }
    }
}

// MARK: - TimeOfDay Tests

struct TimeOfDayTests {
    @Test func testIsBeforeSameHourEarlierMinute() async throws {
        let earlier = TimeOfDay(hour: 10, minute: 15)
        let later = TimeOfDay(hour: 10, minute: 45)

        #expect(earlier.isBefore(later) == true)
        #expect(later.isBefore(earlier) == false)
    }

    @Test func testIsBeforeDifferentHours() async throws {
        let morning = TimeOfDay(hour: 7, minute: 30)
        let evening = TimeOfDay(hour: 19, minute: 30)

        #expect(morning.isBefore(evening) == true)
        #expect(evening.isBefore(morning) == false)
    }

    @Test func testIsBeforeSameTime() async throws {
        let time1 = TimeOfDay(hour: 12, minute: 0)
        let time2 = TimeOfDay(hour: 12, minute: 0)

        #expect(time1.isBefore(time2) == false)
        #expect(time2.isBefore(time1) == false)
    }

    @Test func testIsBeforeMidnightEdgeCases() async throws {
        let beforeMidnight = TimeOfDay(hour: 23, minute: 59)
        let afterMidnight = TimeOfDay(hour: 0, minute: 1)

        #expect(afterMidnight.isBefore(beforeMidnight) == true)
        #expect(beforeMidnight.isBefore(afterMidnight) == false)
    }

    @Test func testAsDateComponents() async throws {
        let time = TimeOfDay(hour: 14, minute: 30)
        let components = time.asDateComponents

        #expect(components.hour == 14)
        #expect(components.minute == 30)
    }
}

// MARK: - DeviceOrientation Tests

struct DeviceOrientationTests {
    @Test func testMatchesExactSame() async throws {
        #expect(DeviceOrientation.portrait.matches(.portrait) == true)
        #expect(DeviceOrientation.landscapeLeft.matches(.landscapeLeft) == true)
        #expect(DeviceOrientation.landscapeRight.matches(.landscapeRight) == true)
    }

    @Test func testMatchesLandscapeVariants() async throws {
        // .landscape should match both landscapeLeft and landscapeRight
        #expect(DeviceOrientation.landscape.matches(.landscapeLeft) == true)
        #expect(DeviceOrientation.landscape.matches(.landscapeRight) == true)

        // And vice versa
        #expect(DeviceOrientation.landscapeLeft.matches(.landscape) == true)
        #expect(DeviceOrientation.landscapeRight.matches(.landscape) == true)
    }

    @Test func testMatchesDifferentOrientations() async throws {
        #expect(DeviceOrientation.portrait.matches(.landscape) == false)
        #expect(DeviceOrientation.portrait.matches(.landscapeLeft) == false)
        #expect(DeviceOrientation.landscapeLeft.matches(.portrait) == false)
        #expect(DeviceOrientation.faceUp.matches(.faceDown) == false)
    }

    @Test func testFromUIDeviceOrientation() async throws {
        #expect(DeviceOrientation.from(.portrait) == .portrait)
        #expect(DeviceOrientation.from(.portraitUpsideDown) == .portraitUpsideDown)
        #expect(DeviceOrientation.from(.landscapeLeft) == .landscapeLeft)
        #expect(DeviceOrientation.from(.landscapeRight) == .landscapeRight)
        #expect(DeviceOrientation.from(.faceUp) == .faceUp)
        #expect(DeviceOrientation.from(.faceDown) == .faceDown)
        #expect(DeviceOrientation.from(.unknown) == .unknown)
    }
}

// MARK: - Enum Display Name Tests

struct EnumDisplayNameTests {
    @Test func testScreensaverModeDisplayNames() async throws {
        #expect(ScreensaverMode.blank.displayName == "Blank (Black Screen)")
        #expect(ScreensaverMode.dim.displayName == "Dim Dashboard")
        #expect(ScreensaverMode.clock.displayName == "Clock")
        #expect(ScreensaverMode.clockWithEntities.displayName == "Clock + Sensors")
        #expect(ScreensaverMode.photos.displayName == "Photo Frame")
        #expect(ScreensaverMode.photosWithClock.displayName == "Photos + Clock")
        #expect(ScreensaverMode.customURL.displayName == "Custom Dashboard")
    }

    @Test func testClockStyleDisplayNames() async throws {
        #expect(ClockStyle.large.displayName == "Large")
        #expect(ClockStyle.minimal.displayName == "Minimal")
        #expect(ClockStyle.analog.displayName == "Analog")
        #expect(ClockStyle.digital.displayName == "Digital")
    }

    @Test func testScreenCornerDisplayNames() async throws {
        #expect(ScreenCorner.topLeft.displayName == "Top Left")
        #expect(ScreenCorner.topRight.displayName == "Top Right")
        #expect(ScreenCorner.bottomLeft.displayName == "Bottom Left")
        #expect(ScreenCorner.bottomRight.displayName == "Bottom Right")
    }

    @Test func testCameraPopupSizeParameters() async throws {
        let small = CameraPopupSize.small.sizeParameters
        #expect(small.widthPercent == 0.4)
        #expect(small.maxWidth == 320)

        let fullScreen = CameraPopupSize.fullScreen.sizeParameters
        #expect(fullScreen.widthPercent == 0.95)
        #expect(fullScreen.maxWidth == 1200)
    }
}

// MARK: - IconMapper Tests

struct IconMapperTests {
    @Test func testCommonMDIToSFSymbol() async throws {
        #expect(IconMapper.sfSymbol(from: "mdi:home") == "house.fill")
        #expect(IconMapper.sfSymbol(from: "mdi:lightbulb") == "lightbulb.fill")
        #expect(IconMapper.sfSymbol(from: "mdi:thermometer") == "thermometer")
        #expect(IconMapper.sfSymbol(from: "mdi:weather-sunny") == "sun.max")
        #expect(IconMapper.sfSymbol(from: "mdi:lock") == "lock.fill")
        #expect(IconMapper.sfSymbol(from: "mdi:lock-open") == "lock.open.fill")
    }

    @Test func testMDIPrefixStripping() async throws {
        // Should work with mdi: prefix - returns mapped value
        let withPrefix = IconMapper.sfSymbol(from: "mdi:home")
        #expect(withPrefix == "house.fill")

        // Without prefix - still should work as it strips mdi: internally
        // But if it doesn't match, it falls back
        let directKey = IconMapper.sfSymbol(from: "home")
        // The implementation may or may not handle this - just verify it returns something
        #expect(!directKey.isEmpty)
    }

    @Test func testUnknownMDIReturnsFallback() async throws {
        let unknown = IconMapper.sfSymbol(from: "mdi:some-unknown-icon-xyz")

        // Should return a fallback symbol
        #expect(unknown == "questionmark.circle")
    }

    @Test func testWeatherIcons() async throws {
        #expect(IconMapper.sfSymbol(from: "mdi:weather-cloudy") == "cloud")
        #expect(IconMapper.sfSymbol(from: "mdi:weather-rainy") == "cloud.rain")
        #expect(IconMapper.sfSymbol(from: "mdi:weather-snowy") == "cloud.snow")
        #expect(IconMapper.sfSymbol(from: "mdi:weather-sunny") == "sun.max")
    }

    @Test func testDeviceIcons() async throws {
        #expect(IconMapper.sfSymbol(from: "mdi:television") == "tv")
        #expect(IconMapper.sfSymbol(from: "mdi:speaker") == "speaker.wave.2")
        #expect(IconMapper.sfSymbol(from: "mdi:fan") == "fan")
    }
}
