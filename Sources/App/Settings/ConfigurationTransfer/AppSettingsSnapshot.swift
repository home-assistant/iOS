import Foundation
import Shared
import UIKit

/// The app's own preferences, in a form that can travel inside a configuration export.
///
/// Only settings the user can actually change are captured. Device identity (push ID, device ID,
/// widget authenticity token), keychain material and "already seen this" bookkeeping are
/// deliberately left out, so importing a file never impersonates the device it came from.
///
/// Every property is optional: a file written by an older or newer build simply skips the settings
/// it does not carry instead of failing to decode.
struct AppSettingsSnapshot: Codable, Equatable {
    /// The mirrored `SettingsStore.Privacy`, which is not itself `Codable`.
    struct Privacy: Codable, Equatable {
        var messaging: Bool
        var crashes: Bool
        var analytics: Bool
        var alerts: Bool
        var updates: Bool
        var updatesIncludeBetas: Bool
    }

    /// The mirrored `SettingsStore.LocationSource`, which is not itself `Codable`.
    struct LocationSources: Codable, Equatable {
        var zone: Bool
        var backgroundFetch: Bool
        var significantLocationChange: Bool
        var pushNotifications: Bool
    }

    var pageZoom: Int?
    var pinchToZoom: Bool?
    var fullScreen: Bool?
    var restoreLastURL: Bool?
    var refreshWebViewAfterInactive: Bool?
    var webViewAlwaysBelowStatusBar: Bool?
    var webViewEmptyStateTimeout: Int?
    var flightGreetingsEnabled: Bool?
    var locationBasedServerSwitching: Bool?
    var clearBadgeAutomatically: Bool?
    var macNativeFeaturesOnly: Bool?
    var receiveDebugNotifications: Bool?
    var notifyOnForceQuit: Bool?
    /// Seconds between periodic sensor updates. A negative value means "disabled", matching how
    /// `SettingsStore.periodicUpdateInterval` stores a nil interval.
    var periodicUpdateIntervalSeconds: Double?
    var locationVisibility: String?
    var menuItemTemplate: String?
    /// Server the menu bar template belongs to. Applied only when that server exists on this device.
    var menuItemTemplateServerId: String?
    var privacy: Privacy?
    var locationSources: LocationSources?
    var gestures: [AppGesture: HAGestureAction]?
    var mediaTypesRequiringUserActionForPlayback: [String]?
    var carPlayAssistDebugSettings: CarPlayAssistDebugSettings?
    /// `AppIcon.rawValue` of the selected alternate icon, or `AppIcon.Release.rawValue` for the
    /// default icon (which is `nil` in `UIApplication.alternateIconName`).
    var appIcon: String?

    @MainActor
    static func capture() -> AppSettingsSnapshot {
        let store = Current.settingsStore
        let privacy = store.privacy
        let locationSources = store.locationSources
        var menuItemTemplateText: String?
        var menuItemTemplateServer: String?
        if let menuItemTemplate = store.menuItemTemplate {
            menuItemTemplateText = menuItemTemplate.template
            menuItemTemplateServer = menuItemTemplate.server.identifier.rawValue
        }

        return AppSettingsSnapshot(
            pageZoom: store.pageZoom.zoom,
            pinchToZoom: store.pinchToZoom,
            fullScreen: store.fullScreen,
            restoreLastURL: store.restoreLastURL,
            refreshWebViewAfterInactive: store.refreshWebViewAfterInactive,
            webViewAlwaysBelowStatusBar: store.webViewAlwaysBelowStatusBar,
            webViewEmptyStateTimeout: store.webViewEmptyStateTimeout,
            flightGreetingsEnabled: store.flightGreetingsEnabled,
            locationBasedServerSwitching: store.locationBasedServerSwitching,
            clearBadgeAutomatically: store.clearBadgeAutomatically,
            macNativeFeaturesOnly: store.macNativeFeaturesOnly,
            receiveDebugNotifications: store.receiveDebugNotifications,
            notifyOnForceQuit: store.notifyOnForceQuit,
            periodicUpdateIntervalSeconds: store.periodicUpdateInterval ?? -1,
            locationVisibility: store.locationVisibility.rawValue,
            menuItemTemplate: menuItemTemplateText,
            menuItemTemplateServerId: menuItemTemplateServer,
            privacy: Privacy(
                messaging: privacy.messaging,
                crashes: privacy.crashes,
                analytics: privacy.analytics,
                alerts: privacy.alerts,
                updates: privacy.updates,
                updatesIncludeBetas: privacy.updatesIncludeBetas
            ),
            locationSources: LocationSources(
                zone: locationSources.zone,
                backgroundFetch: locationSources.backgroundFetch,
                significantLocationChange: locationSources.significantLocationChange,
                pushNotifications: locationSources.pushNotifications
            ),
            gestures: store.gestures,
            mediaTypesRequiringUserActionForPlayback: store.mediaTypesRequiringUserActionForPlayback
                .map(\.rawValue)
                .sorted(),
            carPlayAssistDebugSettings: store.carPlayAssistDebugSettings,
            appIcon: UIApplication.shared.alternateIconName ?? AppIcon.Release.rawValue
        )
    }

    /// Writes every captured setting back through `SettingsStore`, so the same change notifications
    /// fire as when the user edits the setting by hand.
    @MainActor
    func apply() {
        let store = Current.settingsStore
        applyWebViewSettings(store: store)
        applyGeneralSettings(store: store)
        applyPrivacySettings(store: store)
        applyLocationSettings(store: store)
        applyMenuItemTemplate(store: store)
        applyAppIcon()
    }

    @MainActor
    private func applyWebViewSettings(store: SettingsStore) {
        if let pageZoom, let zoom = SettingsStore.PageZoom.allCases.first(where: { $0.zoom == pageZoom }) {
            store.pageZoom = zoom
        }
        if let pinchToZoom { store.pinchToZoom = pinchToZoom }
        if let fullScreen { store.fullScreen = fullScreen }
        if let restoreLastURL { store.restoreLastURL = restoreLastURL }
        if let refreshWebViewAfterInactive { store.refreshWebViewAfterInactive = refreshWebViewAfterInactive }
        if let webViewAlwaysBelowStatusBar { store.webViewAlwaysBelowStatusBar = webViewAlwaysBelowStatusBar }
        if let webViewEmptyStateTimeout { store.webViewEmptyStateTimeout = webViewEmptyStateTimeout }
        if let mediaTypesRequiringUserActionForPlayback {
            store.mediaTypesRequiringUserActionForPlayback = Set(
                mediaTypesRequiringUserActionForPlayback
                    .compactMap(SettingsStore.MediaTypeRequiringUserActionForPlayback.init(rawValue:))
            )
        }
    }

    @MainActor
    private func applyGeneralSettings(store: SettingsStore) {
        if let flightGreetingsEnabled { store.flightGreetingsEnabled = flightGreetingsEnabled }
        if let locationBasedServerSwitching { store.locationBasedServerSwitching = locationBasedServerSwitching }
        if let clearBadgeAutomatically { store.clearBadgeAutomatically = clearBadgeAutomatically }
        if let macNativeFeaturesOnly { store.macNativeFeaturesOnly = macNativeFeaturesOnly }
        if let receiveDebugNotifications { store.receiveDebugNotifications = receiveDebugNotifications }
        if let notifyOnForceQuit { store.notifyOnForceQuit = notifyOnForceQuit }
        if let gestures { store.gestures = gestures }
        if let carPlayAssistDebugSettings { store.carPlayAssistDebugSettings = carPlayAssistDebugSettings }
    }

    @MainActor
    private func applyPrivacySettings(store: SettingsStore) {
        guard let privacy else { return }
        // Read-modify-write rather than a fresh value: `SettingsStore.Privacy`'s memberwise
        // initializer is internal to `Shared`.
        var stored = store.privacy
        stored.messaging = privacy.messaging
        stored.crashes = privacy.crashes
        stored.analytics = privacy.analytics
        stored.alerts = privacy.alerts
        stored.updates = privacy.updates
        stored.updatesIncludeBetas = privacy.updatesIncludeBetas
        store.privacy = stored
    }

    @MainActor
    private func applyLocationSettings(store: SettingsStore) {
        if let periodicUpdateIntervalSeconds {
            store.periodicUpdateInterval = periodicUpdateIntervalSeconds > 0 ? periodicUpdateIntervalSeconds : nil
        }
        if let locationVisibility, let visibility = SettingsStore.LocationVisibility(rawValue: locationVisibility) {
            store.locationVisibility = visibility
        }
        if let locationSources {
            var stored = store.locationSources
            stored.zone = locationSources.zone
            stored.backgroundFetch = locationSources.backgroundFetch
            stored.significantLocationChange = locationSources.significantLocationChange
            stored.pushNotifications = locationSources.pushNotifications
            store.locationSources = stored
        }
    }

    /// The template is meaningless without the server it renders against, so it is restored only when
    /// the exporting server is also signed in here.
    @MainActor
    private func applyMenuItemTemplate(store: SettingsStore) {
        guard let menuItemTemplate,
              let serverId = menuItemTemplateServerId,
              let server = Current.servers.server(forServerIdentifier: serverId) else {
            Current.Log.info("Skipping menu item template import: its server is not present on this device")
            return
        }
        store.menuItemTemplate = (server, menuItemTemplate)
    }

    @MainActor
    private func applyAppIcon() {
        guard let appIcon, AppIcon(rawValue: appIcon) != nil else { return }
        let iconName: String? = appIcon == AppIcon.Release.rawValue ? nil : appIcon
        guard UIApplication.shared.alternateIconName != iconName else { return }
        UIApplication.shared.setAlternateIconName(iconName) { error in
            if let error {
                Current.Log.error("Failed to apply imported app icon \(appIcon): \(error.localizedDescription)")
            }
        }
    }
}
