import SFSafeSymbols
import Shared
import SwiftUI
import UIKit

struct ConditionalContainerView: View {
    @StateObject private var kiosk = Current.kiosk
    @ObservedObject private var appSettings = AppSettingsPresenter.shared
    @Environment(\.scenePhase) private var scenePhase
    @State private var showKioskSettings = false

    var body: some View {
        if Current.isCatalyst {
            content
        } else {
            NavigationStack {
                content
                    .toolbar(.hidden, for: .navigationBar)
                    .navigationDestination(isPresented: $appSettings.isPresented) {
                        SettingsView(embedInOwnNavigation: false)
                            .injectingViewControllerProvider()
                            .onDisappear {
                                Current.sceneManager.webViewControllerPromise.done { $0.refreshIfDisconnected() }
                            }
                    }
            }
        }
    }

    private var content: some View {
        Group {
            if kiosk.settings.enabled {
                KioskView(showSettings: $showKioskSettings)
            } else {
                ContainerView()
            }
        }
        .onAppear { applyKeepScreenOn() }
        .onChange(of: kiosk.shouldKeepScreenOn) { _ in applyKeepScreenOn() }
        .onChange(of: scenePhase) { phase in
            if phase == .active { applyKeepScreenOn() }
        }
        .sheet(isPresented: $showKioskSettings) {
            NavigationView {
                KioskSettingsView()
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            CloseButton { showKioskSettings = false }
                        }
                    }
            }
            .navigationViewStyle(.stack)
        }
    }

    private func applyKeepScreenOn() {
        UIApplication.shared.isIdleTimerDisabled = kiosk.shouldKeepScreenOn
    }
}

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
                )
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

struct KioskSettingsEntryIcon: View {
    static let defaultBackgroundColorHex = "000000"
    static let defaultIconColorHex = "FFFFFF"

    var backgroundColor: Color
    var iconColor: Color

    var body: some View {
        Image(systemSymbol: .gearshapeFill)
            .font(.body)
            .foregroundStyle(iconColor)
            .padding(DesignSystem.Spaces.one)
            .background(backgroundColor)
            .clipShape(.circle)
    }
}
