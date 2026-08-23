import Foundation
@testable import HomeAssistant
@testable import Shared
import SwiftUI
import Testing

/// Covers home-assistant/iOS#4656: screensaver dim of `UIScreen.main.brightness` must restore
/// whenever the app is no longer foreground — not only on a screensaver dismiss path.
@MainActor
struct KioskScreenBrightnessControllerTests {
    private final class BrightnessBox {
        var value: CGFloat = 0
    }

    private func approxEq(_ a: CGFloat, _ b: CGFloat) -> Bool {
        abs(a - b) < 1e-5
    }

    private func withMockBrightness(
        initial: CGFloat,
        _ body: (BrightnessBox, KioskScreenBrightnessController) throws -> Void
    ) rethrows {
        let savedGet = Current.screenBrightness
        let savedSet = Current.setScreenBrightness
        defer {
            Current.screenBrightness = savedGet
            Current.setScreenBrightness = savedSet
        }
        let box = BrightnessBox()
        box.value = initial
        Current.screenBrightness = { box.value }
        Current.setScreenBrightness = { box.value = $0 }
        let controller = KioskScreenBrightnessController()
        defer { controller.restore() }
        try body(box, controller)
    }

    @Test func applyDimsAndRestoreReturnsOriginal() throws {
        try withMockBrightness(initial: 0.8) { box, controller in
            controller.apply(shouldDim: true, dimLevel: 0.1)
            #expect(approxEq(box.value, 0.1))

            controller.restore()
            #expect(approxEq(box.value, 0.8))
        }
    }

    @Test func willResignActiveRestoresEvenIfScreensaverStillWantsDim() throws {
        try withMockBrightness(initial: 0.8) { box, controller in
            controller.apply(shouldDim: true, dimLevel: 0.05)
            #expect(approxEq(box.value, 0.05))

            controller.handleWillResignActive()
            #expect(approxEq(box.value, 0.8))

            // Race: updateBrightness can run while applicationState is still .active.
            controller.apply(shouldDim: true, dimLevel: 0.05)
            #expect(approxEq(box.value, 0.8), "must not re-dim after resigning active")
        }
    }

    @Test func didEnterBackgroundRestoresOriginalBrightness() throws {
        try withMockBrightness(initial: 0.65) { box, controller in
            controller.apply(shouldDim: true, dimLevel: 0.2)
            controller.handleDidEnterBackground()
            #expect(approxEq(box.value, 0.65))
        }
    }

    @Test func scenePhaseBackgroundRestoresOriginalBrightness() throws {
        try withMockBrightness(initial: 0.8) { box, controller in
            controller.apply(shouldDim: true, dimLevel: 0.1)
            controller.handleScenePhase(.background)
            #expect(approxEq(box.value, 0.8))
        }
    }

    @Test func scenePhaseInactiveRestoresOriginalBrightness() throws {
        try withMockBrightness(initial: 0.8) { box, controller in
            controller.apply(shouldDim: true, dimLevel: 0.1)
            controller.handleScenePhase(.inactive)
            #expect(approxEq(box.value, 0.8))
        }
    }

    @Test func stoppingScreensaverRestoresOriginalBrightness() throws {
        try withMockBrightness(initial: 0.7) { box, controller in
            controller.apply(shouldDim: true, dimLevel: 0.2)
            controller.apply(shouldDim: false, dimLevel: 0.2)
            #expect(approxEq(box.value, 0.7))
        }
    }

    @Test func foregroundReappliesDimAfterBackground() throws {
        try withMockBrightness(initial: 0.8) { box, controller in
            controller.apply(shouldDim: true, dimLevel: 0.05)
            controller.handleDidEnterBackground()
            #expect(approxEq(box.value, 0.8))

            controller.handleDidBecomeActive()
            controller.apply(shouldDim: true, dimLevel: 0.05)
            #expect(approxEq(box.value, 0.05))
        }
    }

    @Test func applyDoesNotRecaptureDimmedValueAsOriginal() throws {
        try withMockBrightness(initial: 0.8) { box, controller in
            controller.apply(shouldDim: true, dimLevel: 0.1)
            controller.apply(shouldDim: true, dimLevel: 0.1)
            controller.restore()
            #expect(approxEq(box.value, 0.8))
        }
    }
}
