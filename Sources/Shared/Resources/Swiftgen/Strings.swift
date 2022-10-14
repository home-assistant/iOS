// swiftlint:disable all
// Generated using SwiftGen — https://github.com/SwiftGen/SwiftGen

import Foundation

// swiftlint:disable superfluous_disable_command file_length implicit_return

// MARK: - Strings

// swiftlint:disable explicit_type_interface function_parameter_count identifier_name line_length
// swiftlint:disable nesting type_body_length type_name vertical_whitespace_opening_braces
public enum L10n {
  /// Add
  public static var addButtonLabel: String { return L10n.tr("Localizable", "addButtonLabel") }
  /// Always Open
  public static var alwaysOpenLabel: String { return L10n.tr("Localizable", "always_open_label") }
  /// Cancel
  public static var cancelLabel: String { return L10n.tr("Localizable", "cancel_label") }
  /// Continue
  public static var continueLabel: String { return L10n.tr("Localizable", "continue_label") }
  /// Copy
  public static var copyLabel: String { return L10n.tr("Localizable", "copy_label") }
  /// Debug
  public static var debugSectionLabel: String { return L10n.tr("Localizable", "debug_section_label") }
  /// Delete
  public static var delete: String { return L10n.tr("Localizable", "delete") }
  /// Done
  public static var doneLabel: String { return L10n.tr("Localizable", "done_label") }
  /// Error
  public static var errorLabel: String { return L10n.tr("Localizable", "error_label") }
  /// Help
  public static var helpLabel: String { return L10n.tr("Localizable", "help_label") }
  /// No
  public static var noLabel: String { return L10n.tr("Localizable", "no_label") }
  /// Off
  public static var offLabel: String { return L10n.tr("Localizable", "off_label") }
  /// OK
  public static var okLabel: String { return L10n.tr("Localizable", "ok_label") }
  /// On
  public static var onLabel: String { return L10n.tr("Localizable", "on_label") }
  /// Open
  public static var openLabel: String { return L10n.tr("Localizable", "open_label") }
  /// Preview Output
  public static var previewOutput: String { return L10n.tr("Localizable", "preview_output") }
  /// Requires %@ or later.
  public static func requiresVersion(_ p1: Any) -> String {
    return L10n.tr("Localizable", "requires_version", String(describing: p1))
  }
  /// Retry
  public static var retryLabel: String { return L10n.tr("Localizable", "retry_label") }
  /// Success
  public static var successLabel: String { return L10n.tr("Localizable", "success_label") }
  /// Username
  public static var usernameLabel: String { return L10n.tr("Localizable", "username_label") }
  /// Yes
  public static var yesLabel: String { return L10n.tr("Localizable", "yes_label") }

  public enum About {
    /// About
    public static var title: String { return L10n.tr("Localizable", "about.title") }
    public enum Acknowledgements {
      /// Acknowledgements
      public static var title: String { return L10n.tr("Localizable", "about.acknowledgements.title") }
    }
    public enum Beta {
      /// Join Beta
      public static var title: String { return L10n.tr("Localizable", "about.beta.title") }
    }
    public enum Chat {
      /// Chat
      public static var title: String { return L10n.tr("Localizable", "about.chat.title") }
    }
    public enum Documentation {
      /// Documentation
      public static var title: String { return L10n.tr("Localizable", "about.documentation.title") }
    }
    public enum EasterEgg {
      /// i love you
      public static var message: String { return L10n.tr("Localizable", "about.easter_egg.message") }
      /// You found me!
      public static var title: String { return L10n.tr("Localizable", "about.easter_egg.title") }
    }
    public enum Forums {
      /// Forums
      public static var title: String { return L10n.tr("Localizable", "about.forums.title") }
    }
    public enum Github {
      /// GitHub
      public static var title: String { return L10n.tr("Localizable", "about.github.title") }
    }
    public enum GithubIssueTracker {
      /// GitHub Issue Tracker
      public static var title: String { return L10n.tr("Localizable", "about.github_issue_tracker.title") }
    }
    public enum HelpLocalize {
      /// Help localize the app!
      public static var title: String { return L10n.tr("Localizable", "about.help_localize.title") }
    }
    public enum HomeAssistantOnFacebook {
      /// Home Assistant on Facebook
      public static var title: String { return L10n.tr("Localizable", "about.home_assistant_on_facebook.title") }
    }
    public enum HomeAssistantOnTwitter {
      /// Home Assistant on Twitter
      public static var title: String { return L10n.tr("Localizable", "about.home_assistant_on_twitter.title") }
    }
    public enum Logo {
      /// Home Assistant Companion
      public static var appTitle: String { return L10n.tr("Localizable", "about.logo.app_title") }
      /// Awaken Your Home
      public static var tagline: String { return L10n.tr("Localizable", "about.logo.tagline") }
    }
    public enum Review {
      /// Leave a review
      public static var title: String { return L10n.tr("Localizable", "about.review.title") }
    }
    public enum Website {
      /// Website
      public static var title: String { return L10n.tr("Localizable", "about.website.title") }
    }
  }

  public enum ActionsConfigurator {
    /// New Action
    public static var title: String { return L10n.tr("Localizable", "actions_configurator.title") }
    public enum Rows {
      public enum BackgroundColor {
        /// Background Color
        public static var title: String { return L10n.tr("Localizable", "actions_configurator.rows.background_color.title") }
      }
      public enum Icon {
        /// Icon
        public static var title: String { return L10n.tr("Localizable", "actions_configurator.rows.icon.title") }
      }
      public enum IconColor {
        /// Icon Color
        public static var title: String { return L10n.tr("Localizable", "actions_configurator.rows.icon_color.title") }
      }
      public enum Name {
        /// Name
        public static var title: String { return L10n.tr("Localizable", "actions_configurator.rows.name.title") }
      }
      public enum Text {
        /// Text
        public static var title: String { return L10n.tr("Localizable", "actions_configurator.rows.text.title") }
      }
      public enum TextColor {
        /// Text Color
        public static var title: String { return L10n.tr("Localizable", "actions_configurator.rows.text_color.title") }
      }
    }
    public enum TriggerExample {
      /// Share Contents
      public static var share: String { return L10n.tr("Localizable", "actions_configurator.trigger_example.share") }
      /// Example Trigger
      public static var title: String { return L10n.tr("Localizable", "actions_configurator.trigger_example.title") }
    }
    public enum VisualSection {
      /// The appearance of this action is controlled by the scene configuration.
      public static var sceneDefined: String { return L10n.tr("Localizable", "actions_configurator.visual_section.scene_defined") }
      /// You can also change these by customizing the Scene attributes: %@
      public static func sceneHintFooter(_ p1: Any) -> String {
        return L10n.tr("Localizable", "actions_configurator.visual_section.scene_hint_footer", String(describing: p1))
      }
      /// The appearance of this action is controlled by the server configuration.
      public static var serverDefined: String { return L10n.tr("Localizable", "actions_configurator.visual_section.server_defined") }
    }
  }

  public enum Alerts {
    public enum Alert {
      /// OK
      public static var ok: String { return L10n.tr("Localizable", "alerts.alert.ok") }
    }
    public enum AuthRequired {
      /// The server has rejected your credentials, and you must sign in again to continue.
      public static var message: String { return L10n.tr("Localizable", "alerts.auth_required.message") }
      /// You must sign in to continue
      public static var title: String { return L10n.tr("Localizable", "alerts.auth_required.title") }
    }
    public enum Confirm {
      /// Cancel
      public static var cancel: String { return L10n.tr("Localizable", "alerts.confirm.cancel") }
      /// OK
      public static var ok: String { return L10n.tr("Localizable", "alerts.confirm.ok") }
    }
    public enum Deprecations {
      public enum NotificationCategory {
        /// You must migrate to actions defined in the notification itself before %1$@.
        public static func message(_ p1: Any) -> String {
          return L10n.tr("Localizable", "alerts.deprecations.notification_category.message", String(describing: p1))
        }
        /// Notification Categories are deprecated
        public static var title: String { return L10n.tr("Localizable", "alerts.deprecations.notification_category.title") }
      }
    }
    public enum OpenUrlFromDeepLink {
      /// Open URL (%@) from deep link?
      public static func message(_ p1: Any) -> String {
        return L10n.tr("Localizable", "alerts.open_url_from_deep_link.message", String(describing: p1))
      }
    }
    public enum OpenUrlFromNotification {
      /// Open URL (%@) found in notification?
      public static func message(_ p1: Any) -> String {
        return L10n.tr("Localizable", "alerts.open_url_from_notification.message", String(describing: p1))
      }
      /// Open URL?
      public static var title: String { return L10n.tr("Localizable", "alerts.open_url_from_notification.title") }
    }
    public enum Prompt {
      /// Cancel
      public static var cancel: String { return L10n.tr("Localizable", "alerts.prompt.cancel") }
      /// OK
      public static var ok: String { return L10n.tr("Localizable", "alerts.prompt.ok") }
    }
  }

  public enum ClError {
    public enum Description {
      /// Deferred mode is not supported for the requested accuracy.
      public static var deferredAccuracyTooLow: String { return L10n.tr("Localizable", "cl_error.description.deferred_accuracy_too_low") }
      /// The request for deferred updates was canceled by your app or by the location manager.
      public static var deferredCanceled: String { return L10n.tr("Localizable", "cl_error.description.deferred_canceled") }
      /// Deferred mode does not support distance filters.
      public static var deferredDistanceFiltered: String { return L10n.tr("Localizable", "cl_error.description.deferred_distance_filtered") }
      /// The location manager did not enter deferred mode for an unknown reason.
      public static var deferredFailed: String { return L10n.tr("Localizable", "cl_error.description.deferred_failed") }
      /// The manager did not enter deferred mode since updates were already disabled/paused.
      public static var deferredNotUpdatingLocation: String { return L10n.tr("Localizable", "cl_error.description.deferred_not_updating_location") }
      /// Access to the location service was denied by the user.
      public static var denied: String { return L10n.tr("Localizable", "cl_error.description.denied") }
      /// The geocode request was canceled.
      public static var geocodeCanceled: String { return L10n.tr("Localizable", "cl_error.description.geocode_canceled") }
      /// The geocode request yielded no result.
      public static var geocodeFoundNoResult: String { return L10n.tr("Localizable", "cl_error.description.geocode_found_no_result") }
      /// The geocode request yielded a partial result.
      public static var geocodeFoundPartialResult: String { return L10n.tr("Localizable", "cl_error.description.geocode_found_partial_result") }
      /// The heading could not be determined.
      public static var headingFailure: String { return L10n.tr("Localizable", "cl_error.description.heading_failure") }
      /// The location manager was unable to obtain a location value right now.
      public static var locationUnknown: String { return L10n.tr("Localizable", "cl_error.description.location_unknown") }
      /// The network was unavailable or a network error occurred.
      public static var network: String { return L10n.tr("Localizable", "cl_error.description.network") }
      /// A general ranging error occurred.
      public static var rangingFailure: String { return L10n.tr("Localizable", "cl_error.description.ranging_failure") }
      /// Ranging is disabled.
      public static var rangingUnavailable: String { return L10n.tr("Localizable", "cl_error.description.ranging_unavailable") }
      /// Access to the region monitoring service was denied by the user.
      public static var regionMonitoringDenied: String { return L10n.tr("Localizable", "cl_error.description.region_monitoring_denied") }
      /// A registered region cannot be monitored.
      public static var regionMonitoringFailure: String { return L10n.tr("Localizable", "cl_error.description.region_monitoring_failure") }
      /// Core Location will deliver events but they may be delayed.
      public static var regionMonitoringResponseDelayed: String { return L10n.tr("Localizable", "cl_error.description.region_monitoring_response_delayed") }
      /// Core Location could not initialize the region monitoring feature immediately.
      public static var regionMonitoringSetupDelayed: String { return L10n.tr("Localizable", "cl_error.description.region_monitoring_setup_delayed") }
      /// Unknown Core Location error
      public static var unknown: String { return L10n.tr("Localizable", "cl_error.description.unknown") }
    }
  }

  public enum ClientEvents {
    public enum EventType {
      /// Location Update
      public static var locationUpdate: String { return L10n.tr("Localizable", "client_events.event_type.location_update") }
      /// Network Request
      public static var networkRequest: String { return L10n.tr("Localizable", "client_events.event_type.networkRequest") }
      /// Notification
      public static var notification: String { return L10n.tr("Localizable", "client_events.event_type.notification") }
      /// Service Call
      public static var serviceCall: String { return L10n.tr("Localizable", "client_events.event_type.service_call") }
      /// Unknown
      public static var unknown: String { return L10n.tr("Localizable", "client_events.event_type.unknown") }
      public enum Notification {
        /// Received a Push Notification: %@
        public static func title(_ p1: Any) -> String {
          return L10n.tr("Localizable", "client_events.event_type.notification.title", String(describing: p1))
        }
      }
    }
    public enum View {
      /// Clear
      public static var clear: String { return L10n.tr("Localizable", "client_events.view.clear") }
      public enum ClearConfirm {
        /// This cannot be undone.
        public static var message: String { return L10n.tr("Localizable", "client_events.view.clear_confirm.message") }
        /// Are you sure you want to clear all events?
        public static var title: String { return L10n.tr("Localizable", "client_events.view.clear_confirm.title") }
      }
    }
  }

  public enum Database {
    public enum Problem {
      /// Delete Database & Quit App
      public static var delete: String { return L10n.tr("Localizable", "database.problem.delete") }
      /// Quit App
      public static var quit: String { return L10n.tr("Localizable", "database.problem.quit") }
      /// Database Error
      public static var title: String { return L10n.tr("Localizable", "database.problem.title") }
    }
  }

  public enum Extensions {
    public enum Map {
      public enum Location {
        /// New Location
        public static var new: String { return L10n.tr("Localizable", "extensions.map.location.new") }
        /// Original Location
        public static var original: String { return L10n.tr("Localizable", "extensions.map.location.original") }
      }
      public enum PayloadMissingHomeassistant {
        /// Payload didn't contain a homeassistant dictionary!
        public static var message: String { return L10n.tr("Localizable", "extensions.map.payload_missing_homeassistant.message") }
      }
      public enum ValueMissingOrUncastable {
        public enum Latitude {
          /// Latitude wasn't found or couldn't be casted to string!
          public static var message: String { return L10n.tr("Localizable", "extensions.map.value_missing_or_uncastable.latitude.message") }
        }
        public enum Longitude {
          /// Longitude wasn't found or couldn't be casted to string!
          public static var message: String { return L10n.tr("Localizable", "extensions.map.value_missing_or_uncastable.longitude.message") }
        }
      }
    }
    public enum NotificationContent {
      public enum Error {
        /// No entity_id found in payload!
        public static var noEntityId: String { return L10n.tr("Localizable", "extensions.notification_content.error.no_entity_id") }
        public enum Request {
          /// Authentication failed!
          public static var authFailed: String { return L10n.tr("Localizable", "extensions.notification_content.error.request.auth_failed") }
          /// Entity '%@' not found!
          public static func entityNotFound(_ p1: Any) -> String {
            return L10n.tr("Localizable", "extensions.notification_content.error.request.entity_not_found", String(describing: p1))
          }
          /// HLS stream unavailable
          public static var hlsUnavailable: String { return L10n.tr("Localizable", "extensions.notification_content.error.request.hls_unavailable") }
          /// Got non-200 status code (%li)
          public static func other(_ p1: Int) -> String {
            return L10n.tr("Localizable", "extensions.notification_content.error.request.other", p1)
          }
        }
      }
    }
  }

  public enum HaApi {
    public enum ApiError {
      /// Cant build API URL
      public static var cantBuildUrl: String { return L10n.tr("Localizable", "ha_api.api_error.cant_build_url") }
      /// Received invalid response from Home Assistant
      public static var invalidResponse: String { return L10n.tr("Localizable", "ha_api.api_error.invalid_response") }
      /// HA API Manager is unavailable
      public static var managerNotAvailable: String { return L10n.tr("Localizable", "ha_api.api_error.manager_not_available") }
      /// The mobile_app component is not loaded. Please add it to your configuration, restart Home Assistant, and try again.
      public static var mobileAppComponentNotLoaded: String { return L10n.tr("Localizable", "ha_api.api_error.mobile_app_component_not_loaded") }
      /// Your Home Assistant version (%@) is too old, you must upgrade to at least version %@ to use the app.
      public static func mustUpgradeHomeAssistant(_ p1: Any, _ p2: Any) -> String {
        return L10n.tr("Localizable", "ha_api.api_error.must_upgrade_home_assistant", String(describing: p1), String(describing: p2))
      }
      /// HA API not configured
      public static var notConfigured: String { return L10n.tr("Localizable", "ha_api.api_error.not_configured") }
      /// Unacceptable status code %1$li.
      public static func unacceptableStatusCode(_ p1: Int) -> String {
        return L10n.tr("Localizable", "ha_api.api_error.unacceptable_status_code", p1)
      }
      /// Received response with result of type %1$@ but expected type %2$@.
      public static func unexpectedType(_ p1: Any, _ p2: Any) -> String {
        return L10n.tr("Localizable", "ha_api.api_error.unexpected_type", String(describing: p1), String(describing: p2))
      }
      /// An unknown error occurred.
      public static var unknown: String { return L10n.tr("Localizable", "ha_api.api_error.unknown") }
      /// Operation could not be performed.
      public static var updateNotPossible: String { return L10n.tr("Localizable", "ha_api.api_error.update_not_possible") }
    }
  }

  public enum Intents {
    /// Select a server before picking this value.
    public static var serverRequiredForValue: String { return L10n.tr("Localizable", "intents.server_required_for_value") }
  }

  public enum LocationChangeNotification {
    /// Location change
    public static var title: String { return L10n.tr("Localizable", "location_change_notification.title") }
    public enum AppShortcut {
      /// Location updated via App Shortcut
      public static var body: String { return L10n.tr("Localizable", "location_change_notification.app_shortcut.body") }
    }
    public enum BackgroundFetch {
      /// Current location delivery triggered via background fetch
      public static var body: String { return L10n.tr("Localizable", "location_change_notification.background_fetch.body") }
    }
    public enum BeaconRegionEnter {
      /// %@ entered via iBeacon
      public static func body(_ p1: Any) -> String {
        return L10n.tr("Localizable", "location_change_notification.beacon_region_enter.body", String(describing: p1))
      }
    }
    public enum BeaconRegionExit {
      /// %@ exited via iBeacon
      public static func body(_ p1: Any) -> String {
        return L10n.tr("Localizable", "location_change_notification.beacon_region_exit.body", String(describing: p1))
      }
    }
    public enum Launch {
      /// Location updated via app launch
      public static var body: String { return L10n.tr("Localizable", "location_change_notification.launch.body") }
    }
    public enum Manual {
      /// Location update triggered by user
      public static var body: String { return L10n.tr("Localizable", "location_change_notification.manual.body") }
    }
    public enum Periodic {
      /// Location updated via periodic update
      public static var body: String { return L10n.tr("Localizable", "location_change_notification.periodic.body") }
    }
    public enum PushNotification {
      /// Location updated via push notification
      public static var body: String { return L10n.tr("Localizable", "location_change_notification.push_notification.body") }
    }
    public enum RegionEnter {
      /// %@ entered
      public static func body(_ p1: Any) -> String {
        return L10n.tr("Localizable", "location_change_notification.region_enter.body", String(describing: p1))
      }
    }
    public enum RegionExit {
      /// %@ exited
      public static func body(_ p1: Any) -> String {
        return L10n.tr("Localizable", "location_change_notification.region_exit.body", String(describing: p1))
      }
    }
    public enum Signaled {
      /// Location updated via update signal
      public static var body: String { return L10n.tr("Localizable", "location_change_notification.signaled.body") }
    }
    public enum SignificantLocationUpdate {
      /// Significant location change detected
      public static var body: String { return L10n.tr("Localizable", "location_change_notification.significant_location_update.body") }
    }
    public enum Siri {
      /// Location update triggered by Siri
      public static var body: String { return L10n.tr("Localizable", "location_change_notification.siri.body") }
    }
    public enum Unknown {
      /// Location updated via unknown method
      public static var body: String { return L10n.tr("Localizable", "location_change_notification.unknown.body") }
    }
    public enum UrlScheme {
      /// Location updated via URL Scheme
      public static var body: String { return L10n.tr("Localizable", "location_change_notification.url_scheme.body") }
    }
    public enum Visit {
      /// Location updated via Visit
      public static var body: String { return L10n.tr("Localizable", "location_change_notification.visit.body") }
    }
    public enum XCallbackUrl {
      /// Location updated via X-Callback-URL
      public static var body: String { return L10n.tr("Localizable", "location_change_notification.x_callback_url.body") }
    }
  }

  public enum Menu {
    public enum Actions {
      /// Configure…
      public static var configure: String { return L10n.tr("Localizable", "menu.actions.configure") }
      /// Actions
      public static var title: String { return L10n.tr("Localizable", "menu.actions.title") }
    }
    public enum Application {
      /// About %@
      public static func about(_ p1: Any) -> String {
        return L10n.tr("Localizable", "menu.application.about", String(describing: p1))
      }
      /// Preferences…
      public static var preferences: String { return L10n.tr("Localizable", "menu.application.preferences") }
    }
    public enum File {
      /// Update Sensors
      public static var updateSensors: String { return L10n.tr("Localizable", "menu.file.update_sensors") }
    }
    public enum Help {
      /// %@ Help
      public static func help(_ p1: Any) -> String {
        return L10n.tr("Localizable", "menu.help.help", String(describing: p1))
      }
    }
    public enum StatusItem {
      /// Quit
      public static var quit: String { return L10n.tr("Localizable", "menu.status_item.quit") }
      /// Toggle %1$@
      public static func toggle(_ p1: Any) -> String {
        return L10n.tr("Localizable", "menu.status_item.toggle", String(describing: p1))
      }
    }
    public enum View {
      /// Reload Page
      public static var reloadPage: String { return L10n.tr("Localizable", "menu.view.reload_page") }
    }
  }

  public enum Nfc {
    /// Tag Read
    public static var genericTagRead: String { return L10n.tr("Localizable", "nfc.generic_tag_read") }
    /// NFC is not available on this device
    public static var notAvailable: String { return L10n.tr("Localizable", "nfc.not_available") }
    /// NFC Tag Read
    public static var tagRead: String { return L10n.tr("Localizable", "nfc.tag_read") }
    public enum Detail {
      /// Copy to Pasteboard
      public static var copy: String { return L10n.tr("Localizable", "nfc.detail.copy") }
      /// Create a Duplicate
      public static var duplicate: String { return L10n.tr("Localizable", "nfc.detail.duplicate") }
      /// Example Trigger
      public static var exampleTrigger: String { return L10n.tr("Localizable", "nfc.detail.example_trigger") }
      /// Fire Event
      public static var fire: String { return L10n.tr("Localizable", "nfc.detail.fire") }
      /// Share Identifier
      public static var share: String { return L10n.tr("Localizable", "nfc.detail.share") }
      /// Tag Identifier
      public static var tagValue: String { return L10n.tr("Localizable", "nfc.detail.tag_value") }
      /// NFC Tag
      public static var title: String { return L10n.tr("Localizable", "nfc.detail.title") }
    }
    public enum List {
      /// NFC tags written by the app will show a notification when you bring your device near them. Activating the notification will launch the app and fire an event.
      /// 
      /// Tags will work on any device with Home Assistant installed which has hardware support to read them.
      public static var description: String { return L10n.tr("Localizable", "nfc.list.description") }
      /// Learn More
      public static var learnMore: String { return L10n.tr("Localizable", "nfc.list.learn_more") }
      /// Read Tag
      public static var readTag: String { return L10n.tr("Localizable", "nfc.list.read_tag") }
      /// NFC Tags
      public static var title: String { return L10n.tr("Localizable", "nfc.list.title") }
      /// Write Tag
      public static var writeTag: String { return L10n.tr("Localizable", "nfc.list.write_tag") }
    }
    public enum Read {
      /// Hold your %@ near an NFC tag
      public static func startMessage(_ p1: Any) -> String {
        return L10n.tr("Localizable", "nfc.read.start_message", String(describing: p1))
      }
      public enum Error {
        /// Failed to read tag
        public static var genericFailure: String { return L10n.tr("Localizable", "nfc.read.error.generic_failure") }
        /// NFC tag is not a Home Assistant tag
        public static var notHomeAssistant: String { return L10n.tr("Localizable", "nfc.read.error.not_home_assistant") }
        /// NFC tag is invalid
        public static var tagInvalid: String { return L10n.tr("Localizable", "nfc.read.error.tag_invalid") }
      }
    }
    public enum Write {
      /// Hold your %@ near a writable NFC tag
      public static func startMessage(_ p1: Any) -> String {
        return L10n.tr("Localizable", "nfc.write.start_message", String(describing: p1))
      }
      /// Tag Written!
      public static var successMessage: String { return L10n.tr("Localizable", "nfc.write.success_message") }
      public enum Error {
        /// NFC tag has insufficient capacity: needs %ld but only has %ld
        public static func capacity(_ p1: Int, _ p2: Int) -> String {
          return L10n.tr("Localizable", "nfc.write.error.capacity", p1, p2)
        }
        /// NFC tag is not NDEF format
        public static var invalidFormat: String { return L10n.tr("Localizable", "nfc.write.error.invalid_format") }
        /// NFC tag is read-only
        public static var notWritable: String { return L10n.tr("Localizable", "nfc.write.error.not_writable") }
      }
      public enum IdentifierChoice {
        /// Manual
        public static var manual: String { return L10n.tr("Localizable", "nfc.write.identifier_choice.manual") }
        /// The identifier helps differentiate various tags.
        public static var message: String { return L10n.tr("Localizable", "nfc.write.identifier_choice.message") }
        /// Random (Recommended)
        public static var random: String { return L10n.tr("Localizable", "nfc.write.identifier_choice.random") }
        /// What kind of tag identifier?
        public static var title: String { return L10n.tr("Localizable", "nfc.write.identifier_choice.title") }
      }
      public enum ManualInput {
        /// What identifier for the tag?
        public static var title: String { return L10n.tr("Localizable", "nfc.write.manual_input.title") }
      }
    }
  }

  public enum NotificationService {
    /// Failed to load attachment
    public static var failedToLoad: String { return L10n.tr("Localizable", "notification_service.failed_to_load") }
    /// Loading Actions…
    public static var loadingDynamicActions: String { return L10n.tr("Localizable", "notification_service.loading_dynamic_actions") }
    public enum Parser {
      public enum Camera {
        /// entity_id provided was invalid.
        public static var invalidEntity: String { return L10n.tr("Localizable", "notification_service.parser.camera.invalid_entity") }
      }
      public enum Url {
        /// The given URL was invalid.
        public static var invalidUrl: String { return L10n.tr("Localizable", "notification_service.parser.url.invalid_url") }
        /// No URL was provided.
        public static var noUrl: String { return L10n.tr("Localizable", "notification_service.parser.url.no_url") }
      }
    }
  }

  public enum NotificationsConfigurator {
    /// Identifier
    public static var identifier: String { return L10n.tr("Localizable", "notifications_configurator.identifier") }
    public enum Action {
      public enum Rows {
        public enum AuthenticationRequired {
          /// When the user selects an action with this option, the system prompts the user to unlock the device. After unlocking, Home Assistant will be notified of the selected action.
          public static var footer: String { return L10n.tr("Localizable", "notifications_configurator.action.rows.authentication_required.footer") }
          /// Authentication Required
          public static var title: String { return L10n.tr("Localizable", "notifications_configurator.action.rows.authentication_required.title") }
        }
        public enum Destructive {
          /// When enabled, the action button is displayed with special highlighting to indicate that it performs a destructive task.
          public static var footer: String { return L10n.tr("Localizable", "notifications_configurator.action.rows.destructive.footer") }
          /// Destructive
          public static var title: String { return L10n.tr("Localizable", "notifications_configurator.action.rows.destructive.title") }
        }
        public enum Foreground {
          /// Enabling this will cause the app to launch if it's in the background when tapping a notification
          public static var footer: String { return L10n.tr("Localizable", "notifications_configurator.action.rows.foreground.footer") }
          /// Launch app
          public static var title: String { return L10n.tr("Localizable", "notifications_configurator.action.rows.foreground.title") }
        }
        public enum TextInputButtonTitle {
          /// Button Title
          public static var title: String { return L10n.tr("Localizable", "notifications_configurator.action.rows.text_input_button_title.title") }
        }
        public enum TextInputPlaceholder {
          /// Placeholder
          public static var title: String { return L10n.tr("Localizable", "notifications_configurator.action.rows.text_input_placeholder.title") }
        }
        public enum Title {
          /// Title
          public static var title: String { return L10n.tr("Localizable", "notifications_configurator.action.rows.title.title") }
        }
      }
      public enum TextInput {
        /// Text Input
        public static var title: String { return L10n.tr("Localizable", "notifications_configurator.action.text_input.title") }
      }
    }
    public enum Category {
      public enum ExampleCall {
        /// Example Service Call
        public static var title: String { return L10n.tr("Localizable", "notifications_configurator.category.example_call.title") }
      }
      public enum NavigationBar {
        /// Category Configurator
        public static var title: String { return L10n.tr("Localizable", "notifications_configurator.category.navigation_bar.title") }
      }
      public enum PreviewNotification {
        /// This is a test notification for the %@ notification category
        public static func body(_ p1: Any) -> String {
          return L10n.tr("Localizable", "notifications_configurator.category.preview_notification.body", String(describing: p1))
        }
        /// Test notification
        public static var title: String { return L10n.tr("Localizable", "notifications_configurator.category.preview_notification.title") }
      }
      public enum Rows {
        public enum Actions {
          /// Categories can have a maximum of 10 actions.
          public static var footer: String { return L10n.tr("Localizable", "notifications_configurator.category.rows.actions.footer") }
          /// Actions
          public static var header: String { return L10n.tr("Localizable", "notifications_configurator.category.rows.actions.header") }
        }
        public enum CategorySummary {
          /// %%u notifications in %%@
          public static var `default`: String { return L10n.tr("Localizable", "notifications_configurator.category.rows.category_summary.default") }
          /// A format string for the summary description used when the system groups the category’s notifications. You can optionally use '%%u' to show the number of notifications in the group and '%%@' to show the summary argument provided in the push payload.
          public static var footer: String { return L10n.tr("Localizable", "notifications_configurator.category.rows.category_summary.footer") }
          /// Category Summary
          public static var header: String { return L10n.tr("Localizable", "notifications_configurator.category.rows.category_summary.header") }
        }
        public enum HiddenPreviewPlaceholder {
          /// %%u notifications
          public static var `default`: String { return L10n.tr("Localizable", "notifications_configurator.category.rows.hidden_preview_placeholder.default") }
          /// This text is only displayed if you have notification previews hidden. Use '%%u' for the number of messages with the same thread identifier.
          public static var footer: String { return L10n.tr("Localizable", "notifications_configurator.category.rows.hidden_preview_placeholder.footer") }
          /// Hidden Preview Placeholder
          public static var header: String { return L10n.tr("Localizable", "notifications_configurator.category.rows.hidden_preview_placeholder.header") }
        }
        public enum Name {
          /// Name
          public static var title: String { return L10n.tr("Localizable", "notifications_configurator.category.rows.name.title") }
        }
      }
    }
    public enum NewAction {
      /// New Action
      public static var title: String { return L10n.tr("Localizable", "notifications_configurator.new_action.title") }
    }
    public enum Settings {
      /// Identifier must contain only letters and underscores and be uppercase. It must be globally unique to the app.
      public static var footer: String { return L10n.tr("Localizable", "notifications_configurator.settings.footer") }
      /// Settings
      public static var header: String { return L10n.tr("Localizable", "notifications_configurator.settings.header") }
      public enum Footer {
        /// Identifier can not be changed after creation. You must delete and recreate the action to change the identifier.
        public static var idSet: String { return L10n.tr("Localizable", "notifications_configurator.settings.footer.id_set") }
      }
    }
  }

  public enum Onboarding {
    public enum Connect {
      /// Connecting to %@
      public static func title(_ p1: Any) -> String {
        return L10n.tr("Localizable", "onboarding.connect.title", String(describing: p1))
      }
      public enum MacSafariWarning {
        /// Try restarting Safari if the login form does not open.
        public static var message: String { return L10n.tr("Localizable", "onboarding.connect.mac_safari_warning.message") }
        /// Launching Safari
        public static var title: String { return L10n.tr("Localizable", "onboarding.connect.mac_safari_warning.title") }
      }
    }
    public enum ConnectionError {
      /// More Info
      public static var moreInfoButton: String { return L10n.tr("Localizable", "onboarding.connection_error.more_info_button") }
      /// Failed to Connect
      public static var title: String { return L10n.tr("Localizable", "onboarding.connection_error.title") }
    }
    public enum ConnectionTestResult {
      /// Error Code:
      public static var errorCode: String { return L10n.tr("Localizable", "onboarding.connection_test_result.error_code") }
      public enum AuthenticationUnsupported {
        /// Authentication type is unsupported%@.
        public static func description(_ p1: Any) -> String {
          return L10n.tr("Localizable", "onboarding.connection_test_result.authentication_unsupported.description", String(describing: p1))
        }
      }
      public enum BasicAuth {
        /// HTTP Basic Authentication is unsupported.
        public static var description: String { return L10n.tr("Localizable", "onboarding.connection_test_result.basic_auth.description") }
      }
      public enum CertificateError {
        /// Don't Trust
        public static var actionDontTrust: String { return L10n.tr("Localizable", "onboarding.connection_test_result.certificate_error.action_dont_trust") }
        /// Trust Certificate
        public static var actionTrust: String { return L10n.tr("Localizable", "onboarding.connection_test_result.certificate_error.action_trust") }
        /// Failed to connect securely
        public static var title: String { return L10n.tr("Localizable", "onboarding.connection_test_result.certificate_error.title") }
      }
      public enum ClientCertificate {
        /// Client Certificate Authentication is not supported.
        public static var description: String { return L10n.tr("Localizable", "onboarding.connection_test_result.client_certificate.description") }
      }
      public enum LocalNetworkPermission {
        /// "Local Network" privacy permission may have been denied. You can change this in the system Settings app.
        public static var description: String { return L10n.tr("Localizable", "onboarding.connection_test_result.local_network_permission.description") }
      }
    }
    public enum DeviceNameCheck {
      public enum Error {
        /// What device name should be used instead?
        public static var prompt: String { return L10n.tr("Localizable", "onboarding.device_name_check.error.prompt") }
        /// Rename
        public static var renameAction: String { return L10n.tr("Localizable", "onboarding.device_name_check.error.rename_action") }
        /// A device already exists with the name '%1$@'
        public static func title(_ p1: Any) -> String {
          return L10n.tr("Localizable", "onboarding.device_name_check.error.title", String(describing: p1))
        }
      }
    }
    public enum ManualSetup {
      /// Connect
      public static var connect: String { return L10n.tr("Localizable", "onboarding.manual_setup.connect") }
      /// The URL of your Home Assistant server. Make sure it includes the protocol and port.
      public static var description: String { return L10n.tr("Localizable", "onboarding.manual_setup.description") }
      /// Enter URL
      public static var title: String { return L10n.tr("Localizable", "onboarding.manual_setup.title") }
      public enum CouldntMakeUrl {
        /// The value '%@' was not a valid URL.
        public static func message(_ p1: Any) -> String {
          return L10n.tr("Localizable", "onboarding.manual_setup.couldnt_make_url.message", String(describing: p1))
        }
        /// Could not create a URL
        public static var title: String { return L10n.tr("Localizable", "onboarding.manual_setup.couldnt_make_url.title") }
      }
      public enum NoScheme {
        /// Should we try connecting using http:// or https://?
        public static var message: String { return L10n.tr("Localizable", "onboarding.manual_setup.no_scheme.message") }
        /// URL entered without scheme
        public static var title: String { return L10n.tr("Localizable", "onboarding.manual_setup.no_scheme.title") }
      }
    }
    public enum Permissions {
      /// Allow
      public static var allow: String { return L10n.tr("Localizable", "onboarding.permissions.allow") }
      /// Done
      public static var allowed: String { return L10n.tr("Localizable", "onboarding.permissions.allowed") }
      /// You can change this permission later in Settings
      public static var changeLaterNote: String { return L10n.tr("Localizable", "onboarding.permissions.change_later_note") }
      public enum Focus {
        /// Allow whether you are in focus mode to be sent to Home Assistant
        public static var description: String { return L10n.tr("Localizable", "onboarding.permissions.focus.description") }
        /// Allow focus permission to create sensors for your focus status, also known as do-not-disturb.
        public static var grantDescription: String { return L10n.tr("Localizable", "onboarding.permissions.focus.grant_description") }
        /// Focus
        public static var title: String { return L10n.tr("Localizable", "onboarding.permissions.focus.title") }
        public enum Bullet {
          /// Focus-based automations
          public static var automations: String { return L10n.tr("Localizable", "onboarding.permissions.focus.bullet.automations") }
          /// Instant updates when status changes
          public static var instant: String { return L10n.tr("Localizable", "onboarding.permissions.focus.bullet.instant") }
        }
      }
      public enum Location {
        /// Enable location services to allow presence detection automations.
        public static var description: String { return L10n.tr("Localizable", "onboarding.permissions.location.description") }
        /// Allow location permission to create a device_tracker for your device.
        public static var grantDescription: String { return L10n.tr("Localizable", "onboarding.permissions.location.grant_description") }
        /// Location
        public static var title: String { return L10n.tr("Localizable", "onboarding.permissions.location.title") }
        public enum Bullet {
          /// Presence-based automations
          public static var automations: String { return L10n.tr("Localizable", "onboarding.permissions.location.bullet.automations") }
          /// Track location history
          public static var history: String { return L10n.tr("Localizable", "onboarding.permissions.location.bullet.history") }
          /// Internal URL at home
          public static var wifi: String { return L10n.tr("Localizable", "onboarding.permissions.location.bullet.wifi") }
        }
      }
      public enum Motion {
        /// Allow motion activity and pedometer data to be sent to Home Assistant
        public static var description: String { return L10n.tr("Localizable", "onboarding.permissions.motion.description") }
        /// Allow motion permission to create sensors for motion and pedometer data.
        public static var grantDescription: String { return L10n.tr("Localizable", "onboarding.permissions.motion.grant_description") }
        /// Motion & Pedometer
        public static var title: String { return L10n.tr("Localizable", "onboarding.permissions.motion.title") }
        public enum Bullet {
          /// Sensor for current activity type
          public static var activity: String { return L10n.tr("Localizable", "onboarding.permissions.motion.bullet.activity") }
          /// Sensor for distance moved
          public static var distance: String { return L10n.tr("Localizable", "onboarding.permissions.motion.bullet.distance") }
          /// Sensor for step counts
          public static var steps: String { return L10n.tr("Localizable", "onboarding.permissions.motion.bullet.steps") }
        }
      }
      public enum Notification {
        /// Allow push notifications to be sent from your Home Assistant
        public static var description: String { return L10n.tr("Localizable", "onboarding.permissions.notification.description") }
        /// Allow notification permission to create a notify service for your device.
        public static var grantDescription: String { return L10n.tr("Localizable", "onboarding.permissions.notification.grant_description") }
        /// Notifications
        public static var title: String { return L10n.tr("Localizable", "onboarding.permissions.notification.title") }
        public enum Bullet {
          /// Get alerted from notifications
          public static var alert: String { return L10n.tr("Localizable", "onboarding.permissions.notification.bullet.alert") }
          /// Update app icon badge
          public static var badge: String { return L10n.tr("Localizable", "onboarding.permissions.notification.bullet.badge") }
          /// Send commands to your device
          public static var commands: String { return L10n.tr("Localizable", "onboarding.permissions.notification.bullet.commands") }
        }
      }
    }
    public enum Scanning {
      /// Discovered: %@
      public static func discoveredAnnouncement(_ p1: Any) -> String {
        return L10n.tr("Localizable", "onboarding.scanning.discovered_announcement", String(describing: p1))
      }
      /// Enter Address Manually
      public static var manual: String { return L10n.tr("Localizable", "onboarding.scanning.manual") }
      /// Not finding your server?
      public static var manualHint: String { return L10n.tr("Localizable", "onboarding.scanning.manual_hint") }
      /// Scanning for Servers
      public static var title: String { return L10n.tr("Localizable", "onboarding.scanning.title") }
    }
    public enum Welcome {
      /// This app connects to your Home Assistant server and allows integrating data about you and your phone.
      /// 
      /// Home Assistant is free and open source home automation software with a focus on local control and privacy.
      public static var description: String { return L10n.tr("Localizable", "onboarding.welcome.description") }
      /// Welcome to Home Assistant %@!
      public static func title(_ p1: Any) -> String {
        return L10n.tr("Localizable", "onboarding.welcome.title", String(describing: p1))
      }
    }
  }

  public enum Sensors {
    public enum Active {
      public enum Setting {
        /// Time Until Idle
        public static var timeUntilIdle: String { return L10n.tr("Localizable", "sensors.active.setting.time_until_idle") }
      }
    }
    public enum GeocodedLocation {
      public enum Setting {
        /// Use Zone Name
        public static var useZones: String { return L10n.tr("Localizable", "sensors.geocoded_location.setting.use_zones") }
      }
    }
  }

  public enum Settings {
    public enum ConnectionSection {
      /// Activate
      public static var activateServer: String { return L10n.tr("Localizable", "settings.connection_section.activate_server") }
      /// Quickly activate using a three-finger swipe left or right when viewing a server.
      public static var activateSwipeHint: String { return L10n.tr("Localizable", "settings.connection_section.activate_swipe_hint") }
      /// Add Server
      public static var addServer: String { return L10n.tr("Localizable", "settings.connection_section.add_server") }
      /// All Servers
      public static var allServers: String { return L10n.tr("Localizable", "settings.connection_section.all_servers") }
      /// When connecting via Cloud, the External URL will not be used. You do not need to configure one unless you want to disable Cloud.
      public static var cloudOverridesExternal: String { return L10n.tr("Localizable", "settings.connection_section.cloud_overrides_external") }
      /// Connected via
      public static var connectingVia: String { return L10n.tr("Localizable", "settings.connection_section.connecting_via") }
      /// Details
      public static var details: String { return L10n.tr("Localizable", "settings.connection_section.details") }
      /// Connection
      public static var header: String { return L10n.tr("Localizable", "settings.connection_section.header") }
      /// Directly connect to the Home Assistant server for push notifications when on internal SSIDs.
      public static var localPushDescription: String { return L10n.tr("Localizable", "settings.connection_section.local_push_description") }
      /// Logged in as
      public static var loggedInAs: String { return L10n.tr("Localizable", "settings.connection_section.logged_in_as") }
      /// Servers
      public static var servers: String { return L10n.tr("Localizable", "settings.connection_section.servers") }
      /// Accessing SSIDs in the background requires 'Always' location permission and 'Full' location accuracy. Tap here to change your settings.
      public static var ssidPermissionAndAccuracyMessage: String { return L10n.tr("Localizable", "settings.connection_section.ssid_permission_and_accuracy_message") }
      /// Accessing SSIDs in the background requires 'Always' location permission. Tap here to change your settings.
      public static var ssidPermissionMessage: String { return L10n.tr("Localizable", "settings.connection_section.ssid_permission_message") }
      public enum DeleteServer {
        /// Are you sure you wish to delete this server?
        public static var message: String { return L10n.tr("Localizable", "settings.connection_section.delete_server.message") }
        /// Deleting Server…
        public static var progress: String { return L10n.tr("Localizable", "settings.connection_section.delete_server.progress") }
        /// Delete Server
        public static var title: String { return L10n.tr("Localizable", "settings.connection_section.delete_server.title") }
      }
      public enum Errors {
        /// You cannot remove only available URL.
        public static var cannotRemoveLastUrl: String { return L10n.tr("Localizable", "settings.connection_section.errors.cannot_remove_last_url") }
      }
      public enum ExternalBaseUrl {
        /// https://homeassistant.myhouse.com
        public static var placeholder: String { return L10n.tr("Localizable", "settings.connection_section.external_base_url.placeholder") }
        /// External URL
        public static var title: String { return L10n.tr("Localizable", "settings.connection_section.external_base_url.title") }
      }
      public enum HomeAssistantCloud {
        /// Home Assistant Cloud
        public static var title: String { return L10n.tr("Localizable", "settings.connection_section.home_assistant_cloud.title") }
      }
      public enum InternalBaseUrl {
        /// e.g. http://homeassistant.local:8123/
        public static var placeholder: String { return L10n.tr("Localizable", "settings.connection_section.internal_base_url.placeholder") }
        /// Internal URL
        public static var title: String { return L10n.tr("Localizable", "settings.connection_section.internal_base_url.title") }
      }
      public enum InternalUrlHardwareAddresses {
        /// Add New Hardware Address
        public static var addNewSsid: String { return L10n.tr("Localizable", "settings.connection_section.internal_url_hardware_addresses.add_new_ssid") }
        /// Internal URL will be used when the primary network interface has a MAC address matching one of these hardware addresses.
        public static var footer: String { return L10n.tr("Localizable", "settings.connection_section.internal_url_hardware_addresses.footer") }
        /// Hardware Addresses
        public static var header: String { return L10n.tr("Localizable", "settings.connection_section.internal_url_hardware_addresses.header") }
        /// Hardware addresses must look like aa:bb:cc:dd:ee:ff
        public static var invalid: String { return L10n.tr("Localizable", "settings.connection_section.internal_url_hardware_addresses.invalid") }
      }
      public enum InternalUrlSsids {
        /// Add new SSID
        public static var addNewSsid: String { return L10n.tr("Localizable", "settings.connection_section.internal_url_ssids.add_new_ssid") }
        /// Internal URL will be used when connected to listed SSIDs
        public static var footer: String { return L10n.tr("Localizable", "settings.connection_section.internal_url_ssids.footer") }
        /// SSIDs
        public static var header: String { return L10n.tr("Localizable", "settings.connection_section.internal_url_ssids.header") }
        /// MyFunnyNetworkName
        public static var placeholder: String { return L10n.tr("Localizable", "settings.connection_section.internal_url_ssids.placeholder") }
      }
      public enum LocationSendType {
        /// Location Sent
        public static var title: String { return L10n.tr("Localizable", "settings.connection_section.location_send_type.title") }
        public enum Setting {
          /// Exact
          public static var exact: String { return L10n.tr("Localizable", "settings.connection_section.location_send_type.setting.exact") }
          /// Never
          public static var never: String { return L10n.tr("Localizable", "settings.connection_section.location_send_type.setting.never") }
          /// Zone Name Only
          public static var zoneOnly: String { return L10n.tr("Localizable", "settings.connection_section.location_send_type.setting.zone_only") }
        }
      }
      public enum RemoteUiUrl {
        /// Remote UI URL
        public static var title: String { return L10n.tr("Localizable", "settings.connection_section.remote_ui_url.title") }
      }
      public enum SensorSendType {
        /// Sensors Sent
        public static var title: String { return L10n.tr("Localizable", "settings.connection_section.sensor_send_type.title") }
        public enum Setting {
          /// All
          public static var all: String { return L10n.tr("Localizable", "settings.connection_section.sensor_send_type.setting.all") }
          /// None
          public static var `none`: String { return L10n.tr("Localizable", "settings.connection_section.sensor_send_type.setting.none") }
        }
      }
      public enum ValidateError {
        /// Edit URL
        public static var editUrl: String { return L10n.tr("Localizable", "settings.connection_section.validate_error.edit_url") }
        /// Error Saving URL
        public static var title: String { return L10n.tr("Localizable", "settings.connection_section.validate_error.title") }
        /// Use Anyway
        public static var useAnyway: String { return L10n.tr("Localizable", "settings.connection_section.validate_error.use_anyway") }
      }
      public enum Websocket {
        /// WebSocket
        public static var title: String { return L10n.tr("Localizable", "settings.connection_section.websocket.title") }
        public enum Status {
          /// Authenticating
          public static var authenticating: String { return L10n.tr("Localizable", "settings.connection_section.websocket.status.authenticating") }
          /// Connected
          public static var connected: String { return L10n.tr("Localizable", "settings.connection_section.websocket.status.connected") }
          /// Connecting
          public static var connecting: String { return L10n.tr("Localizable", "settings.connection_section.websocket.status.connecting") }
          public enum Disconnected {
            /// Error: %1$@
            public static func error(_ p1: Any) -> String {
              return L10n.tr("Localizable", "settings.connection_section.websocket.status.disconnected.error", String(describing: p1))
            }
            /// Next Retry: %1$@
            public static func nextRetry(_ p1: Any) -> String {
              return L10n.tr("Localizable", "settings.connection_section.websocket.status.disconnected.next_retry", String(describing: p1))
            }
            /// Retry Count: %1$li
            public static func retryCount(_ p1: Int) -> String {
              return L10n.tr("Localizable", "settings.connection_section.websocket.status.disconnected.retry_count", p1)
            }
            /// Disconnected
            public static var title: String { return L10n.tr("Localizable", "settings.connection_section.websocket.status.disconnected.title") }
          }
        }
      }
    }
    public enum Debugging {
      /// Debugging
      public static var title: String { return L10n.tr("Localizable", "settings.debugging.title") }
    }
    public enum DetailsSection {
      public enum LocationSettingsRow {
        /// Location
        public static var title: String { return L10n.tr("Localizable", "settings.details_section.location_settings_row.title") }
      }
      public enum NotificationSettingsRow {
        /// Notifications
        public static var title: String { return L10n.tr("Localizable", "settings.details_section.notification_settings_row.title") }
      }
      public enum WatchRow {
        /// Apple Watch
        public static var title: String { return L10n.tr("Localizable", "settings.details_section.watch_row.title") }
      }
    }
    public enum Developer {
      /// Don't use these if you don't know what you are doing!
      public static var footer: String { return L10n.tr("Localizable", "settings.developer.footer") }
      /// Developer
      public static var header: String { return L10n.tr("Localizable", "settings.developer.header") }
      public enum AnnoyingBackgroundNotifications {
        /// Annoying Background Info
        public static var title: String { return L10n.tr("Localizable", "settings.developer.annoying_background_notifications.title") }
      }
      public enum CameraNotification {
        /// Show camera notification content extension
        public static var title: String { return L10n.tr("Localizable", "settings.developer.camera_notification.title") }
        public enum Notification {
          /// Expand this to show the camera content extension
          public static var body: String { return L10n.tr("Localizable", "settings.developer.camera_notification.notification.body") }
        }
      }
      public enum CopyRealm {
        /// Copy Realm from app group to Documents
        public static var title: String { return L10n.tr("Localizable", "settings.developer.copy_realm.title") }
        public enum Alert {
          /// Copied Realm from %@ to %@
          public static func message(_ p1: Any, _ p2: Any) -> String {
            return L10n.tr("Localizable", "settings.developer.copy_realm.alert.message", String(describing: p1), String(describing: p2))
          }
          /// Copied Realm
          public static var title: String { return L10n.tr("Localizable", "settings.developer.copy_realm.alert.title") }
        }
      }
      public enum CrashlyticsTest {
        public enum Fatal {
          /// Test Crashlytics Fatal Error
          public static var title: String { return L10n.tr("Localizable", "settings.developer.crashlytics_test.fatal.title") }
          public enum Notification {
            /// NOTE: This will not work if the debugger is connected! When you press OK, the app will crash. You must then re-open the app and wait up to 5 minutes for the crash to appear in the console
            public static var body: String { return L10n.tr("Localizable", "settings.developer.crashlytics_test.fatal.notification.body") }
            /// About to crash
            public static var title: String { return L10n.tr("Localizable", "settings.developer.crashlytics_test.fatal.notification.title") }
          }
        }
        public enum NonFatal {
          /// Test Crashlytics Non-Fatal Error
          public static var title: String { return L10n.tr("Localizable", "settings.developer.crashlytics_test.non_fatal.title") }
          public enum Notification {
            /// When you press OK, a non-fatal error will be sent to Crashlytics. It may take up to 5 minutes to appear in the console.
            public static var body: String { return L10n.tr("Localizable", "settings.developer.crashlytics_test.non_fatal.notification.body") }
            /// About to submit a non-fatal error
            public static var title: String { return L10n.tr("Localizable", "settings.developer.crashlytics_test.non_fatal.notification.title") }
          }
        }
      }
      public enum DebugStrings {
        /// Debug strings
        public static var title: String { return L10n.tr("Localizable", "settings.developer.debug_strings.title") }
      }
      public enum ExportLogFiles {
        /// Export log files
        public static var title: String { return L10n.tr("Localizable", "settings.developer.export_log_files.title") }
      }
      public enum MapNotification {
        /// Show map notification content extension
        public static var title: String { return L10n.tr("Localizable", "settings.developer.map_notification.title") }
        public enum Notification {
          /// Expand this to show the map content extension
          public static var body: String { return L10n.tr("Localizable", "settings.developer.map_notification.notification.body") }
        }
      }
      public enum ShowLogFiles {
        /// Show log files in Finder
        public static var title: String { return L10n.tr("Localizable", "settings.developer.show_log_files.title") }
      }
      public enum SyncWatchContext {
        /// Sync Watch Context
        public static var title: String { return L10n.tr("Localizable", "settings.developer.sync_watch_context.title") }
      }
    }
    public enum EventLog {
      /// Event Log
      public static var title: String { return L10n.tr("Localizable", "settings.event_log.title") }
    }
    public enum LocationHistory {
      /// No Location History
      public static var empty: String { return L10n.tr("Localizable", "settings.location_history.empty") }
      /// Location History
      public static var title: String { return L10n.tr("Localizable", "settings.location_history.title") }
      public enum Detail {
        /// The purple circle is your location and its accuracy. Blue circles are your zones. You are inside a zone if the purple circle overlaps a blue circle. Orange circles are additional regions used for sub-100 m zones.
        public static var explanation: String { return L10n.tr("Localizable", "settings.location_history.detail.explanation") }
      }
    }
    public enum NavigationBar {
      /// Settings
      public static var title: String { return L10n.tr("Localizable", "settings.navigation_bar.title") }
      public enum AboutButton {
        /// About
        public static var title: String { return L10n.tr("Localizable", "settings.navigation_bar.about_button.title") }
      }
    }
    public enum ResetSection {
      public enum ResetAlert {
        /// Your settings will be reset and this device will be unregistered from push notifications as well as removed from your Home Assistant configuration.
        public static var message: String { return L10n.tr("Localizable", "settings.reset_section.reset_alert.message") }
        /// Resetting…
        public static var progressMessage: String { return L10n.tr("Localizable", "settings.reset_section.reset_alert.progress_message") }
        /// Reset
        public static var title: String { return L10n.tr("Localizable", "settings.reset_section.reset_alert.title") }
      }
      public enum ResetRow {
        /// Reset
        public static var title: String { return L10n.tr("Localizable", "settings.reset_section.reset_row.title") }
      }
      public enum ResetWebCache {
        /// Reset frontend cache
        public static var title: String { return L10n.tr("Localizable", "settings.reset_section.reset_web_cache.title") }
      }
    }
    public enum ServerSelect {
      /// Server
      public static var pageTitle: String { return L10n.tr("Localizable", "settings.server_select.page_title") }
      /// Server
      public static var title: String { return L10n.tr("Localizable", "settings.server_select.title") }
    }
    public enum StatusSection {
      /// Status
      public static var header: String { return L10n.tr("Localizable", "settings.status_section.header") }
      public enum LocationNameRow {
        /// My Home Assistant
        public static var placeholder: String { return L10n.tr("Localizable", "settings.status_section.location_name_row.placeholder") }
        /// Name
        public static var title: String { return L10n.tr("Localizable", "settings.status_section.location_name_row.title") }
      }
      public enum VersionRow {
        /// 0.92.0
        public static var placeholder: String { return L10n.tr("Localizable", "settings.status_section.version_row.placeholder") }
        /// Version
        public static var title: String { return L10n.tr("Localizable", "settings.status_section.version_row.title") }
      }
    }
    public enum TemplateEdit {
      /// Edit Template
      public static var title: String { return L10n.tr("Localizable", "settings.template_edit.title") }
    }
  }

  public enum SettingsDetails {
    public enum Actions {
      /// Actions are used in the Apple Watch app, App Icon Actions and the Today widget
      public static var footer: String { return L10n.tr("Localizable", "settings_details.actions.footer") }
      /// Actions are used in the application menu and widgets.
      public static var footerMac: String { return L10n.tr("Localizable", "settings_details.actions.footer_mac") }
      /// Actions
      public static var title: String { return L10n.tr("Localizable", "settings_details.actions.title") }
      public enum ActionsSynced {
        /// No Synced Actions
        public static var empty: String { return L10n.tr("Localizable", "settings_details.actions.actions_synced.empty") }
        /// Actions defined in .yaml are not editable on device.
        public static var footer: String { return L10n.tr("Localizable", "settings_details.actions.actions_synced.footer") }
        /// Actions may be also defined in the .yaml configuration.
        public static var footerNoActions: String { return L10n.tr("Localizable", "settings_details.actions.actions_synced.footer_no_actions") }
        /// Synced Actions
        public static var header: String { return L10n.tr("Localizable", "settings_details.actions.actions_synced.header") }
      }
      public enum Scenes {
        /// Customize
        public static var customizeAction: String { return L10n.tr("Localizable", "settings_details.actions.scenes.customize_action") }
        /// No Scenes
        public static var empty: String { return L10n.tr("Localizable", "settings_details.actions.scenes.empty") }
        /// When enabled, Scenes display alongside actions. When performed, they trigger scene changes.
        public static var footer: String { return L10n.tr("Localizable", "settings_details.actions.scenes.footer") }
        /// Scene Actions
        public static var title: String { return L10n.tr("Localizable", "settings_details.actions.scenes.title") }
      }
    }
    public enum General {
      /// General
      public static var title: String { return L10n.tr("Localizable", "settings_details.general.title") }
      public enum AppIcon {
        /// App Icon
        public static var title: String { return L10n.tr("Localizable", "settings_details.general.app_icon.title") }
        public enum Enum {
          /// Beta
          public static var beta: String { return L10n.tr("Localizable", "settings_details.general.app_icon.enum.beta") }
          /// Black
          public static var black: String { return L10n.tr("Localizable", "settings_details.general.app_icon.enum.black") }
          /// Blue
          public static var blue: String { return L10n.tr("Localizable", "settings_details.general.app_icon.enum.blue") }
          /// Caribbean Green
          public static var caribbeanGreen: String { return L10n.tr("Localizable", "settings_details.general.app_icon.enum.caribbean_green") }
          /// Cornflower Blue
          public static var cornflowerBlue: String { return L10n.tr("Localizable", "settings_details.general.app_icon.enum.cornflower_blue") }
          /// Crimson
          public static var crimson: String { return L10n.tr("Localizable", "settings_details.general.app_icon.enum.crimson") }
          /// Dev
          public static var dev: String { return L10n.tr("Localizable", "settings_details.general.app_icon.enum.dev") }
          /// Electric Violet
          public static var electricViolet: String { return L10n.tr("Localizable", "settings_details.general.app_icon.enum.electric_violet") }
          /// Fire Orange
          public static var fireOrange: String { return L10n.tr("Localizable", "settings_details.general.app_icon.enum.fire_orange") }
          /// Green
          public static var green: String { return L10n.tr("Localizable", "settings_details.general.app_icon.enum.green") }
          /// Home Assistant Blue
          public static var haBlue: String { return L10n.tr("Localizable", "settings_details.general.app_icon.enum.ha_blue") }
          /// Old Beta
          public static var oldBeta: String { return L10n.tr("Localizable", "settings_details.general.app_icon.enum.old_beta") }
          /// Old Dev
          public static var oldDev: String { return L10n.tr("Localizable", "settings_details.general.app_icon.enum.old_dev") }
          /// Old Release
          public static var oldRelease: String { return L10n.tr("Localizable", "settings_details.general.app_icon.enum.old_release") }
          /// Orange
          public static var orange: String { return L10n.tr("Localizable", "settings_details.general.app_icon.enum.orange") }
          /// Pink
          public static var pink: String { return L10n.tr("Localizable", "settings_details.general.app_icon.enum.pink") }
          /// Pride: Bi
          public static var prideBi: String { return L10n.tr("Localizable", "settings_details.general.app_icon.enum.pride_bi") }
          /// Pride: 8-Color
          public static var pridePoc: String { return L10n.tr("Localizable", "settings_details.general.app_icon.enum.pride_poc") }
          /// Pride: Rainbow
          public static var prideRainbow: String { return L10n.tr("Localizable", "settings_details.general.app_icon.enum.pride_rainbow") }
          /// Pride: Rainbow (Inverted)
          public static var prideRainbowInvert: String { return L10n.tr("Localizable", "settings_details.general.app_icon.enum.pride_rainbow_invert") }
          /// Pride: Trans
          public static var prideTrans: String { return L10n.tr("Localizable", "settings_details.general.app_icon.enum.pride_trans") }
          /// Purple
          public static var purple: String { return L10n.tr("Localizable", "settings_details.general.app_icon.enum.purple") }
          /// Red
          public static var red: String { return L10n.tr("Localizable", "settings_details.general.app_icon.enum.red") }
          /// Release
          public static var release: String { return L10n.tr("Localizable", "settings_details.general.app_icon.enum.release") }
          /// White
          public static var white: String { return L10n.tr("Localizable", "settings_details.general.app_icon.enum.white") }
        }
      }
      public enum DeviceName {
        /// Device Name
        public static var title: String { return L10n.tr("Localizable", "settings_details.general.device_name.title") }
      }
      public enum FullScreen {
        /// Full Screen
        public static var title: String { return L10n.tr("Localizable", "settings_details.general.full_screen.title") }
      }
      public enum LaunchOnLogin {
        /// Launch App on Login
        public static var title: String { return L10n.tr("Localizable", "settings_details.general.launch_on_login.title") }
      }
      public enum MenuBarText {
        /// Menu Bar Text
        public static var title: String { return L10n.tr("Localizable", "settings_details.general.menu_bar_text.title") }
      }
      public enum OpenInBrowser {
        /// Google Chrome
        public static var chrome: String { return L10n.tr("Localizable", "settings_details.general.open_in_browser.chrome") }
        /// System Default
        public static var `default`: String { return L10n.tr("Localizable", "settings_details.general.open_in_browser.default") }
        /// Mozilla Firefox
        public static var firefox: String { return L10n.tr("Localizable", "settings_details.general.open_in_browser.firefox") }
        /// Mozilla Firefox Focus
        public static var firefoxFocus: String { return L10n.tr("Localizable", "settings_details.general.open_in_browser.firefoxFocus") }
        /// Mozilla Firefox Klar
        public static var firefoxKlar: String { return L10n.tr("Localizable", "settings_details.general.open_in_browser.firefoxKlar") }
        /// Apple Safari
        public static var safari: String { return L10n.tr("Localizable", "settings_details.general.open_in_browser.safari") }
        /// Apple Safari (in app)
        public static var safariInApp: String { return L10n.tr("Localizable", "settings_details.general.open_in_browser.safari_in_app") }
        /// Open Links In
        public static var title: String { return L10n.tr("Localizable", "settings_details.general.open_in_browser.title") }
      }
      public enum OpenInPrivateTab {
        /// Open in Private Tab
        public static var title: String { return L10n.tr("Localizable", "settings_details.general.open_in_private_tab.title") }
      }
      public enum PageZoom {
        /// %@ (Default)
        public static func `default`(_ p1: Any) -> String {
          return L10n.tr("Localizable", "settings_details.general.page_zoom.default", String(describing: p1))
        }
        /// Page Zoom
        public static var title: String { return L10n.tr("Localizable", "settings_details.general.page_zoom.title") }
      }
      public enum PinchToZoom {
        /// Pinch to Zoom
        public static var title: String { return L10n.tr("Localizable", "settings_details.general.pinch_to_zoom.title") }
      }
      public enum Restoration {
        /// Remember Last Page
        public static var title: String { return L10n.tr("Localizable", "settings_details.general.restoration.title") }
      }
      public enum Visibility {
        /// Show App In…
        public static var title: String { return L10n.tr("Localizable", "settings_details.general.visibility.title") }
        public enum Options {
          /// Dock
          public static var dock: String { return L10n.tr("Localizable", "settings_details.general.visibility.options.dock") }
          /// Dock and Menu Bar
          public static var dockAndMenuBar: String { return L10n.tr("Localizable", "settings_details.general.visibility.options.dock_and_menu_bar") }
          /// Menu Bar
          public static var menuBar: String { return L10n.tr("Localizable", "settings_details.general.visibility.options.menu_bar") }
        }
      }
    }
    public enum Location {
      /// Location
      public static var title: String { return L10n.tr("Localizable", "settings_details.location.title") }
      /// Update Location
      public static var updateLocation: String { return L10n.tr("Localizable", "settings_details.location.update_location") }
      public enum BackgroundRefresh {
        /// Disabled
        public static var disabled: String { return L10n.tr("Localizable", "settings_details.location.background_refresh.disabled") }
        /// Enabled
        public static var enabled: String { return L10n.tr("Localizable", "settings_details.location.background_refresh.enabled") }
        /// Background Refresh
        public static var title: String { return L10n.tr("Localizable", "settings_details.location.background_refresh.title") }
      }
      public enum LocationAccuracy {
        /// Full
        public static var full: String { return L10n.tr("Localizable", "settings_details.location.location_accuracy.full") }
        /// Reduced
        public static var reduced: String { return L10n.tr("Localizable", "settings_details.location.location_accuracy.reduced") }
        /// Location Accuracy
        public static var title: String { return L10n.tr("Localizable", "settings_details.location.location_accuracy.title") }
      }
      public enum LocationPermission {
        /// Always
        public static var always: String { return L10n.tr("Localizable", "settings_details.location.location_permission.always") }
        /// Disabled
        public static var needsRequest: String { return L10n.tr("Localizable", "settings_details.location.location_permission.needs_request") }
        /// Never
        public static var never: String { return L10n.tr("Localizable", "settings_details.location.location_permission.never") }
        /// Location Permission
        public static var title: String { return L10n.tr("Localizable", "settings_details.location.location_permission.title") }
        /// While In Use
        public static var whileInUse: String { return L10n.tr("Localizable", "settings_details.location.location_permission.while_in_use") }
      }
      public enum MotionPermission {
        /// Denied
        public static var denied: String { return L10n.tr("Localizable", "settings_details.location.motion_permission.denied") }
        /// Enabled
        public static var enabled: String { return L10n.tr("Localizable", "settings_details.location.motion_permission.enabled") }
        /// Disabled
        public static var needsRequest: String { return L10n.tr("Localizable", "settings_details.location.motion_permission.needs_request") }
        /// Motion Permission
        public static var title: String { return L10n.tr("Localizable", "settings_details.location.motion_permission.title") }
      }
      public enum Notifications {
        /// Location Notifications
        public static var header: String { return L10n.tr("Localizable", "settings_details.location.notifications.header") }
        public enum BackgroundFetch {
          /// Background Fetch Notifications
          public static var title: String { return L10n.tr("Localizable", "settings_details.location.notifications.background_fetch.title") }
        }
        public enum BeaconEnter {
          /// Enter Zone via iBeacon Notifications
          public static var title: String { return L10n.tr("Localizable", "settings_details.location.notifications.beacon_enter.title") }
        }
        public enum BeaconExit {
          /// Exit Zone via iBeacon Notifications
          public static var title: String { return L10n.tr("Localizable", "settings_details.location.notifications.beacon_exit.title") }
        }
        public enum Enter {
          /// Enter Zone Notifications
          public static var title: String { return L10n.tr("Localizable", "settings_details.location.notifications.enter.title") }
        }
        public enum Exit {
          /// Exit Zone Notifications
          public static var title: String { return L10n.tr("Localizable", "settings_details.location.notifications.exit.title") }
        }
        public enum LocationChange {
          /// Significant Location Change Notifications
          public static var title: String { return L10n.tr("Localizable", "settings_details.location.notifications.location_change.title") }
        }
        public enum PushNotification {
          /// Pushed Location Request Notifications
          public static var title: String { return L10n.tr("Localizable", "settings_details.location.notifications.push_notification.title") }
        }
        public enum UrlScheme {
          /// URL Scheme Location Notifications
          public static var title: String { return L10n.tr("Localizable", "settings_details.location.notifications.url_scheme.title") }
        }
        public enum XCallbackUrl {
          /// X-Callback-URL Location Notifications
          public static var title: String { return L10n.tr("Localizable", "settings_details.location.notifications.x_callback_url.title") }
        }
      }
      public enum Updates {
        /// Manual location updates can always be triggered
        public static var footer: String { return L10n.tr("Localizable", "settings_details.location.updates.footer") }
        /// Update sources
        public static var header: String { return L10n.tr("Localizable", "settings_details.location.updates.header") }
        public enum Background {
          /// Background fetch
          public static var title: String { return L10n.tr("Localizable", "settings_details.location.updates.background.title") }
        }
        public enum Notification {
          /// Push notification request
          public static var title: String { return L10n.tr("Localizable", "settings_details.location.updates.notification.title") }
        }
        public enum Significant {
          /// Significant location change
          public static var title: String { return L10n.tr("Localizable", "settings_details.location.updates.significant.title") }
        }
        public enum Zone {
          /// Zone enter/exit
          public static var title: String { return L10n.tr("Localizable", "settings_details.location.updates.zone.title") }
        }
      }
      public enum Zones {
        /// To disable location tracking add track_ios: false to each zones settings or under customize.
        public static var footer: String { return L10n.tr("Localizable", "settings_details.location.zones.footer") }
        public enum Beacon {
          public enum PropNotSet {
            /// Not set
            public static var value: String { return L10n.tr("Localizable", "settings_details.location.zones.beacon.prop_not_set.value") }
          }
        }
        public enum BeaconMajor {
          /// iBeacon Major
          public static var title: String { return L10n.tr("Localizable", "settings_details.location.zones.beacon_major.title") }
        }
        public enum BeaconMinor {
          /// iBeacon Minor
          public static var title: String { return L10n.tr("Localizable", "settings_details.location.zones.beacon_minor.title") }
        }
        public enum BeaconUuid {
          /// iBeacon UUID
          public static var title: String { return L10n.tr("Localizable", "settings_details.location.zones.beacon_uuid.title") }
        }
        public enum EnterExitTracked {
          /// Enter/exit tracked
          public static var title: String { return L10n.tr("Localizable", "settings_details.location.zones.enter_exit_tracked.title") }
        }
        public enum Location {
          /// Location
          public static var title: String { return L10n.tr("Localizable", "settings_details.location.zones.location.title") }
        }
        public enum Radius {
          /// %li m
          public static func label(_ p1: Int) -> String {
            return L10n.tr("Localizable", "settings_details.location.zones.radius.label", p1)
          }
          /// Radius
          public static var title: String { return L10n.tr("Localizable", "settings_details.location.zones.radius.title") }
        }
      }
    }
    public enum Notifications {
      /// Use the mobile_app notify service to send notifications to your device.
      public static var info: String { return L10n.tr("Localizable", "settings_details.notifications.info") }
      /// Notifications
      public static var title: String { return L10n.tr("Localizable", "settings_details.notifications.title") }
      public enum BadgeSection {
        public enum AutomaticSetting {
          /// Resets the badge to 0 every time you launch the app.
          public static var description: String { return L10n.tr("Localizable", "settings_details.notifications.badge_section.automatic_setting.description") }
          /// Automatically
          public static var title: String { return L10n.tr("Localizable", "settings_details.notifications.badge_section.automatic_setting.title") }
        }
        public enum Button {
          /// Reset Badge
          public static var title: String { return L10n.tr("Localizable", "settings_details.notifications.badge_section.button.title") }
        }
      }
      public enum Categories {
        /// Categories are no longer required for actionable notifications and will be removed in a future release.
        public static var deprecatedNote: String { return L10n.tr("Localizable", "settings_details.notifications.categories.deprecated_note") }
        /// Categories
        public static var header: String { return L10n.tr("Localizable", "settings_details.notifications.categories.header") }
      }
      public enum CategoriesSynced {
        /// No Synced Categories
        public static var empty: String { return L10n.tr("Localizable", "settings_details.notifications.categories_synced.empty") }
        /// Categories defined in .yaml are not editable on device.
        public static var footer: String { return L10n.tr("Localizable", "settings_details.notifications.categories_synced.footer") }
        /// Categories may be also defined in the .yaml configuration.
        public static var footerNoCategories: String { return L10n.tr("Localizable", "settings_details.notifications.categories_synced.footer_no_categories") }
        /// Synced Categories
        public static var header: String { return L10n.tr("Localizable", "settings_details.notifications.categories_synced.header") }
      }
      public enum LocalPush {
        /// Local Push
        public static var title: String { return L10n.tr("Localizable", "settings_details.notifications.local_push.title") }
        public enum Status {
          /// Available (%1$@)
          public static func available(_ p1: Any) -> String {
            return L10n.tr("Localizable", "settings_details.notifications.local_push.status.available", String(describing: p1))
          }
          /// Disabled
          public static var disabled: String { return L10n.tr("Localizable", "settings_details.notifications.local_push.status.disabled") }
          /// Establishing
          public static var establishing: String { return L10n.tr("Localizable", "settings_details.notifications.local_push.status.establishing") }
          /// Unavailable
          public static var unavailable: String { return L10n.tr("Localizable", "settings_details.notifications.local_push.status.unavailable") }
          /// Unsupported
          public static var unsupported: String { return L10n.tr("Localizable", "settings_details.notifications.local_push.status.unsupported") }
        }
      }
      public enum NewCategory {
        /// New Category
        public static var title: String { return L10n.tr("Localizable", "settings_details.notifications.new_category.title") }
      }
      public enum Permission {
        /// Denied
        public static var disabled: String { return L10n.tr("Localizable", "settings_details.notifications.permission.disabled") }
        /// Enabled
        public static var enabled: String { return L10n.tr("Localizable", "settings_details.notifications.permission.enabled") }
        /// Disabled
        public static var needsRequest: String { return L10n.tr("Localizable", "settings_details.notifications.permission.needs_request") }
        /// Permission
        public static var title: String { return L10n.tr("Localizable", "settings_details.notifications.permission.title") }
      }
      public enum PromptToOpenUrls {
        /// Confirm before opening URL
        public static var title: String { return L10n.tr("Localizable", "settings_details.notifications.prompt_to_open_urls.title") }
      }
      public enum PushIdSection {
        /// Push ID
        public static var header: String { return L10n.tr("Localizable", "settings_details.notifications.push_id_section.header") }
        /// Not registered for remote notifications
        public static var notRegistered: String { return L10n.tr("Localizable", "settings_details.notifications.push_id_section.not_registered") }
      }
      public enum RateLimits {
        /// Attempts
        public static var attempts: String { return L10n.tr("Localizable", "settings_details.notifications.rate_limits.attempts") }
        /// Delivered
        public static var delivered: String { return L10n.tr("Localizable", "settings_details.notifications.rate_limits.delivered") }
        /// Errors
        public static var errors: String { return L10n.tr("Localizable", "settings_details.notifications.rate_limits.errors") }
        /// You are allowed 300 push notifications per 24 hours. Rate limits reset at midnight Universal Coordinated Time (UTC).
        public static var footer: String { return L10n.tr("Localizable", "settings_details.notifications.rate_limits.footer") }
        /// You are allowed %u push notifications per 24 hours. Rate limits reset at midnight Universal Coordinated Time (UTC).
        public static func footerWithParam(_ p1: Int) -> String {
          return L10n.tr("Localizable", "settings_details.notifications.rate_limits.footer_with_param", p1)
        }
        /// Rate Limits
        public static var header: String { return L10n.tr("Localizable", "settings_details.notifications.rate_limits.header") }
        /// Resets In
        public static var resetsIn: String { return L10n.tr("Localizable", "settings_details.notifications.rate_limits.resets_in") }
        /// Total
        public static var total: String { return L10n.tr("Localizable", "settings_details.notifications.rate_limits.total") }
      }
      public enum Sounds {
        /// Bundled
        public static var bundled: String { return L10n.tr("Localizable", "settings_details.notifications.sounds.bundled") }
        /// Built-in, system, or custom sounds can be used with your notifications.
        public static var footer: String { return L10n.tr("Localizable", "settings_details.notifications.sounds.footer") }
        /// Import custom sound
        public static var importCustom: String { return L10n.tr("Localizable", "settings_details.notifications.sounds.import_custom") }
        /// Import sounds from iTunes File Sharing
        public static var importFileSharing: String { return L10n.tr("Localizable", "settings_details.notifications.sounds.import_file_sharing") }
        /// Add custom sounds to your Sounds folder to use them in notifications. Use their filename as the sound value in the service call.
        public static var importMacInstructions: String { return L10n.tr("Localizable", "settings_details.notifications.sounds.import_mac_instructions") }
        /// Open Folder in Finder
        public static var importMacOpenFolder: String { return L10n.tr("Localizable", "settings_details.notifications.sounds.import_mac_open_folder") }
        /// Import system sounds
        public static var importSystem: String { return L10n.tr("Localizable", "settings_details.notifications.sounds.import_system") }
        /// Imported
        public static var imported: String { return L10n.tr("Localizable", "settings_details.notifications.sounds.imported") }
        /// System
        public static var system: String { return L10n.tr("Localizable", "settings_details.notifications.sounds.system") }
        /// Sounds
        public static var title: String { return L10n.tr("Localizable", "settings_details.notifications.sounds.title") }
        public enum Error {
          /// Can't build ~/Library/Sounds path: %@
          public static func cantBuildLibrarySoundsPath(_ p1: Any) -> String {
            return L10n.tr("Localizable", "settings_details.notifications.sounds.error.cant_build_library_sounds_path", String(describing: p1))
          }
          /// Can't list directory contents: %@
          public static func cantGetDirectoryContents(_ p1: Any) -> String {
            return L10n.tr("Localizable", "settings_details.notifications.sounds.error.cant_get_directory_contents", String(describing: p1))
          }
          /// Can't access file sharing sounds directory: %@
          public static func cantGetFileSharingPath(_ p1: Any) -> String {
            return L10n.tr("Localizable", "settings_details.notifications.sounds.error.cant_get_file_sharing_path", String(describing: p1))
          }
          /// Failed to convert audio to PCM 32 bit 48khz: %@
          public static func conversionFailed(_ p1: Any) -> String {
            return L10n.tr("Localizable", "settings_details.notifications.sounds.error.conversion_failed", String(describing: p1))
          }
          /// Failed to copy file: %@
          public static func copyError(_ p1: Any) -> String {
            return L10n.tr("Localizable", "settings_details.notifications.sounds.error.copy_error", String(describing: p1))
          }
          /// Failed to delete file: %@
          public static func deleteError(_ p1: Any) -> String {
            return L10n.tr("Localizable", "settings_details.notifications.sounds.error.delete_error", String(describing: p1))
          }
        }
        public enum ImportedAlert {
          /// %li sounds were imported. Please restart your phone to complete the import.
          public static func message(_ p1: Int) -> String {
            return L10n.tr("Localizable", "settings_details.notifications.sounds.imported_alert.message", p1)
          }
          /// Sounds Imported
          public static var title: String { return L10n.tr("Localizable", "settings_details.notifications.sounds.imported_alert.title") }
        }
      }
    }
    public enum Privacy {
      /// Privacy
      public static var title: String { return L10n.tr("Localizable", "settings_details.privacy.title") }
      public enum Alerts {
        /// Allows checking for important alerts like security vulnerabilities.
        public static var description: String { return L10n.tr("Localizable", "settings_details.privacy.alerts.description") }
        /// Alerts
        public static var title: String { return L10n.tr("Localizable", "settings_details.privacy.alerts.title") }
      }
      public enum Analytics {
        /// Allows collection of basic information about your device and interactions with the app. No user identifiable data is shared, including your Home Assistant URLs and tokens. You must restart the app for changes to this setting to take effect.
        public static var genericDescription: String { return L10n.tr("Localizable", "settings_details.privacy.analytics.generic_description") }
        /// Analytics
        public static var genericTitle: String { return L10n.tr("Localizable", "settings_details.privacy.analytics.generic_title") }
      }
      public enum CrashReporting {
        /// Allows for deeper tracking of crashes and other errors in the app, leading to faster fixes being published. No user identifiable information is sent, other than basic device information. You must restart the app for changes to this setting to take effect.
        public static var description: String { return L10n.tr("Localizable", "settings_details.privacy.crash_reporting.description") }
        /// This feature currently uses Sentry as the report destination.
        public static var sentry: String { return L10n.tr("Localizable", "settings_details.privacy.crash_reporting.sentry") }
        /// Crash Reporting
        public static var title: String { return L10n.tr("Localizable", "settings_details.privacy.crash_reporting.title") }
      }
      public enum Messaging {
        /// Firebase Cloud Messaging must be enabled for push notifications to function.
        public static var description: String { return L10n.tr("Localizable", "settings_details.privacy.messaging.description") }
        /// Firebase Cloud Messaging
        public static var title: String { return L10n.tr("Localizable", "settings_details.privacy.messaging.title") }
      }
    }
    public enum Updates {
      public enum CheckForUpdates {
        /// Include Beta Releases
        public static var includeBetas: String { return L10n.tr("Localizable", "settings_details.updates.check_for_updates.include_betas") }
        /// Automatically Check for Updates
        public static var title: String { return L10n.tr("Localizable", "settings_details.updates.check_for_updates.title") }
      }
    }
    public enum Watch {
      /// Apple Watch
      public static var title: String { return L10n.tr("Localizable", "settings_details.watch.title") }
    }
  }

  public enum SettingsSensors {
    /// Disabled
    public static var disabledStateReplacement: String { return L10n.tr("Localizable", "settings_sensors.disabled_state_replacement") }
    /// Sensors
    public static var title: String { return L10n.tr("Localizable", "settings_sensors.title") }
    public enum Detail {
      /// Attributes
      public static var attributes: String { return L10n.tr("Localizable", "settings_sensors.detail.attributes") }
      /// Device Class
      public static var deviceClass: String { return L10n.tr("Localizable", "settings_sensors.detail.device_class") }
      /// Enabled
      public static var enabled: String { return L10n.tr("Localizable", "settings_sensors.detail.enabled") }
      /// Icon
      public static var icon: String { return L10n.tr("Localizable", "settings_sensors.detail.icon") }
      /// State
      public static var state: String { return L10n.tr("Localizable", "settings_sensors.detail.state") }
    }
    public enum FocusPermission {
      /// Focus Permission
      public static var title: String { return L10n.tr("Localizable", "settings_sensors.focus_permission.title") }
    }
    public enum LastUpdated {
      /// Last Updated %@
      public static func footer(_ p1: Any) -> String {
        return L10n.tr("Localizable", "settings_sensors.last_updated.footer", String(describing: p1))
      }
    }
    public enum LoadingError {
      /// Failed to load sensors
      public static var title: String { return L10n.tr("Localizable", "settings_sensors.loading_error.title") }
    }
    public enum PeriodicUpdate {
      /// When enabled, these sensors will update with this frequency while the app is open in the foreground.
      public static var description: String { return L10n.tr("Localizable", "settings_sensors.periodic_update.description") }
      /// When enabled, these sensors will update with this frequency while the app is open. Some sensors will update automatically more often.
      public static var descriptionMac: String { return L10n.tr("Localizable", "settings_sensors.periodic_update.description_mac") }
      /// Off
      public static var off: String { return L10n.tr("Localizable", "settings_sensors.periodic_update.off") }
      /// Periodic Update
      public static var title: String { return L10n.tr("Localizable", "settings_sensors.periodic_update.title") }
    }
    public enum Settings {
      /// Changes will be applied on the next update.
      public static var footer: String { return L10n.tr("Localizable", "settings_sensors.settings.footer") }
      /// Settings
      public static var header: String { return L10n.tr("Localizable", "settings_sensors.settings.header") }
    }
  }

  public enum ShareExtension {
    /// 'entered' in event
    public static var enteredPlaceholder: String { return L10n.tr("Localizable", "share_extension.entered_placeholder") }
    public enum Error {
      /// Couldn't Send
      public static var title: String { return L10n.tr("Localizable", "share_extension.error.title") }
    }
  }

  public enum TokenError {
    /// Connection failed.
    public static var connectionFailed: String { return L10n.tr("Localizable", "token_error.connection_failed") }
    /// Token is expired.
    public static var expired: String { return L10n.tr("Localizable", "token_error.expired") }
    /// Token is unavailable.
    public static var tokenUnavailable: String { return L10n.tr("Localizable", "token_error.token_unavailable") }
  }

  public enum Updater {
    public enum CheckForUpdatesMenu {
      /// Check for Updates…
      public static var title: String { return L10n.tr("Localizable", "updater.check_for_updates_menu.title") }
    }
    public enum NoUpdatesAvailable {
      /// You're on the latest version!
      public static var onLatestVersion: String { return L10n.tr("Localizable", "updater.no_updates_available.on_latest_version") }
      /// Check for Updates
      public static var title: String { return L10n.tr("Localizable", "updater.no_updates_available.title") }
    }
    public enum UpdateAvailable {
      /// View '%@'
      public static func `open`(_ p1: Any) -> String {
        return L10n.tr("Localizable", "updater.update_available.open", String(describing: p1))
      }
      /// Update Available
      public static var title: String { return L10n.tr("Localizable", "updater.update_available.title") }
    }
  }

  public enum UrlHandler {
    public enum CallService {
      public enum Error {
        /// An error occurred while attempting to call service %@: %@
        public static func message(_ p1: Any, _ p2: Any) -> String {
          return L10n.tr("Localizable", "url_handler.call_service.error.message", String(describing: p1), String(describing: p2))
        }
      }
      public enum Success {
        /// Successfully called %@
        public static func message(_ p1: Any) -> String {
          return L10n.tr("Localizable", "url_handler.call_service.success.message", String(describing: p1))
        }
        /// Called service
        public static var title: String { return L10n.tr("Localizable", "url_handler.call_service.success.title") }
      }
    }
    public enum Error {
      /// Action Not Found
      public static var actionNotFound: String { return L10n.tr("Localizable", "url_handler.error.action_not_found") }
    }
    public enum FireEvent {
      public enum Error {
        /// An error occurred while attempting to fire event %@: %@
        public static func message(_ p1: Any, _ p2: Any) -> String {
          return L10n.tr("Localizable", "url_handler.fire_event.error.message", String(describing: p1), String(describing: p2))
        }
      }
      public enum Success {
        /// Successfully fired event %@
        public static func message(_ p1: Any) -> String {
          return L10n.tr("Localizable", "url_handler.fire_event.success.message", String(describing: p1))
        }
        /// Fired event
        public static var title: String { return L10n.tr("Localizable", "url_handler.fire_event.success.title") }
      }
    }
    public enum NoService {
      /// %@ is not a valid route
      public static func message(_ p1: Any) -> String {
        return L10n.tr("Localizable", "url_handler.no_service.message", String(describing: p1))
      }
    }
    public enum SendLocation {
      public enum Error {
        /// An unknown error occurred while attempting to send location: %@
        public static func message(_ p1: Any) -> String {
          return L10n.tr("Localizable", "url_handler.send_location.error.message", String(describing: p1))
        }
      }
      public enum Success {
        /// Sent a one shot location
        public static var message: String { return L10n.tr("Localizable", "url_handler.send_location.success.message") }
        /// Sent location
        public static var title: String { return L10n.tr("Localizable", "url_handler.send_location.success.title") }
      }
    }
    public enum XCallbackUrl {
      public enum Error {
        /// eventName must be defined
        public static var eventNameMissing: String { return L10n.tr("Localizable", "url_handler.x_callback_url.error.eventNameMissing") }
        /// A general error occurred
        public static var general: String { return L10n.tr("Localizable", "url_handler.x_callback_url.error.general") }
        /// service (e.g. homeassistant.turn_on) must be defined
        public static var serviceMissing: String { return L10n.tr("Localizable", "url_handler.x_callback_url.error.serviceMissing") }
        /// A renderable template must be defined
        public static var templateMissing: String { return L10n.tr("Localizable", "url_handler.x_callback_url.error.templateMissing") }
      }
    }
  }

  public enum Watch {
    /// Placeholder
    public static var placeholderComplicationName: String { return L10n.tr("Localizable", "watch.placeholder_complication_name") }
    public enum Configurator {
      public enum Delete {
        /// Delete Complication
        public static var button: String { return L10n.tr("Localizable", "watch.configurator.delete.button") }
        /// Are you sure you want to delete this Complication? This cannot be undone.
        public static var message: String { return L10n.tr("Localizable", "watch.configurator.delete.message") }
        /// Delete Complication?
        public static var title: String { return L10n.tr("Localizable", "watch.configurator.delete.title") }
      }
      public enum List {
        /// Configure a new Complication using the Add button. Once saved, you can choose it on your Apple Watch or in the Watch app.
        public static var description: String { return L10n.tr("Localizable", "watch.configurator.list.description") }
        public enum ManualUpdates {
          /// Automatic updates occur 4 times per hour. Manual updates can also be done using notifications.
          public static var footer: String { return L10n.tr("Localizable", "watch.configurator.list.manual_updates.footer") }
          /// Update Complications
          public static var manuallyUpdate: String { return L10n.tr("Localizable", "watch.configurator.list.manual_updates.manually_update") }
          /// Remaining
          public static var remaining: String { return L10n.tr("Localizable", "watch.configurator.list.manual_updates.remaining") }
          /// Manual Updates
          public static var title: String { return L10n.tr("Localizable", "watch.configurator.list.manual_updates.title") }
          public enum State {
            /// Not Enabled
            public static var notEnabled: String { return L10n.tr("Localizable", "watch.configurator.list.manual_updates.state.not_enabled") }
            /// Not Installed
            public static var notInstalled: String { return L10n.tr("Localizable", "watch.configurator.list.manual_updates.state.not_installed") }
            /// No Device
            public static var notPaired: String { return L10n.tr("Localizable", "watch.configurator.list.manual_updates.state.not_paired") }
          }
        }
      }
      public enum New {
        /// Adding another Complication for the same type as an existing one requires watchOS 7 or newer.
        public static var multipleComplicationInfo: String { return L10n.tr("Localizable", "watch.configurator.new.multiple_complication_info") }
        /// New Complication
        public static var title: String { return L10n.tr("Localizable", "watch.configurator.new.title") }
      }
      public enum PreviewError {
        /// Expected a number but got %1$@: '%2$@'
        public static func notNumber(_ p1: Any, _ p2: Any) -> String {
          return L10n.tr("Localizable", "watch.configurator.preview_error.not_number", String(describing: p1), String(describing: p2))
        }
        /// Expected a number between 0.0 and 1.0 but got %1$f
        public static func outOfRange(_ p1: Float) -> String {
          return L10n.tr("Localizable", "watch.configurator.preview_error.out_of_range", p1)
        }
      }
      public enum Rows {
        public enum Color {
          /// Color
          public static var title: String { return L10n.tr("Localizable", "watch.configurator.rows.color.title") }
        }
        public enum Column2Alignment {
          /// Column 2 Alignment
          public static var title: String { return L10n.tr("Localizable", "watch.configurator.rows.column_2_alignment.title") }
          public enum Options {
            /// Leading
            public static var leading: String { return L10n.tr("Localizable", "watch.configurator.rows.column_2_alignment.options.leading") }
            /// Trailing
            public static var trailing: String { return L10n.tr("Localizable", "watch.configurator.rows.column_2_alignment.options.trailing") }
          }
        }
        public enum DisplayName {
          /// Display Name
          public static var title: String { return L10n.tr("Localizable", "watch.configurator.rows.display_name.title") }
        }
        public enum Gauge {
          /// Gauge
          public static var title: String { return L10n.tr("Localizable", "watch.configurator.rows.gauge.title") }
          public enum Color {
            /// Color
            public static var title: String { return L10n.tr("Localizable", "watch.configurator.rows.gauge.color.title") }
          }
          public enum GaugeType {
            /// Type
            public static var title: String { return L10n.tr("Localizable", "watch.configurator.rows.gauge.gauge_type.title") }
            public enum Options {
              /// Closed
              public static var closed: String { return L10n.tr("Localizable", "watch.configurator.rows.gauge.gauge_type.options.closed") }
              /// Open
              public static var `open`: String { return L10n.tr("Localizable", "watch.configurator.rows.gauge.gauge_type.options.open") }
            }
          }
          public enum Style {
            /// Style
            public static var title: String { return L10n.tr("Localizable", "watch.configurator.rows.gauge.style.title") }
            public enum Options {
              /// Fill
              public static var fill: String { return L10n.tr("Localizable", "watch.configurator.rows.gauge.style.options.fill") }
              /// Ring
              public static var ring: String { return L10n.tr("Localizable", "watch.configurator.rows.gauge.style.options.ring") }
            }
          }
        }
        public enum Icon {
          public enum Choose {
            /// Choose an icon
            public static var title: String { return L10n.tr("Localizable", "watch.configurator.rows.icon.choose.title") }
          }
          public enum Color {
            /// Color
            public static var title: String { return L10n.tr("Localizable", "watch.configurator.rows.icon.color.title") }
          }
        }
        public enum IsPublic {
          /// Show When Locked
          public static var title: String { return L10n.tr("Localizable", "watch.configurator.rows.is_public.title") }
        }
        public enum Ring {
          public enum Color {
            /// Color
            public static var title: String { return L10n.tr("Localizable", "watch.configurator.rows.ring.color.title") }
          }
          public enum RingType {
            /// Type
            public static var title: String { return L10n.tr("Localizable", "watch.configurator.rows.ring.ring_type.title") }
            public enum Options {
              /// Closed
              public static var closed: String { return L10n.tr("Localizable", "watch.configurator.rows.ring.ring_type.options.closed") }
              /// Open
              public static var `open`: String { return L10n.tr("Localizable", "watch.configurator.rows.ring.ring_type.options.open") }
            }
          }
          public enum Value {
            /// Fractional value
            public static var title: String { return L10n.tr("Localizable", "watch.configurator.rows.ring.value.title") }
          }
        }
        public enum Template {
          /// Choose a template
          public static var selectorTitle: String { return L10n.tr("Localizable", "watch.configurator.rows.template.selector_title") }
          /// Template
          public static var title: String { return L10n.tr("Localizable", "watch.configurator.rows.template.title") }
        }
      }
      public enum Sections {
        public enum Gauge {
          /// The gauge to display in the complication.
          public static var footer: String { return L10n.tr("Localizable", "watch.configurator.sections.gauge.footer") }
          /// Gauge
          public static var header: String { return L10n.tr("Localizable", "watch.configurator.sections.gauge.header") }
        }
        public enum Icon {
          /// The image to display in the complication.
          public static var footer: String { return L10n.tr("Localizable", "watch.configurator.sections.icon.footer") }
          /// Icon
          public static var header: String { return L10n.tr("Localizable", "watch.configurator.sections.icon.header") }
        }
        public enum Ring {
          /// The ring showing progress surrounding the text.
          public static var footer: String { return L10n.tr("Localizable", "watch.configurator.sections.ring.footer") }
          /// Ring
          public static var header: String { return L10n.tr("Localizable", "watch.configurator.sections.ring.header") }
        }
      }
    }
    public enum Labels {
      /// No actions configured. Configure actions on your phone to dismiss this message.
      public static var noAction: String { return L10n.tr("Localizable", "watch.labels.no_action") }
      public enum ComplicationGroup {
        public enum CircularSmall {
          /// Use circular small complications to display content in the corners of the Color watch face.
          public static var description: String { return L10n.tr("Localizable", "watch.labels.complication_group.circular_small.description") }
          /// Circular Small
          public static var name: String { return L10n.tr("Localizable", "watch.labels.complication_group.circular_small.name") }
        }
        public enum ExtraLarge {
          /// Use the extra large complications to display content on the X-Large watch faces.
          public static var description: String { return L10n.tr("Localizable", "watch.labels.complication_group.extra_large.description") }
          /// Extra Large
          public static var name: String { return L10n.tr("Localizable", "watch.labels.complication_group.extra_large.name") }
        }
        public enum Graphic {
          /// Use graphic complications to display visually rich content in the Infograph and Infograph Modular clock faces.
          public static var description: String { return L10n.tr("Localizable", "watch.labels.complication_group.graphic.description") }
          /// Graphic
          public static var name: String { return L10n.tr("Localizable", "watch.labels.complication_group.graphic.name") }
        }
        public enum Modular {
          /// Use modular small complications to display content in the Modular watch face.
          public static var description: String { return L10n.tr("Localizable", "watch.labels.complication_group.modular.description") }
          /// Modular
          public static var name: String { return L10n.tr("Localizable", "watch.labels.complication_group.modular.name") }
        }
        public enum Utilitarian {
          /// Use the utilitarian complications to display content in the Utility, Motion, Mickey Mouse, and Minnie Mouse watch faces.
          public static var description: String { return L10n.tr("Localizable", "watch.labels.complication_group.utilitarian.description") }
          /// Utilitarian
          public static var name: String { return L10n.tr("Localizable", "watch.labels.complication_group.utilitarian.name") }
        }
      }
      public enum ComplicationGroupMember {
        public enum CircularSmall {
          /// A small circular area used in the Color clock face.
          public static var description: String { return L10n.tr("Localizable", "watch.labels.complication_group_member.circular_small.description") }
          /// Circular Small
          public static var name: String { return L10n.tr("Localizable", "watch.labels.complication_group_member.circular_small.name") }
          /// Circular Small
          public static var shortName: String { return L10n.tr("Localizable", "watch.labels.complication_group_member.circular_small.short_name") }
        }
        public enum ExtraLarge {
          /// A large square area used in the X-Large clock face.
          public static var description: String { return L10n.tr("Localizable", "watch.labels.complication_group_member.extra_large.description") }
          /// Extra Large
          public static var name: String { return L10n.tr("Localizable", "watch.labels.complication_group_member.extra_large.name") }
          /// Extra Large
          public static var shortName: String { return L10n.tr("Localizable", "watch.labels.complication_group_member.extra_large.short_name") }
        }
        public enum GraphicBezel {
          /// A small square area used in the Modular clock face.
          public static var description: String { return L10n.tr("Localizable", "watch.labels.complication_group_member.graphic_bezel.description") }
          /// Graphic Bezel
          public static var name: String { return L10n.tr("Localizable", "watch.labels.complication_group_member.graphic_bezel.name") }
          /// Bezel
          public static var shortName: String { return L10n.tr("Localizable", "watch.labels.complication_group_member.graphic_bezel.short_name") }
        }
        public enum GraphicCircular {
          /// A large rectangular area used in the Modular clock face.
          public static var description: String { return L10n.tr("Localizable", "watch.labels.complication_group_member.graphic_circular.description") }
          /// Graphic Circular
          public static var name: String { return L10n.tr("Localizable", "watch.labels.complication_group_member.graphic_circular.name") }
          /// Circular
          public static var shortName: String { return L10n.tr("Localizable", "watch.labels.complication_group_member.graphic_circular.short_name") }
        }
        public enum GraphicCorner {
          /// A small square or rectangular area used in the Utility, Mickey, Chronograph, and Simple clock faces.
          public static var description: String { return L10n.tr("Localizable", "watch.labels.complication_group_member.graphic_corner.description") }
          /// Graphic Corner
          public static var name: String { return L10n.tr("Localizable", "watch.labels.complication_group_member.graphic_corner.name") }
          /// Corner
          public static var shortName: String { return L10n.tr("Localizable", "watch.labels.complication_group_member.graphic_corner.short_name") }
        }
        public enum GraphicRectangular {
          /// A small rectangular area used in the in the Photos, Motion, and Timelapse clock faces.
          public static var description: String { return L10n.tr("Localizable", "watch.labels.complication_group_member.graphic_rectangular.description") }
          /// Graphic Rectangular
          public static var name: String { return L10n.tr("Localizable", "watch.labels.complication_group_member.graphic_rectangular.name") }
          /// Rectangular
          public static var shortName: String { return L10n.tr("Localizable", "watch.labels.complication_group_member.graphic_rectangular.short_name") }
        }
        public enum ModularLarge {
          /// A large rectangular area that spans the width of the screen in the Utility and Mickey clock faces.
          public static var description: String { return L10n.tr("Localizable", "watch.labels.complication_group_member.modular_large.description") }
          /// Modular Large
          public static var name: String { return L10n.tr("Localizable", "watch.labels.complication_group_member.modular_large.name") }
          /// Large
          public static var shortName: String { return L10n.tr("Localizable", "watch.labels.complication_group_member.modular_large.short_name") }
        }
        public enum ModularSmall {
          /// A curved area that fills the corners in the Infograph clock face.
          public static var description: String { return L10n.tr("Localizable", "watch.labels.complication_group_member.modular_small.description") }
          /// Modular Small
          public static var name: String { return L10n.tr("Localizable", "watch.labels.complication_group_member.modular_small.name") }
          /// Small
          public static var shortName: String { return L10n.tr("Localizable", "watch.labels.complication_group_member.modular_small.short_name") }
        }
        public enum UtilitarianLarge {
          /// A circular area used in the Infograph and Infograph Modular clock faces.
          public static var description: String { return L10n.tr("Localizable", "watch.labels.complication_group_member.utilitarian_large.description") }
          /// Utilitarian Large
          public static var name: String { return L10n.tr("Localizable", "watch.labels.complication_group_member.utilitarian_large.name") }
          /// Large
          public static var shortName: String { return L10n.tr("Localizable", "watch.labels.complication_group_member.utilitarian_large.short_name") }
        }
        public enum UtilitarianSmall {
          /// A circular area with optional curved text placed along the bezel of the Infograph clock face.
          public static var description: String { return L10n.tr("Localizable", "watch.labels.complication_group_member.utilitarian_small.description") }
          /// Utilitarian Small
          public static var name: String { return L10n.tr("Localizable", "watch.labels.complication_group_member.utilitarian_small.name") }
          /// Small
          public static var shortName: String { return L10n.tr("Localizable", "watch.labels.complication_group_member.utilitarian_small.short_name") }
        }
        public enum UtilitarianSmallFlat {
          /// A large rectangular area used in the Infograph Modular clock face.
          public static var description: String { return L10n.tr("Localizable", "watch.labels.complication_group_member.utilitarian_small_flat.description") }
          /// Utilitarian Small Flat
          public static var name: String { return L10n.tr("Localizable", "watch.labels.complication_group_member.utilitarian_small_flat.name") }
          /// Small Flat
          public static var shortName: String { return L10n.tr("Localizable", "watch.labels.complication_group_member.utilitarian_small_flat.short_name") }
        }
      }
      public enum ComplicationTemplate {
        public enum CircularSmallRingImage {
          /// A template for displaying a single image surrounded by a configurable progress ring.
          public static var description: String { return L10n.tr("Localizable", "watch.labels.complication_template.circular_small_ring_image.description") }
        }
        public enum CircularSmallRingText {
          /// A template for displaying a short text string encircled by a configurable progress ring.
          public static var description: String { return L10n.tr("Localizable", "watch.labels.complication_template.circular_small_ring_text.description") }
        }
        public enum CircularSmallSimpleImage {
          /// A template for displaying a single image.
          public static var description: String { return L10n.tr("Localizable", "watch.labels.complication_template.circular_small_simple_image.description") }
        }
        public enum CircularSmallSimpleText {
          /// A template for displaying a short text string.
          public static var description: String { return L10n.tr("Localizable", "watch.labels.complication_template.circular_small_simple_text.description") }
        }
        public enum CircularSmallStackImage {
          /// A template for displaying an image with a line of text below it.
          public static var description: String { return L10n.tr("Localizable", "watch.labels.complication_template.circular_small_stack_image.description") }
        }
        public enum CircularSmallStackText {
          /// A template for displaying two text strings stacked on top of each other.
          public static var description: String { return L10n.tr("Localizable", "watch.labels.complication_template.circular_small_stack_text.description") }
        }
        public enum ExtraLargeColumnsText {
          /// A template for displaying two rows and two columns of text.
          public static var description: String { return L10n.tr("Localizable", "watch.labels.complication_template.extra_large_columns_text.description") }
        }
        public enum ExtraLargeRingImage {
          /// A template for displaying an image encircled by a configurable progress ring.
          public static var description: String { return L10n.tr("Localizable", "watch.labels.complication_template.extra_large_ring_image.description") }
        }
        public enum ExtraLargeRingText {
          /// A template for displaying text encircled by a configurable progress ring.
          public static var description: String { return L10n.tr("Localizable", "watch.labels.complication_template.extra_large_ring_text.description") }
        }
        public enum ExtraLargeSimpleImage {
          /// A template for displaying an image.
          public static var description: String { return L10n.tr("Localizable", "watch.labels.complication_template.extra_large_simple_image.description") }
        }
        public enum ExtraLargeSimpleText {
          /// A template for displaying a small amount of text
          public static var description: String { return L10n.tr("Localizable", "watch.labels.complication_template.extra_large_simple_text.description") }
        }
        public enum ExtraLargeStackImage {
          /// A template for displaying a single image with a short line of text below it.
          public static var description: String { return L10n.tr("Localizable", "watch.labels.complication_template.extra_large_stack_image.description") }
        }
        public enum ExtraLargeStackText {
          /// A template for displaying two strings stacked one on top of the other.
          public static var description: String { return L10n.tr("Localizable", "watch.labels.complication_template.extra_large_stack_text.description") }
        }
        public enum GraphicBezelCircularText {
          /// A template for displaying a circular complication with text along the bezel.
          public static var description: String { return L10n.tr("Localizable", "watch.labels.complication_template.graphic_bezel_circular_text.description") }
        }
        public enum GraphicCircularClosedGaugeImage {
          /// A template for displaying a full-color circular image and a closed circular gauge.
          public static var description: String { return L10n.tr("Localizable", "watch.labels.complication_template.graphic_circular_closed_gauge_image.description") }
        }
        public enum GraphicCircularClosedGaugeText {
          /// A template for displaying text inside a closed circular gauge.
          public static var description: String { return L10n.tr("Localizable", "watch.labels.complication_template.graphic_circular_closed_gauge_text.description") }
        }
        public enum GraphicCircularImage {
          /// A template for displaying a full-color circular image.
          public static var description: String { return L10n.tr("Localizable", "watch.labels.complication_template.graphic_circular_image.description") }
        }
        public enum GraphicCircularOpenGaugeImage {
          /// A template for displaying a full-color circular image, an open gauge, and text.
          public static var description: String { return L10n.tr("Localizable", "watch.labels.complication_template.graphic_circular_open_gauge_image.description") }
        }
        public enum GraphicCircularOpenGaugeRangeText {
          /// A template for displaying text inside an open gauge, with leading and trailing text for the gauge.
          public static var description: String { return L10n.tr("Localizable", "watch.labels.complication_template.graphic_circular_open_gauge_range_text.description") }
        }
        public enum GraphicCircularOpenGaugeSimpleText {
          /// A template for displaying text inside an open gauge, with a single piece of text for the gauge.
          public static var description: String { return L10n.tr("Localizable", "watch.labels.complication_template.graphic_circular_open_gauge_simple_text.description") }
        }
        public enum GraphicCornerCircularImage {
          /// A template for displaying an image in the clock face’s corner.
          public static var description: String { return L10n.tr("Localizable", "watch.labels.complication_template.graphic_corner_circular_image.description") }
        }
        public enum GraphicCornerGaugeImage {
          /// A template for displaying an image and a gauge in the clock face’s corner.
          public static var description: String { return L10n.tr("Localizable", "watch.labels.complication_template.graphic_corner_gauge_image.description") }
        }
        public enum GraphicCornerGaugeText {
          /// A template for displaying text and a gauge in the clock face’s corner.
          public static var description: String { return L10n.tr("Localizable", "watch.labels.complication_template.graphic_corner_gauge_text.description") }
        }
        public enum GraphicCornerStackText {
          /// A template for displaying stacked text in the clock face’s corner.
          public static var description: String { return L10n.tr("Localizable", "watch.labels.complication_template.graphic_corner_stack_text.description") }
        }
        public enum GraphicCornerTextImage {
          /// A template for displaying an image and text in the clock face’s corner.
          public static var description: String { return L10n.tr("Localizable", "watch.labels.complication_template.graphic_corner_text_image.description") }
        }
        public enum GraphicRectangularLargeImage {
          /// A template for displaying a large rectangle containing header text and an image.
          public static var description: String { return L10n.tr("Localizable", "watch.labels.complication_template.graphic_rectangular_large_image.description") }
        }
        public enum GraphicRectangularStandardBody {
          /// A template for displaying a large rectangle containing text.
          public static var description: String { return L10n.tr("Localizable", "watch.labels.complication_template.graphic_rectangular_standard_body.description") }
        }
        public enum GraphicRectangularTextGauge {
          /// A template for displaying a large rectangle containing text and a gauge.
          public static var description: String { return L10n.tr("Localizable", "watch.labels.complication_template.graphic_rectangular_text_gauge.description") }
        }
        public enum ModularLargeColumns {
          /// A template for displaying multiple columns of data.
          public static var description: String { return L10n.tr("Localizable", "watch.labels.complication_template.modular_large_columns.description") }
        }
        public enum ModularLargeStandardBody {
          /// A template for displaying a header row and two lines of text
          public static var description: String { return L10n.tr("Localizable", "watch.labels.complication_template.modular_large_standard_body.description") }
        }
        public enum ModularLargeTable {
          /// A template for displaying a header row and columns
          public static var description: String { return L10n.tr("Localizable", "watch.labels.complication_template.modular_large_table.description") }
        }
        public enum ModularLargeTallBody {
          /// A template for displaying a header row and a tall row of body text.
          public static var description: String { return L10n.tr("Localizable", "watch.labels.complication_template.modular_large_tall_body.description") }
        }
        public enum ModularSmallColumnsText {
          /// A template for displaying two rows and two columns of text
          public static var description: String { return L10n.tr("Localizable", "watch.labels.complication_template.modular_small_columns_text.description") }
        }
        public enum ModularSmallRingImage {
          /// A template for displaying an image encircled by a configurable progress ring
          public static var description: String { return L10n.tr("Localizable", "watch.labels.complication_template.modular_small_ring_image.description") }
        }
        public enum ModularSmallRingText {
          /// A template for displaying text encircled by a configurable progress ring
          public static var description: String { return L10n.tr("Localizable", "watch.labels.complication_template.modular_small_ring_text.description") }
        }
        public enum ModularSmallSimpleImage {
          /// A template for displaying an image.
          public static var description: String { return L10n.tr("Localizable", "watch.labels.complication_template.modular_small_simple_image.description") }
        }
        public enum ModularSmallSimpleText {
          /// A template for displaying a small amount of text.
          public static var description: String { return L10n.tr("Localizable", "watch.labels.complication_template.modular_small_simple_text.description") }
        }
        public enum ModularSmallStackImage {
          /// A template for displaying a single image with a short line of text below it.
          public static var description: String { return L10n.tr("Localizable", "watch.labels.complication_template.modular_small_stack_image.description") }
        }
        public enum ModularSmallStackText {
          /// A template for displaying two strings stacked one on top of the other.
          public static var description: String { return L10n.tr("Localizable", "watch.labels.complication_template.modular_small_stack_text.description") }
        }
        public enum Style {
          /// Circular Image
          public static var circularImage: String { return L10n.tr("Localizable", "watch.labels.complication_template.style.circular_image") }
          /// Circular Text
          public static var circularText: String { return L10n.tr("Localizable", "watch.labels.complication_template.style.circular_text") }
          /// Closed Gauge Image
          public static var closedGaugeImage: String { return L10n.tr("Localizable", "watch.labels.complication_template.style.closed_gauge_image") }
          /// Closed Gauge Text
          public static var closedGaugeText: String { return L10n.tr("Localizable", "watch.labels.complication_template.style.closed_gauge_text") }
          /// Columns
          public static var columns: String { return L10n.tr("Localizable", "watch.labels.complication_template.style.columns") }
          /// Columns Text
          public static var columnsText: String { return L10n.tr("Localizable", "watch.labels.complication_template.style.columns_text") }
          /// Flat
          public static var flat: String { return L10n.tr("Localizable", "watch.labels.complication_template.style.flat") }
          /// Gauge Image
          public static var gaugeImage: String { return L10n.tr("Localizable", "watch.labels.complication_template.style.gauge_image") }
          /// Gauge Text
          public static var gaugeText: String { return L10n.tr("Localizable", "watch.labels.complication_template.style.gauge_text") }
          /// Large Image
          public static var largeImage: String { return L10n.tr("Localizable", "watch.labels.complication_template.style.large_image") }
          /// Open Gauge Image
          public static var openGaugeImage: String { return L10n.tr("Localizable", "watch.labels.complication_template.style.open_gauge_image") }
          /// Open Gauge Range Text
          public static var openGaugeRangeText: String { return L10n.tr("Localizable", "watch.labels.complication_template.style.open_gauge_range_text") }
          /// Open Gauge Simple Text
          public static var openGaugeSimpleText: String { return L10n.tr("Localizable", "watch.labels.complication_template.style.open_gauge_simple_text") }
          /// Ring Image
          public static var ringImage: String { return L10n.tr("Localizable", "watch.labels.complication_template.style.ring_image") }
          /// Ring Text
          public static var ringText: String { return L10n.tr("Localizable", "watch.labels.complication_template.style.ring_text") }
          /// Simple Image
          public static var simpleImage: String { return L10n.tr("Localizable", "watch.labels.complication_template.style.simple_image") }
          /// Simple Text
          public static var simpleText: String { return L10n.tr("Localizable", "watch.labels.complication_template.style.simple_text") }
          /// Square
          public static var square: String { return L10n.tr("Localizable", "watch.labels.complication_template.style.square") }
          /// Stack Image
          public static var stackImage: String { return L10n.tr("Localizable", "watch.labels.complication_template.style.stack_image") }
          /// Stack Text
          public static var stackText: String { return L10n.tr("Localizable", "watch.labels.complication_template.style.stack_text") }
          /// Standard Body
          public static var standardBody: String { return L10n.tr("Localizable", "watch.labels.complication_template.style.standard_body") }
          /// Table
          public static var table: String { return L10n.tr("Localizable", "watch.labels.complication_template.style.table") }
          /// Tall Body
          public static var tallBody: String { return L10n.tr("Localizable", "watch.labels.complication_template.style.tall_body") }
          /// Text Gauge
          public static var textGauge: String { return L10n.tr("Localizable", "watch.labels.complication_template.style.text_gauge") }
          /// Text Image
          public static var textImage: String { return L10n.tr("Localizable", "watch.labels.complication_template.style.text_image") }
        }
        public enum UtilitarianLargeFlat {
          /// A template for displaying an image and string in a single long line.
          public static var description: String { return L10n.tr("Localizable", "watch.labels.complication_template.utilitarian_large_flat.description") }
        }
        public enum UtilitarianSmallFlat {
          /// A template for displaying an image and text in a single line.
          public static var description: String { return L10n.tr("Localizable", "watch.labels.complication_template.utilitarian_small_flat.description") }
        }
        public enum UtilitarianSmallRingImage {
          /// A template for displaying an image encircled by a configurable progress ring
          public static var description: String { return L10n.tr("Localizable", "watch.labels.complication_template.utilitarian_small_ring_image.description") }
        }
        public enum UtilitarianSmallRingText {
          /// A template for displaying text encircled by a configurable progress ring.
          public static var description: String { return L10n.tr("Localizable", "watch.labels.complication_template.utilitarian_small_ring_text.description") }
        }
        public enum UtilitarianSmallSquare {
          /// A template for displaying a single square image.
          public static var description: String { return L10n.tr("Localizable", "watch.labels.complication_template.utilitarian_small_square.description") }
        }
      }
      public enum ComplicationTextAreas {
        public enum Body1 {
          /// The main body text to display in the complication.
          public static var description: String { return L10n.tr("Localizable", "watch.labels.complication_text_areas.body1.description") }
          /// Body 1
          public static var label: String { return L10n.tr("Localizable", "watch.labels.complication_text_areas.body1.label") }
        }
        public enum Body2 {
          /// The secondary body text to display in the complication.
          public static var description: String { return L10n.tr("Localizable", "watch.labels.complication_text_areas.body2.description") }
          /// Body 2
          public static var label: String { return L10n.tr("Localizable", "watch.labels.complication_text_areas.body2.label") }
        }
        public enum Bottom {
          /// The text to display at the bottom of the gauge.
          public static var description: String { return L10n.tr("Localizable", "watch.labels.complication_text_areas.bottom.description") }
          /// Bottom
          public static var label: String { return L10n.tr("Localizable", "watch.labels.complication_text_areas.bottom.label") }
        }
        public enum Center {
          /// The text to display in the complication.
          public static var description: String { return L10n.tr("Localizable", "watch.labels.complication_text_areas.center.description") }
          /// Center
          public static var label: String { return L10n.tr("Localizable", "watch.labels.complication_text_areas.center.label") }
        }
        public enum Header {
          /// The header text to display in the complication.
          public static var description: String { return L10n.tr("Localizable", "watch.labels.complication_text_areas.header.description") }
          /// Header
          public static var label: String { return L10n.tr("Localizable", "watch.labels.complication_text_areas.header.label") }
        }
        public enum Inner {
          /// The inner text to display in the complication.
          public static var description: String { return L10n.tr("Localizable", "watch.labels.complication_text_areas.inner.description") }
          /// Inner
          public static var label: String { return L10n.tr("Localizable", "watch.labels.complication_text_areas.inner.label") }
        }
        public enum InsideRing {
          /// The text to display in the ring of the complication.
          public static var description: String { return L10n.tr("Localizable", "watch.labels.complication_text_areas.inside_ring.description") }
          /// Inside Ring
          public static var label: String { return L10n.tr("Localizable", "watch.labels.complication_text_areas.inside_ring.label") }
        }
        public enum Leading {
          /// The text to display on the leading edge of the gauge.
          public static var description: String { return L10n.tr("Localizable", "watch.labels.complication_text_areas.leading.description") }
          /// Leading
          public static var label: String { return L10n.tr("Localizable", "watch.labels.complication_text_areas.leading.label") }
        }
        public enum Line1 {
          /// The text to display on the top line of the complication.
          public static var description: String { return L10n.tr("Localizable", "watch.labels.complication_text_areas.line1.description") }
          /// Line 1
          public static var label: String { return L10n.tr("Localizable", "watch.labels.complication_text_areas.line1.label") }
        }
        public enum Line2 {
          /// The text to display on the bottom line of the complication.
          public static var description: String { return L10n.tr("Localizable", "watch.labels.complication_text_areas.line2.description") }
          /// Line 2
          public static var label: String { return L10n.tr("Localizable", "watch.labels.complication_text_areas.line2.label") }
        }
        public enum Outer {
          /// The outer text to display in the complication.
          public static var description: String { return L10n.tr("Localizable", "watch.labels.complication_text_areas.outer.description") }
          /// Outer
          public static var label: String { return L10n.tr("Localizable", "watch.labels.complication_text_areas.outer.label") }
        }
        public enum Row1Column1 {
          /// The text to display in the first column of the first row.
          public static var description: String { return L10n.tr("Localizable", "watch.labels.complication_text_areas.row1_column1.description") }
          /// Row 1, Column 1
          public static var label: String { return L10n.tr("Localizable", "watch.labels.complication_text_areas.row1_column1.label") }
        }
        public enum Row1Column2 {
          /// The text to display in the second column of the first row.
          public static var description: String { return L10n.tr("Localizable", "watch.labels.complication_text_areas.row1_column2.description") }
          /// Row 1, Column 2
          public static var label: String { return L10n.tr("Localizable", "watch.labels.complication_text_areas.row1_column2.label") }
        }
        public enum Row2Column1 {
          /// The text to display in the first column of the second row.
          public static var description: String { return L10n.tr("Localizable", "watch.labels.complication_text_areas.row2_column1.description") }
          /// Row 2, Column 1
          public static var label: String { return L10n.tr("Localizable", "watch.labels.complication_text_areas.row2_column1.label") }
        }
        public enum Row2Column2 {
          /// The text to display in the second column of the second row.
          public static var description: String { return L10n.tr("Localizable", "watch.labels.complication_text_areas.row2_column2.description") }
          /// Row 2, Column 2
          public static var label: String { return L10n.tr("Localizable", "watch.labels.complication_text_areas.row2_column2.label") }
        }
        public enum Row3Column1 {
          /// The text to display in the first column of the third row.
          public static var description: String { return L10n.tr("Localizable", "watch.labels.complication_text_areas.row3_column1.description") }
          /// Row 3, Column 1
          public static var label: String { return L10n.tr("Localizable", "watch.labels.complication_text_areas.row3_column1.label") }
        }
        public enum Row3Column2 {
          /// The text to display in the second column of the third row.
          public static var description: String { return L10n.tr("Localizable", "watch.labels.complication_text_areas.row3_column2.description") }
          /// Row 3, Column 2
          public static var label: String { return L10n.tr("Localizable", "watch.labels.complication_text_areas.row3_column2.label") }
        }
        public enum Trailing {
          /// The text to display on the trailing edge of the gauge.
          public static var description: String { return L10n.tr("Localizable", "watch.labels.complication_text_areas.trailing.description") }
          /// Trailing
          public static var label: String { return L10n.tr("Localizable", "watch.labels.complication_text_areas.trailing.label") }
        }
      }
    }
  }

  public enum Widgets {
    public enum Actions {
      /// Perform Home Assistant actions.
      public static var description: String { return L10n.tr("Localizable", "widgets.actions.description") }
      /// No Actions Configured
      public static var notConfigured: String { return L10n.tr("Localizable", "widgets.actions.not_configured") }
      /// Actions
      public static var title: String { return L10n.tr("Localizable", "widgets.actions.title") }
    }
    public enum OpenPage {
      /// Open a frontend page in Home Assistant.
      public static var description: String { return L10n.tr("Localizable", "widgets.open_page.description") }
      /// No Pages Available
      public static var notConfigured: String { return L10n.tr("Localizable", "widgets.open_page.not_configured") }
      /// Open Page
      public static var title: String { return L10n.tr("Localizable", "widgets.open_page.title") }
    }
  }
}
// swiftlint:enable explicit_type_interface function_parameter_count identifier_name line_length
// swiftlint:enable nesting type_body_length type_name vertical_whitespace_opening_braces

// MARK: - Implementation Details

extension L10n {
  private static func tr(_ table: String, _ key: String, _ args: CVarArg...) -> String {
    let format = Current.localized.string(key, table)
    return String(format: format, locale: Locale.current, arguments: args)
  }
}
