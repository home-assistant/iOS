import SFSafeSymbols
import Shared
import SwiftUI

struct KioskSettingsView: View {
    @StateObject private var viewModel = KioskSettingsViewModel()

    var body: some View {
        List {
            AppleLikeListTopRowHeader(
                image: .tabletDashboardIcon,
                title: L10n.Kiosk.title,
                subtitle: L10n.Kiosk.body
            ) {
                Toggle(L10n.Kiosk.enabled, isOn: $viewModel.settings.enabled)
            }

            Section {
                Toggle(isOn: $viewModel.settings.requireAuthentication) {
                    KioskRow.label(L10n.Kiosk.Authentication.title, icon: .fingerprintIcon)
                }
            } footer: {
                Text(L10n.Kiosk.Authentication.footer)
            }

            Section {
                Toggle(isOn: $viewModel.settings.acceptRemoteCommands) {
                    KioskRow.label(L10n.Kiosk.AcceptRemoteCommands.title, systemSymbol: .antennaRadiowavesLeftAndRight)
                }
            } footer: {
                Text(L10n.Kiosk.AcceptRemoteCommands.footer)
            }

            Section {
                KioskRow.picker(
                    L10n.Kiosk.Display.server,
                    icon: .serverIcon,
                    selection: $viewModel.settings.serverId
                ) {
                    ForEach(viewModel.servers, id: \.identifier) { server in
                        Text(server.info.name).tag(Optional(server.identifier.rawValue))
                    }
                }
                KioskRow.picker(
                    L10n.Kiosk.Display.dashboard,
                    icon: .viewDashboardOutlineIcon,
                    selection: $viewModel.settings.dashboard
                ) {
                    Text(L10n.Kiosk.Display.dashboardDefault).tag(String?.none)
                    ForEach(viewModel.panels, id: \.path) { panel in
                        Text(panel.title).tag(Optional(panel.path))
                    }
                }
            } header: {
                Text(L10n.Kiosk.Display.title)
            } footer: {
                Text(L10n.Kiosk.Display.footer)
            }

            Section(L10n.Kiosk.Customization.title) {
                Toggle(isOn: $viewModel.settings.keepScreenOn) {
                    KioskRow.label(L10n.Kiosk.keepScreenOn, icon: .sleepOffIcon)
                }
                Toggle(isOn: $viewModel.settings.removeHeaderAndSidebar) {
                    KioskRow.label(L10n.Kiosk.removeHeaderAndSidebar, icon: .dockLeftIcon)
                }
                Toggle(isOn: $viewModel.settings.hideStatusBar) {
                    KioskRow.label(L10n.Kiosk.hideStatusBar, systemSymbol: .menubarRectangle)
                }
                KioskRow.picker(
                    L10n.Kiosk.AutoReload.title,
                    subtitle: L10n.Kiosk.AutoReload.subtitle,
                    icon: .refreshIcon,
                    selection: $viewModel.settings.autoReload
                ) {
                    ForEach(KioskAutoReloadInterval.allCases) { interval in
                        Text(interval.title).tag(interval)
                    }
                }
                NavigationLink {
                    KioskScreensaverSettingsView(viewModel: viewModel)
                } label: {
                    KioskRow.label(L10n.Kiosk.Screensaver.title, icon: .weatherNightIcon)
                }
                NavigationLink {
                    KioskSensorsView()
                } label: {
                    KioskRow.label(L10n.Kiosk.Sensors.title, icon: .motionSensorIcon)
                }
            }

            Section(L10n.Kiosk.Screensaver.ConfigurationAccess.title) {
                KioskRow.picker(
                    L10n.Kiosk.Screensaver.ConfigurationAccess.position,
                    icon: .cogOutlineIcon,
                    selection: $viewModel.settings.settingsEntryPosition
                ) {
                    ForEach(KioskCornerPosition.allCases) { position in
                        Text(position.title).tag(position)
                    }
                }
            }
        }
        .onChange(of: viewModel.settings.serverId) { _ in
            viewModel.serverDidChange()
        }
        .overlay {
            if !viewModel.isUnlocked {
                lockOverlay
            }
        }
        .onAppear {
            viewModel.authenticateIfNeeded()
        }
    }

    private var lockOverlay: some View {
        ZStack {
            Color(uiColor: .systemGroupedBackground)
            VStack(spacing: DesignSystem.Spaces.two) {
                Spacer()
                Image(systemSymbol: .lockFill)
                    .font(.system(size: 72))
                    .foregroundStyle(.secondary)
                Text(L10n.Kiosk.Authentication.lockedTitle)
                    .font(.title.bold())
                    .multilineTextAlignment(.center)
                Spacer()
                Button(L10n.Kiosk.Authentication.unlockButton) {
                    viewModel.authenticate()
                }
                .buttonStyle(.primaryButton)
            }
            .padding(DesignSystem.Spaces.two)
        }
    }
}

enum KioskRow {
    static func label(_ title: String, subtitle: String? = nil, icon: MaterialDesignIcons) -> some View {
        Label {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                if let subtitle {
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        } icon: {
            MaterialDesignIconsImage(icon: icon, size: 24)
        }
    }

    static func label(_ title: String, systemSymbol: SFSymbol) -> some View {
        Label {
            Text(title)
        } icon: {
            Image(systemSymbol: systemSymbol)
        }
    }

    static func picker(
        _ title: String,
        subtitle: String? = nil,
        icon: MaterialDesignIcons,
        selection: Binding<some Hashable>,
        @ViewBuilder content: () -> some View
    ) -> some View {
        HStack {
            label(title, subtitle: subtitle, icon: icon)
            Spacer()
            Picker(title, selection: selection, content: content)
                .labelsHidden()
                .pickerStyle(.menu)
                .fixedMenuOrder()
        }
    }

    static func slider(_ title: String, icon: MaterialDesignIcons, value: Binding<Double>) -> some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spaces.half) {
            HStack {
                label(title, icon: icon)
                Spacer()
                Text("\(Int((value.wrappedValue * 100).rounded()))%")
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }
            Slider(value: value, in: 0 ... 1, step: 0.05)
        }
    }
}

private extension View {
    // Keeps menu items in declaration order (top-to-bottom) instead of letting the
    // system reverse them when the menu opens upward, so the first option stays on top.
    @ViewBuilder
    func fixedMenuOrder() -> some View {
        if #available(iOS 16.0, *) {
            menuOrder(.fixed)
        } else {
            self
        }
    }
}

#Preview {
    NavigationView {
        KioskSettingsView()
    }
}
