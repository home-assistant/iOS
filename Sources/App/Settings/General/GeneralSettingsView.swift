import Shared
import SwiftUI

enum GeneralSettingsUserDefaultKey: String {
    case openInBrowser
    case openInPrivateTab
    case confirmBeforeOpeningUrl
}

struct GeneralSettingsView: View {
    /// Helper variable to force redraw view
    @State private var redrawHelper: UUID = .init()

    var body: some View {
        List {
            AppleLikeListTopRowHeader(
                image: .cogIcon,
                title: L10n.SettingsDetails.General.title,
                subtitle: L10n.SettingsDetails.General.body
            )
            appIconSelection

            #if targetEnvironment(macCatalyst)
            Section {
                launchOnLogin
                showAppInPicker
                menuBarText
            }
            Section {
                checkForUpdates
            }
            Section {
                macNativeFeaturesOnly
            }
            #endif

            Section(L10n.SettingsDetails.General.Links.title) {
                openInBrowser
                confirmBeforeOpenURL
            }

            Section(L10n.SettingsDetails.General.Page.title) {
                rememberLastPage
                pageZoomPicker
                pinchZoom
                fullScreen
                refreshAfterInactive
            }
            edgeToEdge
        }
        .id(redrawHelper)
    }

    @ViewBuilder
    private var appIconSelection: some View {
        if !Current.isCatalyst {
            Section {
                NavigationLink(destination: AppIconSelectorView()) {
                    HStack(spacing: DesignSystem.Spaces.two) {
                        RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.half)
                            .frame(width: 18, height: 18)
                            .foregroundStyle(Color.haPrimary)
                        Text(L10n.SettingsDetails.General.AppIcon.title)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var openInBrowser: some View {
        let openInBrowserUserDefaultsKey = GeneralSettingsUserDefaultKey.openInBrowser.rawValue
        let openInPrivateTabUserDefaultsKey = GeneralSettingsUserDefaultKey.openInPrivateTab.rawValue
        if !Current.isCatalyst {
            Picker(
                L10n.SettingsDetails.General.OpenInBrowser.title,
                selection: .init(get: {
                    prefs.string(forKey: openInBrowserUserDefaultsKey)
                }, set: { newValue in
                    prefs.setValue(newValue, forKey: openInBrowserUserDefaultsKey)
                    redrawView()
                })
            ) {
                ForEach(OpenInBrowser.allCases.filter(\.isInstalled), id: \.self) { browser in
                    Text(browser.title)
                        .tag(browser.rawValue)
                }
            }

            if let selectedBrowser = prefs.string(forKey: openInBrowserUserDefaultsKey)
                .flatMap({ OpenInBrowser(rawValue: $0) }), selectedBrowser.supportsPrivateTabs {
                Toggle(isOn: .init(get: {
                    prefs.bool(forKey: openInPrivateTabUserDefaultsKey)
                }, set: { newValue in
                    prefs.setValue(newValue, forKey: openInPrivateTabUserDefaultsKey)
                    redrawView()
                })) {
                    Text(L10n.SettingsDetails.General.OpenInPrivateTab.title)
                }
            }
        }
    }

    @ViewBuilder
    private var confirmBeforeOpenURL: some View {
        let confirmBeforeOpenURLUserDefaultsKey = GeneralSettingsUserDefaultKey.confirmBeforeOpeningUrl.rawValue
        Toggle(isOn: .init(get: {
            prefs.bool(forKey: confirmBeforeOpenURLUserDefaultsKey)
        }, set: { newValue in
            prefs.setValue(newValue, forKey: confirmBeforeOpenURLUserDefaultsKey)
            redrawView()
        })) {
            Text(L10n.SettingsDetails.Notifications.PromptToOpenUrls.title)
        }
    }

    @ViewBuilder
    private var rememberLastPage: some View {
        // Mac has a system-level setting for state restoration
        if !Current.isCatalyst {
            Toggle(isOn: .init(get: {
                Current.settingsStore.restoreLastURL
            }, set: { newValue in
                Current.settingsStore.restoreLastURL = newValue
                redrawView()
            })) {
                Text(L10n.SettingsDetails.General.Restoration.title)
            }
        }
    }

    private var pageZoomPicker: some View {
        Picker(
            L10n.SettingsDetails.General.PageZoom.title,
            selection: .init(get: {
                Current.settingsStore.pageZoom
            }, set: { newValue in
                Current.settingsStore.pageZoom = newValue
                redrawView()
            })
        ) {
            ForEach(SettingsStore.PageZoom.allCases, id: \.zoom) { zoom in
                Text(zoom.description)
                    .tag(zoom)
            }
        }
    }

    @ViewBuilder
    private var pinchZoom: some View {
        if !Current.isCatalyst {
            Toggle(isOn: .init(get: {
                Current.settingsStore.pinchToZoom
            }, set: { newValue in
                Current.settingsStore.pinchToZoom = newValue
                redrawView()
            })) {
                Text(L10n.SettingsDetails.General.PinchToZoom.title)
            }
        }
    }

    @ViewBuilder
    private var fullScreen: some View {
        if !Current.isCatalyst {
            Toggle(isOn: .init(get: {
                Current.settingsStore.fullScreen
            }, set: { newValue in
                Current.settingsStore.fullScreen = newValue
                redrawView()
            })) {
                Text(L10n.SettingsDetails.General.FullScreen.title)
            }
        }
    }

    @ViewBuilder
    private var edgeToEdge: some View {
        Section {
            if !Current.isCatalyst {
                Toggle(isOn: .init(get: {
                    Current.settingsStore.edgeToEdge
                }, set: { newValue in
                    Current.settingsStore.edgeToEdge = newValue
                    redrawView()
                })) {
                    Text("Edge to edge display")
                }
            }
        } header: {
            Text("Experimental")
        } footer: {
            Text("Display Home Asistant UI from edge to edge on devices that support it. This is an experimental feature which can be removed at any time and also may cause layout issues.")
        }

    }

    @ViewBuilder
    private var refreshAfterInactive: some View {
        Toggle(isOn: .init(get: {
            Current.settingsStore.refreshWebViewAfterInactive
        }, set: { newValue in
            Current.settingsStore.refreshWebViewAfterInactive = newValue
            redrawView()
        })) {
            Text(L10n.SettingsDetails.General.RefreshAfterInactive.title)
        }
    }

    // MARK: - Mac

    #if targetEnvironment(macCatalyst)
    @ViewBuilder
    private var launchOnLogin: some View {
        let launcherIdentifier = AppConstants.BundleID.appending(".Launcher")
        Section {
            Toggle(isOn: .init(get: {
                Current.macBridge.isLoginItemEnabled(forBundleIdentifier: launcherIdentifier)
            }, set: { newValue in
                _ = Current.macBridge.setLoginItem(
                    forBundleIdentifier: launcherIdentifier,
                    enabled: newValue
                )
                redrawView()
            })) {
                Text(L10n.SettingsDetails.General.LaunchOnLogin.title)
            }
        }
    }

    // Mac picker to decide if app is shown in dock or bar
    private var showAppInPicker: some View {
        Picker(
            L10n.SettingsDetails.General.Visibility.title,
            selection: .init(get: {
                Current.settingsStore.locationVisibility
            }, set: { newValue in
                Current.settingsStore.locationVisibility = newValue
                redrawView()
            }),
            content: {
                ForEach(SettingsStore.LocationVisibility.allCases, id: \.self) { visibility in
                    Text(visibility.title)
                        .tag(visibility)
                }
            }
        )
    }

    @ViewBuilder
    private var menuBarText: some View {
        if [.menuBar, .dockAndMenuBar].contains(Current.settingsStore.locationVisibility) {
            NavigationLink {
                GeneralSettingsTemplateEditor()
                    .onDisappear {
                        redrawView()
                    }
            } label: {
                HStack {
                    Text(L10n.SettingsDetails.General.MenuBarText.title)
                    Spacer()
                    Text(Current.settingsStore.menuItemTemplate?.template ?? "")
                        .foregroundColor(.secondary)
                }
            }
        }
    }

    private var macNativeFeaturesOnly: some View {
        Toggle(isOn: .init(get: {
            Current.settingsStore.macNativeFeaturesOnly
        }, set: { newValue in
            Current.settingsStore.macNativeFeaturesOnly = newValue
            redrawView()
        })) {
            Text(L10n.SettingsDetails.MacNativeFeatures.title)
        }
    }

    @ViewBuilder
    private var checkForUpdates: some View {
        if Current.updater.isSupported {
            Toggle(isOn: .init(get: {
                Current.settingsStore.privacy.updates
            }, set: { newValue in
                Current.settingsStore.privacy.updates = newValue
                redrawView()
            })) {
                Text(L10n.SettingsDetails.Updates.CheckForUpdates.title)
            }
            Toggle(isOn: .init(get: {
                Current.settingsStore.privacy.updatesIncludeBetas
            }, set: { newValue in
                Current.settingsStore.privacy.updatesIncludeBetas = newValue
                redrawView()
            })) {
                Text(L10n.SettingsDetails.Updates.CheckForUpdates.includeBetas)
            }
        }
    }
    #endif

    private func redrawView() {
        redrawHelper = UUID()
    }
}

#Preview {
    NavigationView {
        GeneralSettingsView()
    }
    .navigationViewStyle(.stack)
}
