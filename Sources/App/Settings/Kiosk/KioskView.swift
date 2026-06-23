import Shared
import SwiftUI
import UIKit

struct ConditionalContainerView: View {
    @StateObject private var kiosk = Current.kiosk
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        Group {
            if kiosk.settings.enabled {
                KioskView()
            } else {
                ContainerView()
            }
        }
        .onAppear { applyKeepScreenOn() }
        .onChange(of: kiosk.shouldKeepScreenOn) { _ in applyKeepScreenOn() }
        .onChange(of: scenePhase) { phase in
            if phase == .active { applyKeepScreenOn() }
        }
    }

    private func applyKeepScreenOn() {
        UIApplication.shared.isIdleTimerDisabled = kiosk.shouldKeepScreenOn
    }
}

struct KioskView: View {
    @StateObject private var screensaver = KioskScreensaverController()

    var body: some View {
        ContainerView()
            .background(KioskActivityDetector { screensaver.recordActivity() })
            .overlay(alignment: .bottomLeading) {
                if Current.isDebug {
                    debugWatermark
                }
            }
            .overlay {
                if screensaver.isActive {
                    KioskScreensaverView(settings: screensaver.screensaver) {
                        screensaver.wake()
                    }
                    .transition(.opacity)
                }
            }
            .animation(.easeInOut(duration: 0.4), value: screensaver.isActive)
    }

    private var debugWatermark: some View {
        Text(verbatim: "KIOSK MODE")
            .font(.caption2.weight(.bold))
            .foregroundColor(.white)
            .padding(.horizontal, DesignSystem.Spaces.one)
            .padding(.vertical, DesignSystem.Spaces.half)
            .background(Color.red.opacity(0.75))
            .clipShape(Capsule())
            .padding(DesignSystem.Spaces.two)
            .allowsHitTesting(false)
    }
}
