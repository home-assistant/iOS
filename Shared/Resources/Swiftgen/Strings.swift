// Generated using SwiftGen, by O.Halligon — https://github.com/SwiftGen/SwiftGen

import Foundation

// swiftlint:disable superfluous_disable_command
// swiftlint:disable file_length

// swiftlint:disable explicit_type_interface identifier_name line_length nesting type_body_length type_name
internal enum L10n {
  /// Cancel
  internal static let cancelLabel = L10n.tr("Localizable", "cancel_label")
  /// Error
  internal static let errorLabel = L10n.tr("Localizable", "error_label")
  /// No
  internal static let noLabel = L10n.tr("Localizable", "no_label")
  /// OK
  internal static let okLabel = L10n.tr("Localizable", "ok_label")
  /// Preview Output
  internal static let previewOutput = L10n.tr("Localizable", "preview_output")
  /// Success
  internal static let successLabel = L10n.tr("Localizable", "success_label")
  /// Username
  internal static let usernameLabel = L10n.tr("Localizable", "username_label")
  /// Yes
  internal static let yesLabel = L10n.tr("Localizable", "yes_label")

  internal enum About {
    /// About
    internal static let title = L10n.tr("Localizable", "about.title")

    internal enum Acknowledgements {
      /// Acknowledgements
      internal static let title = L10n.tr("Localizable", "about.acknowledgements.title")
    }

    internal enum Chat {
      /// Chat
      internal static let title = L10n.tr("Localizable", "about.chat.title")
    }

    internal enum Documentation {
      /// Documentation
      internal static let title = L10n.tr("Localizable", "about.documentation.title")
    }

    internal enum Forums {
      /// Forums
      internal static let title = L10n.tr("Localizable", "about.forums.title")
    }

    internal enum Github {
      /// GitHub
      internal static let title = L10n.tr("Localizable", "about.github.title")
    }

    internal enum GithubIssueTracker {
      /// GitHub Issue Tracker
      internal static let title = L10n.tr("Localizable", "about.github_issue_tracker.title")
    }

    internal enum HomeAssistantOnFacebook {
      /// Home Assistant on Facebook
      internal static let title = L10n.tr("Localizable", "about.home_assistant_on_facebook.title")
    }

    internal enum HomeAssistantOnTwitter {
      /// Home Assistant on Twitter
      internal static let title = L10n.tr("Localizable", "about.home_assistant_on_twitter.title")
    }

    internal enum Logo {
      /// Home Assistant for iOS
      internal static let appTitle = L10n.tr("Localizable", "about.logo.app_title")
      /// Awaken Your Home
      internal static let tagline = L10n.tr("Localizable", "about.logo.tagline")
    }

    internal enum Review {
      /// Leave a review
      internal static let title = L10n.tr("Localizable", "about.review.title")
    }

    internal enum Website {
      /// Website
      internal static let title = L10n.tr("Localizable", "about.website.title")
    }
  }

  internal enum Alerts {

    internal enum AuthRequired {
      /// The server has rejected your credentials, and you must sign in again to continue.
      internal static let message = L10n.tr("Localizable", "alerts.auth_required.message")
      /// You must sign in to continue
      internal static let title = L10n.tr("Localizable", "alerts.auth_required.title")
    }

    internal enum OpenUrlFromNotification {
      /// Open URL (%@) found in notification?
      internal static func message(_ p1: String) -> String {
        return L10n.tr("Localizable", "alerts.open_url_from_notification.message", p1)
      }
      /// Open URL?
      internal static let title = L10n.tr("Localizable", "alerts.open_url_from_notification.title")
    }
  }

  internal enum ClError {

    internal enum Description {
      /// Deferred mode is not supported for the requested accuracy.
      internal static let deferredAccuracyTooLow = L10n.tr("Localizable", "cl_error.description.deferred_accuracy_too_low")
      /// The request for deferred updates was canceled by your app or by the location manager.
      internal static let deferredCanceled = L10n.tr("Localizable", "cl_error.description.deferred_canceled")
      /// Deferred mode does not support distance filters.
      internal static let deferredDistanceFiltered = L10n.tr("Localizable", "cl_error.description.deferred_distance_filtered")
      /// The location manager did not enter deferred mode for an unknown reason.
      internal static let deferredFailed = L10n.tr("Localizable", "cl_error.description.deferred_failed")
      /// The manager did not enter deferred mode since updates were already disabled/paused.
      internal static let deferredNotUpdatingLocation = L10n.tr("Localizable", "cl_error.description.deferred_not_updating_location")
      /// Access to the location service was denied by the user.
      internal static let denied = L10n.tr("Localizable", "cl_error.description.denied")
      /// The geocode request was canceled.
      internal static let geocodeCanceled = L10n.tr("Localizable", "cl_error.description.geocode_canceled")
      /// The geocode request yielded no result.
      internal static let geocodeFoundNoResult = L10n.tr("Localizable", "cl_error.description.geocode_found_no_result")
      /// The geocode request yielded a partial result.
      internal static let geocodeFoundPartialResult = L10n.tr("Localizable", "cl_error.description.geocode_found_partial_result")
      /// The heading could not be determined.
      internal static let headingFailure = L10n.tr("Localizable", "cl_error.description.heading_failure")
      /// The location manager was unable to obtain a location value right now.
      internal static let locationUnknown = L10n.tr("Localizable", "cl_error.description.location_unknown")
      /// The network was unavailable or a network error occurred.
      internal static let network = L10n.tr("Localizable", "cl_error.description.network")
      /// A general ranging error occurred.
      internal static let rangingFailure = L10n.tr("Localizable", "cl_error.description.ranging_failure")
      /// Ranging is disabled.
      internal static let rangingUnavailable = L10n.tr("Localizable", "cl_error.description.ranging_unavailable")
      /// Access to the region monitoring service was denied by the user.
      internal static let regionMonitoringDenied = L10n.tr("Localizable", "cl_error.description.region_monitoring_denied")
      /// A registered region cannot be monitored.
      internal static let regionMonitoringFailure = L10n.tr("Localizable", "cl_error.description.region_monitoring_failure")
      /// Core Location will deliver events but they may be delayed.
      internal static let regionMonitoringResponseDelayed = L10n.tr("Localizable", "cl_error.description.region_monitoring_response_delayed")
      /// Core Location could not initialize the region monitoring feature immediately.
      internal static let regionMonitoringSetupDelayed = L10n.tr("Localizable", "cl_error.description.region_monitoring_setup_delayed")
      /// Unknown Core Location error
      internal static let unknown = L10n.tr("Localizable", "cl_error.description.unknown")
    }
  }

  internal enum ClientEvents {

    internal enum EventType {
      /// Location Update
      internal static let locationUpdate = L10n.tr("Localizable", "client_events.event_type.location_update")
      /// Network Request
      internal static let networkRequest = L10n.tr("Localizable", "client_events.event_type.networkRequest")
      /// Notification
      internal static let notification = L10n.tr("Localizable", "client_events.event_type.notification")
      /// Service Call
      internal static let serviceCall = L10n.tr("Localizable", "client_events.event_type.service_call")
      /// Unknown
      internal static let unknown = L10n.tr("Localizable", "client_events.event_type.unknown")

      internal enum Notification {
        /// Received a Push Notification: %@
        internal static func title(_ p1: String) -> String {
          return L10n.tr("Localizable", "client_events.event_type.notification.title", p1)
        }
      }

      internal enum Request {
        /// Request(SSID: %@ - %@)
        internal static func log(_ p1: String, _ p2: String) -> String {
          return L10n.tr("Localizable", "client_events.event_type.request.log", p1, p2)
        }
      }
    }

    internal enum View {
      /// Clear
      internal static let clear = L10n.tr("Localizable", "client_events.view.clear")
    }
  }

  internal enum DevicesMap {
    /// Battery
    internal static let batteryLabel = L10n.tr("Localizable", "devices_map.battery_label")
    /// Devices & Zones
    internal static let title = L10n.tr("Localizable", "devices_map.title")

    internal enum MapTypes {
      /// Hybrid
      internal static let hybrid = L10n.tr("Localizable", "devices_map.map_types.hybrid")
      /// Satellite
      internal static let satellite = L10n.tr("Localizable", "devices_map.map_types.satellite")
      /// Standard
      internal static let standard = L10n.tr("Localizable", "devices_map.map_types.standard")
    }
  }

  internal enum Extensions {

    internal enum Map {

      internal enum Location {
        /// New Location
        internal static let new = L10n.tr("Localizable", "extensions.map.location.new")
        /// Original Location
        internal static let original = L10n.tr("Localizable", "extensions.map.location.original")
      }

      internal enum PayloadMissingHomeassistant {
        /// Payload didn't contain a homeassistant dictionary!
        internal static let message = L10n.tr("Localizable", "extensions.map.payload_missing_homeassistant.message")
      }

      internal enum ValueMissingOrUncastable {

        internal enum Latitude {
          /// Latitude wasn't found or couldn't be casted to string!
          internal static let message = L10n.tr("Localizable", "extensions.map.value_missing_or_uncastable.latitude.message")
        }

        internal enum Longitude {
          /// Longitude wasn't found or couldn't be casted to string!
          internal static let message = L10n.tr("Localizable", "extensions.map.value_missing_or_uncastable.longitude.message")
        }
      }
    }

    internal enum NotificationContent {

      internal enum Error {
        /// No entity_id found in payload!
        internal static let noEntityId = L10n.tr("Localizable", "extensions.notification_content.error.no_entity_id")

        internal enum Request {
          /// Authentication failed!
          internal static let authFailed = L10n.tr("Localizable", "extensions.notification_content.error.request.auth_failed")
          /// Entity '%@' not found!
          internal static func entityNotFound(_ p1: String) -> String {
            return L10n.tr("Localizable", "extensions.notification_content.error.request.entity_not_found", p1)
          }
          /// Got non-200 status code (%d)
          internal static func other(_ p1: Int) -> String {
            return L10n.tr("Localizable", "extensions.notification_content.error.request.other", p1)
          }
          /// Unknown error!
          internal static let unknown = L10n.tr("Localizable", "extensions.notification_content.error.request.unknown")
        }
      }

      internal enum Hud {
        /// Loading %@...
        internal static func loading(_ p1: String) -> String {
          return L10n.tr("Localizable", "extensions.notification_content.hud.loading", p1)
        }
      }
    }
  }

  internal enum LocationChangeNotification {
    /// Location change
    internal static let title = L10n.tr("Localizable", "location_change_notification.title")

    internal enum BackgroundFetch {
      /// Current location delivery triggered via background fetch
      internal static let body = L10n.tr("Localizable", "location_change_notification.background_fetch.body")
    }

    internal enum BeaconRegionEnter {
      /// %@ entered via iBeacon
      internal static func body(_ p1: String) -> String {
        return L10n.tr("Localizable", "location_change_notification.beacon_region_enter.body", p1)
      }
    }

    internal enum BeaconRegionExit {
      /// %@ exited via iBeacon
      internal static func body(_ p1: String) -> String {
        return L10n.tr("Localizable", "location_change_notification.beacon_region_exit.body", p1)
      }
    }

    internal enum Manual {
      /// Location update triggered by user
      internal static let body = L10n.tr("Localizable", "location_change_notification.manual.body")
    }

    internal enum PushNotification {
      /// Location updated via push notification
      internal static let body = L10n.tr("Localizable", "location_change_notification.push_notification.body")
    }

    internal enum RegionEnter {
      /// %@ entered
      internal static func body(_ p1: String) -> String {
        return L10n.tr("Localizable", "location_change_notification.region_enter.body", p1)
      }
    }

    internal enum RegionExit {
      /// %@ exited
      internal static func body(_ p1: String) -> String {
        return L10n.tr("Localizable", "location_change_notification.region_exit.body", p1)
      }
    }

    internal enum SignificantLocationUpdate {
      /// Significant location change detected
      internal static let body = L10n.tr("Localizable", "location_change_notification.significant_location_update.body")
    }

    internal enum Siri {
      /// Location update triggered by Siri
      internal static let body = L10n.tr("Localizable", "location_change_notification.siri.body")
    }

    internal enum Unknown {
      /// Location updated via unknown method
      internal static let body = L10n.tr("Localizable", "location_change_notification.unknown.body")
    }

    internal enum UrlScheme {
      /// Location updated via URL Scheme
      internal static let body = L10n.tr("Localizable", "location_change_notification.url_scheme.body")
    }

    internal enum Visit {
      /// Location updated via Visit
      internal static let body = L10n.tr("Localizable", "location_change_notification.visit.body")
    }
  }

  internal enum ManualLocationUpdateFailedNotification {
    /// Failed to send current location to server. The error was %@
    internal static func message(_ p1: String) -> String {
      return L10n.tr("Localizable", "manual_location_update_failed_notification.message", p1)
    }
    /// Location failed to update
    internal static let title = L10n.tr("Localizable", "manual_location_update_failed_notification.title")
  }

  internal enum ManualLocationUpdateNotification {
    /// Successfully sent a one shot location to the server
    internal static let message = L10n.tr("Localizable", "manual_location_update_notification.message")
    /// Location updated
    internal static let title = L10n.tr("Localizable", "manual_location_update_notification.title")
  }

  internal enum Permissions {

    internal enum Location {
      /// We use this to inform\r\nHome Assistant of your device location and state.
      internal static let message = L10n.tr("Localizable", "permissions.location.message")
    }

    internal enum Notification {
      /// We use this to let you\r\nsend notifications to your device.
      internal static let message = L10n.tr("Localizable", "permissions.notification.message")
    }
  }

  internal enum Settings {

    internal enum CertificateErrorNotification {
      /// A self-signed or invalid SSL certificate has been detected. Certificates of this kind are not supported by Home Assistant for iOS. Please tap the More Info button for further information.
      internal static let message = L10n.tr("Localizable", "settings.certificate_error_notification.message")
      /// Self-signed or invalid certificate detected
      internal static let title = L10n.tr("Localizable", "settings.certificate_error_notification.title")
    }

    internal enum ConnectionError {

      internal enum Forbidden {
        /// The password was incorrect.
        internal static let message = L10n.tr("Localizable", "settings.connection_error.forbidden.message")
      }

      internal enum InvalidUrl {
        /// Looks like your URL is invalid. Please check the format and try again.
        internal static let message = L10n.tr("Localizable", "settings.connection_error.invalid_url.message")
        /// Error unwrapping URL
        internal static let title = L10n.tr("Localizable", "settings.connection_error.invalid_url.title")
      }
    }

    internal enum ConnectionErrorNotification {
      /// There was an error connecting to Home Assistant. Please confirm the settings are correct and save to attempt to reconnect. The error was:\n\n%@
      internal static func message(_ p1: String) -> String {
        return L10n.tr("Localizable", "settings.connection_error_notification.message", p1)
      }
      /// Connection Error
      internal static let title = L10n.tr("Localizable", "settings.connection_error_notification.title")
    }

    internal enum ConnectionSection {
      /// Connection
      internal static let header = L10n.tr("Localizable", "settings.connection_section.header")

      internal enum ApiPasswordRow {
        /// password
        internal static let placeholder = L10n.tr("Localizable", "settings.connection_section.api_password_row.placeholder")
        /// Password
        internal static let title = L10n.tr("Localizable", "settings.connection_section.api_password_row.title")
      }

      internal enum BaseUrl {
        /// https://homeassistant.myhouse.com
        internal static let placeholder = L10n.tr("Localizable", "settings.connection_section.base_url.placeholder")
        /// URL
        internal static let title = L10n.tr("Localizable", "settings.connection_section.base_url.title")
      }

      internal enum BasicAuth {
        /// HTTP Basic Authentication
        internal static let title = L10n.tr("Localizable", "settings.connection_section.basic_auth.title")

        internal enum Password {
          /// verysecure
          internal static let placeholder = L10n.tr("Localizable", "settings.connection_section.basic_auth.password.placeholder")
          /// Password
          internal static let title = L10n.tr("Localizable", "settings.connection_section.basic_auth.password.title")
        }

        internal enum Username {
          /// iam
          internal static let placeholder = L10n.tr("Localizable", "settings.connection_section.basic_auth.username.placeholder")
          /// Username
          internal static let title = L10n.tr("Localizable", "settings.connection_section.basic_auth.username.title")
        }
      }

      internal enum ConnectRow {
        /// Connect
        internal static let title = L10n.tr("Localizable", "settings.connection_section.connect_row.title")
      }

      internal enum ErrorEnablingNotifications {
        /// There was an error enabling notifications. Please try again.
        internal static let message = L10n.tr("Localizable", "settings.connection_section.error_enabling_notifications.message")
        /// Error enabling notifications
        internal static let title = L10n.tr("Localizable", "settings.connection_section.error_enabling_notifications.title")
      }

      internal enum ExternalBaseUrl {
        /// External URL
        internal static let title = L10n.tr("Localizable", "settings.connection_section.external_base_url.title")
      }

      internal enum InternalBaseUrl {
        /// Internal URL
        internal static let title = L10n.tr("Localizable", "settings.connection_section.internal_base_url.title")
      }

      internal enum InvalidUrlSchemeNotification {
        /// The URL must begin with either http:// or https://.
        internal static let message = L10n.tr("Localizable", "settings.connection_section.invalid_url_scheme_notification.message")
        /// Invalid URL
        internal static let title = L10n.tr("Localizable", "settings.connection_section.invalid_url_scheme_notification.title")
      }

      internal enum NetworkName {
        /// Current Network Name
        internal static let title = L10n.tr("Localizable", "settings.connection_section.network_name.title")
      }

      internal enum SaveButton {
        /// Save
        internal static let title = L10n.tr("Localizable", "settings.connection_section.save_button.title")
      }

      internal enum UseInternalUrl {
        /// Use internal URL
        internal static let title = L10n.tr("Localizable", "settings.connection_section.use_internal_url.title")
      }

      internal enum UseLegacyAuth {
        /// Use legacy authentication
        internal static let title = L10n.tr("Localizable", "settings.connection_section.use_legacy_auth.title")
      }
    }

    internal enum DetailsSection {

      internal enum EnableLocationRow {
        /// Enable location tracking
        internal static let title = L10n.tr("Localizable", "settings.details_section.enable_location_row.title")
      }

      internal enum EnableNotificationRow {
        /// Enable notifications
        internal static let title = L10n.tr("Localizable", "settings.details_section.enable_notification_row.title")
      }

      internal enum LocationSettingsRow {
        /// Location Settings
        internal static let title = L10n.tr("Localizable", "settings.details_section.location_settings_row.title")
      }

      internal enum NotificationSettingsRow {
        /// Notification Settings
        internal static let title = L10n.tr("Localizable", "settings.details_section.notification_settings_row.title")
      }

      internal enum SiriShortcutsRow {
        /// Siri Shortcuts
        internal static let title = L10n.tr("Localizable", "settings.details_section.siri_shortcuts_row.title")
      }

      internal enum WatchRow {
        /// Apple Watch
        internal static let title = L10n.tr("Localizable", "settings.details_section.watch_row.title")
      }
    }

    internal enum DeviceIdSection {
      /// Device ID is the identifier used when sending location updates to Home Assistant, as well as the target to send push notifications to.
      internal static let footer = L10n.tr("Localizable", "settings.device_id_section.footer")

      internal enum DeviceIdRow {
        /// Device ID
        internal static let title = L10n.tr("Localizable", "settings.device_id_section.device_id_row.title")
      }
    }

    internal enum DiscoverySection {
      /// Discovered Home Assistants
      internal static let header = L10n.tr("Localizable", "settings.discovery_section.header")
      /// Requires password
      internal static let requiresPassword = L10n.tr("Localizable", "settings.discovery_section.requiresPassword")
    }

    internal enum EventLog {
      /// Event Log
      internal static let title = L10n.tr("Localizable", "settings.event_log.title")
    }

    internal enum GeneralSettingsButton {
      /// General Settings
      internal static let title = L10n.tr("Localizable", "settings.general_settings_button.title")
    }

    internal enum NavigationBar {
      /// Settings
      internal static let title = L10n.tr("Localizable", "settings.navigation_bar.title")

      internal enum AboutButton {
        /// About
        internal static let title = L10n.tr("Localizable", "settings.navigation_bar.about_button.title")
      }
    }

    internal enum ResetSection {

      internal enum ResetAlert {
        /// Your settings will be reset and this device will be unregistered from push notifications as well as removed from your Home Assistant configuration.
        internal static let message = L10n.tr("Localizable", "settings.reset_section.reset_alert.message")
        /// Reset
        internal static let title = L10n.tr("Localizable", "settings.reset_section.reset_alert.title")
      }

      internal enum ResetRow {
        /// Reset
        internal static let title = L10n.tr("Localizable", "settings.reset_section.reset_row.title")
      }
    }

    internal enum StatusSection {
      /// Status
      internal static let header = L10n.tr("Localizable", "settings.status_section.header")

      internal enum ConnectedToSseRow {
        /// Connected
        internal static let title = L10n.tr("Localizable", "settings.status_section.connected_to_sse_row.title")
      }

      internal enum DeviceTrackerComponentLoadedRow {
        /// Device Tracker Component Loaded
        internal static let title = L10n.tr("Localizable", "settings.status_section.device_tracker_component_loaded_row.title")
      }

      internal enum IosComponentLoadedRow {
        /// iOS Component Loaded
        internal static let title = L10n.tr("Localizable", "settings.status_section.ios_component_loaded_row.title")
      }

      internal enum LocationNameRow {
        /// My Home Assistant
        internal static let placeholder = L10n.tr("Localizable", "settings.status_section.location_name_row.placeholder")
        /// Name
        internal static let title = L10n.tr("Localizable", "settings.status_section.location_name_row.title")
      }

      internal enum NotifyPlatformLoadedRow {
        /// iOS Notify Platform Loaded
        internal static let title = L10n.tr("Localizable", "settings.status_section.notify_platform_loaded_row.title")
      }

      internal enum VersionRow {
        /// 0.78.0
        internal static let placeholder = L10n.tr("Localizable", "settings.status_section.version_row.placeholder")
        /// Version
        internal static let title = L10n.tr("Localizable", "settings.status_section.version_row.title")
      }
    }
  }

  internal enum SettingsDetails {

    internal enum General {
      /// General Settings
      internal static let title = L10n.tr("Localizable", "settings_details.general.title")

      internal enum Chrome {
        /// Open links in Chrome
        internal static let title = L10n.tr("Localizable", "settings_details.general.chrome.title")
      }
    }

    internal enum Location {
      /// Location Settings
      internal static let title = L10n.tr("Localizable", "settings_details.location.title")

      internal enum Notifications {
        /// Location Notifications
        internal static let header = L10n.tr("Localizable", "settings_details.location.notifications.header")

        internal enum BackgroundFetch {
          /// Background Fetch Notifications
          internal static let title = L10n.tr("Localizable", "settings_details.location.notifications.background_fetch.title")
        }

        internal enum BeaconEnter {
          /// Enter Zone via iBeacon Notifications
          internal static let title = L10n.tr("Localizable", "settings_details.location.notifications.beacon_enter.title")
        }

        internal enum BeaconExit {
          /// Exit Zone via iBeacon Notifications
          internal static let title = L10n.tr("Localizable", "settings_details.location.notifications.beacon_exit.title")
        }

        internal enum Enter {
          /// Enter Zone Notifications
          internal static let title = L10n.tr("Localizable", "settings_details.location.notifications.enter.title")
        }

        internal enum Exit {
          /// Exit Zone Notifications
          internal static let title = L10n.tr("Localizable", "settings_details.location.notifications.exit.title")
        }

        internal enum LocationChange {
          /// Significant Location Change Notifications
          internal static let title = L10n.tr("Localizable", "settings_details.location.notifications.location_change.title")
        }

        internal enum PushNotification {
          /// Pushed Location Request Notifications
          internal static let title = L10n.tr("Localizable", "settings_details.location.notifications.push_notification.title")
        }

        internal enum UrlScheme {
          /// URL Scheme Location Notifications
          internal static let title = L10n.tr("Localizable", "settings_details.location.notifications.url_scheme.title")
        }

        internal enum Visit {
          /// Visit Location Notifications
          internal static let title = L10n.tr("Localizable", "settings_details.location.notifications.visit.title")
        }
      }

      internal enum Updates {
        /// Manual location updates can always be triggered
        internal static let footer = L10n.tr("Localizable", "settings_details.location.updates.footer")
        /// Update sources
        internal static let header = L10n.tr("Localizable", "settings_details.location.updates.header")

        internal enum Background {
          /// Background fetch
          internal static let title = L10n.tr("Localizable", "settings_details.location.updates.background.title")
        }

        internal enum Notification {
          /// Push notification request
          internal static let title = L10n.tr("Localizable", "settings_details.location.updates.notification.title")
        }

        internal enum Significant {
          /// Significant location change
          internal static let title = L10n.tr("Localizable", "settings_details.location.updates.significant.title")
        }

        internal enum Zone {
          /// Zone enter/exit
          internal static let title = L10n.tr("Localizable", "settings_details.location.updates.zone.title")
        }
      }

      internal enum Zones {
        /// To disable location tracking add track_ios: false to each zones settings or under customize.
        internal static let footer = L10n.tr("Localizable", "settings_details.location.zones.footer")

        internal enum Beacon {

          internal enum PropNotSet {
            /// Not set
            internal static let value = L10n.tr("Localizable", "settings_details.location.zones.beacon.prop_not_set.value")
          }
        }

        internal enum BeaconMajor {
          /// iBeacon Major
          internal static let title = L10n.tr("Localizable", "settings_details.location.zones.beacon_major.title")
        }

        internal enum BeaconMinor {
          /// iBeacon Minor
          internal static let title = L10n.tr("Localizable", "settings_details.location.zones.beacon_minor.title")
        }

        internal enum BeaconUuid {
          /// iBeacon UUID
          internal static let title = L10n.tr("Localizable", "settings_details.location.zones.beacon_uuid.title")
        }

        internal enum EnterExitTracked {
          /// Enter/exit tracked
          internal static let title = L10n.tr("Localizable", "settings_details.location.zones.enter_exit_tracked.title")
        }

        internal enum Location {
          /// Location
          internal static let title = L10n.tr("Localizable", "settings_details.location.zones.location.title")
        }

        internal enum Radius {
          /// Radius
          internal static let title = L10n.tr("Localizable", "settings_details.location.zones.radius.title")
        }
      }
    }

    internal enum Notifications {
      /// Notification Settings
      internal static let title = L10n.tr("Localizable", "settings_details.notifications.title")

      internal enum BadgeSection {

        internal enum Button {
          /// Reset badge to 0
          internal static let title = L10n.tr("Localizable", "settings_details.notifications.badge_section.button.title")
        }

        internal enum ResetAlert {
          /// The badge has been reset to 0.
          internal static let message = L10n.tr("Localizable", "settings_details.notifications.badge_section.reset_alert.message")
          /// Badge reset
          internal static let title = L10n.tr("Localizable", "settings_details.notifications.badge_section.reset_alert.title")
        }
      }

      internal enum PromptToOpenUrls {
        /// Confirm before opening URL
        internal static let title = L10n.tr("Localizable", "settings_details.notifications.prompt_to_open_urls.title")
      }

      internal enum PushIdSection {
        /// This is the target to use in your Home Assistant configuration. Tap to copy or share.
        internal static let footer = L10n.tr("Localizable", "settings_details.notifications.push_id_section.footer")
        /// Push ID
        internal static let header = L10n.tr("Localizable", "settings_details.notifications.push_id_section.header")
        /// Not registered for remote notifications
        internal static let notRegistered = L10n.tr("Localizable", "settings_details.notifications.push_id_section.not_registered")
        /// Push ID
        internal static let placeholder = L10n.tr("Localizable", "settings_details.notifications.push_id_section.placeholder")
      }

      internal enum SoundsSection {
        /// Custom push notification sounds can be added via iTunes.
        internal static let footer = L10n.tr("Localizable", "settings_details.notifications.sounds_section.footer")

        internal enum Button {
          /// Import Sounds
          internal static let title = L10n.tr("Localizable", "settings_details.notifications.sounds_section.button.title")
        }

        internal enum ImportedAlert {
          /// %d sounds were imported. Please restart your phone to complete the import.
          internal static func message(_ p1: Int) -> String {
            return L10n.tr("Localizable", "settings_details.notifications.sounds_section.imported_alert.message", p1)
          }
          /// Sounds Imported
          internal static let title = L10n.tr("Localizable", "settings_details.notifications.sounds_section.imported_alert.title")
        }
      }

      internal enum UpdateSection {
        /// Updating push settings will request the latest push actions and categories from Home Assistant.
        internal static let footer = L10n.tr("Localizable", "settings_details.notifications.update_section.footer")

        internal enum Button {
          /// Update push settings
          internal static let title = L10n.tr("Localizable", "settings_details.notifications.update_section.button.title")
        }

        internal enum UpdatedAlert {
          /// Push settings imported from Home Assistant.
          internal static let message = L10n.tr("Localizable", "settings_details.notifications.update_section.updated_alert.message")
          /// Settings Imported
          internal static let title = L10n.tr("Localizable", "settings_details.notifications.update_section.updated_alert.title")
        }
      }
    }

    internal enum Siri {
      /// Siri Shortcuts
      internal static let title = L10n.tr("Localizable", "settings_details.siri.title")
    }
  }

  internal enum SiriShortcuts {

    internal enum Configurator {

      internal enum Fields {
        /// Use default value
        internal static let useDefaultValue = L10n.tr("Localizable", "siri_shortcuts.configurator.fields.use_default_value")
        /// Use suggested value
        internal static let useSuggestedValue = L10n.tr("Localizable", "siri_shortcuts.configurator.fields.use_suggested_value")

        internal enum Section {
          /// Suggested: %@
          internal static func footer(_ p1: String) -> String {
            return L10n.tr("Localizable", "siri_shortcuts.configurator.fields.section.footer", p1)
          }
          /// Fields
          internal static let header = L10n.tr("Localizable", "siri_shortcuts.configurator.fields.section.header")
        }
      }

      internal enum Settings {

        internal enum Name {
          /// Shortcut name
          internal static let title = L10n.tr("Localizable", "siri_shortcuts.configurator.settings.name.title")
        }

        internal enum NotifyOnRun {
          /// Send notification when run
          internal static let title = L10n.tr("Localizable", "siri_shortcuts.configurator.settings.notify_on_run.title")
        }
      }
    }
  }

  internal enum UrlHandler {

    internal enum CallService {

      internal enum Error {
        /// An error occurred while attempting to call service %@\n%@
        internal static func message(_ p1: String, _ p2: String) -> String {
          return L10n.tr("Localizable", "url_handler.call_service.error.message", p1, p2)
        }
      }

      internal enum Success {
        /// Successfully called %@
        internal static func message(_ p1: String) -> String {
          return L10n.tr("Localizable", "url_handler.call_service.success.message", p1)
        }
        /// Called service
        internal static let title = L10n.tr("Localizable", "url_handler.call_service.success.title")
      }
    }

    internal enum FireEvent {

      internal enum Error {
        /// An error occurred while attempting to fire event %@\n%@
        internal static func message(_ p1: String, _ p2: String) -> String {
          return L10n.tr("Localizable", "url_handler.fire_event.error.message", p1, p2)
        }
      }

      internal enum Success {
        /// Successfully fired event %@
        internal static func message(_ p1: String) -> String {
          return L10n.tr("Localizable", "url_handler.fire_event.success.message", p1)
        }
        /// Fired event
        internal static let title = L10n.tr("Localizable", "url_handler.fire_event.success.title")
      }
    }

    internal enum NoService {
      /// %@ is not a valid route
      internal static func message(_ p1: String) -> String {
        return L10n.tr("Localizable", "url_handler.no_service.message", p1)
      }
    }

    internal enum SendLocation {

      internal enum Error {
        /// An unknown error occurred while attempting to send location\n%@
        internal static func message(_ p1: String) -> String {
          return L10n.tr("Localizable", "url_handler.send_location.error.message", p1)
        }
      }

      internal enum Success {
        /// Sent a one shot location
        internal static let message = L10n.tr("Localizable", "url_handler.send_location.success.message")
        /// Sent location
        internal static let title = L10n.tr("Localizable", "url_handler.send_location.success.title")
      }
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
