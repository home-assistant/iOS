import Shared
import SwiftUI
import UIKit

struct KioskView: View {
    @StateObject private var screensaver = KioskScreensaverController()
    @StateObject private var kiosk = Current.kiosk
    @Binding var showSettings: Bool

    var body: some View {
        ContainerView()
            .background(KioskActivityDetector { screensaver.recordActivity() })
            .overlay(alignment: .bottomLeading) {
                if Current.isDebug {
                    debugWatermark
                }
            }
            .overlay {
                ZStack(alignment: settingsEntryAlignment) {
                    Color.clear
                        .allowsHitTesting(false)
                    settingsEntryButton
                        .padding(DesignSystem.Spaces.two)
                }
                .ignoresSafeArea()
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

    private var settingsEntryAlignment: Alignment {
        switch kiosk.settings.settingsEntryPosition {
        case .topLeading: return .topLeading
        case .topTrailing: return .topTrailing
        case .bottomLeading: return .bottomLeading
        case .bottomTrailing: return .bottomTrailing
        }
    }

    private var settingsEntryButton: some View {
        Button {
            showSettings = true
        } label: {
            KioskSettingsEntryIcon(
                backgroundColor: Color(
                    hex: kiosk.settings.settingsEntryBackgroundColor ?? KioskSettingsEntryIcon
                        .defaultBackgroundColorHex
                ),
                iconColor: Color(
                    hex: kiosk.settings.settingsEntryIconColor ?? KioskSettingsEntryIcon
                        .defaultIconColorHex
                ),
                isHidden: kiosk.settings.settingsEntryHidden
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(L10n.Kiosk.title)
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
