import Foundation
@testable import HomeAssistant
import Shared
import Testing

// MARK: - MotionSensitivity Tests

struct MotionSensitivityTests {
    @Test func thresholdValues() async throws {
        #expect(MotionSensitivity.low.threshold == 0.05)
        #expect(MotionSensitivity.medium.threshold == 0.02)
        #expect(MotionSensitivity.high.threshold == 0.008)
    }

    @Test func thresholdOrdering() async throws {
        // Higher sensitivity = lower threshold value
        #expect(MotionSensitivity.high.threshold < MotionSensitivity.medium.threshold)
        #expect(MotionSensitivity.medium.threshold < MotionSensitivity.low.threshold)
    }

    @Test func displayNames() async throws {
        #expect(MotionSensitivity.low.displayName == L10n.Kiosk.Camera.Sensitivity.low)
        #expect(MotionSensitivity.medium.displayName == L10n.Kiosk.Camera.Sensitivity.medium)
        #expect(MotionSensitivity.high.displayName == L10n.Kiosk.Camera.Sensitivity.high)
    }

    @Test func caseCount() async throws {
        #expect(MotionSensitivity.allCases.count == 3)
    }

    @Test func codableRoundtrip() async throws {
        for sensitivity in MotionSensitivity.allCases {
            let encoded = try JSONEncoder().encode(sensitivity)
            let decoded = try JSONDecoder().decode(MotionSensitivity.self, from: encoded)
            #expect(decoded == sensitivity)
        }
    }

    @Test func rawValues() async throws {
        #expect(MotionSensitivity.low.rawValue == "low")
        #expect(MotionSensitivity.medium.rawValue == "medium")
        #expect(MotionSensitivity.high.rawValue == "high")
    }
}

// MARK: - Camera Settings Tests

struct KioskCameraSettingsTests {
    @Test func defaultCameraSettings() async throws {
        let settings = KioskSettings()
        #expect(settings.cameraMotionEnabled == false)
        #expect(settings.cameraMotionSensitivity == .medium)
        #expect(settings.wakeOnCameraMotion == false)
        #expect(settings.cameraPresenceEnabled == false)
        #expect(settings.cameraFaceDetectionEnabled == false)
        #expect(settings.wakeOnCameraPresence == false)
    }

    @Test func cameraSettingsRoundtrip() async throws {
        var settings = KioskSettings()
        settings.cameraMotionEnabled = true
        settings.cameraMotionSensitivity = .high
        settings.wakeOnCameraMotion = true
        settings.cameraPresenceEnabled = true
        settings.cameraFaceDetectionEnabled = true
        settings.wakeOnCameraPresence = true

        let encoded = try JSONEncoder().encode(settings)
        let decoded = try JSONDecoder().decode(KioskSettings.self, from: encoded)

        #expect(decoded.cameraMotionEnabled == true)
        #expect(decoded.cameraMotionSensitivity == .high)
        #expect(decoded.wakeOnCameraMotion == true)
        #expect(decoded.cameraPresenceEnabled == true)
        #expect(decoded.cameraFaceDetectionEnabled == true)
        #expect(decoded.wakeOnCameraPresence == true)
    }

    @Test func backwardsCompatibility() async throws {
        // Simulate PR1-era settings JSON (no camera fields)
        let pr1JSON = """
        {
            "isKioskModeEnabled": true,
            "screensaverMode": "clock",
            "clockStyle": "large",
            "secretExitGestureCorner": "bottomRight",
            "secretExitGestureTaps": 3
        }
        """.data(using: .utf8)!

        let decoded = try JSONDecoder().decode(KioskSettings.self, from: pr1JSON)

        // PR1 fields preserved
        #expect(decoded.isKioskModeEnabled == true)
        #expect(decoded.screensaverMode == .clock)

        // Camera fields default correctly
        #expect(decoded.cameraMotionEnabled == false)
        #expect(decoded.cameraMotionSensitivity == .medium)
        #expect(decoded.wakeOnCameraMotion == false)
        #expect(decoded.cameraPresenceEnabled == false)
        #expect(decoded.cameraFaceDetectionEnabled == false)
        #expect(decoded.wakeOnCameraPresence == false)
    }

    @Test func settingsEqualityWithCameraFields() async throws {
        var settings1 = KioskSettings()
        settings1.cameraMotionEnabled = true
        settings1.cameraMotionSensitivity = .high

        var settings2 = KioskSettings()
        settings2.cameraMotionEnabled = true
        settings2.cameraMotionSensitivity = .high

        #expect(settings1 == settings2)

        settings2.cameraMotionSensitivity = .low
        #expect(settings1 != settings2)
    }
}
