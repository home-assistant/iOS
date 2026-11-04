@testable import HomeAssistant
@testable import Shared
import SwiftUI
import Testing

/// Lays the screensaver out in every mode, with and without the date, seconds and pixel shift.
@Suite
@MainActor
struct KioskScreensaverViewRenderTests {
    @Test func rendersEveryModeAndClockOption() async {
        var woke = 0
        for mode in KioskScreensaverMode.allCases {
            for flag in [false, true] {
                let settings = KioskScreensaverSettings(
                    enabled: true,
                    mode: mode,
                    showDate: flag,
                    showSeconds: flag,
                    dimLevel: flag ? 0.3 : 1.5,
                    pixelShiftEnabled: flag,
                    clockFontWeight: flag ? 1 : 0,
                    dateFontWeight: flag ? 0 : 1,
                    clockFontSize: flag ? 1 : 0,
                    dateFontSize: flag ? 0 : 1
                )
                let driver = await SwiftUIScreenDriver.show(
                    KioskScreensaverView(settings: settings) { woke += 1 },
                    size: CGSize(width: 1024, height: 768),
                    inNavigationStack: false
                )
                await driver.settle()
                driver.close()
            }
        }
        #expect(woke == 0)
    }
}
