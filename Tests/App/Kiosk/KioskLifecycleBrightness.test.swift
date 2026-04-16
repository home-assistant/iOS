import Foundation
@testable import HomeAssistant
import Shared
import Testing

// MARK: - Kiosk Lifecycle Brightness Tests

//
// Covers home-assistant/iOS#4506: when HA backgrounds while kiosk mode has
// dimmed UIScreen.main.brightness, the dim persists system-wide because we
// never restore it. These tests verify the lifecycle observers restore the
// user's original brightness on background and reapply kiosk brightness on
// foreground.
//
// The manager is wired to UIApplication.didEnterBackgroundNotification
// (intentionally not willResignActiveNotification) so a notification banner
// or Control Center pull-down alone does NOT restore brightness — only
// actually leaving the app does.
//
// Tests drive KioskModeManager.shared directly (no injectable instance
// exists yet). setupTest() snapshots both Current brightness closures AND
// persisted kiosk settings; the returned cleanup closure restores both,
// so tests do not pollute the shared GRDB database or leak state between
// runs.

@MainActor
struct KioskLifecycleBrightnessTests {
    /// Small reference box so the closure-based Current.screenBrightness / setScreenBrightness
    /// mocks can share mutable state by reference rather than by capture-by-value.
    private final class BrightnessBox {
        var value: CGFloat = 0
    }

    /// Prepare the shared manager for a test: ensure kiosk is disabled, snapshot the
    /// current persisted settings, and install mocked brightness closures on Current.
    /// Returns the brightness box plus a single cleanup closure that restores everything.
    private func setupTest(initialBrightness: CGFloat) -> (BrightnessBox, () -> Void) {
        let mgr = KioskModeManager.shared

        let savedSettings = mgr.settings
        if mgr.isKioskModeActive {
            mgr.disableKioskMode()
        }

        let box = BrightnessBox()
        box.value = initialBrightness
        let savedGet = Current.screenBrightness
        let savedSet = Current.setScreenBrightness
        Current.screenBrightness = { box.value }
        Current.setScreenBrightness = { box.value = $0 }

        let cleanup: () -> Void = {
            if mgr.isKioskModeActive {
                mgr.disableKioskMode()
            }
            mgr.updateSettings(savedSettings)
            Current.screenBrightness = savedGet
            Current.setScreenBrightness = savedSet
        }
        return (box, cleanup)
    }

    @Test func backgroundRestoresOriginalBrightnessWhenScreensaverActive() async throws {
        let (box, cleanup) = setupTest(initialBrightness: 0.8)
        defer { cleanup() }

        let mgr = KioskModeManager.shared

        mgr.enableKioskMode()
        #expect(mgr.isKioskModeActive == true)

        var settings = mgr.settings
        settings.screensaverMode = .dim
        settings.screensaverDimLevel = 0.05
        mgr.updateSettings(settings)

        mgr.sleepScreen(mode: .dim)
        #expect(box.value == 0.05, "screensaver should have dimmed to settings.screensaverDimLevel")

        // Act: HA backgrounds (user taps a notification and opens another app)
        mgr.appDidEnterBackground()

        #expect(
            box.value == 0.8,
            "expected background to restore originalBrightness (0.8), got \(box.value)"
        )
    }

    @Test func foregroundReappliesScreensaverDim() async throws {
        let (box, cleanup) = setupTest(initialBrightness: 0.8)
        defer { cleanup() }

        let mgr = KioskModeManager.shared
        mgr.enableKioskMode()

        var settings = mgr.settings
        settings.screensaverMode = .dim
        settings.screensaverDimLevel = 0.05
        mgr.updateSettings(settings)

        mgr.sleepScreen(mode: .dim)

        mgr.appDidEnterBackground()
        #expect(box.value == 0.8)

        #expect(
            mgr.activeScreensaverMode == .dim,
            "screensaver should remain active across background — backgrounding does not wake"
        )

        mgr.appDidBecomeActive()

        #expect(
            box.value == 0.05,
            "expected foreground to re-apply screensaver dim (0.05), got \(box.value)"
        )
    }

    @Test func foregroundReappliesManagedBrightnessWithoutScreensaver() async throws {
        let (box, cleanup) = setupTest(initialBrightness: 0.8)
        defer { cleanup() }

        let mgr = KioskModeManager.shared
        mgr.enableKioskMode()

        var settings = mgr.settings
        settings.brightnessControlEnabled = true
        settings.manualBrightness = 0.3
        mgr.updateSettings(settings)

        #expect(box.value == 0.3, "managed brightness should have been applied on enable/settings change")

        mgr.appDidEnterBackground()
        #expect(box.value == 0.8, "background should restore originalBrightness")

        #expect(mgr.activeScreensaverMode == nil)

        mgr.appDidBecomeActive()

        #expect(
            box.value == 0.3,
            "expected foreground to re-apply managed brightness (0.3), got \(box.value)"
        )
    }

    @Test func lifecycleDoesNothingWhenKioskInactive() async throws {
        let (box, cleanup) = setupTest(initialBrightness: 0.65)
        defer { cleanup() }

        let mgr = KioskModeManager.shared
        #expect(mgr.isKioskModeActive == false)

        mgr.appDidEnterBackground()
        #expect(box.value == 0.65, "kiosk inactive: background must not touch brightness")

        mgr.appDidBecomeActive()
        #expect(box.value == 0.65, "kiosk inactive: foreground must not touch brightness")
    }
}
