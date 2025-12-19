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
  /// Close
  public static var closeLabel: String { return L10n.tr("Localizable", "close_label") }
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
  /// OK
  public static var okLabel: String { return L10n.tr("Localizable", "ok_label") }
  /// Open
  public static var openLabel: String { return L10n.tr("Localizable", "open_label") }
  /// Preview Output
  public static var previewOutput: String { return L10n.tr("Localizable", "preview_output") }
  /// Privacy
  public static var privacyLabel: String { return L10n.tr("Localizable", "privacyLabel") }
  /// Requires %@ or later.
  public static func requiresVersion(_ p1: Any) -> String {
    return L10n.tr("Localizable", "requires_version", String(describing: p1))
  }
  /// Retry
  public static var retryLabel: String { return L10n.tr("Localizable", "retry_label") }
  /// Save
  public static var saveLabel: String { return L10n.tr("Localizable", "save_label") }
  /// Unknown
  public static var unknownLabel: String { return L10n.tr("Localizable", "unknownLabel") }
  /// URL
  public static var urlLabel: String { return L10n.tr("Localizable", "url_label") }
  /// Yes
  public static var yesLabel: String { return L10n.tr("Localizable", "yes_label") }

  public enum WebRTCPlayer {
    public enum Experimental {
      /// Note: Native WebRTC video player is currently an experimental feature, audio may not work and microphone permission and usage may be requested even though not in use. Please use the web player interface for advanced options and reliable playback.
      public static var disclaimer: String { return L10n.tr("Localizable", "WebRTC_player.experimental.disclaimer") }
    }
  }

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
      /// Home Assistant
      public static var title: String { return L10n.tr("Localizable", "about.logo.title") }
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
    public enum Action {
      /// Create automation
      public static var createAutomation: String { return L10n.tr("Localizable", "actions_configurator.action.create_automation") }
      /// Define what will be executed when Action is performed, alternatively you can use the example trigger below manually.
      public static var footer: String { return L10n.tr("Localizable", "actions_configurator.action.footer") }
      /// Execute
      public static var title: String { return L10n.tr("Localizable", "actions_configurator.action.title") }
    }
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
    }
  }

  public enum Alert {
    public enum Confirmation {
      public enum DeleteEntities {
        /// This will clean your entities from database and it will only reload the next time you open the app from zero.
        public static var message: String { return L10n.tr("Localizable", "alert.confirmation.delete_entities.message") }
      }
      public enum Generic {
        /// Are you sure?
        public static var title: String { return L10n.tr("Localizable", "alert.confirmation.generic.title") }
      }
    }
  }

  public enum Alerts {
    public enum ActionAutomationEditor {
      public enum Unavailable {
        /// To automatically create an automation for an Action please update your Home Assistant to at least version 2024.2
        public static var body: String { return L10n.tr("Localizable", "alerts.action_automation_editor.unavailable.body") }
        /// Please update Home Assistant
        public static var title: String { return L10n.tr("Localizable", "alerts.action_automation_editor.unavailable.title") }
      }
    }
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
      /// Confirm
      public static var confirm: String { return L10n.tr("Localizable", "alerts.confirm.confirm") }
      /// OK
      public static var ok: String { return L10n.tr("Localizable", "alerts.confirm.ok") }
    }
    public enum Deprecations {
      public enum NotificationCategory {
        /// You must migrate to actions defined in the notification itself before %1$@.
        public static func message(_ p1: Any) -> String {
          return L10n.tr("Localizable", "alerts.deprecations.notification_category.message", String(describing: p1))
        }
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
    }
    public enum Prompt {
    }
  }

  public enum Announcement {
    public enum DropSupport {
    }
  }

  public enum AppIntents {
    public enum Assist {
      public enum Pipeline {
        public enum Default {
        }
      }
      public enum PreferredPipeline {
        /// Preferred
        public static var title: String { return L10n.tr("Localizable", "app_intents.assist.preferred_pipeline.title") }
      }
      public enum RefreshWarning {
        /// Can't find your Assist pipeline? Open Assist in the app to refresh pipelines list.
        public static var title: String { return L10n.tr("Localizable", "app_intents.assist.refresh_warning.title") }
      }
    }
    public enum ClosedStateIcon {
    }
    public enum Controls {
      public enum Assist {
        public enum Parameter {
        }
      }
    }
    public enum Cover {
    }
    public enum Fan {
      public enum OffStateIcon {
      }
      public enum OnStateIcon {
      }
    }
    public enum HapticConfirmation {
    }
    public enum Icon {
    }
    public enum Intent {
      public enum Cover {
      }
      public enum Fan {
      }
      public enum Light {
      }
      public enum Switch {
      }
    }
    public enum Lights {
      public enum Light {
      }
      public enum OffStateIcon {
      }
      public enum OnStateIcon {
      }
    }
    public enum NotifyWhenRun {
    }
    public enum OpenStateIcon {
    }
    public enum PerformAction {
      /// Which action?
      public static var actionParameterConfiguration: String { return L10n.tr("Localizable", "app_intents.perform_action.action_parameter_configuration") }
      /// Just to confirm, you wanted ‘%@’?
      public static func actionParameterConfirmation(_ p1: Any) -> String {
        return L10n.tr("Localizable", "app_intents.perform_action.action_parameter_confirmation", String(describing: p1))
      }
      /// There are %@ options matching ‘%@’.
      public static func actionParameterDisambiguationIntro(_ p1: Any, _ p2: Any) -> String {
        return L10n.tr("Localizable", "app_intents.perform_action.action_parameter_disambiguation_intro", String(describing: p1), String(describing: p2))
      }
      /// Failed: %@
      public static func responseFailure(_ p1: Any) -> String {
        return L10n.tr("Localizable", "app_intents.perform_action.response_failure", String(describing: p1))
      }
    }
    public enum Scenes {
      public enum FailureMessage {
        /// Scene "%@" failed to execute, please check your logs.
        public static func content(_ p1: Any) -> String {
          return L10n.tr("Localizable", "app_intents.scenes.failure_message.content", String(describing: p1))
        }
      }
      public enum Icon {
      }
      public enum Parameter {
        public enum Scene {
        }
      }
      public enum RequiresConfirmationBeforeRun {
      }
      public enum Scene {
      }
      public enum SuccessMessage {
        /// Scene "%@" executed.
        public static func content(_ p1: Any) -> String {
          return L10n.tr("Localizable", "app_intents.scenes.success_message.content", String(describing: p1))
        }
      }
    }
    public enum Scripts {
      public enum FailureMessage {
        /// Script "%@" failed to execute, please check your logs.
        public static func content(_ p1: Any) -> String {
          return L10n.tr("Localizable", "app_intents.scripts.failure_message.content", String(describing: p1))
        }
      }
      public enum HapticConfirmation {
      }
      public enum Icon {
      }
      public enum RequiresConfirmationBeforeRun {
      }
      public enum Script {
      }
      public enum ShowConfirmationDialog {
      }
      public enum SuccessMessage {
        /// Script "%@" executed.
        public static func content(_ p1: Any) -> String {
          return L10n.tr("Localizable", "app_intents.scripts.success_message.content", String(describing: p1))
        }
      }
    }
    public enum ShowConfirmationDialog {
    }
    public enum State {
    }
    public enum Switch {
    }
    public enum WidgetAction {
    }
  }

  public enum Assist {
    public enum Button {
      public enum Listening {
        /// Listening...
        public static var title: String { return L10n.tr("Localizable", "assist.button.listening.title") }
      }
    }
    public enum Error {
      /// Failed to obtain Assist pipelines, please check your pipelines configuration.
      public static var pipelinesResponse: String { return L10n.tr("Localizable", "assist.error.pipelines_response") }
    }
    public enum PipelinesPicker {
      /// Assist Pipelines
      public static var title: String { return L10n.tr("Localizable", "assist.pipelines_picker.title") }
    }
    public enum Watch {
      public enum MicButton {
        /// Tap to
        public static var title: String { return L10n.tr("Localizable", "assist.watch.mic_button.title") }
      }
      public enum NotReachable {
        /// Assist requires iPhone connectivity. Your iPhone is currently unreachable.
        public static var title: String { return L10n.tr("Localizable", "assist.watch.not_reachable.title") }
      }
      public enum Volume {
      }
    }
  }

  public enum AssistPipelinePicker {
    /// No pipelines available
    public static var noPipelines: String { return L10n.tr("Localizable", "assist_pipeline_picker.no_pipelines") }
    /// Pick pipeline
    public static var placeholder: String { return L10n.tr("Localizable", "assist_pipeline_picker.placeholder") }
  }

  public enum CarPlay {
    public enum Action {
      public enum Intro {
        public enum Item {
          /// Tap to continue on your iPhone
          public static var body: String { return L10n.tr("Localizable", "carPlay.action.intro.item.body") }
        }
      }
    }
    public enum Config {
      public enum Tabs {
        /// Tabs
        public static var title: String { return L10n.tr("Localizable", "carPlay.config.tabs.title") }
      }
    }
    public enum Debug {
      public enum DeleteDb {
        public enum Alert {
          /// Are you sure you want to delete CarPlay configuration? This can't be reverted
          public static var title: String { return L10n.tr("Localizable", "carPlay.debug.delete_db.alert.title") }
          public enum Failed {
            /// Failed to delete configuration, error: %@
            public static func message(_ p1: Any) -> String {
              return L10n.tr("Localizable", "carPlay.debug.delete_db.alert.failed.message", String(describing: p1))
            }
          }
        }
        public enum Button {
        }
        public enum Reset {
        }
      }
    }
    public enum Labels {
      public enum Settings {
        public enum Advanced {
          public enum Section {
            public enum Button {
            }
          }
        }
      }
      public enum Tab {
      }
    }
    public enum Lock {
      public enum Confirmation {
        /// Are you sure you want to perform lock action on %@?
        public static func title(_ p1: Any) -> String {
          return L10n.tr("Localizable", "carPlay.lock.confirmation.title", String(describing: p1))
        }
      }
    }
    public enum Navigation {
      public enum Button {
      }
      public enum Tab {
      }
    }
    public enum NoActions {
    }
    public enum NoEntities {
    }
    public enum Notification {
      public enum Action {
        public enum Intro {
        }
      }
      public enum QuickAccess {
        public enum Intro {
        }
      }
    }
    public enum QuickAccess {
      public enum Intro {
        public enum Item {
        }
      }
    }
    public enum State {
      public enum Loading {
      }
    }
    public enum Tabs {
      public enum Active {
        public enum DeleteAction {
        }
      }
      public enum Inactive {
      }
    }
    public enum Unlock {
      public enum Confirmation {
        /// Are you sure you want to perform unlock action on %@?
        public static func title(_ p1: Any) -> String {
          return L10n.tr("Localizable", "carPlay.unlock.confirmation.title", String(describing: p1))
        }
      }
    }
  }

  public enum Carplay {
    public enum Labels {
    }
    public enum Lock {
      public enum Confirmation {
        /// Are you sure you want to perform lock action on %@?
        public static func title(_ p1: Any) -> String {
          return L10n.tr("Localizable", "carplay.lock.confirmation.title", String(describing: p1))
        }
      }
    }
    public enum Navigation {
      public enum Button {
      }
    }
    public enum Unlock {
      public enum Confirmation {
        /// Are you sure you want to perform unlock action on %@?
        public static func title(_ p1: Any) -> String {
          return L10n.tr("Localizable", "carplay.unlock.confirmation.title", String(describing: p1))
        }
      }
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
    /// No events
    public static var noEvents: String { return L10n.tr("Localizable", "client_events.no_events") }
    public enum EventType {
      /// All
      public static var all: String { return L10n.tr("Localizable", "client_events.event_type.all") }
      /// Background operation
      public static var backgroundOperation: String { return L10n.tr("Localizable", "client_events.event_type.background_operation") }
      /// Database
      public static var database: String { return L10n.tr("Localizable", "client_events.event_type.database") }
      /// Location Update
      public static var locationUpdate: String { return L10n.tr("Localizable", "client_events.event_type.location_update") }
      /// Network Request
      public static var networkRequest: String { return L10n.tr("Localizable", "client_events.event_type.networkRequest") }
      /// Notification
      public static var notification: String { return L10n.tr("Localizable", "client_events.event_type.notification") }
      /// Service Call
      public static var serviceCall: String { return L10n.tr("Localizable", "client_events.event_type.service_call") }
      /// Settings
      public static var settings: String { return L10n.tr("Localizable", "client_events.event_type.settings") }
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
      public enum ClearConfirm {
      }
    }
  }

  public enum Component {
    public enum CollapsibleView {
      /// Collapse
      public static var collapse: String { return L10n.tr("Localizable", "component.collapsible_view.collapse") }
    }
  }

  public enum Connection {
    public enum Error {
      /// Uh oh! Looks like we are unable to establish a connection.
      public static var genericTitle: String { return L10n.tr("Localizable", "connection.error.generic_title") }
      public enum Details {
        public enum Button {
          /// Copy to clipboard
          public static var clipboard: String { return L10n.tr("Localizable", "connection.error.details.button.clipboard") }
          /// Ask in Discord
          public static var discord: String { return L10n.tr("Localizable", "connection.error.details.button.discord") }
          /// Read documentation
          public static var doc: String { return L10n.tr("Localizable", "connection.error.details.button.doc") }
          /// Search in GitHub
          public static var searchGithub: String { return L10n.tr("Localizable", "connection.error.details.button.search_github") }
        }
        public enum Label {
          /// Code
          public static var code: String { return L10n.tr("Localizable", "connection.error.details.label.code") }
          /// Description
          public static var description: String { return L10n.tr("Localizable", "connection.error.details.label.description") }
          /// Domain
          public static var domain: String { return L10n.tr("Localizable", "connection.error.details.label.domain") }
        }
      }
      public enum FailedConnect {
        /// Check your connection and try again. If you are not at home make sure you have configured remote access.
        public static var subtitle: String { return L10n.tr("Localizable", "connection.error.failed_connect.subtitle") }
        /// We couldn't connect to Home Assistant
        public static var title: String { return L10n.tr("Localizable", "connection.error.failed_connect.title") }
        /// The app is currently connecting to
        public static var url: String { return L10n.tr("Localizable", "connection.error.failed_connect.url") }
        public enum Cloud {
        }
        public enum CloudInactive {
          /// You have disabled Home Assistant Cloud use in the app, if you need it for remote access please open companion app settings and enable it.
          public static var title: String { return L10n.tr("Localizable", "connection.error.failed_connect.cloud_inactive.title") }
        }
      }
    }
    public enum Permission {
      public enum InternalUrl {
        public enum Ignore {
          public enum Alert {
          }
        }
      }
    }
  }

  public enum ConnectionError {
    public enum AdvancedSection {
    }
    public enum MoreDetailsSection {
      /// More details
      public static var title: String { return L10n.tr("Localizable", "connection_error.more_details_section.title") }
    }
    public enum OpenSettings {
      /// Open settings
      public static var title: String { return L10n.tr("Localizable", "connection_error.open_settings.title") }
    }
  }

  public enum ConnectionSecurityLevelBlock {
    /// Due to your connection security choice ('Most secure'), there's no URL that we are allowed to use.
    public static var body: String { return L10n.tr("Localizable", "connection_security_level_block.body") }
    /// You're disconnected
    public static var title: String { return L10n.tr("Localizable", "connection_security_level_block.title") }
    public enum ChangePreference {
      /// Change connection preference
      public static var title: String { return L10n.tr("Localizable", "connection_security_level_block.change_preference.title") }
    }
    public enum OpenSettings {
      /// Open settings
      public static var title: String { return L10n.tr("Localizable", "connection_security_level_block.open_settings.title") }
    }
    public enum Requirement {
      /// Missing requirements
      public static var title: String { return L10n.tr("Localizable", "connection_security_level_block.requirement.title") }
      public enum HomeNetworkMissing {
        /// Configure local network
        public static var title: String { return L10n.tr("Localizable", "connection_security_level_block.requirement.home_network_missing.title") }
      }
      public enum LearnMore {
        /// Learn more
        public static var title: String { return L10n.tr("Localizable", "connection_security_level_block.requirement.learn_more.title") }
      }
      public enum LocationPermissionMissing {
        /// Grant location permission
        public static var title: String { return L10n.tr("Localizable", "connection_security_level_block.requirement.location_permission_missing.title") }
      }
      public enum NotOnHomeNetwork {
        /// Connect to your home network
        public static var title: String { return L10n.tr("Localizable", "connection_security_level_block.requirement.not_on_home_network.title") }
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

  public enum Debug {
    public enum Reset {
      public enum EntitiesDatabase {
        /// Reset app entities database
        public static var title: String { return L10n.tr("Localizable", "debug.reset.entities_database.title") }
      }
    }
  }

  public enum DeviceName {
    /// This is used to identify your device in your Home Assistant.
    public static var subtitle: String { return L10n.tr("Localizable", "device_name.subtitle") }
    /// How would you like to name this device?
    public static var title: String { return L10n.tr("Localizable", "device_name.title") }
    public enum PrimaryButton {
      /// Save
      public static var title: String { return L10n.tr("Localizable", "device_name.primary_button.title") }
    }
    public enum Textfield {
      /// iPhone/iPad/Mac name
      public static var placeholder: String { return L10n.tr("Localizable", "device_name.textfield.placeholder") }
    }
  }

  public enum DownloadManager {
    public enum Downloading {
      /// Downloading
      public static var title: String { return L10n.tr("Localizable", "download_manager.downloading.title") }
    }
    public enum Failed {
      /// Failed to download file, error: %@
      public static func title(_ p1: Any) -> String {
        return L10n.tr("Localizable", "download_manager.failed.title", String(describing: p1))
      }
    }
    public enum Finished {
    }
  }

  public enum EntityPicker {
    /// Pick entity
    public static var placeholder: String { return L10n.tr("Localizable", "entity_picker.placeholder") }
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
          /// Got non-200 status code (%li)
          public static func other(_ p1: Int) -> String {
            return L10n.tr("Localizable", "extensions.notification_content.error.request.other", p1)
          }
        }
      }
    }
  }

  public enum Gestures {
    public enum _1Finger {
      /// Using one finger
      public static var title: String { return L10n.tr("Localizable", "gestures.1_finger.title") }
    }
    public enum _2Fingers {
      /// Using two fingers
      public static var title: String { return L10n.tr("Localizable", "gestures.2_fingers.title") }
    }
    public enum _2FingersSwipeDown {
    }
    public enum _2FingersSwipeLeft {
    }
    public enum _2FingersSwipeRight {
    }
    public enum _2FingersSwipeUp {
    }
    public enum _3Fingers {
      /// Using three fingers
      public static var title: String { return L10n.tr("Localizable", "gestures.3_fingers.title") }
    }
    public enum _3FingersSwipeDown {
    }
    public enum _3FingersSwipeLeft {
    }
    public enum _3FingersSwipeRight {
    }
    public enum _3FingersSwipeUp {
    }
    public enum Category {
      /// App
      public static var app: String { return L10n.tr("Localizable", "gestures.category.app") }
      /// Home Assistant
      public static var homeAssistant: String { return L10n.tr("Localizable", "gestures.category.homeAssistant") }
      /// Other
      public static var other: String { return L10n.tr("Localizable", "gestures.category.other") }
      /// Navigation
      public static var page: String { return L10n.tr("Localizable", "gestures.category.page") }
      /// Servers
      public static var servers: String { return L10n.tr("Localizable", "gestures.category.servers") }
    }
    public enum Footer {
    }
    public enum Reset {
      /// Reset
      public static var title: String { return L10n.tr("Localizable", "gestures.reset.title") }
    }
    public enum Screen {
      /// Gestures below will be applied whenever you are using Home Assistant main UI.
      public static var body: String { return L10n.tr("Localizable", "gestures.screen.body") }
      /// Gestures
      public static var title: String { return L10n.tr("Localizable", "gestures.screen.title") }
    }
    public enum Shake {
      /// Shake
      public static var title: String { return L10n.tr("Localizable", "gestures.shake.title") }
    }
    public enum Swipe {
      public enum Down {
        /// Swipe down
        public static var header: String { return L10n.tr("Localizable", "gestures.swipe.down.header") }
      }
      public enum Left {
        /// Swipe left
        public static var header: String { return L10n.tr("Localizable", "gestures.swipe.left.header") }
      }
      public enum Right {
        /// Swipe right
        public static var header: String { return L10n.tr("Localizable", "gestures.swipe.right.header") }
      }
      public enum Up {
        /// Swipe up
        public static var header: String { return L10n.tr("Localizable", "gestures.swipe.up.header") }
      }
    }
    public enum SwipeLeft {
    }
    public enum SwipeRight {
    }
    public enum Value {
      public enum Option {
        /// Open Assist
        public static var assist: String { return L10n.tr("Localizable", "gestures.value.option.assist") }
        /// Back to previous page
        public static var backPage: String { return L10n.tr("Localizable", "gestures.value.option.back_page") }
        /// Go to next page
        public static var nextPage: String { return L10n.tr("Localizable", "gestures.value.option.next_page") }
        /// Next server
        public static var nextServer: String { return L10n.tr("Localizable", "gestures.value.option.next_server") }
        /// None
        public static var `none`: String { return L10n.tr("Localizable", "gestures.value.option.none") }
        /// Open debug
        public static var openDebug: String { return L10n.tr("Localizable", "gestures.value.option.open_debug") }
        /// Previous server
        public static var previousServer: String { return L10n.tr("Localizable", "gestures.value.option.previous_server") }
        /// Search commands
        public static var searchCommands: String { return L10n.tr("Localizable", "gestures.value.option.search_commands") }
        /// Search devices
        public static var searchDevices: String { return L10n.tr("Localizable", "gestures.value.option.search_devices") }
        /// Search entities
        public static var searchEntities: String { return L10n.tr("Localizable", "gestures.value.option.search_entities") }
        /// Servers list
        public static var serversList: String { return L10n.tr("Localizable", "gestures.value.option.servers_list") }
        /// Open App settings
        public static var showSettings: String { return L10n.tr("Localizable", "gestures.value.option.show_settings") }
        /// Show sidebar
        public static var showSidebar: String { return L10n.tr("Localizable", "gestures.value.option.show_sidebar") }
        public enum MoreInfo {
          /// Search commands
          public static var searchCommands: String { return L10n.tr("Localizable", "gestures.value.option.more_info.search_commands") }
          /// Search devices
          public static var searchDevices: String { return L10n.tr("Localizable", "gestures.value.option.more_info.search_devices") }
          /// Search entities
          public static var searchEntities: String { return L10n.tr("Localizable", "gestures.value.option.more_info.search_entities") }
        }
      }
    }
  }

  public enum Grdb {
    public enum Config {
      public enum MigrationError {
        /// Failed to access database (GRDB), error: %@
        public static func failedAccessGrdb(_ p1: Any) -> String {
          return L10n.tr("Localizable", "grdb.config.migration_error.failed_access_grdb", String(describing: p1))
        }
        /// Failed to save new config, error: %@
        public static func failedToSave(_ p1: Any) -> String {
          return L10n.tr("Localizable", "grdb.config.migration_error.failed_to_save", String(describing: p1))
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
      /// Unacceptable status code %1$li.
      public static func unacceptableStatusCode(_ p1: Int) -> String {
        return L10n.tr("Localizable", "ha_api.api_error.unacceptable_status_code", p1)
      }
      /// Received response with result of type %1$@ but expected type %2$@.
      public static func unexpectedType(_ p1: Any, _ p2: Any) -> String {
        return L10n.tr("Localizable", "ha_api.api_error.unexpected_type", String(describing: p1), String(describing: p2))
      }
    }
  }

  public enum Improv {
    public enum Button {
      /// Continue
      public static var `continue`: String { return L10n.tr("Localizable", "improv.button.continue") }
    }
    public enum ConnectionState {
      /// Setting up Wi-Fi
      public static var authorized: String { return L10n.tr("Localizable", "improv.connection_state.authorized") }
      /// Connecting to Wi-Fi
      public static var provisioning: String { return L10n.tr("Localizable", "improv.connection_state.provisioning") }
    }
    public enum ErrorState {
      /// Invalid RPC Packet
      public static var invalidRpcPacket: String { return L10n.tr("Localizable", "improv.error_state.invalid_rpc_packet") }
      /// Not authorized
      public static var notAuthorized: String { return L10n.tr("Localizable", "improv.error_state.not_authorized") }
      /// Unable to connect
      public static var unableToConnect: String { return L10n.tr("Localizable", "improv.error_state.unable_to_connect") }
      /// Unknown error, please try again.
      public static var unknown: String { return L10n.tr("Localizable", "improv.error_state.unknown") }
      /// Unknown command
      public static var unknownCommand: String { return L10n.tr("Localizable", "improv.error_state.unknown_command") }
    }
    public enum List {
      /// Devices ready to set up
      public static var title: String { return L10n.tr("Localizable", "improv.list.title") }
    }
    public enum State {
      /// Connected
      public static var connected: String { return L10n.tr("Localizable", "improv.state.connected") }
      /// Connecting...
      public static var connecting: String { return L10n.tr("Localizable", "improv.state.connecting") }
      /// Wi-Fi connected successfully
      public static var success: String { return L10n.tr("Localizable", "improv.state.success") }
    }
    public enum Toast {
    }
    public enum Wifi {
      public enum Alert {
        /// Cancel
        public static var cancelButton: String { return L10n.tr("Localizable", "improv.wifi.alert.cancel_button") }
        /// Connect
        public static var connectButton: String { return L10n.tr("Localizable", "improv.wifi.alert.connect_button") }
        /// Please enter your SSID and password.
        public static var description: String { return L10n.tr("Localizable", "improv.wifi.alert.description") }
        /// Password
        public static var passwordPlaceholder: String { return L10n.tr("Localizable", "improv.wifi.alert.password_placeholder") }
        /// Network Name
        public static var ssidPlaceholder: String { return L10n.tr("Localizable", "improv.wifi.alert.ssid_placeholder") }
        /// Connect to WiFi
        public static var title: String { return L10n.tr("Localizable", "improv.wifi.alert.title") }
      }
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
    }
    public enum Manual {
    }
    public enum Periodic {
    }
    public enum PushNotification {
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
    }
    public enum SignificantLocationUpdate {
    }
    public enum Siri {
    }
    public enum Unknown {
    }
    public enum UrlScheme {
    }
    public enum Visit {
    }
    public enum WatchContext {
    }
    public enum XCallbackUrl {
    }
  }

  public enum Mac {
    public enum Copy {
      /// Copy
      public static var accessibilityLabel: String { return L10n.tr("Localizable", "mac.copy.accessibility_label") }
    }
    public enum Navigation {
      public enum GoBack {
        /// Navigate back
        public static var accessibilityLabel: String { return L10n.tr("Localizable", "mac.navigation.go_back.accessibility_label") }
      }
      public enum GoForward {
        /// Navigate forward
        public static var accessibilityLabel: String { return L10n.tr("Localizable", "mac.navigation.go_forward.accessibility_label") }
      }
    }
    public enum Paste {
      /// Paste
      public static var accessibilityLabel: String { return L10n.tr("Localizable", "mac.paste.accessibility_label") }
    }
  }

  public enum MagicItem {
    /// Action
    public static var action: String { return L10n.tr("Localizable", "magic_item.action") }
    /// Add
    public static var add: String { return L10n.tr("Localizable", "magic_item.add") }
    /// Save
    public static var edit: String { return L10n.tr("Localizable", "magic_item.edit") }
    public enum Action {
      /// On tap
      public static var onTap: String { return L10n.tr("Localizable", "magic_item.action.on_tap") }
      public enum Assist {
        /// Assist
        public static var title: String { return L10n.tr("Localizable", "magic_item.action.assist.title") }
        public enum Pipeline {
          /// Pipeline
          public static var title: String { return L10n.tr("Localizable", "magic_item.action.assist.pipeline.title") }
        }
        public enum StartListening {
          /// Start listening
          public static var title: String { return L10n.tr("Localizable", "magic_item.action.assist.start_listening.title") }
        }
      }
      public enum NavigationPath {
        /// e.g. /lovelace/cameras
        public static var placeholder: String { return L10n.tr("Localizable", "magic_item.action.navigation_path.placeholder") }
        /// Navigation path
        public static var title: String { return L10n.tr("Localizable", "magic_item.action.navigation_path.title") }
      }
      public enum Script {
        /// Script
        public static var title: String { return L10n.tr("Localizable", "magic_item.action.script.title") }
      }
    }
    public enum BackgroundColor {
      /// Background color
      public static var title: String { return L10n.tr("Localizable", "magic_item.background_color.title") }
    }
    public enum DisplayText {
      /// Display text
      public static var title: String { return L10n.tr("Localizable", "magic_item.display_text.title") }
    }
    public enum IconColor {
      /// Icon color
      public static var title: String { return L10n.tr("Localizable", "magic_item.icon_color.title") }
    }
    public enum IconName {
    }
    public enum ItemType {
      public enum Action {
        public enum List {
          /// iOS Actions
          public static var title: String { return L10n.tr("Localizable", "magic_item.item_type.action.list.title") }
          public enum Warning {
            /// We will stop supporting iOS Actions in the future, please consider using Home Assistant scripts or scenes instead.
            public static var title: String { return L10n.tr("Localizable", "magic_item.item_type.action.list.warning.title") }
          }
        }
      }
      public enum App {
        public enum List {
        }
      }
      public enum Entity {
        public enum List {
          /// Entity
          public static var title: String { return L10n.tr("Localizable", "magic_item.item_type.entity.list.title") }
        }
      }
      public enum Scene {
        public enum List {
          /// Scenes
          public static var title: String { return L10n.tr("Localizable", "magic_item.item_type.scene.list.title") }
        }
      }
      public enum Script {
        public enum List {
          /// Scripts
          public static var title: String { return L10n.tr("Localizable", "magic_item.item_type.script.list.title") }
        }
      }
      public enum Selection {
        public enum List {
          /// Item type
          public static var title: String { return L10n.tr("Localizable", "magic_item.item_type.selection.list.title") }
        }
      }
    }
    public enum Name {
    }
    public enum NameAndIcon {
      public enum Footer {
      }
    }
    public enum RequireConfirmation {
      /// Require confirmation
      public static var title: String { return L10n.tr("Localizable", "magic_item.require_confirmation.title") }
    }
    public enum TextColor {
      /// Text color
      public static var title: String { return L10n.tr("Localizable", "magic_item.text_color.title") }
    }
    public enum UseCustomColors {
      /// Use custom colors
      public static var title: String { return L10n.tr("Localizable", "magic_item.use_custom_colors.title") }
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
    }
    public enum File {
    }
    public enum Help {
      /// %@ Help
      public static func help(_ p1: Any) -> String {
        return L10n.tr("Localizable", "menu.help.help", String(describing: p1))
      }
    }
    public enum StatusItem {
      /// Toggle %1$@
      public static func toggle(_ p1: Any) -> String {
        return L10n.tr("Localizable", "menu.status_item.toggle", String(describing: p1))
      }
    }
    public enum View {
    }
  }

  public enum NavBar {
  }

  public enum Network {
    public enum Error {
      public enum NoActiveUrl {
      }
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
      }
    }
    public enum Write {
      /// Hold your %@ near a writable NFC tag
      public static func startMessage(_ p1: Any) -> String {
        return L10n.tr("Localizable", "nfc.write.start_message", String(describing: p1))
      }
      public enum Error {
        /// NFC tag has insufficient capacity: needs %ld but only has %ld
        public static func capacity(_ p1: Int, _ p2: Int) -> String {
          return L10n.tr("Localizable", "nfc.write.error.capacity", p1, p2)
        }
      }
      public enum IdentifierChoice {
      }
      public enum ManualInput {
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
      }
      public enum Rows {
        public enum Actions {
        }
        public enum CategorySummary {
          /// %%u notifications in %%@
          public static var `default`: String { return L10n.tr("Localizable", "notifications_configurator.category.rows.category_summary.default") }
        }
        public enum HiddenPreviewPlaceholder {
          /// %%u notifications
          public static var `default`: String { return L10n.tr("Localizable", "notifications_configurator.category.rows.hidden_preview_placeholder.default") }
        }
        public enum Name {
        }
      }
    }
    public enum NewAction {
    }
    public enum Settings {
      public enum Footer {
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
      }
    }
    public enum ConnectionError {
    }
    public enum ConnectionTestResult {
      public enum AuthenticationUnsupported {
        /// Authentication type is unsupported%@.
        public static func description(_ p1: Any) -> String {
          return L10n.tr("Localizable", "onboarding.connection_test_result.authentication_unsupported.description", String(describing: p1))
        }
      }
      public enum BasicAuth {
      }
      public enum CertificateError {
      }
      public enum ClientCertificate {
      }
      public enum LocalNetworkPermission {
      }
    }
    public enum DeviceNameCheck {
      public enum Error {
        /// A device already exists with the name '%1$@'
        public static func title(_ p1: Any) -> String {
          return L10n.tr("Localizable", "onboarding.device_name_check.error.title", String(describing: p1))
        }
      }
    }
    public enum Invitation {
    }
    public enum LocalAccess {
      public enum LessSecureOption {
      }
      public enum SecureOption {
      }
    }
    public enum LocalOnlyDisclaimer {
      /// Local by default.
      public enum PrimaryButton {
      }
    }
    public enum LocationAccess {
      public enum PrimaryAction {
      }
      public enum SecondaryAction {
      }
    }
    public enum ManualSetup {
      public enum CouldntMakeUrl {
        /// The value '%@' was not a valid URL.
        public static func message(_ p1: Any) -> String {
          return L10n.tr("Localizable", "onboarding.manual_setup.couldnt_make_url.message", String(describing: p1))
        }
      }
      public enum HelperSection {
      }
      public enum InputError {
      }
      public enum NoScheme {
      }
      public enum TextField {
      }
    }
    public enum ManualUrlEntry {
      public enum PrimaryAction {
      }
    }
    public enum NetworkInput {
      public enum Disclaimer {
      }
      public enum Hardware {
        public enum InputField {
        }
      }
      public enum InputField {
      }
      public enum NoNetwork {
        public enum Alert {
        }
        public enum Skip {
          public enum Alert {
            public enum PrimaryButton {
            }
            public enum SecondaryButton {
            }
          }
        }
      }
      public enum PrimaryButton {
      }
      public enum SecondaryButton {
      }
    }
    public enum Permission {
      public enum Location {
        public enum Buttons {
        }
        public enum Deny {
          public enum Alert {
          }
        }
      }
    }
    public enum Permissions {
      public enum Focus {
        public enum Bullet {
        }
      }
      public enum Location {
        public enum Bullet {
        }
      }
      public enum Motion {
        public enum Bullet {
        }
      }
      public enum Notification {
        public enum Bullet {
        }
      }
    }
    public enum Scanning {
      /// Discovered: %@
      public static func discoveredAnnouncement(_ p1: Any) -> String {
        return L10n.tr("Localizable", "onboarding.scanning.discovered_announcement", String(describing: p1))
      }
      public enum Manual {
        public enum Button {
          public enum Divider {
          }
        }
      }
    }
    public enum Servers {
      public enum AutoConnect {
      }
      public enum Docs {
      }
      public enum Search {
        public enum Loader {
        }
      }
    }
    public enum Welcome {
      /// This app connects to your Home Assistant server and allows integrating data about you and your phone.
      /// 
      /// Welcome to Home Assistant %@!
      public static func title(_ p1: Any) -> String {
        return L10n.tr("Localizable", "onboarding.welcome.title", String(describing: p1))
      }
      public enum Logo {
      }
      public enum Updated {
        /// Access your Home Assistant server on the go. 
        /// 
      }
    }
  }

  public enum Permission {
    public enum Notification {
      /// Enable notifications and get what's happening in your home, from detecting leaks to doors left open, you have full control over what it tells you.
      public static var body: String { return L10n.tr("Localizable", "permission.notification.body") }
      /// Allow notifications
      public static var primaryButton: String { return L10n.tr("Localizable", "permission.notification.primary_button") }
      /// Do not allow
      public static var secondaryButton: String { return L10n.tr("Localizable", "permission.notification.secondary_button") }
      /// Allow notifications?
      public static var title: String { return L10n.tr("Localizable", "permission.notification.title") }
    }
    public enum Screen {
      public enum Bluetooth {
        /// Skip
        public static var secondaryButton: String { return L10n.tr("Localizable", "permission.screen.bluetooth.secondary_button") }
        /// The Home Assistant app can find devices using Bluetooth of this device. Allow Bluetooth access for the Home Assistant app.
        public static var subtitle: String { return L10n.tr("Localizable", "permission.screen.bluetooth.subtitle") }
        /// Search devices
        public static var title: String { return L10n.tr("Localizable", "permission.screen.bluetooth.title") }
      }
    }
  }

  public enum PostOnboarding {
    public enum Permission {
      public enum Notification {
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

  public enum ServersSelection {
    /// Servers
    public static var title: String { return L10n.tr("Localizable", "servers_selection.title") }
  }

  public enum Settings {
    public enum ConnectionSection {
      /// Activate
      public static var activateServer: String { return L10n.tr("Localizable", "settings.connection_section.activate_server") }
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
      /// Directly connect to the Home Assistant server for push notifications when on internal SSIDs.
      public static var localPushDescription: String { return L10n.tr("Localizable", "settings.connection_section.local_push_description") }
      /// Logged in as
      public static var loggedInAs: String { return L10n.tr("Localizable", "settings.connection_section.logged_in_as") }
      /// Servers
      public static var servers: String { return L10n.tr("Localizable", "settings.connection_section.servers") }
      /// Reorder to define default server
      public static var serversFooter: String { return L10n.tr("Localizable", "settings.connection_section.servers_footer") }
      /// Servers
      public static var serversHeader: String { return L10n.tr("Localizable", "settings.connection_section.servers_header") }
      /// Accessing SSIDs in the background requires 'Always' location permission and 'Full' location accuracy. Tap here to change your settings.
      public static var ssidPermissionAndAccuracyMessage: String { return L10n.tr("Localizable", "settings.connection_section.ssid_permission_and_accuracy_message") }
      public enum AlwaysFallbackInternal {
        public enum Confirmation {
        }
      }
      public enum ConnectionAccessSecurityLevel {
        /// Connection security level
        public static var title: String { return L10n.tr("Localizable", "settings.connection_section.connection_access_security_level.title") }
        public enum LessSecure {
          /// Less secure
          public static var title: String { return L10n.tr("Localizable", "settings.connection_section.connection_access_security_level.less_secure.title") }
        }
        public enum MostSecure {
          /// Most secure
          public static var title: String { return L10n.tr("Localizable", "settings.connection_section.connection_access_security_level.most_secure.title") }
        }
        public enum Undefined {
          /// Not configured
          public static var title: String { return L10n.tr("Localizable", "settings.connection_section.connection_access_security_level.undefined.title") }
        }
      }
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
        public enum RequiresSetup {
        }
        public enum SsidBssidRequired {
        }
        public enum SsidRequired {
        }
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
      public enum LocalAccessSecurityLevel {
        public enum LessSecure {
        }
        public enum MostSecure {
        }
        public enum Undefined {
        }
      }
      public enum LocationSendType {
        /// Location Sent
        public static var title: String { return L10n.tr("Localizable", "settings.connection_section.location_send_type.title") }
        public enum Setting {
          /// Exact
          public static var exact: String { return L10n.tr("Localizable", "settings.connection_section.location_send_type.setting.exact") }
          /// Never
          public static var never: String { return L10n.tr("Localizable", "settings.connection_section.location_send_type.setting.never") }
          /// Zone only
          public static var zoneOnly: String { return L10n.tr("Localizable", "settings.connection_section.location_send_type.setting.zone_only") }
        }
      }
      public enum NoBaseUrl {
        /// No URL
        public static var title: String { return L10n.tr("Localizable", "settings.connection_section.no_base_url.title") }
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
          }
          public enum Rejected {
          }
        }
      }
    }
    public enum Debugging {
      public enum CriticalSection {
      }
      public enum Header {
      }
      public enum ShakeDisclaimer {
      }
      public enum ShakeDisclaimerOptional {
      }
      public enum Thread {
      }
    }
    public enum DetailsSection {
      public enum LocationSettingsRow {
      }
      public enum NotificationSettingsRow {
      }
      public enum WatchRow {
      }
      public enum WatchRowComplications {
      }
      public enum WatchRowConfiguration {
      }
    }
    public enum Developer {
      public enum AnnoyingBackgroundNotifications {
      }
      public enum CameraNotification {
        public enum Notification {
        }
      }
      public enum CopyRealm {
        public enum Alert {
          /// Copied Realm from %@ to %@
          public static func message(_ p1: Any, _ p2: Any) -> String {
            return L10n.tr("Localizable", "settings.developer.copy_realm.alert.message", String(describing: p1), String(describing: p2))
          }
        }
      }
      public enum CrashlyticsTest {
        public enum Fatal {
          public enum Notification {
          }
        }
        public enum NonFatal {
          public enum Notification {
          }
        }
      }
      public enum DebugStrings {
      }
      public enum ExportLogFiles {
      }
      public enum MapNotification {
        public enum Notification {
        }
      }
      public enum MockThreadCredentialsSharing {
      }
      public enum ShowLogFiles {
      }
      public enum SyncWatchContext {
      }
    }
    public enum EventLog {
    }
    public enum LocationHistory {
      public enum Detail {
      }
    }
    public enum NavigationBar {
      public enum AboutButton {
      }
    }
    public enum ResetSection {
      public enum ResetAlert {
      }
      public enum ResetApp {
      }
      public enum ResetRow {
      }
      public enum ResetWebCache {
      }
    }
    public enum ServerSelect {
    }
    public enum StatusSection {
      public enum LocationNameRow {
      }
      public enum VersionRow {
      }
    }
    public enum TemplateEdit {
    }
    public enum WhatsNew {
    }
    public enum Widgets {
      public enum Create {
        public enum AddItem {
        }
        public enum Footer {
        }
        public enum Items {
        }
        public enum Name {
        }
        public enum NoItems {
        }
      }
      public enum Custom {
        public enum DeleteAll {
        }
      }
      public enum YourWidgets {
      }
    }
  }

  public enum SettingsDetails {
    /// Learn more
    public static var learnMore: String { return L10n.tr("Localizable", "settings_details.learn_more") }
    public enum Actions {
      /// Actions are used in the Apple Watch app, App Icon Actions, the Today widget and CarPlay.
      public static var footer: String { return L10n.tr("Localizable", "settings_details.actions.footer") }
      /// Actions are used in the application menu and widgets.
      public static var footerMac: String { return L10n.tr("Localizable", "settings_details.actions.footer_mac") }
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
      public enum CarPlay {
        public enum Available {
        }
      }
      public enum Learn {
        public enum Button {
          /// Introduction to iOS Actions
          public static var title: String { return L10n.tr("Localizable", "settings_details.actions.learn.button.title") }
        }
      }
      public enum Scenes {
        /// Customize
        public static var customizeAction: String { return L10n.tr("Localizable", "settings_details.actions.scenes.customize_action") }
      }
      public enum ServerControlled {
        public enum Update {
          /// Update server Actions
          public static var title: String { return L10n.tr("Localizable", "settings_details.actions.server_controlled.update.title") }
        }
      }
      public enum UseCustomColors {
        /// Use custom colors
        public static var title: String { return L10n.tr("Localizable", "settings_details.actions.use_custom_colors.title") }
      }
      public enum Watch {
        public enum Available {
        }
      }
    }
    public enum General {
      /// Basic App configuration, App Icon and web page settings.
      public static var body: String { return L10n.tr("Localizable", "settings_details.general.body") }
      /// General
      public static var title: String { return L10n.tr("Localizable", "settings_details.general.title") }
      public enum AppIcon {
        /// App Icon
        public static var title: String { return L10n.tr("Localizable", "settings_details.general.app_icon.title") }
        public enum CurrentSelected {
          /// - Selected
          public static var title: String { return L10n.tr("Localizable", "settings_details.general.app_icon.current_selected.title") }
        }
        public enum Enum {
          /// Beta
          public static var beta: String { return L10n.tr("Localizable", "settings_details.general.app_icon.enum.beta") }
          /// Black
          public static var black: String { return L10n.tr("Localizable", "settings_details.general.app_icon.enum.black") }
          /// Blue
          public static var blue: String { return L10n.tr("Localizable", "settings_details.general.app_icon.enum.blue") }
          /// Caribbean Green
          public static var caribbeanGreen: String { return L10n.tr("Localizable", "settings_details.general.app_icon.enum.caribbean_green") }
          /// Classic
          public static var classic: String { return L10n.tr("Localizable", "settings_details.general.app_icon.enum.classic") }
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
          /// Pride: Non Binary
          public static var prideNonBinary: String { return L10n.tr("Localizable", "settings_details.general.app_icon.enum.pride_non_binary") }
          /// Pride: 8-Color
          public static var pridePoc: String { return L10n.tr("Localizable", "settings_details.general.app_icon.enum.pride_poc") }
          /// Pride: Rainbow
          public static var prideRainbow: String { return L10n.tr("Localizable", "settings_details.general.app_icon.enum.pride_rainbow") }
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
        public enum Explanation {
          /// Each icon has 3 variants (iOS 18+), default, dark and tinted to react according to the selected iOS home screen style. Some icons are the same in dark mode or handled automatically by iOS.
          public static var title: String { return L10n.tr("Localizable", "settings_details.general.app_icon.explanation.title") }
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
      public enum Links {
        /// Links
        public static var title: String { return L10n.tr("Localizable", "settings_details.general.links.title") }
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
        /// Apple Safari (in app)
        public static var safariInApp: String { return L10n.tr("Localizable", "settings_details.general.open_in_browser.safari_in_app") }
        /// Open Links In
        public static var title: String { return L10n.tr("Localizable", "settings_details.general.open_in_browser.title") }
      }
      public enum OpenInPrivateTab {
        /// Open in Private Tab
        public static var title: String { return L10n.tr("Localizable", "settings_details.general.open_in_private_tab.title") }
      }
      public enum Page {
        /// Page
        public static var title: String { return L10n.tr("Localizable", "settings_details.general.page.title") }
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
      }
      public enum Restoration {
      }
      public enum Visibility {
        public enum Options {
        }
      }
    }
    public enum Http {
      public enum Warning {
      }
    }
    public enum LegacyActions {
    }
    public enum Location {
      public enum BackgroundRefresh {
      }
      public enum FocusPermission {
      }
      public enum LocationAccuracy {
      }
      public enum LocationPermission {
      }
      public enum MotionPermission {
      }
      public enum Notifications {
        public enum BackgroundFetch {
        }
        public enum BeaconEnter {
        }
        public enum BeaconExit {
        }
        public enum Enter {
        }
        public enum Exit {
        }
        public enum LocationChange {
        }
        public enum PushNotification {
        }
        public enum UrlScheme {
        }
        public enum XCallbackUrl {
        }
      }
      public enum Updates {
        public enum Background {
        }
        public enum Notification {
        }
        public enum Significant {
        }
        public enum Zone {
        }
      }
      public enum Zones {
        public enum Beacon {
          public enum PropNotSet {
          }
        }
        public enum BeaconMajor {
        }
        public enum BeaconMinor {
        }
        public enum BeaconUuid {
        }
        public enum EnterExitTracked {
        }
        public enum Location {
        }
        public enum Radius {
          /// %li m
          public static func label(_ p1: Int) -> String {
            return L10n.tr("Localizable", "settings_details.location.zones.radius.label", p1)
          }
        }
      }
    }
    public enum MacNativeFeatures {
    }
    public enum Notifications {
      public enum BadgeSection {
        public enum AutomaticSetting {
        }
        public enum Button {
        }
      }
      public enum Categories {
      }
      public enum CategoriesSynced {
      }
      public enum LocalPush {
        public enum Status {
          /// Available (%1$@)
          public static func available(_ p1: Any) -> String {
            return L10n.tr("Localizable", "settings_details.notifications.local_push.status.available", String(describing: p1))
          }
        }
      }
      public enum NewCategory {
      }
      public enum Permission {
      }
      public enum PromptToOpenUrls {
      }
      public enum PushIdSection {
      }
      public enum RateLimits {
        /// You are allowed %u push notifications per 24 hours. Rate limits reset at midnight Universal Coordinated Time (UTC).
        public static func footerWithParam(_ p1: Int) -> String {
          return L10n.tr("Localizable", "settings_details.notifications.rate_limits.footer_with_param", p1)
        }
      }
      public enum Sounds {
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
        }
      }
    }
    public enum Privacy {
      public enum Alerts {
      }
      public enum Analytics {
      }
      public enum CrashReporting {
      }
      public enum Messaging {
      }
    }
    public enum Thread {
      public enum DeleteCredential {
        public enum Confirmation {
        }
      }
    }
    public enum Updates {
      public enum CheckForUpdates {
      }
    }
    public enum Watch {
    }
    public enum Widgets {
      public enum ReloadAll {
      }
    }
  }

  public enum SettingsSensors {
    /// Decide which of your device sensors you want to share with Home Assistant.
    public static var body: String { return L10n.tr("Localizable", "settings_sensors.body") }
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
      /// Last Updated
      public static var `prefix`: String { return L10n.tr("Localizable", "settings_sensors.last_updated.prefix") }
    }
    public enum LoadingError {
    }
    public enum PeriodicUpdate {
    }
    public enum Permissions {
    }
    public enum Sensors {
    }
    public enum Settings {
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

  public enum ShortcutItem {
    public enum OpenSettings {
      /// Open Settings
      public static var title: String { return L10n.tr("Localizable", "shortcut_item.open_settings.title") }
    }
  }

  public enum Thread {
    public enum ActiveOperationalDataSet {
      /// Active operational data set
      public static var title: String { return L10n.tr("Localizable", "thread.active_operational_data_set.title") }
    }
    public enum BorderAgentId {
      /// Border Agent ID
      public static var title: String { return L10n.tr("Localizable", "thread.border_agent_id.title") }
    }
    public enum Credentials {
      public enum ShareCredentials {
        /// Make sure your are logged in with your iCloud account which is owner of a Home in Apple Home.
        public static var noCredentialsMessage: String { return L10n.tr("Localizable", "thread.credentials.share_credentials.no_credentials_message") }
        /// You don't have credentials to share
        public static var noCredentialsTitle: String { return L10n.tr("Localizable", "thread.credentials.share_credentials.no_credentials_title") }
      }
    }
    public enum ExtendedPanId {
      /// Extended PAN ID
      public static var title: String { return L10n.tr("Localizable", "thread.extended_pan_id.title") }
    }
    public enum Management {
      /// Thread Credentials
      public static var title: String { return L10n.tr("Localizable", "thread.management.title") }
    }
    public enum NetworkKey {
      /// Network Key
      public static var title: String { return L10n.tr("Localizable", "thread.network_key.title") }
    }
    public enum SaveCredential {
      public enum Fail {
        public enum Alert {
          /// Failed to save thread network credential.
          public static var message: String { return L10n.tr("Localizable", "thread.save_credential.fail.alert.message") }
          /// Failed to save thread network credential, error: %@
          public static func title(_ p1: Any) -> String {
            return L10n.tr("Localizable", "thread.save_credential.fail.alert.title", String(describing: p1))
          }
        }
        public enum Continue {
        }
      }
    }
    public enum StoreInKeychain {
      public enum Error {
        /// Failed to store thread credential in keychain, error: %@
        public static func message(_ p1: Any) -> String {
          return L10n.tr("Localizable", "thread.store_in_keychain.error.message", String(describing: p1))
        }
        public enum Generic {
        }
        public enum HexadecimalConversion {
        }
      }
    }
    public enum TransterToApple {
    }
    public enum TransterToHomeassistant {
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

  public enum Unauthenticated {
    public enum Message {
      /// This could be temporary if you are behind a proxy or network restriction, otherwise if it persists remove your server and add it back in.
      public static var body: String { return L10n.tr("Localizable", "unauthenticated.message.body") }
      /// You are unauthenticated
      public static var title: String { return L10n.tr("Localizable", "unauthenticated.message.title") }
    }
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
    }
  }

  public enum UrlHandler {
    public enum CallService {
      public enum Confirm {
        /// Do you want to call the service %@?
        public static func message(_ p1: Any) -> String {
          return L10n.tr("Localizable", "url_handler.call_service.confirm.message", String(describing: p1))
        }
      }
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
      }
    }
    public enum Error {
    }
    public enum FireEvent {
      public enum Confirm {
        /// Do you want to fire the event %@?
        public static func message(_ p1: Any) -> String {
          return L10n.tr("Localizable", "url_handler.fire_event.confirm.message", String(describing: p1))
        }
      }
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
      }
    }
    public enum NoService {
      /// %@ is not a valid route
      public static func message(_ p1: Any) -> String {
        return L10n.tr("Localizable", "url_handler.no_service.message", String(describing: p1))
      }
    }
    public enum RenderTemplate {
      public enum Confirm {
        /// Do you want to render %@?
        public static func message(_ p1: Any) -> String {
          return L10n.tr("Localizable", "url_handler.render_template.confirm.message", String(describing: p1))
        }
      }
    }
    public enum SendLocation {
      public enum Confirm {
      }
      public enum Error {
        /// An unknown error occurred while attempting to send location: %@
        public static func message(_ p1: Any) -> String {
          return L10n.tr("Localizable", "url_handler.send_location.error.message", String(describing: p1))
        }
      }
      public enum Success {
      }
    }
    public enum XCallbackUrl {
      public enum Error {
      }
    }
  }

  public enum Watch {
    /// Placeholder
    public static var placeholderComplicationName: String { return L10n.tr("Localizable", "watch.placeholder_complication_name") }
    public enum Assist {
      public enum Button {
        public enum Recording {
          /// Recording...
          public static var title: String { return L10n.tr("Localizable", "watch.assist.button.recording.title") }
        }
        public enum SendRequest {
          /// Tap to send request
          public static var title: String { return L10n.tr("Localizable", "watch.assist.button.send_request.title") }
        }
      }
      public enum LackConfig {
        public enum Error {
        }
      }
    }
    public enum Config {
      public enum Assist {
      }
      public enum Cache {
        public enum Error {
          /// Failed to load watch config from cache.
          public static var message: String { return L10n.tr("Localizable", "watch.config.cache.error.message") }
        }
      }
      public enum Error {
        /// Failed to load watch config, error: %@
        public static func message(_ p1: Any) -> String {
          return L10n.tr("Localizable", "watch.config.error.message", String(describing: p1))
        }
      }
      public enum MigrationError {
        /// Failed to access database (GRDB), error: %@
        public static func failedAccessGrdb(_ p1: Any) -> String {
          return L10n.tr("Localizable", "watch.config.migration_error.failed_access_grdb", String(describing: p1))
        }
        /// Failed to save initial watch config, error: %@
        public static func failedCreateNewConfig(_ p1: Any) -> String {
          return L10n.tr("Localizable", "watch.config.migration_error.failed_create_new_config", String(describing: p1))
        }
        /// Failed to migrate actions to watch config, error: %@
        public static func failedMigrateActions(_ p1: Any) -> String {
          return L10n.tr("Localizable", "watch.config.migration_error.failed_migrate_actions", String(describing: p1))
        }
        /// Failed to save new Watch config, error: %@
        public static func failedToSave(_ p1: Any) -> String {
          return L10n.tr("Localizable", "watch.config.migration_error.failed_to_save", String(describing: p1))
        }
      }
    }
    public enum Configuration {
      public enum AddItem {
      }
      public enum Items {
      }
      public enum Save {
      }
      public enum ShowAssist {
      }
    }
    public enum Configurator {
      public enum Delete {
      }
      public enum List {
        public enum ManualUpdates {
          public enum State {
          }
        }
      }
      public enum New {
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
        }
        public enum Column2Alignment {
          public enum Options {
          }
        }
        public enum DisplayName {
        }
        public enum Gauge {
          public enum Color {
          }
          public enum GaugeType {
            public enum Options {
              /// Open
              public static var `open`: String { return L10n.tr("Localizable", "watch.configurator.rows.gauge.gauge_type.options.open") }
            }
          }
          public enum Style {
            public enum Options {
            }
          }
        }
        public enum Icon {
          public enum Choose {
          }
          public enum Color {
          }
        }
        public enum IsPublic {
        }
        public enum Ring {
          public enum Color {
          }
          public enum RingType {
            public enum Options {
              /// Open
              public static var `open`: String { return L10n.tr("Localizable", "watch.configurator.rows.ring.ring_type.options.open") }
            }
          }
          public enum Value {
          }
        }
        public enum Template {
        }
      }
      public enum Sections {
        public enum Gauge {
        }
        public enum Icon {
        }
        public enum Ring {
        }
      }
      public enum Warning {
      }
    }
    public enum Debug {
      public enum DeleteDb {
        public enum Alert {
          public enum Failed {
            /// Failed to delete configuration, error: %@
            public static func message(_ p1: Any) -> String {
              return L10n.tr("Localizable", "watch.debug.delete_db.alert.failed.message", String(describing: p1))
            }
          }
        }
        public enum Reset {
        }
      }
    }
    public enum Home {
      public enum CancelAndUseCache {
      }
      public enum Loading {
        public enum Skip {
        }
      }
      public enum Run {
        public enum Confirmation {
          /// Are you sure you want to run "%@"?
          public static func title(_ p1: Any) -> String {
            return L10n.tr("Localizable", "watch.home.run.confirmation.title", String(describing: p1))
          }
        }
      }
    }
    public enum Labels {
      public enum ComplicationGroup {
        public enum CircularSmall {
        }
        public enum ExtraLarge {
        }
        public enum Graphic {
        }
        public enum Modular {
        }
        public enum Utilitarian {
        }
      }
      public enum ComplicationGroupMember {
        public enum CircularSmall {
        }
        public enum ExtraLarge {
        }
        public enum GraphicBezel {
        }
        public enum GraphicCircular {
        }
        public enum GraphicCorner {
        }
        public enum GraphicRectangular {
        }
        public enum ModularLarge {
        }
        public enum ModularSmall {
        }
        public enum UtilitarianLarge {
        }
        public enum UtilitarianSmall {
        }
        public enum UtilitarianSmallFlat {
        }
      }
      public enum ComplicationTemplate {
        public enum CircularSmallRingImage {
        }
        public enum CircularSmallRingText {
        }
        public enum CircularSmallSimpleImage {
        }
        public enum CircularSmallSimpleText {
        }
        public enum CircularSmallStackImage {
        }
        public enum CircularSmallStackText {
        }
        public enum ExtraLargeColumnsText {
        }
        public enum ExtraLargeRingImage {
        }
        public enum ExtraLargeRingText {
        }
        public enum ExtraLargeSimpleImage {
        }
        public enum ExtraLargeSimpleText {
        }
        public enum ExtraLargeStackImage {
        }
        public enum ExtraLargeStackText {
        }
        public enum GraphicBezelCircularText {
        }
        public enum GraphicCircularClosedGaugeImage {
        }
        public enum GraphicCircularClosedGaugeText {
        }
        public enum GraphicCircularImage {
        }
        public enum GraphicCircularOpenGaugeImage {
        }
        public enum GraphicCircularOpenGaugeRangeText {
        }
        public enum GraphicCircularOpenGaugeSimpleText {
        }
        public enum GraphicCornerCircularImage {
        }
        public enum GraphicCornerGaugeImage {
        }
        public enum GraphicCornerGaugeText {
        }
        public enum GraphicCornerStackText {
        }
        public enum GraphicCornerTextImage {
        }
        public enum GraphicRectangularLargeImage {
        }
        public enum GraphicRectangularStandardBody {
        }
        public enum GraphicRectangularTextGauge {
        }
        public enum ModularLargeColumns {
        }
        public enum ModularLargeStandardBody {
        }
        public enum ModularLargeTable {
        }
        public enum ModularLargeTallBody {
        }
        public enum ModularSmallColumnsText {
        }
        public enum ModularSmallRingImage {
        }
        public enum ModularSmallRingText {
        }
        public enum ModularSmallSimpleImage {
        }
        public enum ModularSmallSimpleText {
        }
        public enum ModularSmallStackImage {
        }
        public enum ModularSmallStackText {
        }
        public enum Style {
        }
        public enum UtilitarianLargeFlat {
        }
        public enum UtilitarianSmallFlat {
        }
        public enum UtilitarianSmallRingImage {
        }
        public enum UtilitarianSmallRingText {
        }
        public enum UtilitarianSmallSquare {
        }
      }
      public enum ComplicationTextAreas {
        public enum Body1 {
        }
        public enum Body2 {
        }
        public enum Bottom {
        }
        public enum Center {
        }
        public enum Header {
        }
        public enum Inner {
        }
        public enum InsideRing {
        }
        public enum Leading {
        }
        public enum Line1 {
        }
        public enum Line2 {
        }
        public enum Outer {
        }
        public enum Row1Column1 {
        }
        public enum Row1Column2 {
        }
        public enum Row2Column1 {
        }
        public enum Row2Column2 {
        }
        public enum Row3Column1 {
        }
        public enum Row3Column2 {
        }
        public enum Trailing {
        }
      }
      public enum SelectedPipeline {
      }
    }
    public enum Settings {
      public enum NoItems {
        public enum Phone {
        }
      }
    }
  }

  public enum WebView {
    public enum EmptyState {
      /// Please check your connection or try again later. If Home Assistant is restarting it will reconnect after it is back online.
      public static var body: String { return L10n.tr("Localizable", "web_view.empty_state.body") }
      /// Open App settings
      public static var openSettingsButton: String { return L10n.tr("Localizable", "web_view.empty_state.open_settings_button") }
      /// Retry
      public static var retryButton: String { return L10n.tr("Localizable", "web_view.empty_state.retry_button") }
      /// You're disconnected
      public static var title: String { return L10n.tr("Localizable", "web_view.empty_state.title") }
    }
    public enum NoUrlAvailable {
      /// 🔐  Due to your security choices, there's no URL that we are allowed to use. 
      /// 
      public enum PrimaryButton {
      }
    }
    public enum ServerSelection {
      /// Choose server
      public static var title: String { return L10n.tr("Localizable", "web_view.server_selection.title") }
    }
    public enum UniqueServerSelection {
      /// Choose one server
      public static var title: String { return L10n.tr("Localizable", "web_view.unique_server_selection.title") }
    }
  }

  public enum Widgets {
    public enum Action {
      public enum Name {
        /// Assist
        public static var assist: String { return L10n.tr("Localizable", "widgets.action.name.assist") }
        /// Default
        public static var `default`: String { return L10n.tr("Localizable", "widgets.action.name.default") }
        /// More info
        public static var moreInfoDialog: String { return L10n.tr("Localizable", "widgets.action.name.moreInfoDialog") }
        /// Navigate
        public static var navigate: String { return L10n.tr("Localizable", "widgets.action.name.navigate") }
        /// Nothing
        public static var nothing: String { return L10n.tr("Localizable", "widgets.action.name.nothing") }
        /// Run Script
        public static var runScript: String { return L10n.tr("Localizable", "widgets.action.name.run_script") }
      }
    }
    public enum Actions {
      /// Perform Home Assistant actions.
      public static var description: String { return L10n.tr("Localizable", "widgets.actions.description") }
      /// No Actions Configured
      public static var notConfigured: String { return L10n.tr("Localizable", "widgets.actions.not_configured") }
      /// Actions
      public static var title: String { return L10n.tr("Localizable", "widgets.actions.title") }
      public enum Parameters {
      }
    }
    public enum Assist {
      /// Ask Assist
      public static var actionTitle: String { return L10n.tr("Localizable", "widgets.assist.action_title") }
      /// Open Assist in the app
      public static var description: String { return L10n.tr("Localizable", "widgets.assist.description") }
      /// Assist
      public static var title: String { return L10n.tr("Localizable", "widgets.assist.title") }
      /// Configure
      public static var unknownConfiguration: String { return L10n.tr("Localizable", "widgets.assist.unknown_configuration") }
    }
    public enum Button {
    }
    public enum Controls {
      public enum Assist {
        /// Open Assist in Home Assistant app
        public static var description: String { return L10n.tr("Localizable", "widgets.controls.assist.description") }
        public enum Pipeline {
          /// Choose a pipeline
          public static var placeholder: String { return L10n.tr("Localizable", "widgets.controls.assist.pipeline.placeholder") }
        }
      }
      public enum Button {
        /// Press button
        public static var description: String { return L10n.tr("Localizable", "widgets.controls.button.description") }
        /// Choose button
        public static var placeholderTitle: String { return L10n.tr("Localizable", "widgets.controls.button.placeholder_title") }
        /// Button
        public static var title: String { return L10n.tr("Localizable", "widgets.controls.button.title") }
      }
      public enum Cover {
        /// Toggle cover
        public static var description: String { return L10n.tr("Localizable", "widgets.controls.cover.description") }
        /// Choose cover
        public static var placeholderTitle: String { return L10n.tr("Localizable", "widgets.controls.cover.placeholder_title") }
        /// Cover
        public static var title: String { return L10n.tr("Localizable", "widgets.controls.cover.title") }
      }
      public enum Fan {
        /// Turn on/off your fan
        public static var description: String { return L10n.tr("Localizable", "widgets.controls.fan.description") }
        /// Choose Fan
        public static var placeholderTitle: String { return L10n.tr("Localizable", "widgets.controls.fan.placeholder_title") }
        /// Fan
        public static var title: String { return L10n.tr("Localizable", "widgets.controls.fan.title") }
      }
      public enum Light {
        /// Turn on/off your light
        public static var description: String { return L10n.tr("Localizable", "widgets.controls.light.description") }
        /// Choose Light
        public static var placeholderTitle: String { return L10n.tr("Localizable", "widgets.controls.light.placeholder_title") }
        /// Light
        public static var title: String { return L10n.tr("Localizable", "widgets.controls.light.title") }
      }
      public enum OpenCamera {
        /// Opens the selected camera entity inside the app
        public static var description: String { return L10n.tr("Localizable", "widgets.controls.open_camera.description") }
        public enum Configuration {
          /// Open Camera
          public static var title: String { return L10n.tr("Localizable", "widgets.controls.open_camera.configuration.title") }
          public enum Parameter {
          }
        }
      }
      public enum OpenCover {
        /// Opens the selected cover entity inside the app
        public static var description: String { return L10n.tr("Localizable", "widgets.controls.open_cover.description") }
        public enum Configuration {
          /// Open Cover
          public static var title: String { return L10n.tr("Localizable", "widgets.controls.open_cover.configuration.title") }
          public enum Parameter {
          }
        }
      }
      public enum OpenEntity {
        public enum Configuration {
          public enum Parameter {
          }
        }
      }
      public enum OpenInputBoolean {
        /// Opens the selected input boolean entity inside the app
        public static var description: String { return L10n.tr("Localizable", "widgets.controls.open_input_boolean.description") }
        public enum Configuration {
          /// Open Input Boolean
          public static var title: String { return L10n.tr("Localizable", "widgets.controls.open_input_boolean.configuration.title") }
          public enum Parameter {
          }
        }
      }
      public enum OpenLight {
        /// Opens the selected light entity inside the app
        public static var description: String { return L10n.tr("Localizable", "widgets.controls.open_light.description") }
        public enum Configuration {
          /// Open Light
          public static var title: String { return L10n.tr("Localizable", "widgets.controls.open_light.configuration.title") }
          public enum Parameter {
          }
        }
      }
      public enum OpenLock {
        /// Opens the selected lock entity inside the app
        public static var description: String { return L10n.tr("Localizable", "widgets.controls.open_lock.description") }
        public enum Configuration {
          /// Open Lock
          public static var title: String { return L10n.tr("Localizable", "widgets.controls.open_lock.configuration.title") }
          public enum Parameter {
          }
        }
      }
      public enum OpenPage {
        public enum Configuration {
          public enum Parameter {
            /// Choose page
            public static var choosePage: String { return L10n.tr("Localizable", "widgets.controls.open_page.configuration.parameter.choose_page") }
          }
        }
      }
      public enum OpenSensor {
        /// Opens the selected sensor entity inside the app
        public static var description: String { return L10n.tr("Localizable", "widgets.controls.open_sensor.description") }
        public enum Configuration {
          /// Open Sensor
          public static var title: String { return L10n.tr("Localizable", "widgets.controls.open_sensor.configuration.title") }
          public enum Parameter {
          }
        }
      }
      public enum OpenSwitch {
        /// Opens the selected switch entity inside the app
        public static var description: String { return L10n.tr("Localizable", "widgets.controls.open_switch.description") }
        public enum Configuration {
          /// Open Switch
          public static var title: String { return L10n.tr("Localizable", "widgets.controls.open_switch.configuration.title") }
          public enum Parameter {
          }
        }
      }
      public enum Scene {
        /// Run scene
        public static var description: String { return L10n.tr("Localizable", "widgets.controls.scene.description") }
        /// Scene
        public static var displayName: String { return L10n.tr("Localizable", "widgets.controls.scene.display_name") }
      }
      public enum Scenes {
        /// Choose scene
        public static var placeholderTitle: String { return L10n.tr("Localizable", "widgets.controls.scenes.placeholder_title") }
      }
      public enum Script {
        /// Run script
        public static var description: String { return L10n.tr("Localizable", "widgets.controls.script.description") }
        /// Script
        public static var displayName: String { return L10n.tr("Localizable", "widgets.controls.script.display_name") }
      }
      public enum Scripts {
        /// Choose script
        public static var placeholderTitle: String { return L10n.tr("Localizable", "widgets.controls.scripts.placeholder_title") }
      }
      public enum Switch {
        /// Turn on/off your switch
        public static var description: String { return L10n.tr("Localizable", "widgets.controls.switch.description") }
        /// Choose switch
        public static var placeholderTitle: String { return L10n.tr("Localizable", "widgets.controls.switch.placeholder_title") }
        /// Switch
        public static var title: String { return L10n.tr("Localizable", "widgets.controls.switch.title") }
      }
    }
    public enum Custom {
      /// Create widgets with your own style
      public static var subtitle: String { return L10n.tr("Localizable", "widgets.custom.subtitle") }
      /// Custom widgets
      public static var title: String { return L10n.tr("Localizable", "widgets.custom.title") }
      public enum IntentActivateFailed {
        /// Please try again
        public static var body: String { return L10n.tr("Localizable", "widgets.custom.intent_activate_failed.body") }
        /// Failed to 'activate' entity
        public static var title: String { return L10n.tr("Localizable", "widgets.custom.intent_activate_failed.title") }
      }
      public enum IntentPressFailed {
        /// Please try again
        public static var body: String { return L10n.tr("Localizable", "widgets.custom.intent_press_failed.body") }
        /// Failed to 'press' entity
        public static var title: String { return L10n.tr("Localizable", "widgets.custom.intent_press_failed.title") }
      }
      public enum IntentToggleFailed {
        /// Please try again
        public static var body: String { return L10n.tr("Localizable", "widgets.custom.intent_toggle_failed.body") }
        /// Failed to 'toggle' entity
        public static var title: String { return L10n.tr("Localizable", "widgets.custom.intent_toggle_failed.title") }
      }
      public enum RequireConfirmation {
        /// Widget confirmation and state display are currently in BETA, if you experience issues please disable 'Require confirmation' and save.
        public static var footer: String { return L10n.tr("Localizable", "widgets.custom.require_confirmation.footer") }
      }
      public enum ShowLastUpdateTime {
        public enum Param {
        }
      }
      public enum ShowStates {
        /// Displaying latest states is not 100% guaranteed, you can give it a try and check the companion App documentation for more information.
        public static func description(_ p1: Float) -> String {
          return L10n.tr("Localizable", "widgets.custom.show_states.description", p1)
        }
        public enum Param {
        }
      }
      public enum ShowUpdateTime {
      }
    }
    public enum Details {
      public enum Parameters {
      }
    }
    public enum EntityState {
    }
    public enum Gauge {
      public enum Parameters {
        public enum GaugeType {
        }
      }
    }
    public enum Lights {
    }
    public enum OpenEntity {
    }
    public enum OpenPage {
    }
    public enum Preview {
      public enum Custom {
      }
      public enum Empty {
        public enum Create {
        }
      }
    }
    public enum ReloadWidgets {
      public enum AppIntent {
      }
    }
    public enum Scene {
      public enum Activate {
      }
      public enum Description {
      }
    }
    public enum Scripts {
    }
    public enum Sensors {
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
