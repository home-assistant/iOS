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
                    normalizedSlider(
                        title: L10n.Kiosk.Screensaver.clockSize,
                        icon: .formatSizeIcon,
                        value: screensaver.clockFontSize
                    )
                    normalizedSlider(
                        title: L10n.Kiosk.Screensaver.clockBoldness,
                        icon: .formatBoldIcon,
                        value: screensaver.clockFontWeight
                    )
                    Toggle(isOn: screensaver.showDate) {
                        KioskRow.label(L10n.Kiosk.Screensaver.showDate, icon: .calendarOutlineIcon)
                    }
                    if screensaver.wrappedValue.showDate {
                        normalizedSlider(
                            title: L10n.Kiosk.Screensaver.dateSize,
                            icon: .formatSizeIcon,
                            value: screensaver.dateFontSize
                        )
                        normalizedSlider(
                            title: L10n.Kiosk.Screensaver.dateBoldness,
                            icon: .formatBoldIcon,
                            value: screensaver.dateFontWeight
                        )
                    }
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

                KioskRow.picker(
                    L10n.Kiosk.Screensaver.timeToStart,
                    icon: .clockStartIcon,
                    selection: screensaver.timeToStart
                ) {
                    ForEach(KioskScreensaverTimeout.allCases) { timeout in
                        Text(timeout.title).tag(timeout)
                    }
                }

                Toggle(isOn: screensaver.dimEnabled) {
                    KioskRow.label(L10n.Kiosk.Screensaver.dim, icon: .brightness6Icon)
                }

                if screensaver.wrappedValue.dimEnabled {
                    VStack(alignment: .leading, spacing: DesignSystem.Spaces.half) {
                        HStack {
                            KioskRow.label(L10n.Kiosk.Screensaver.dimmingLevel, icon: .brightness6Icon)
                            Spacer()
                            Text(dimLevelPercentage)
                                .foregroundStyle(.secondary)
                                .monospacedDigit()
                        }
                        Slider(value: screensaver.dimLevel, in: 0 ... 1, step: 0.05)
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

    private var dimLevelPercentage: String {
        let percentage = Int((screensaver.wrappedValue.dimLevel * 100).rounded())
        return "\(percentage)%"
    }

    @ViewBuilder
    private func normalizedSlider(
        title: String,
        icon: MaterialDesignIcons,
        value: Binding<Double>
    ) -> some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spaces.half) {
            HStack {
                KioskRow.label(title, icon: icon)
                Spacer()
                Text("\(Int((value.wrappedValue * 100).rounded()))%")
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }
            Slider(value: value, in: 0 ... 1, step: 0.05)
        }
    }
}
