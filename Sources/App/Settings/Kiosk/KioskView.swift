import SFSafeSymbols
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
    @StateObject private var kiosk = Current.kiosk
    @State private var showSettings = false

    var body: some View {
        ContainerView()
            .background(KioskActivityDetector { screensaver.recordActivity() })
            .overlay(alignment: .bottomLeading) {
                if Current.isDebug {
                    debugWatermark
                }
            }
            .overlay(alignment: settingsEntryAlignment) {
                settingsEntryButton
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
            .sheet(isPresented: $showSettings) {
                NavigationView {
                    KioskSettingsView()
                        .toolbar {
                            ToolbarItem(placement: .cancellationAction) {
                                CloseButton { showSettings = false }
                            }
                        }
                }
                .navigationViewStyle(.stack)
            }
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
            Image(systemSymbol: .gearshapeFill)
                .font(.body)
                .foregroundStyle(.white)
                .padding(DesignSystem.Spaces.one)
                .background(.black)
                .clipShape(.circle)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(L10n.Kiosk.title)
        .padding({
            switch kiosk.settings.settingsEntryPosition {
            case .bottomLeading, .bottomTrailing: [.horizontal]
            case .topLeading, .topTrailing: [.horizontal, .top]
            }}(), DesignSystem.Spaces.two)
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
