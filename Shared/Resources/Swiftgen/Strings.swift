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

    internal enum Beta {
      /// Join Beta
      internal static let title = L10n.tr("Localizable", "about.beta.title")
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

  internal enum NotificationsConfigurator {
    /// Identifier
    internal static let identifier = L10n.tr("Localizable", "notifications_configurator.identifier")

    internal enum Action {

      internal enum Rows {

        internal enum AuthenticationRequired {
          /// When the user selects an action with this option, the system prompts the user to unlock the device. After unlocking, Home Assistant will be notified of the selected action.
          internal static let footer = L10n.tr("Localizable", "notifications_configurator.action.rows.authentication_required.footer")
          /// Authentication Required
          internal static let title = L10n.tr("Localizable", "notifications_configurator.action.rows.authentication_required.title")
        }

        internal enum Destructive {
          /// When enabled, the action button is displayed with special highlighting to indicate that it performs a destructive task.
          internal static let footer = L10n.tr("Localizable", "notifications_configurator.action.rows.destructive.footer")
          /// Desctructive
          internal static let title = L10n.tr("Localizable", "notifications_configurator.action.rows.destructive.title")
        }

        internal enum Foreground {
          /// Enabling this will cause the app to launch if it's in the background when tapping a notification
          internal static let footer = L10n.tr("Localizable", "notifications_configurator.action.rows.foreground.footer")
          /// Launch app
          internal static let title = L10n.tr("Localizable", "notifications_configurator.action.rows.foreground.title")
        }

        internal enum TextInputButtonTitle {
          /// Button Title
          internal static let title = L10n.tr("Localizable", "notifications_configurator.action.rows.text_input_button_title.title")
        }

        internal enum TextInputPlaceholder {
          /// Placeholder
          internal static let title = L10n.tr("Localizable", "notifications_configurator.action.rows.text_input_placeholder.title")
        }

        internal enum Title {
          /// Title
          internal static let title = L10n.tr("Localizable", "notifications_configurator.action.rows.title.title")
        }
      }

      internal enum TextInput {
        /// Text Input
        internal static let title = L10n.tr("Localizable", "notifications_configurator.action.text_input.title")
      }
    }

    internal enum Category {

      internal enum NavigationBar {
        /// Category Configurator
        internal static let title = L10n.tr("Localizable", "notifications_configurator.category.navigation_bar.title")
      }

      internal enum Rows {

        internal enum Actions {
          /// Actions
          internal static let header = L10n.tr("Localizable", "notifications_configurator.category.rows.actions.header")

          internal enum AddRow {
            /// Add
            internal static let title = L10n.tr("Localizable", "notifications_configurator.category.rows.actions.add_row.title")
          }

          internal enum Footer {
            /// Categories can have a maximum of 4 actions. Banner notifications will only show 2. Change your notification settings to Alert in order to add up to 4.
            internal static let `default` = L10n.tr("Localizable", "notifications_configurator.category.rows.actions.footer.default")

            internal enum Style {
              /// Categories can have a maximum of 4 actions. You are currently using the Alert style which allows 4 actions.
              internal static let alert = L10n.tr("Localizable", "notifications_configurator.category.rows.actions.footer.style.alert")
              /// Categories can have a maximum of 4 actions. You are currently using the Banner style which allows 2 actions. Change your notification settings to Alert in order to add up to 4.
              internal static let banner = L10n.tr("Localizable", "notifications_configurator.category.rows.actions.footer.style.banner")
            }
          }
        }

        internal enum CategorySummary {
          /// %%u notifications in %%@
          internal static let `default` = L10n.tr("Localizable", "notifications_configurator.category.rows.category_summary.default")
          /// A format string for the summary description used when the system groups the category’s notifications. You can optionally uses '%%u' to show the number of notifications in the group and '%%@' to show the summary argument provided in the push payload.
          internal static let footer = L10n.tr("Localizable", "notifications_configurator.category.rows.category_summary.footer")
          /// Category Summary
          internal static let header = L10n.tr("Localizable", "notifications_configurator.category.rows.category_summary.header")
        }

        internal enum HiddenPreviewPlaceholder {
          /// %%u notifications
          internal static let `default` = L10n.tr("Localizable", "notifications_configurator.category.rows.hidden_preview_placeholder.default")
          /// This text is only displayed if you have notification previews hidden. Use '%%u' for the number of messages with the same thread identifier.
          internal static let footer = L10n.tr("Localizable", "notifications_configurator.category.rows.hidden_preview_placeholder.footer")
          /// Hidden Preview Placeholder
          internal static let header = L10n.tr("Localizable", "notifications_configurator.category.rows.hidden_preview_placeholder.header")
        }

        internal enum Name {
          /// Name
          internal static let title = L10n.tr("Localizable", "notifications_configurator.category.rows.name.title")
        }
      }
    }

    internal enum NewAction {
      /// New Action
      internal static let title = L10n.tr("Localizable", "notifications_configurator.new_action.title")
    }

    internal enum Settings {
      /// Identifier must contain only letters and underscores. It must be globally unique to the app.
      internal static let footer = L10n.tr("Localizable", "notifications_configurator.settings.footer")
      /// Settings
      internal static let header = L10n.tr("Localizable", "notifications_configurator.settings.header")

      internal enum Footer {
        /// Identifier can not be changed after creation. You must delete and recreate the action to change the identifier.
        internal static let idSet = L10n.tr("Localizable", "notifications_configurator.settings.footer.id_set")
      }
    }
  }

  internal enum Permissions {

    internal enum Location {
      /// We use this to inform\rHome Assistant of your device location and state.
      internal static let message = L10n.tr("Localizable", "permissions.location.message")

      internal enum Initial {
        /// We need permission to allow informing\rHome Assistant of your device location and state.
        internal static let message = L10n.tr("Localizable", "permissions.location.initial.message")
        /// Allow Location Access?
        internal static let title = L10n.tr("Localizable", "permissions.location.initial.title")

        internal enum Button {
          /// Allow
          internal static let allow = L10n.tr("Localizable", "permissions.location.initial.button.allow")
          /// Deny
          internal static let deny = L10n.tr("Localizable", "permissions.location.initial.button.deny")
        }
      }

      internal enum Reenable {
        /// You previously had location access enabled but it now appears disabled. Do you wish to re-enable it?
        internal static let message = L10n.tr("Localizable", "permissions.location.reenable.message")
        /// Re-enable Location Access?
        internal static let title = L10n.tr("Localizable", "permissions.location.reenable.title")

        internal enum Button {
          /// Re-enable
          internal static let allow = L10n.tr("Localizable", "permissions.location.reenable.button.allow")
          /// Leave disabled
          internal static let deny = L10n.tr("Localizable", "permissions.location.reenable.button.deny")
        }
      }
    }

    internal enum Motion {

      internal enum Initial {
        /// We can use motion data to enhance location updates but need permission to do so.
        internal static let message = L10n.tr("Localizable", "permissions.motion.initial.message")
        /// Allow Motion?
        internal static let title = L10n.tr("Localizable", "permissions.motion.initial.title")

        internal enum Button {
          /// Allow
          internal static let allow = L10n.tr("Localizable", "permissions.motion.initial.button.allow")
          /// Deny
          internal static let deny = L10n.tr("Localizable", "permissions.motion.initial.button.deny")
        }
      }

      internal enum Reenable {
        /// You previously had allowed use of motion data but it now appears to be disabled. Do you wish to re-enable motion data to enhance location updates?
        internal static let message = L10n.tr("Localizable", "permissions.motion.reenable.message")
        /// Re-enable Motion?
        internal static let title = L10n.tr("Localizable", "permissions.motion.reenable.title")

        internal enum Button {
          /// Re-enable
          internal static let allow = L10n.tr("Localizable", "permissions.motion.reenable.button.allow")
          /// Leave disabled
          internal static let deny = L10n.tr("Localizable", "permissions.motion.reenable.button.deny")
        }
      }
    }

    internal enum Notification {
      /// We use this to let you\rsend notifications to your device.
      internal static let message = L10n.tr("Localizable", "permissions.notification.message")

      internal enum Initial {
        /// We need permission to allow you\rsend notifications to your device.
        internal static let message = L10n.tr("Localizable", "permissions.notification.initial.message")
        /// Allow Notifications?
        internal static let title = L10n.tr("Localizable", "permissions.notification.initial.title")

        internal enum Button {
          /// Allow
          internal static let allow = L10n.tr("Localizable", "permissions.notification.initial.button.allow")
          /// Deny
          internal static let deny = L10n.tr("Localizable", "permissions.notification.initial.button.deny")
        }
      }

      internal enum Reenable {
        /// You previously had notifications enabled but they now appears disabled. Do you wish to re-enable notifications?
        internal static let message = L10n.tr("Localizable", "permissions.notification.reenable.message")
        /// Re-enable Notifications?
        internal static let title = L10n.tr("Localizable", "permissions.notification.reenable.title")

        internal enum Button {
          /// Re-enable
          internal static let allow = L10n.tr("Localizable", "permissions.notification.reenable.button.allow")
          /// Leave disabled
          internal static let deny = L10n.tr("Localizable", "permissions.notification.reenable.button.deny")
        }
      }
    }
  }

  internal enum Settings {

    internal enum AdvancedConnectionSettingsSection {
      /// Advanced Connection Settings
      internal static let title = L10n.tr("Localizable", "settings.advanced_connection_settings_section.title")
    }

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
        /// Error parsing URL
        internal static let title = L10n.tr("Localizable", "settings.connection_error.invalid_url.title")
      }
    }

    internal enum ConnectionErrorNotification {
      /// There was an error connecting to Home Assistant. Please confirm the settings are correct and save to attempt to reconnect. The error was: %@
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
        /// Validate and Save Connection Settings
        internal static let title = L10n.tr("Localizable", "settings.connection_section.save_button.title")
      }

      internal enum ShowAdvancedSettingsRow {
        /// Show advanced settings
        internal static let title = L10n.tr("Localizable", "settings.connection_section.show_advanced_settings_row.title")
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
        /// 0.42.0
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
          /// %d m
          internal static func label(_ p1: Int) -> String {
            return L10n.tr("Localizable", "settings_details.location.zones.radius.label", p1)
          }
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

      internal enum Categories {
        /// Categories
        internal static let header = L10n.tr("Localizable", "settings_details.notifications.categories.header")
      }

      internal enum NewCategory {
        /// New Category
        internal static let title = L10n.tr("Localizable", "settings_details.notifications.new_category.title")
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

    internal enum Watch {
      /// Apple Watch
      internal static let title = L10n.tr("Localizable", "settings_details.watch.title")

      internal enum RemainingSends {
        /// Remaining sends
        internal static let title = L10n.tr("Localizable", "settings_details.watch.remaining_sends.title")
      }

      internal enum SendNow {
        /// Send now
        internal static let title = L10n.tr("Localizable", "settings_details.watch.send_now.title")
      }
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
        /// An error occurred while attempting to call service %@: %@
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

    internal enum Error {
      /// Error
      internal static let title = L10n.tr("Localizable", "url_handler.error.title")
    }

    internal enum FireEvent {

      internal enum Error {
        /// An error occurred while attempting to fire event %@: %@
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
        /// An unknown error occurred while attempting to send location: %@
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

  internal enum Watch {

    internal enum Configurator {

      internal enum Rows {

        internal enum Color {
          /// Color
          internal static let title = L10n.tr("Localizable", "watch.configurator.rows.color.title")
        }

        internal enum FractionalValue {
          /// Fractional value
          internal static let title = L10n.tr("Localizable", "watch.configurator.rows.fractional_value.title")
        }

        internal enum Gauge {
          /// Gauge
          internal static let title = L10n.tr("Localizable", "watch.configurator.rows.gauge.title")

          internal enum Color {
            /// Color
            internal static let title = L10n.tr("Localizable", "watch.configurator.rows.gauge.color.title")
          }

          internal enum GaugeType {
            /// Type
            internal static let title = L10n.tr("Localizable", "watch.configurator.rows.gauge.gauge_type.title")

            internal enum Options {
              /// Closed
              internal static let closed = L10n.tr("Localizable", "watch.configurator.rows.gauge.gauge_type.options.closed")
              /// Open
              internal static let `open` = L10n.tr("Localizable", "watch.configurator.rows.gauge.gauge_type.options.open")
            }
          }

          internal enum Style {
            /// Style
            internal static let title = L10n.tr("Localizable", "watch.configurator.rows.gauge.style.title")

            internal enum Options {
              /// Fill
              internal static let fill = L10n.tr("Localizable", "watch.configurator.rows.gauge.style.options.fill")
              /// Ring
              internal static let ring = L10n.tr("Localizable", "watch.configurator.rows.gauge.style.options.ring")
            }
          }
        }

        internal enum Icon {

          internal enum Choose {
            /// Choose an icon
            internal static let title = L10n.tr("Localizable", "watch.configurator.rows.icon.choose.title")
          }

          internal enum Color {
            /// Color
            internal static let title = L10n.tr("Localizable", "watch.configurator.rows.icon.color.title")
          }
        }

        internal enum PreviewOutput {
          /// Preview Output
          internal static let title = L10n.tr("Localizable", "watch.configurator.rows.preview_output.title")
        }

        internal enum Ring {
          /// Ring
          internal static let title = L10n.tr("Localizable", "watch.configurator.rows.ring.title")

          internal enum Color {
            /// Color
            internal static let title = L10n.tr("Localizable", "watch.configurator.rows.ring.color.title")
          }

          internal enum RingType {
            /// Type
            internal static let title = L10n.tr("Localizable", "watch.configurator.rows.ring.ring_type.title")

            internal enum Options {
              /// Closed
              internal static let closed = L10n.tr("Localizable", "watch.configurator.rows.ring.ring_type.options.closed")
              /// Open
              internal static let `open` = L10n.tr("Localizable", "watch.configurator.rows.ring.ring_type.options.open")
            }
          }

          internal enum Value {
            /// Fractional value
            internal static let title = L10n.tr("Localizable", "watch.configurator.rows.ring.value.title")
          }
        }

        internal enum Row2Alignment {
          /// Row 2 Alignment
          internal static let title = L10n.tr("Localizable", "watch.configurator.rows.row_2_alignment.title")

          internal enum Options {
            /// Leading
            internal static let leading = L10n.tr("Localizable", "watch.configurator.rows.row_2_alignment.options.leading")
            /// Trailing
            internal static let trailing = L10n.tr("Localizable", "watch.configurator.rows.row_2_alignment.options.trailing")
          }
        }

        internal enum Style {
          /// Style
          internal static let title = L10n.tr("Localizable", "watch.configurator.rows.style.title")
        }

        internal enum Template {
          /// Choose a template
          internal static let selectorTitle = L10n.tr("Localizable", "watch.configurator.rows.template.selector_title")
          /// Template
          internal static let title = L10n.tr("Localizable", "watch.configurator.rows.template.title")
        }
      }

      internal enum Sections {

        internal enum Gauge {
          /// The gague to display in the complication.
          internal static let footer = L10n.tr("Localizable", "watch.configurator.sections.gauge.footer")
          /// Gauge
          internal static let header = L10n.tr("Localizable", "watch.configurator.sections.gauge.header")
        }

        internal enum Icon {
          /// The image to display in the complication.
          internal static let footer = L10n.tr("Localizable", "watch.configurator.sections.icon.footer")
          /// Icon
          internal static let header = L10n.tr("Localizable", "watch.configurator.sections.icon.header")
        }

        internal enum Ring {
          /// The ring showing progress surrounding the text.
          internal static let footer = L10n.tr("Localizable", "watch.configurator.sections.ring.footer")
          /// Ring
          internal static let header = L10n.tr("Localizable", "watch.configurator.sections.ring.header")
        }
      }
    }

    internal enum Labels {

      internal enum ComplicationGroup {

        internal enum CircularSmall {
          /// Use circular small complications to display content in the corners of the Color watch face.
          internal static let description = L10n.tr("Localizable", "watch.labels.complication_group.circular_small.description")
          /// Circular Small
          internal static let name = L10n.tr("Localizable", "watch.labels.complication_group.circular_small.name")
        }

        internal enum ExtraLarge {
          /// Use the extra large complications to display content on the X-Large watch faces.
          internal static let description = L10n.tr("Localizable", "watch.labels.complication_group.extra_large.description")
          /// Extra Large
          internal static let name = L10n.tr("Localizable", "watch.labels.complication_group.extra_large.name")
        }

        internal enum Graphic {
          /// Use graphic complications to display visually rich content in the Infograph and Infograph Modular clock faces.
          internal static let description = L10n.tr("Localizable", "watch.labels.complication_group.graphic.description")
          /// Graphic
          internal static let name = L10n.tr("Localizable", "watch.labels.complication_group.graphic.name")
        }

        internal enum Modular {
          /// Use modular small complications to display content in the Modular watch face.
          internal static let description = L10n.tr("Localizable", "watch.labels.complication_group.modular.description")
          /// Modular
          internal static let name = L10n.tr("Localizable", "watch.labels.complication_group.modular.name")
        }

        internal enum Utilitarian {
          /// Use the utilitarian complications to display content in the Utility, Motion, Mickey Mouse, and Minnie Mouse watch faces.
          internal static let description = L10n.tr("Localizable", "watch.labels.complication_group.utilitarian.description")
          /// Utilitarian
          internal static let name = L10n.tr("Localizable", "watch.labels.complication_group.utilitarian.name")
        }
      }

      internal enum ComplicationGroupMember {

        internal enum CircularSmall {
          /// A small circular area used in the Color clock face.
          internal static let description = L10n.tr("Localizable", "watch.labels.complication_group_member.circular_small.description")
          /// Circular Small
          internal static let name = L10n.tr("Localizable", "watch.labels.complication_group_member.circular_small.name")
          /// Circular Small
          internal static let shortName = L10n.tr("Localizable", "watch.labels.complication_group_member.circular_small.short_name")
        }

        internal enum ExtraLarge {
          /// A large square area used in the X-Large clock face.
          internal static let description = L10n.tr("Localizable", "watch.labels.complication_group_member.extra_large.description")
          /// Extra Large
          internal static let name = L10n.tr("Localizable", "watch.labels.complication_group_member.extra_large.name")
          /// Extra Large
          internal static let shortName = L10n.tr("Localizable", "watch.labels.complication_group_member.extra_large.short_name")
        }

        internal enum GraphicBezel {
          /// A small square area used in the Modular clock face.
          internal static let description = L10n.tr("Localizable", "watch.labels.complication_group_member.graphic_bezel.description")
          /// Graphic Bezel
          internal static let name = L10n.tr("Localizable", "watch.labels.complication_group_member.graphic_bezel.name")
          /// Bezel
          internal static let shortName = L10n.tr("Localizable", "watch.labels.complication_group_member.graphic_bezel.short_name")
        }

        internal enum GraphicCircular {
          /// A large rectangular area used in the Modular clock face.
          internal static let description = L10n.tr("Localizable", "watch.labels.complication_group_member.graphic_circular.description")
          /// Graphic Circular
          internal static let name = L10n.tr("Localizable", "watch.labels.complication_group_member.graphic_circular.name")
          /// Circular
          internal static let shortName = L10n.tr("Localizable", "watch.labels.complication_group_member.graphic_circular.short_name")
        }

        internal enum GraphicCorner {
          /// A small square or rectangular area used in the Utility, Mickey, Chronograph, and Simple clock faces.
          internal static let description = L10n.tr("Localizable", "watch.labels.complication_group_member.graphic_corner.description")
          /// Graphic Corner
          internal static let name = L10n.tr("Localizable", "watch.labels.complication_group_member.graphic_corner.name")
          /// Corner
          internal static let shortName = L10n.tr("Localizable", "watch.labels.complication_group_member.graphic_corner.short_name")
        }

        internal enum GraphicRectangular {
          /// A small rectangular area used in the in the Photos, Motion, and Timelapse clock faces.
          internal static let description = L10n.tr("Localizable", "watch.labels.complication_group_member.graphic_rectangular.description")
          /// Graphic Rectangular
          internal static let name = L10n.tr("Localizable", "watch.labels.complication_group_member.graphic_rectangular.name")
          /// Rectangular
          internal static let shortName = L10n.tr("Localizable", "watch.labels.complication_group_member.graphic_rectangular.short_name")
        }

        internal enum ModularLarge {
          /// A large rectangular area that spans the width of the screen in the Utility and Mickey clock faces.
          internal static let description = L10n.tr("Localizable", "watch.labels.complication_group_member.modular_large.description")
          /// Modular Large
          internal static let name = L10n.tr("Localizable", "watch.labels.complication_group_member.modular_large.name")
          /// Large
          internal static let shortName = L10n.tr("Localizable", "watch.labels.complication_group_member.modular_large.short_name")
        }

        internal enum ModularSmall {
          /// A curved area that fills the corners in the Infograph clock face.
          internal static let description = L10n.tr("Localizable", "watch.labels.complication_group_member.modular_small.description")
          /// Modular Small
          internal static let name = L10n.tr("Localizable", "watch.labels.complication_group_member.modular_small.name")
          /// Small
          internal static let shortName = L10n.tr("Localizable", "watch.labels.complication_group_member.modular_small.short_name")
        }

        internal enum UtilitarianLarge {
          /// A circular area used in the Infograph and Infograph Modular clock faces.
          internal static let description = L10n.tr("Localizable", "watch.labels.complication_group_member.utilitarian_large.description")
          /// Utilitarian Large
          internal static let name = L10n.tr("Localizable", "watch.labels.complication_group_member.utilitarian_large.name")
          /// Large
          internal static let shortName = L10n.tr("Localizable", "watch.labels.complication_group_member.utilitarian_large.short_name")
        }

        internal enum UtilitarianSmall {
          /// A circular area with optional curved text placed along the bezel of the Infograph clock face.
          internal static let description = L10n.tr("Localizable", "watch.labels.complication_group_member.utilitarian_small.description")
          /// Utilitarian Small
          internal static let name = L10n.tr("Localizable", "watch.labels.complication_group_member.utilitarian_small.name")
          /// Small
          internal static let shortName = L10n.tr("Localizable", "watch.labels.complication_group_member.utilitarian_small.short_name")
        }

        internal enum UtilitarianSmallFlat {
          /// A large rectangular area used in the Infograph Modular clock face.
          internal static let description = L10n.tr("Localizable", "watch.labels.complication_group_member.utilitarian_small_flat.description")
          /// Utilitarian Small Flat
          internal static let name = L10n.tr("Localizable", "watch.labels.complication_group_member.utilitarian_small_flat.name")
          /// Small Flat
          internal static let shortName = L10n.tr("Localizable", "watch.labels.complication_group_member.utilitarian_small_flat.short_name")
        }
      }

      internal enum ComplicationTemplate {

        internal enum CircularSmallRingImage {
          /// A template for displaying a single image surrounded by a configurable progress ring.
          internal static let description = L10n.tr("Localizable", "watch.labels.complication_template.circular_small_ring_image.description")
        }

        internal enum CircularSmallRingText {
          /// A template for displaying a short text string encircled by a configurable progress ring.
          internal static let description = L10n.tr("Localizable", "watch.labels.complication_template.circular_small_ring_text.description")
        }

        internal enum CircularSmallSimpleImage {
          /// A template for displaying a single image.
          internal static let description = L10n.tr("Localizable", "watch.labels.complication_template.circular_small_simple_image.description")
        }

        internal enum CircularSmallSimpleText {
          /// A template for displaying a short text string.
          internal static let description = L10n.tr("Localizable", "watch.labels.complication_template.circular_small_simple_text.description")
        }

        internal enum CircularSmallStackImage {
          /// A template for displaying an image with a line of text below it.
          internal static let description = L10n.tr("Localizable", "watch.labels.complication_template.circular_small_stack_image.description")
        }

        internal enum CircularSmallStackText {
          /// A template for displaying two text strings stacked on top of each other.
          internal static let description = L10n.tr("Localizable", "watch.labels.complication_template.circular_small_stack_text.description")
        }

        internal enum ExtraLargeColumnsText {
          /// A template for displaying two rows and two columns of text.
          internal static let description = L10n.tr("Localizable", "watch.labels.complication_template.extra_large_columns_text.description")
        }

        internal enum ExtraLargeRingImage {
          /// A template for displaying an image encircled by a configurable progress ring.
          internal static let description = L10n.tr("Localizable", "watch.labels.complication_template.extra_large_ring_image.description")
        }

        internal enum ExtraLargeRingText {
          /// A template for displaying text encircled by a configurable progress ring.
          internal static let description = L10n.tr("Localizable", "watch.labels.complication_template.extra_large_ring_text.description")
        }

        internal enum ExtraLargeSimpleImage {
          /// A template for displaying an image.
          internal static let description = L10n.tr("Localizable", "watch.labels.complication_template.extra_large_simple_image.description")
        }

        internal enum ExtraLargeSimpleText {
          /// A template for displaying a small amount of text
          internal static let description = L10n.tr("Localizable", "watch.labels.complication_template.extra_large_simple_text.description")
        }

        internal enum ExtraLargeStackImage {
          /// A template for displaying a single image with a short line of text below it.
          internal static let description = L10n.tr("Localizable", "watch.labels.complication_template.extra_large_stack_image.description")
        }

        internal enum ExtraLargeStackText {
          /// A template for displaying two strings stacked one on top of the other.
          internal static let description = L10n.tr("Localizable", "watch.labels.complication_template.extra_large_stack_text.description")
        }

        internal enum GraphicBezelCircularText {
          /// A template for displaying a circular complication with text along the bezel.
          internal static let description = L10n.tr("Localizable", "watch.labels.complication_template.graphic_bezel_circular_text.description")
        }

        internal enum GraphicCircularClosedGaugeImage {
          /// A template for displaying a full-color circular image and a closed circular gauge.
          internal static let description = L10n.tr("Localizable", "watch.labels.complication_template.graphic_circular_closed_gauge_image.description")
        }

        internal enum GraphicCircularClosedGaugeText {
          /// A template for displaying text inside a closed circular gauge.
          internal static let description = L10n.tr("Localizable", "watch.labels.complication_template.graphic_circular_closed_gauge_text.description")
        }

        internal enum GraphicCircularImage {
          /// A template for displaying a full-color circular image.
          internal static let description = L10n.tr("Localizable", "watch.labels.complication_template.graphic_circular_image.description")
        }

        internal enum GraphicCircularOpenGaugeImage {
          /// A template for displaying a full-color circular image, an open gauge, and text.
          internal static let description = L10n.tr("Localizable", "watch.labels.complication_template.graphic_circular_open_gauge_image.description")
        }

        internal enum GraphicCircularOpenGaugeRangeText {
          /// A template for displaying text inside an open gauge, with leading and trailing text for the gauge.
          internal static let description = L10n.tr("Localizable", "watch.labels.complication_template.graphic_circular_open_gauge_range_text.description")
        }

        internal enum GraphicCircularOpenGaugeSimpleText {
          /// A template for displaying text inside an open gauge, with a single piece of text for the gauge.
          internal static let description = L10n.tr("Localizable", "watch.labels.complication_template.graphic_circular_open_gauge_simple_text.description")
        }

        internal enum GraphicCornerCircularImage {
          /// A template for displaying an image in the clock face’s corner.
          internal static let description = L10n.tr("Localizable", "watch.labels.complication_template.graphic_corner_circular_image.description")
        }

        internal enum GraphicCornerGaugeImage {
          /// A template for displaying an image and a gauge in the clock face’s corner.
          internal static let description = L10n.tr("Localizable", "watch.labels.complication_template.graphic_corner_gauge_image.description")
        }

        internal enum GraphicCornerGaugeText {
          /// A template for displaying text and a gauge in the clock face’s corner.
          internal static let description = L10n.tr("Localizable", "watch.labels.complication_template.graphic_corner_gauge_text.description")
        }

        internal enum GraphicCornerStackText {
          /// A template for displaying stacked text in the clock face’s corner.
          internal static let description = L10n.tr("Localizable", "watch.labels.complication_template.graphic_corner_stack_text.description")
        }

        internal enum GraphicCornerTextImage {
          /// A template for displaying an image and text in the clock face’s corner.
          internal static let description = L10n.tr("Localizable", "watch.labels.complication_template.graphic_corner_text_image.description")
        }

        internal enum GraphicRectangularLargeImage {
          /// A template for displaying a large rectangle containing header text and an image.
          internal static let description = L10n.tr("Localizable", "watch.labels.complication_template.graphic_rectangular_large_image.description")
        }

        internal enum GraphicRectangularStandardBody {
          /// A template for displaying a large rectangle containing text.
          internal static let description = L10n.tr("Localizable", "watch.labels.complication_template.graphic_rectangular_standard_body.description")
        }

        internal enum GraphicRectangularTextGauge {
          /// A template for displaying a large rectangle containing text and a gauge.
          internal static let description = L10n.tr("Localizable", "watch.labels.complication_template.graphic_rectangular_text_gauge.description")
        }

        internal enum ModularLargeColumns {
          /// A template for displaying multiple columns of data.
          internal static let description = L10n.tr("Localizable", "watch.labels.complication_template.modular_large_columns.description")
        }

        internal enum ModularLargeStandardBody {
          /// A template for displaying a header row and two lines of text
          internal static let description = L10n.tr("Localizable", "watch.labels.complication_template.modular_large_standard_body.description")
        }

        internal enum ModularLargeTable {
          /// A template for displaying a header row and columns
          internal static let description = L10n.tr("Localizable", "watch.labels.complication_template.modular_large_table.description")
        }

        internal enum ModularLargeTallBody {
          /// A template for displaying a header row and a tall row of body text.
          internal static let description = L10n.tr("Localizable", "watch.labels.complication_template.modular_large_tall_body.description")
        }

        internal enum ModularSmallColumnsText {
          /// A template for displaying two rows and two columns of text
          internal static let description = L10n.tr("Localizable", "watch.labels.complication_template.modular_small_columns_text.description")
        }

        internal enum ModularSmallRingImage {
          /// A template for displaying an image encircled by a configurable progress ring
          internal static let description = L10n.tr("Localizable", "watch.labels.complication_template.modular_small_ring_image.description")
        }

        internal enum ModularSmallRingText {
          /// A template for displaying text encircled by a configurable progress ring
          internal static let description = L10n.tr("Localizable", "watch.labels.complication_template.modular_small_ring_text.description")
        }

        internal enum ModularSmallSimpleImage {
          /// A template for displaying an image.
          internal static let description = L10n.tr("Localizable", "watch.labels.complication_template.modular_small_simple_image.description")
        }

        internal enum ModularSmallSimpleText {
          /// A template for displaying a small amount of text.
          internal static let description = L10n.tr("Localizable", "watch.labels.complication_template.modular_small_simple_text.description")
        }

        internal enum ModularSmallStackImage {
          /// A template for displaying a single image with a short line of text below it.
          internal static let description = L10n.tr("Localizable", "watch.labels.complication_template.modular_small_stack_image.description")
        }

        internal enum ModularSmallStackText {
          /// A template for displaying two strings stacked one on top of the other.
          internal static let description = L10n.tr("Localizable", "watch.labels.complication_template.modular_small_stack_text.description")
        }

        internal enum Style {
          /// Circular Image
          internal static let circularImage = L10n.tr("Localizable", "watch.labels.complication_template.style.circular_image")
          /// Circular Text
          internal static let circularText = L10n.tr("Localizable", "watch.labels.complication_template.style.circular_text")
          /// Closed Gauge Image
          internal static let closedGaugeImage = L10n.tr("Localizable", "watch.labels.complication_template.style.closed_gauge_image")
          /// Closed Gauge Text
          internal static let closedGaugeText = L10n.tr("Localizable", "watch.labels.complication_template.style.closed_gauge_text")
          /// Columns
          internal static let columns = L10n.tr("Localizable", "watch.labels.complication_template.style.columns")
          /// Columns Text
          internal static let columnsText = L10n.tr("Localizable", "watch.labels.complication_template.style.columns_text")
          /// Flat
          internal static let flat = L10n.tr("Localizable", "watch.labels.complication_template.style.flat")
          /// Gauge Image
          internal static let gaugeImage = L10n.tr("Localizable", "watch.labels.complication_template.style.gauge_image")
          /// Gauge Text
          internal static let gaugeText = L10n.tr("Localizable", "watch.labels.complication_template.style.gauge_text")
          /// Large Image
          internal static let largeImage = L10n.tr("Localizable", "watch.labels.complication_template.style.large_image")
          /// Open Gauge Image
          internal static let openGaugeImage = L10n.tr("Localizable", "watch.labels.complication_template.style.open_gauge_image")
          /// Open Gauge Range Text
          internal static let openGaugeRangeText = L10n.tr("Localizable", "watch.labels.complication_template.style.open_gauge_range_text")
          /// Open Gauge Simple Text
          internal static let openGaugeSimpleText = L10n.tr("Localizable", "watch.labels.complication_template.style.open_gauge_simple_text")
          /// Ring Image
          internal static let ringImage = L10n.tr("Localizable", "watch.labels.complication_template.style.ring_image")
          /// Ring Text
          internal static let ringText = L10n.tr("Localizable", "watch.labels.complication_template.style.ring_text")
          /// Simple Image
          internal static let simpleImage = L10n.tr("Localizable", "watch.labels.complication_template.style.simple_image")
          /// Simple Text
          internal static let simpleText = L10n.tr("Localizable", "watch.labels.complication_template.style.simple_text")
          /// Square
          internal static let square = L10n.tr("Localizable", "watch.labels.complication_template.style.square")
          /// Stack Image
          internal static let stackImage = L10n.tr("Localizable", "watch.labels.complication_template.style.stack_image")
          /// Stack Text
          internal static let stackText = L10n.tr("Localizable", "watch.labels.complication_template.style.stack_text")
          /// Standard Body
          internal static let standardBody = L10n.tr("Localizable", "watch.labels.complication_template.style.standard_body")
          /// Table
          internal static let table = L10n.tr("Localizable", "watch.labels.complication_template.style.table")
          /// Tall Body
          internal static let tallBody = L10n.tr("Localizable", "watch.labels.complication_template.style.tall_body")
          /// Text Gauge
          internal static let textGauge = L10n.tr("Localizable", "watch.labels.complication_template.style.text_gauge")
          /// Text Image
          internal static let textImage = L10n.tr("Localizable", "watch.labels.complication_template.style.text_image")
        }

        internal enum UtilitarianLargeFlat {
          /// A template for displaying an image and string in a single long line.
          internal static let description = L10n.tr("Localizable", "watch.labels.complication_template.utilitarian_large_flat.description")
        }

        internal enum UtilitarianSmallFlat {
          /// A template for displaying an image and text in a single line.
          internal static let description = L10n.tr("Localizable", "watch.labels.complication_template.utilitarian_small_flat.description")
        }

        internal enum UtilitarianSmallRingImage {
          /// A template for displaying an image encircled by a configurable progress ring
          internal static let description = L10n.tr("Localizable", "watch.labels.complication_template.utilitarian_small_ring_image.description")
        }

        internal enum UtilitarianSmallRingText {
          /// A template for displaying text encircled by a configurable progress ring.
          internal static let description = L10n.tr("Localizable", "watch.labels.complication_template.utilitarian_small_ring_text.description")
        }

        internal enum UtilitarianSmallSquare {
          /// A template for displaying a single square image.
          internal static let description = L10n.tr("Localizable", "watch.labels.complication_template.utilitarian_small_square.description")
        }
      }

      internal enum ComplicationTextAreas {

        internal enum Body1 {
          /// The main body text to display in the complication.
          internal static let description = L10n.tr("Localizable", "watch.labels.complication_text_areas.body1.description")
          /// Body 1
          internal static let label = L10n.tr("Localizable", "watch.labels.complication_text_areas.body1.label")
        }

        internal enum Body2 {
          /// The secondary body text to display in the complication.
          internal static let description = L10n.tr("Localizable", "watch.labels.complication_text_areas.body2.description")
          /// Body 2
          internal static let label = L10n.tr("Localizable", "watch.labels.complication_text_areas.body2.label")
        }

        internal enum Bottom {
          /// The text to display at the bottom of the gauge.
          internal static let description = L10n.tr("Localizable", "watch.labels.complication_text_areas.bottom.description")
          /// Bottom
          internal static let label = L10n.tr("Localizable", "watch.labels.complication_text_areas.bottom.label")
        }

        internal enum Center {
          /// The text to display in the complication.
          internal static let description = L10n.tr("Localizable", "watch.labels.complication_text_areas.center.description")
          /// Center
          internal static let label = L10n.tr("Localizable", "watch.labels.complication_text_areas.center.label")
        }

        internal enum Header {
          /// The header text to display in the complication.
          internal static let description = L10n.tr("Localizable", "watch.labels.complication_text_areas.header.description")
          /// Header
          internal static let label = L10n.tr("Localizable", "watch.labels.complication_text_areas.header.label")
        }

        internal enum Inner {
          /// The inner text to display in the complication.
          internal static let description = L10n.tr("Localizable", "watch.labels.complication_text_areas.inner.description")
          /// Inner
          internal static let label = L10n.tr("Localizable", "watch.labels.complication_text_areas.inner.label")
        }

        internal enum InsideRing {
          /// The text to display in the ring of the complication.
          internal static let description = L10n.tr("Localizable", "watch.labels.complication_text_areas.inside_ring.description")
          /// Inside Ring
          internal static let label = L10n.tr("Localizable", "watch.labels.complication_text_areas.inside_ring.label")
        }

        internal enum Leading {
          /// The text to display on the leading edge of the gague.
          internal static let description = L10n.tr("Localizable", "watch.labels.complication_text_areas.leading.description")
          /// Leading
          internal static let label = L10n.tr("Localizable", "watch.labels.complication_text_areas.leading.label")
        }

        internal enum Line1 {
          /// The text to display on the top line of the complication.
          internal static let description = L10n.tr("Localizable", "watch.labels.complication_text_areas.line1.description")
          /// Line 1
          internal static let label = L10n.tr("Localizable", "watch.labels.complication_text_areas.line1.label")
        }

        internal enum Line2 {
          /// The text to display on the bottom line of the complication.
          internal static let description = L10n.tr("Localizable", "watch.labels.complication_text_areas.line2.description")
          /// Line 2
          internal static let label = L10n.tr("Localizable", "watch.labels.complication_text_areas.line2.label")
        }

        internal enum Outer {
          /// The outer text to display in the complication.
          internal static let description = L10n.tr("Localizable", "watch.labels.complication_text_areas.outer.description")
          /// Outer
          internal static let label = L10n.tr("Localizable", "watch.labels.complication_text_areas.outer.label")
        }

        internal enum Row1Column1 {
          /// The text to display in the first column of the first row.
          internal static let description = L10n.tr("Localizable", "watch.labels.complication_text_areas.row1_column1.description")
          /// Row 1, Column 1
          internal static let label = L10n.tr("Localizable", "watch.labels.complication_text_areas.row1_column1.label")
        }

        internal enum Row1Column2 {
          /// The text to display in the second column of the first row.
          internal static let description = L10n.tr("Localizable", "watch.labels.complication_text_areas.row1_column2.description")
          /// Row 1, Column 2
          internal static let label = L10n.tr("Localizable", "watch.labels.complication_text_areas.row1_column2.label")
        }

        internal enum Row2Column1 {
          /// The text to display in the first column of the second row.
          internal static let description = L10n.tr("Localizable", "watch.labels.complication_text_areas.row2_column1.description")
          /// Row 2, Column 1
          internal static let label = L10n.tr("Localizable", "watch.labels.complication_text_areas.row2_column1.label")
        }

        internal enum Row2Column2 {
          /// The text to display in the second column of the second row.
          internal static let description = L10n.tr("Localizable", "watch.labels.complication_text_areas.row2_column2.description")
          /// Row 2, Column 2
          internal static let label = L10n.tr("Localizable", "watch.labels.complication_text_areas.row2_column2.label")
        }

        internal enum Row3Column1 {
          /// The text to display in the first column of the third row.
          internal static let description = L10n.tr("Localizable", "watch.labels.complication_text_areas.row3_column1.description")
          /// Row 3, Column 1
          internal static let label = L10n.tr("Localizable", "watch.labels.complication_text_areas.row3_column1.label")
        }

        internal enum Row3Column2 {
          /// The text to display in the second column of the third row.
          internal static let description = L10n.tr("Localizable", "watch.labels.complication_text_areas.row3_column2.description")
          /// Row 3, Column 2
          internal static let label = L10n.tr("Localizable", "watch.labels.complication_text_areas.row3_column2.label")
        }

        internal enum Trailing {
          /// The text to display on the trailing edge of the gauge.
          internal static let description = L10n.tr("Localizable", "watch.labels.complication_text_areas.trailing.description")
          /// Trailing
          internal static let label = L10n.tr("Localizable", "watch.labels.complication_text_areas.trailing.label")
        }
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
