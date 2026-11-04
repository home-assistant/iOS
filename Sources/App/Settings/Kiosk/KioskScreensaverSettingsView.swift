import SFSafeSymbols
import Shared
import SwiftUI

struct KioskScreensaverSettingsView: View {
    @ObservedObject var viewModel: KioskSettingsViewModel
    @State private var showPreview = false

    private var screensaver: Binding<KioskScreensaverSettings> {
        $viewModel.settings.screensaver
    }

    var body: some View {
        List {
            AppleLikeListTopRowHeader(
                image: .weatherNightIcon,
                title: L10n.Kiosk.Screensaver.title,
                subtitle: L10n.Kiosk.Screensaver.body
            ) {
                Toggle(L10n.Kiosk.Screensaver.enabled, isOn: screensaver.enabled)
            }

            Section(L10n.Kiosk.Customization.title) {
                KioskRow.picker(
                    L10n.Kiosk.Screensaver.Mode.title,
                    icon: .monitorScreenshotIcon,
                    selection: screensaver.mode
                ) {
                    ForEach(KioskScreensaverMode.allCases) { mode in
                        Text(mode.title).tag(mode)
                    }
                }

                if screensaver.wrappedValue.mode == .clock {
                    NavigationLink {
                        KioskScreensaverClockSettingsView(viewModel: viewModel)
                    } label: {
                        KioskRow.label(L10n.Kiosk.Screensaver.Clock.title, icon: .clockOutlineIcon)
                    }
                }

                KioskRow.picker(
                    L10n.Kiosk.Screensaver.timeToStart,
                    icon: .clockStartIcon,
                    selection: screensaver.timeToStart
                ) {
                    ForEach(KioskScreensaverTimeout.allCases) { timeout in
                        Text(timeout.title).tag(timeout)
                    }
                }

                NavigationLink {
                    KioskScreensaverDimmingSettingsView(viewModel: viewModel)
                } label: {
                    KioskRow.label(L10n.Kiosk.Screensaver.Dimming.title, icon: .brightness6Icon)
                }

                if Current.motionDetection.canDetectMotion {
                    Toggle(isOn: screensaver.wakeOnCameraMotion) {
                        KioskRow.label(
                            L10n.Kiosk.Screensaver.wakeOnCameraMotion,
                            subtitle: L10n.Kiosk.Screensaver.wakeOnCameraMotionFooter,
                            icon: .motionSensorIcon
                        )
                    }
                }
            }

            Section {
                Button {
                    showPreview = true
                } label: {
                    KioskRow.label(L10n.Kiosk.Screensaver.preview, systemSymbol: .eye)
                }
            }
        }
        .fullScreenCover(isPresented: $showPreview) {
            KioskScreensaverView(settings: screensaver.wrappedValue) {
                showPreview = false
            }
        }
    }
}

struct KioskScreensaverClockSettingsView: View {
    @ObservedObject var viewModel: KioskSettingsViewModel

    private var screensaver: Binding<KioskScreensaverSettings> {
        $viewModel.settings.screensaver
    }

    var body: some View {
        List {
            Section {
                KioskRow.slider(
                    L10n.Kiosk.Screensaver.clockSize,
                    icon: .formatSizeIcon,
                    value: screensaver.clockFontSize
                )
                KioskRow.slider(
                    L10n.Kiosk.Screensaver.clockBoldness,
                    icon: .formatBoldIcon,
                    value: screensaver.clockFontWeight
                )
                Toggle(isOn: screensaver.showSeconds) {
                    KioskRow.label(L10n.Kiosk.Screensaver.showSeconds, icon: .timerOutlineIcon)
                }
                Toggle(isOn: screensaver.pixelShiftEnabled) {
                    KioskRow.label(
                        L10n.Kiosk.Screensaver.pixelShift,
                        subtitle: L10n.Kiosk.Screensaver.pixelShiftFooter,
                        icon: .arrowAllIcon
                    )
                }
            }

            Section {
                Toggle(isOn: screensaver.showDate) {
                    KioskRow.label(L10n.Kiosk.Screensaver.showDate, icon: .calendarOutlineIcon)
                }
                if screensaver.wrappedValue.showDate {
                    KioskRow.slider(
                        L10n.Kiosk.Screensaver.dateSize,
                        icon: .formatSizeIcon,
                        value: screensaver.dateFontSize
                    )
                    KioskRow.slider(
                        L10n.Kiosk.Screensaver.dateBoldness,
                        icon: .formatBoldIcon,
                        value: screensaver.dateFontWeight
                    )
                }
            }
        }
        .navigationTitle(L10n.Kiosk.Screensaver.Clock.title)
    }
}

struct KioskScreensaverDimmingSettingsView: View {
    @ObservedObject var viewModel: KioskSettingsViewModel

    private var screensaver: Binding<KioskScreensaverSettings> {
        $viewModel.settings.screensaver
    }

    var body: some View {
        List {
            Section {
                Toggle(isOn: screensaver.dimEnabled) {
                    KioskRow.label(L10n.Kiosk.Screensaver.dim, icon: .brightness6Icon)
                }
                if screensaver.wrappedValue.dimEnabled {
                    KioskRow.slider(
                        L10n.Kiosk.Screensaver.dimmingLevel,
                        icon: .brightness6Icon,
                        value: screensaver.dimLevel
                    )
                }
            }
        }
        .navigationTitle(L10n.Kiosk.Screensaver.Dimming.title)
    }
}
