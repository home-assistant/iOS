import Foundation
import Shared
import SwiftUI

/// Owns kiosk screensaver dimming of `UIScreen` brightness.
///
/// `UIScreen.main.brightness` is the system brightness. If we leave it dimmed, other apps stay dim
/// after the user leaves HA (#4656). iOS also drops brightness writes once the app is mid-background,
/// so restore must run on willResignActive — not only on a later dismiss path.
final class KioskScreenBrightnessController {
    private var brightnessBeforeDimming: CGFloat?
    private(set) var isForeground = true

    func handleWillResignActive() {
        leaveForeground()
    }

    func handleDidEnterBackground() {
        leaveForeground()
    }

    func handleScenePhase(_ phase: ScenePhase) {
        switch phase {
        case .active:
            handleDidBecomeActive()
        case .inactive, .background:
            leaveForeground()
        @unknown default:
            break
        }
    }

    func handleDidBecomeActive() {
        isForeground = true
    }

    /// Dims when the screensaver wants it *and* we are in the foreground. Any other state restores.
    func apply(shouldDim: Bool, dimLevel: Double) {
        #if os(iOS) && !targetEnvironment(macCatalyst)
        guard isForeground, shouldDim else {
            restore()
            return
        }
        if brightnessBeforeDimming == nil {
            brightnessBeforeDimming = Current.screenBrightness()
        }
        Current.setScreenBrightness(CGFloat(min(max(dimLevel, 0), 1)))
        #endif
    }

    func restore() {
        #if os(iOS) && !targetEnvironment(macCatalyst)
        guard let brightnessBeforeDimming else { return }
        Current.setScreenBrightness(brightnessBeforeDimming)
        self.brightnessBeforeDimming = nil
        #endif
    }

    private func leaveForeground() {
        isForeground = false
        restore()
    }

    deinit {
        restore()
    }
}
