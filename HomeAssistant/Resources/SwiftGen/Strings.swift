// Generated using SwiftGen, by O.Halligon — https://github.com/SwiftGen/SwiftGen

import Foundation

// swiftlint:disable superfluous_disable_command
// swiftlint:disable file_length

// swiftlint:disable explicit_type_interface identifier_name line_length nesting type_body_length type_name
enum L10n {
  /// No
  static let noLabel = L10n.tr("Localizable", "no_label")
  /// OK
  static let okLabel = L10n.tr("Localizable", "ok_label")
  /// Yes
  static let yesLabel = L10n.tr("Localizable", "yes_label")

  enum About {
    /// About
    static let title = L10n.tr("Localizable", "about.title")

    enum Acknowledgements {
      /// Acknowledgements
      static let title = L10n.tr("Localizable", "about.acknowledgements.title")
    }

    enum Chat {
      /// Chat
      static let title = L10n.tr("Localizable", "about.chat.title")
    }

    enum Documentation {
      /// Documentation
      static let title = L10n.tr("Localizable", "about.documentation.title")
    }

    enum Forums {
      /// Forums
      static let title = L10n.tr("Localizable", "about.forums.title")
    }

    enum Github {
      /// GitHub
      static let title = L10n.tr("Localizable", "about.github.title")
    }

    enum GithubIssueTracker {
      /// GitHub Issue Tracker
      static let title = L10n.tr("Localizable", "about.github_issue_tracker.title")
    }

    enum HomeAssistantOnFacebook {
      /// Home Assistant on Facebook
      static let title = L10n.tr("Localizable", "about.home_assistant_on_facebook.title")
    }

    enum HomeAssistantOnTwitter {
      /// Home Assistant on Twitter
      static let title = L10n.tr("Localizable", "about.home_assistant_on_twitter.title")
    }

    enum Logo {
      /// Home Assistant for iOS
      static let appTitle = L10n.tr("Localizable", "about.logo.app_title")
      /// Awaken Your Home
      static let tagline = L10n.tr("Localizable", "about.logo.tagline")
    }

    enum Website {
      /// Website
      static let title = L10n.tr("Localizable", "about.website.title")
    }
  }

  enum Alerts {

    enum OpenUrlFromNotification {
      /// Open URL (%@) found in notification?
      static func message(_ p1: String) -> String {
        return L10n.tr("Localizable", "alerts.open_url_from_notification.message", p1)
      }
      /// Open URL?
      static let title = L10n.tr("Localizable", "alerts.open_url_from_notification.title")
    }
  }

  enum DevicesMap {
    /// Battery
    static let batteryLabel = L10n.tr("Localizable", "devices_map.battery_label")
    /// Devices & Zones
    static let title = L10n.tr("Localizable", "devices_map.title")

    enum MapTypes {
      /// Hybrid
      static let hybrid = L10n.tr("Localizable", "devices_map.map_types.hybrid")
      /// Satellite
      static let satellite = L10n.tr("Localizable", "devices_map.map_types.satellite")
      /// Standard
      static let standard = L10n.tr("Localizable", "devices_map.map_types.standard")
    }
  }

  enum LocationChangeNotification {
    /// Location change
    static let title = L10n.tr("Localizable", "location_change_notification.title")

    enum BackgroundFetch {
      /// Current location delivery triggered via background fetch
      static let body = L10n.tr("Localizable", "location_change_notification.background_fetch.body")
    }

    enum BeaconRegionEnter {
      /// %@ entered via iBeacon
      static func body(_ p1: String) -> String {
        return L10n.tr("Localizable", "location_change_notification.beacon_region_enter.body", p1)
      }
    }

    enum BeaconRegionExit {
      /// %@ exited via iBeacon
      static func body(_ p1: String) -> String {
        return L10n.tr("Localizable", "location_change_notification.beacon_region_exit.body", p1)
      }
    }

    enum RegionEnter {
      /// %@ entered
      static func body(_ p1: String) -> String {
        return L10n.tr("Localizable", "location_change_notification.region_enter.body", p1)
      }
    }

    enum RegionExit {
      /// %@ exited
      static func body(_ p1: String) -> String {
        return L10n.tr("Localizable", "location_change_notification.region_exit.body", p1)
      }
    }

    enum SignificantLocationUpdate {
      /// Significant location change detected
      static let body = L10n.tr("Localizable", "location_change_notification.significant_location_update.body")
    }
  }

  enum ManualLocationUpdateFailedNotification {
    /// Failed to send current location to server. The error was %@
    static func message(_ p1: String) -> String {
      return L10n.tr("Localizable", "manual_location_update_failed_notification.message", p1)
    }
    /// Location failed to update
    static let title = L10n.tr("Localizable", "manual_location_update_failed_notification.title")
  }

  enum ManualLocationUpdateNotification {
    /// Successfully sent a one shot location to the server
    static let message = L10n.tr("Localizable", "manual_location_update_notification.message")
    /// Location updated
    static let title = L10n.tr("Localizable", "manual_location_update_notification.title")
  }

  enum Permissions {

    enum Location {
      /// We use this to inform\r\nHome Assistant of your device location and state.
      static let message = L10n.tr("Localizable", "permissions.location.message")
    }

    enum Notification {
      /// We use this to let you\r\nsend notifications to your device.
      static let message = L10n.tr("Localizable", "permissions.notification.message")
    }
  }

  enum Settings {

    enum CertificateErrorNotification {
      /// A self-signed or invalid SSL certificate has been detected. Certificates of this kind are not supported by Home Assistant for iOS. Please tap the More Info button for further information.
      static let message = L10n.tr("Localizable", "settings.certificate_error_notification.message")
      /// Self-signed or invalid certificate detected
      static let title = L10n.tr("Localizable", "settings.certificate_error_notification.title")
    }

    enum ConnectionError {

      enum Forbidden {
        /// The password was incorrect.
        static let message = L10n.tr("Localizable", "settings.connection_error.forbidden.message")
      }

      enum InvalidUrl {
        /// Looks like your URL is invalid. Please check the format and try again.
        static let message = L10n.tr("Localizable", "settings.connection_error.invalid_url.message")
        /// Error unwrapping URL
        static let title = L10n.tr("Localizable", "settings.connection_error.invalid_url.title")
      }
    }

    enum ConnectionErrorNotification {
      /// There was an error connecting to Home Assistant. Please confirm the settings are correct and save to attempt to reconnect. The error was:\n\n %@
      static func message(_ p1: String) -> String {
        return L10n.tr("Localizable", "settings.connection_error_notification.message", p1)
      }
      /// Connection Error
      static let title = L10n.tr("Localizable", "settings.connection_error_notification.title")
    }

    enum ConnectionSection {
      /// Connection
      static let header = L10n.tr("Localizable", "settings.connection_section.header")

      enum ApiPasswordRow {
        /// password
        static let placeholder = L10n.tr("Localizable", "settings.connection_section.api_password_row.placeholder")
        /// Password
        static let title = L10n.tr("Localizable", "settings.connection_section.api_password_row.title")
      }

      enum BaseUrl {
        /// URL
        static let title = L10n.tr("Localizable", "settings.connection_section.base_url.title")
      }

      enum ConnectRow {
        /// Connect
        static let title = L10n.tr("Localizable", "settings.connection_section.connect_row.title")
      }

      enum ErrorEnablingNotifications {
        /// There was an error enabling notifications. Please try again.
        static let message = L10n.tr("Localizable", "settings.connection_section.error_enabling_notifications.message")
        /// Error enabling notifications
        static let title = L10n.tr("Localizable", "settings.connection_section.error_enabling_notifications.title")
      }

      enum InvalidUrlSchemeNotification {
        /// The URL must begin with either http:// or https://.
        static let message = L10n.tr("Localizable", "settings.connection_section.invalid_url_scheme_notification.message")
        /// Invalid URL
        static let title = L10n.tr("Localizable", "settings.connection_section.invalid_url_scheme_notification.title")
      }

      enum SaveButton {
        /// Save
        static let title = L10n.tr("Localizable", "settings.connection_section.save_button.title")
      }
    }

    enum DetailsSection {

      enum EnableLocationRow {
        /// Enable location tracking
        static let title = L10n.tr("Localizable", "settings.details_section.enable_location_row.title")
      }

      enum EnableNotificationRow {
        /// Enable notifications
        static let title = L10n.tr("Localizable", "settings.details_section.enable_notification_row.title")
      }

      enum LocationSettingsRow {
        /// Location Settings
        static let title = L10n.tr("Localizable", "settings.details_section.location_settings_row.title")
      }

      enum NotificationSettingsRow {
        /// Notification Settings
        static let title = L10n.tr("Localizable", "settings.details_section.notification_settings_row.title")
      }
    }

    enum DeviceIdSection {
      /// Device ID is the identifier used when sending location updates to Home Assistant, as well as the target to send push notifications to.
      static let footer = L10n.tr("Localizable", "settings.device_id_section.footer")

      enum DeviceIdRow {
        /// Device ID
        static let title = L10n.tr("Localizable", "settings.device_id_section.device_id_row.title")
      }
    }

    enum DiscoverySection {
      /// Discovered Home Assistants
      static let header = L10n.tr("Localizable", "settings.discovery_section.header")
      /// Requires password
      static let requiresPassword = L10n.tr("Localizable", "settings.discovery_section.requiresPassword")
    }

    enum GeneralSettingsButton {
      /// General Settings
      static let title = L10n.tr("Localizable", "settings.general_settings_button.title")
    }

    enum NavigationBar {
      /// Settings
      static let title = L10n.tr("Localizable", "settings.navigation_bar.title")

      enum AboutButton {
        /// About
        static let title = L10n.tr("Localizable", "settings.navigation_bar.about_button.title")
      }
    }

    enum ResetSection {

      enum ResetAlert {
        /// Your settings will be reset and this device will be unregistered from push notifications as well as removed from your Home Assistant configuration.
        static let message = L10n.tr("Localizable", "settings.reset_section.reset_alert.message")
        /// Reset
        static let title = L10n.tr("Localizable", "settings.reset_section.reset_alert.title")
      }

      enum ResetRow {
        /// Reset
        static let title = L10n.tr("Localizable", "settings.reset_section.reset_row.title")
      }
    }

    enum StatusSection {
      /// Status
      static let header = L10n.tr("Localizable", "settings.status_section.header")

      enum ConnectedToSseRow {
        /// Connected
        static let title = L10n.tr("Localizable", "settings.status_section.connected_to_sse_row.title")
      }

      enum DeviceTrackerComponentLoadedRow {
        /// Device Tracker Component Loaded
        static let title = L10n.tr("Localizable", "settings.status_section.device_tracker_component_loaded_row.title")
      }

      enum IosComponentLoadedRow {
        /// iOS Component Loaded
        static let title = L10n.tr("Localizable", "settings.status_section.ios_component_loaded_row.title")
      }

      enum LocationNameRow {
        /// My Home Assistant
        static let placeholder = L10n.tr("Localizable", "settings.status_section.location_name_row.placeholder")
        /// Name
        static let title = L10n.tr("Localizable", "settings.status_section.location_name_row.title")
      }

      enum NotifyPlatformLoadedRow {
        /// iOS Notify Platform Loaded
        static let title = L10n.tr("Localizable", "settings.status_section.notify_platform_loaded_row.title")
      }

      enum VersionRow {
        /// 0.42.0
        static let placeholder = L10n.tr("Localizable", "settings.status_section.version_row.placeholder")
        /// Version
        static let title = L10n.tr("Localizable", "settings.status_section.version_row.title")
      }
    }
  }

  enum SettingsDetails {

    enum General {
      /// General Settings
      static let title = L10n.tr("Localizable", "settings_details.general.title")

      enum Chrome {
        /// Open links in Chrome
        static let title = L10n.tr("Localizable", "settings_details.general.chrome.title")
      }
    }

    enum Location {
      /// Location Settings
      static let title = L10n.tr("Localizable", "settings_details.location.title")

      enum Notifications {
        /// Notifications
        static let header = L10n.tr("Localizable", "settings_details.location.notifications.header")

        enum BackgroundFetch {
          /// Background Fetch Notifications
          static let title = L10n.tr("Localizable", "settings_details.location.notifications.background_fetch.title")
        }

        enum BeaconEnter {
          /// Enter Zone via iBeacon Notifications
          static let title = L10n.tr("Localizable", "settings_details.location.notifications.beacon_enter.title")
        }

        enum BeaconExit {
          /// Exit Zone via iBeacon Notifications
          static let title = L10n.tr("Localizable", "settings_details.location.notifications.beacon_exit.title")
        }

        enum Enter {
          /// Enter Zone Notifications
          static let title = L10n.tr("Localizable", "settings_details.location.notifications.enter.title")
        }

        enum Exit {
          /// Exit Zone Notifications
          static let title = L10n.tr("Localizable", "settings_details.location.notifications.exit.title")
        }

        enum LocationChange {
          /// Significant Location Change Notifications
          static let title = L10n.tr("Localizable", "settings_details.location.notifications.location_change.title")
        }
      }

      enum Updates {
        /// Manual location updates can always be triggered
        static let footer = L10n.tr("Localizable", "settings_details.location.updates.footer")
        /// Update sources
        static let header = L10n.tr("Localizable", "settings_details.location.updates.header")

        enum Background {
          /// Background fetch
          static let title = L10n.tr("Localizable", "settings_details.location.updates.background.title")
        }

        enum Notification {
          /// Push notification request
          static let title = L10n.tr("Localizable", "settings_details.location.updates.notification.title")
        }

        enum Significant {
          /// Significant location change
          static let title = L10n.tr("Localizable", "settings_details.location.updates.significant.title")
        }

        enum Zone {
          /// Zone enter/exit
          static let title = L10n.tr("Localizable", "settings_details.location.updates.zone.title")
        }
      }

      enum Zones {
        /// To disable location tracking add track_ios: false to each zones settings or under customize.
        static let footer = L10n.tr("Localizable", "settings_details.location.zones.footer")

        enum Beacon {

          enum PropNotSet {
            /// Not set
            static let value = L10n.tr("Localizable", "settings_details.location.zones.beacon.prop_not_set.value")
          }
        }

        enum BeaconMajor {
          /// iBeacon Major
          static let title = L10n.tr("Localizable", "settings_details.location.zones.beacon_major.title")
        }

        enum BeaconMinor {
          /// iBeacon Minor
          static let title = L10n.tr("Localizable", "settings_details.location.zones.beacon_minor.title")
        }

        enum BeaconUuid {
          /// iBeacon UUID
          static let title = L10n.tr("Localizable", "settings_details.location.zones.beacon_uuid.title")
        }

        enum EnterExitTracked {
          /// Enter/exit tracked
          static let title = L10n.tr("Localizable", "settings_details.location.zones.enter_exit_tracked.title")
        }

        enum Location {
          /// Location
          static let title = L10n.tr("Localizable", "settings_details.location.zones.location.title")
        }

        enum Radius {
          /// Radius
          static let title = L10n.tr("Localizable", "settings_details.location.zones.radius.title")
        }
      }
    }

    enum Notifications {
      /// Notification Settings
      static let title = L10n.tr("Localizable", "settings_details.notifications.title")

      enum BadgeSection {

        enum Button {
          /// Reset badge to 0
          static let title = L10n.tr("Localizable", "settings_details.notifications.badge_section.button.title")
        }

        enum ResetAlert {
          /// The badge has been reset to 0.
          static let message = L10n.tr("Localizable", "settings_details.notifications.badge_section.reset_alert.message")
          /// Badge reset
          static let title = L10n.tr("Localizable", "settings_details.notifications.badge_section.reset_alert.title")
        }
      }

      enum PromptToOpenUrls {
        /// Confirm before opening URL
        static let title = L10n.tr("Localizable", "settings_details.notifications.prompt_to_open_urls.title")
      }

      enum PushIdSection {
        /// This is the target to use in your Home Assistant configuration. Tap to copy or share.
        static let footer = L10n.tr("Localizable", "settings_details.notifications.push_id_section.footer")
        /// Push ID
        static let header = L10n.tr("Localizable", "settings_details.notifications.push_id_section.header")
        /// Not registered for remote notifications
        static let notRegistered = L10n.tr("Localizable", "settings_details.notifications.push_id_section.not_registered")
        /// Push ID
        static let placeholder = L10n.tr("Localizable", "settings_details.notifications.push_id_section.placeholder")
      }

      enum SoundsSection {
        /// Custom push notification sounds can be added via iTunes.
        static let footer = L10n.tr("Localizable", "settings_details.notifications.sounds_section.footer")

        enum Button {
          /// Import Sounds
          static let title = L10n.tr("Localizable", "settings_details.notifications.sounds_section.button.title")
        }

        enum ImportedAlert {
          /// %d sounds were imported. Please restart your phone to complete the import.
          static func message(_ p1: Int) -> String {
            return L10n.tr("Localizable", "settings_details.notifications.sounds_section.imported_alert.message", p1)
          }
          /// Sounds Imported
          static let title = L10n.tr("Localizable", "settings_details.notifications.sounds_section.imported_alert.title")
        }
      }

      enum UpdateSection {
        /// Updating push settings will request the latest push actions and categories from Home Assistant.
        static let footer = L10n.tr("Localizable", "settings_details.notifications.update_section.footer")

        enum Button {
          /// Update push settings
          static let title = L10n.tr("Localizable", "settings_details.notifications.update_section.button.title")
        }

        enum UpdatedAlert {
          /// Push settings imported from Home Assistant.
          static let message = L10n.tr("Localizable", "settings_details.notifications.update_section.updated_alert.message")
          /// Settings Imported
          static let title = L10n.tr("Localizable", "settings_details.notifications.update_section.updated_alert.title")
        }
      }
    }
  }

  enum SignificantLocationChangeNotification {
    /// Significant location change detected, notifying Home Assistant
    static let message = L10n.tr("Localizable", "significant_location_change_notification.message")
  }

  enum UrlHandler {

    enum CallService {

      enum Error {
        /// An error occurred while attempting to call service %@\n%@
        static func message(_ p1: String, _ p2: String) -> String {
          return L10n.tr("Localizable", "url_handler.call_service.error.message", p1, p2)
        }
      }

      enum Success {
        /// Successfully called %@
        static func message(_ p1: String) -> String {
          return L10n.tr("Localizable", "url_handler.call_service.success.message", p1)
        }
        /// Called service
        static let title = L10n.tr("Localizable", "url_handler.call_service.success.title")
      }
    }

    enum Error {
      /// Error
      static let title = L10n.tr("Localizable", "url_handler.error.title")
    }

    enum FireEvent {

      enum Error {
        /// An error occurred while attempting to fire event %@\n%@
        static func message(_ p1: String, _ p2: String) -> String {
          return L10n.tr("Localizable", "url_handler.fire_event.error.message", p1, p2)
        }
      }

      enum Success {
        /// Successfully fired event %@
        static func message(_ p1: String) -> String {
          return L10n.tr("Localizable", "url_handler.fire_event.success.message", p1)
        }
        /// Fired event
        static let title = L10n.tr("Localizable", "url_handler.fire_event.success.title")
      }
    }

    enum NoService {
      /// %@ is not a valid route
      static func message(_ p1: String) -> String {
        return L10n.tr("Localizable", "url_handler.no_service.message", p1)
      }
    }

    enum SendLocation {

      enum Error {
        /// An unknown error occurred while attempting to send location\n%@
        static func message(_ p1: String) -> String {
          return L10n.tr("Localizable", "url_handler.send_location.error.message", p1)
        }
      }

      enum Success {
        /// Sent a one shot location
        static let message = L10n.tr("Localizable", "url_handler.send_location.success.message")
        /// Sent location
        static let title = L10n.tr("Localizable", "url_handler.send_location.success.title")
      }
    }
  }

  enum ZoneEnteredNotification {
    /// %@ entered
    static func message(_ p1: String) -> String {
      return L10n.tr("Localizable", "zone_entered_notification.message", p1)
    }
  }
}
// swiftlint:enable explicit_type_interface identifier_name line_length nesting type_body_length type_name

extension L10n {
  private static func tr(_ table: String, _ key: String, _ args: CVarArg...) -> String {
    let format = NSLocalizedString(key, tableName: table, bundle: Bundle(for: BundleToken.self), comment: "")
    return String(format: format, locale: Locale.current, arguments: args)
  }
}

private final class BundleToken {}
