@testable import HomeAssistant
@testable import Shared
import SwiftUI
import Testing
import UIKit

/// Lays the kiosk screensaver out in each of its modes, so SwiftUI evaluates the clock, date and
/// pixel-shift branches, and checks the font weight mapping the clock sliders drive.
@MainActor
@Suite(.serialized)
struct KioskScreensaverViewRenderTests {
    @Test func fontWeightMapsTheSliderOntoEveryWeight() {
        #expect(KioskScreensaverView.fontWeight(for: 0) == .ultraLight)
        #expect(KioskScreensaverView.fontWeight(for: 0.5) == .medium)
        #expect(KioskScreensaverView.fontWeight(for: 1) == .black)
    }

    @Test func fontWeightClampsOutOfRangeValues() {
        #expect(KioskScreensaverView.fontWeight(for: -3) == .ultraLight)
        #expect(KioskScreensaverView.fontWeight(for: 42) == .black)
    }

    @Test func rendersTheClockWithSecondsAndDate() {
        let settings = KioskScreensaverSettings(
            enabled: true,
            mode: .clock,
            showDate: true,
            showSeconds: true,
            clockFontSize: 2,
            dateFontSize: -1
        )
        #expect(render(KioskScreensaverView(settings: settings) {}).width > 0)
    }

    @Test func rendersTheClockWithoutSecondsOrDateWhilePixelShifting() {
        let settings = KioskScreensaverSettings(
            enabled: true,
            mode: .clock,
            showDate: false,
            showSeconds: false,
            pixelShiftEnabled: true
        )
        #expect(render(KioskScreensaverView(settings: settings) {}).width > 0)
    }

    @Test func rendersTheDimAndBlankModes() {
        let dim = KioskScreensaverSettings(enabled: true, mode: .dim, dimLevel: 1.5)
        let blank = KioskScreensaverSettings(enabled: true, mode: .blank, pixelShiftEnabled: true)
        #expect(render(KioskScreensaverView(settings: dim) {}).width > 0)
        #expect(render(KioskScreensaverView(settings: blank) {}).width > 0)
    }

    /// The activity detector installs its touch recogniser on the window it is placed in; laying it
    /// out alone must not report any activity.
    @Test func activityDetectorAttachesToItsWindow() {
        var activityCount = 0
        let controller = UIHostingController(rootView: KioskActivityDetector { activityCount += 1 })
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 320, height: 480))
        window.rootViewController = controller
        window.isHidden = false
        controller.view.layoutIfNeeded()

        #expect(activityCount == 0)

        window.isHidden = true
        window.rootViewController = nil
    }

    private func render(_ view: some View) -> CGSize {
        let controller = UIHostingController(rootView: view)
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 390, height: 844))
        window.rootViewController = controller
        window.isHidden = false
        controller.view.setNeedsLayout()
        controller.view.layoutIfNeeded()
        let size = controller.sizeThatFits(in: CGSize(width: 390, height: 844))

        window.isHidden = true
        window.rootViewController = nil
        return size
    }
}
