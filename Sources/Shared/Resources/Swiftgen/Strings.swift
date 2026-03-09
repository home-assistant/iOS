// swiftlint:disable all
// Generated using SwiftGen — https://github.com/SwiftGen/SwiftGen

import Foundation

// swiftlint:disable superfluous_disable_command file_length implicit_return prefer_self_in_static_references

// MARK: - Strings

// swiftlint:disable explicit_type_interface function_parameter_count identifier_name line_length
// swiftlint:disable nesting type_body_length type_name vertical_whitespace_opening_braces
public enum L10n {
  /// Add
  public static var addButtonLabel: String { return L10n.tr("Localizable", "addButtonLabel", fallback: "Add") }
  /// Always Open
  public static var alwaysOpenLabel: String { return L10n.tr("Localizable", "always_open_label", fallback: "Always Open") }
  /// Cancel
  public static var cancelLabel: String { return L10n.tr("Localizable", "cancel_label", fallback: "Cancel") }
  /// Close
  public static var closeLabel: String { return L10n.tr("Localizable", "close_label", fallback: "Close") }
  /// Continue
  public static var continueLabel: String { return L10n.tr("Localizable", "continue_label", fallback: "Continue") }
  /// Copy
  public static var copyLabel: String { return L10n.tr("Localizable", "copy_label", fallback: "Copy") }
  /// Debug
  public static var debugSectionLabel: String { return L10n.tr("Localizable", "debug_section_label", fallback: "Debug") }
  /// Delete
  public static var delete: String { return L10n.tr("Localizable", "delete", fallback: "Delete") }
  /// Done
  public static var doneLabel: String { return L10n.tr("Localizable", "done_label", fallback: "Done") }
  /// Error
  public static var errorLabel: String { return L10n.tr("Localizable", "error_label", fallback: "Error") }
  /// Help
  public static var helpLabel: String { return L10n.tr("Localizable", "help_label", fallback: "Help") }
  /// Not in a room
  public static var noArea: String { return L10n.tr("Localizable", "no_area", fallback: "Not in a room") }
  /// No
  public static var noLabel: String { return L10n.tr("Localizable", "no_label", fallback: "No") }
  /// OK
  public static var okLabel: String { return L10n.tr("Localizable", "ok_label", fallback: "OK") }
  /// Open
  public static var openLabel: String { return L10n.tr("Localizable", "open_label", fallback: "Open") }
  /// Preview Output
  public static var previewOutput: String { return L10n.tr("Localizable", "preview_output", fallback: "Preview Output") }
  /// Privacy
  public static var privacyLabel: String { return L10n.tr("Localizable", "privacyLabel", fallback: "Privacy") }
  /// Requires %@ or later.
  public static func requiresVersion(_ p1: Any) -> String {
    return L10n.tr("Localizable", "requires_version", String(describing: p1), fallback: "Requires %@ or later.")
  }
  /// Retry
  public static var retryLabel: String { return L10n.tr("Localizable", "retry_label", fallback: "Retry") }
  /// Save
  public static var saveLabel: String { return L10n.tr("Localizable", "save_label", fallback: "Save") }
  /// Unknown
  public static var unknownLabel: String { return L10n.tr("Localizable", "unknownLabel", fallback: "Unknown") }
  /// URL
  public static var urlLabel: String { return L10n.tr("Localizable", "url_label", fallback: "URL") }
  /// Yes
  public static var yesLabel: String { return L10n.tr("Localizable", "yes_label", fallback: "Yes") }
  public enum About {
    /// About
    public static var title: String { return L10n.tr("Localizable", "about.title", fallback: "About") }
    public enum Acknowledgements {
      /// Acknowledgements
      public static var title: String { return L10n.tr("Localizable", "about.acknowledgements.title", fallback: "Acknowledgements") }
    }
    public enum Beta {
      /// Join Beta
      public static var title: String { return L10n.tr("Localizable", "about.beta.title", fallback: "Join Beta") }
    }
    public enum Chat {
      /// Chat
      public static var title: String { return L10n.tr("Localizable", "about.chat.title", fallback: "Chat") }
    }
    public enum Documentation {
      /// Documentation
      public static var title: String { return L10n.tr("Localizable", "about.documentation.title", fallback: "Documentation") }
    }
    public enum EasterEgg {
      /// i love you
      public static var message: String { return L10n.tr("Localizable", "about.easter_egg.message", fallback: "i love you") }
      /// You found me!
      public static var title: String { return L10n.tr("Localizable", "about.easter_egg.title", fallback: "You found me!") }
    }
    public enum Forums {
      /// Forums
      public static var title: String { return L10n.tr("Localizable", "about.forums.title", fallback: "Forums") }
    }
    public enum Github {
      /// GitHub
      public static var title: String { return L10n.tr("Localizable", "about.github.title", fallback: "GitHub") }
    }
    public enum GithubIssueTracker {
      /// GitHub Issue Tracker
      public static var title: String { return L10n.tr("Localizable", "about.github_issue_tracker.title", fallback: "GitHub Issue Tracker") }
    }
    public enum HelpLocalize {
      /// Help localize the app!
      public static var title: String { return L10n.tr("Localizable", "about.help_localize.title", fallback: "Help localize the app!") }
    }
    public enum HomeAssistantOnFacebook {
      /// Home Assistant on Facebook
      public static var title: String { return L10n.tr("Localizable", "about.home_assistant_on_facebook.title", fallback: "Home Assistant on Facebook") }
    }
    public enum HomeAssistantOnTwitter {
      /// Home Assistant on Twitter
      public static var title: String { return L10n.tr("Localizable", "about.home_assistant_on_twitter.title", fallback: "Home Assistant on Twitter") }
    }
    public enum Logo {
      /// Home Assistant Companion
      public static var appTitle: String { return L10n.tr("Localizable", "about.logo.app_title", fallback: "Home Assistant Companion") }
      /// Home Assistant
      public static var title: String { return L10n.tr("Localizable", "about.logo.title", fallback: "Home Assistant") }
    }
    public enum Review {
      /// Leave a review
      public static var title: String { return L10n.tr("Localizable", "about.review.title", fallback: "Leave a review") }
    }
    public enum Website {
      /// Website
      public static var title: String { return L10n.tr("Localizable", "about.website.title", fallback: "Website") }
    }
  }
  public enum ActionsConfigurator {
    /// New Action
    public static var title: String { return L10n.tr("Localizable", "actions_configurator.title", fallback: "New Action") }
    public enum Action {
      /// Create automation
      public static var createAutomation: String { return L10n.tr("Localizable", "actions_configurator.action.create_automation", fallback: "Create automation") }
      /// Define what will be executed when Action is performed, alternatively you can use the example trigger below manually.
      public static var footer: String { return L10n.tr("Localizable", "actions_configurator.action.footer", fallback: "Define what will be executed when Action is performed, alternatively you can use the example trigger below manually.") }
      /// Execute
      public static var title: String { return L10n.tr("Localizable", "actions_configurator.action.title", fallback: "Execute") }
    }
    public enum Rows {
      public enum BackgroundColor {
        /// Background Color
        public static var title: String { return L10n.tr("Localizable", "actions_configurator.rows.background_color.title", fallback: "Background Color") }
      }
      public enum Icon {
        /// Icon
        public static var title: String { return L10n.tr("Localizable", "actions_configurator.rows.icon.title", fallback: "Icon") }
      }
      public enum IconColor {
        /// Icon Color
        public static var title: String { return L10n.tr("Localizable", "actions_configurator.rows.icon_color.title", fallback: "Icon Color") }
      }
      public enum Name {
        /// Name
        public static var title: String { return L10n.tr("Localizable", "actions_configurator.rows.name.title", fallback: "Name") }
      }
      public enum Text {
        /// Text
        public static var title: String { return L10n.tr("Localizable", "actions_configurator.rows.text.title", fallback: "Text") }
      }
      public enum TextColor {
        /// Text Color
        public static var title: String { return L10n.tr("Localizable", "actions_configurator.rows.text_color.title", fallback: "Text Color") }
      }
    }
    public enum TriggerExample {
      /// Share Contents
      public static var share: String { return L10n.tr("Localizable", "actions_configurator.trigger_example.share", fallback: "Share Contents") }
      /// Example Trigger
      public static var title: String { return L10n.tr("Localizable", "actions_configurator.trigger_example.title", fallback: "Example Trigger") }
    }
    public enum VisualSection {
      /// The appearance of this action is controlled by the scene configuration.
      public static var sceneDefined: String { return L10n.tr("Localizable", "actions_configurator.visual_section.scene_defined", fallback: "The appearance of this action is controlled by the scene configuration.") }
      /// You can also change these by customizing the Scene attributes: %@
      public static func sceneHintFooter(_ p1: Any) -> String {
        return L10n.tr("Localizable", "actions_configurator.visual_section.scene_hint_footer", String(describing: p1), fallback: "You can also change these by customizing the Scene attributes: %@")
      }
      /// The appearance of this action is controlled by the server configuration.
      public static var serverDefined: String { return L10n.tr("Localizable", "actions_configurator.visual_section.server_defined", fallback: "The appearance of this action is controlled by the server configuration.") }
    }
  }
  public enum Alert {
    public enum Confirmation {
      public enum DeleteEntities {
        /// This will clean your entities from database and it will only reload the next time you open the app from zero.
        public static var message: String { return L10n.tr("Localizable", "alert.confirmation.delete_entities.message", fallback: "This will clean your entities from database and it will only reload the next time you open the app from zero.") }
      }
      public enum Generic {
        /// Are you sure?
        public static var title: String { return L10n.tr("Localizable", "alert.confirmation.generic.title", fallback: "Are you sure?") }
      }
    }
  }
  public enum Alerts {
    public enum ActionAutomationEditor {
      public enum Unavailable {
        /// To automatically create an automation for an Action please update your Home Assistant to at least version 2024.2
        public static var body: String { return L10n.tr("Localizable", "alerts.action_automation_editor.unavailable.body", fallback: "To automatically create an automation for an Action please update your Home Assistant to at least version 2024.2") }
        /// Please update Home Assistant
        public static var title: String { return L10n.tr("Localizable", "alerts.action_automation_editor.unavailable.title", fallback: "Please update Home Assistant") }
      }
    }
    public enum Alert {
      /// OK
      public static var ok: String { return L10n.tr("Localizable", "alerts.alert.ok", fallback: "OK") }
    }
    public enum AuthRequired {
      /// The server has rejected your credentials, and you must sign in again to continue.
      public static var message: String { return L10n.tr("Localizable", "alerts.auth_required.message", fallback: "The server has rejected your credentials, and you must sign in again to continue.") }
      /// You must sign in to continue
      public static var title: String { return L10n.tr("Localizable", "alerts.auth_required.title", fallback: "You must sign in to continue") }
    }
    public enum Confirm {
      /// Cancel
      public static var cancel: String { return L10n.tr("Localizable", "alerts.confirm.cancel", fallback: "Cancel") }
      /// Confirm
      public static var confirm: String { return L10n.tr("Localizable", "alerts.confirm.confirm", fallback: "Confirm") }
      /// OK
      public static var ok: String { return L10n.tr("Localizable", "alerts.confirm.ok", fallback: "OK") }
    }
    public enum Deprecations {
      public enum NotificationCategory {
        /// You must migrate to actions defined in the notification itself before %1$@.
        public static func message(_ p1: Any) -> String {
          return L10n.tr("Localizable", "alerts.deprecations.notification_category.message", String(describing: p1), fallback: "You must migrate to actions defined in the notification itself before %1$@.")
        }
        /// Notification Categories are deprecated
        public static var title: String { return L10n.tr("Localizable", "alerts.deprecations.notification_category.title", fallback: "Notification Categories are deprecated") }
      }
    }
    public enum NavigationError {
      /// This page cannot be displayed because it's outside your Home Assistant server or the page was not found.
      public static var message: String { return L10n.tr("Localizable", "alerts.navigation_error.message", fallback: "This page cannot be displayed because it's outside your Home Assistant server or the page was not found.") }
      /// Navigation Error
      public static var title: String { return L10n.tr("Localizable", "alerts.navigation_error.title", fallback: "Navigation Error") }
    }
    public enum OpenUrlFromDeepLink {
      /// Open URL (%@) from deep link?
      public static func message(_ p1: Any) -> String {
        return L10n.tr("Localizable", "alerts.open_url_from_deep_link.message", String(describing: p1), fallback: "Open URL (%@) from deep link?")
      }
    }
    public enum OpenUrlFromNotification {
      /// Open URL (%@) found in notification?
      public static func message(_ p1: Any) -> String {
        return L10n.tr("Localizable", "alerts.open_url_from_notification.message", String(describing: p1), fallback: "Open URL (%@) found in notification?")
      }
      /// Open URL?
      public static var title: String { return L10n.tr("Localizable", "alerts.open_url_from_notification.title", fallback: "Open URL?") }
    }
    public enum Prompt {
      /// Cancel
      public static var cancel: String { return L10n.tr("Localizable", "alerts.prompt.cancel", fallback: "Cancel") }
      /// OK
      public static var ok: String { return L10n.tr("Localizable", "alerts.prompt.ok", fallback: "OK") }
    }
  }
  public enum Announcement {
    public enum DropSupport {
      /// Continue
      public static var button: String { return L10n.tr("Localizable", "announcement.drop_support.button", fallback: "Continue") }
      /// After careful consideration, we will be discontinuing support for iOS 12, 13 and 14 in our upcoming updates.
      public static var subtitle: String { return L10n.tr("Localizable", "announcement.drop_support.subtitle", fallback: "After careful consideration, we will be discontinuing support for iOS 12, 13 and 14 in our upcoming updates.") }
      /// Important update
      public static var title: String { return L10n.tr("Localizable", "announcement.drop_support.title", fallback: "Important update") }
    }
  }
  public enum AppIntents {
    public enum Assist {
      public enum Pipeline {
        /// Pipeline
        public static var title: String { return L10n.tr("Localizable", "app_intents.assist.pipeline.title", fallback: "Pipeline") }
        public enum Default {
          /// Default
          public static var title: String { return L10n.tr("Localizable", "app_intents.assist.pipeline.default.title", fallback: "Default") }
        }
      }
      public enum PreferredPipeline {
        /// Preferred
        public static var title: String { return L10n.tr("Localizable", "app_intents.assist.preferred_pipeline.title", fallback: "Preferred") }
      }
      public enum RefreshWarning {
        /// Can't find your Assist pipeline? Open Assist in the app to refresh pipelines list.
        public static var title: String { return L10n.tr("Localizable", "app_intents.assist.refresh_warning.title", fallback: "Can't find your Assist pipeline? Open Assist in the app to refresh pipelines list.") }
      }
    }
    public enum Automations {
      public enum Automation {
        /// Automation
        public static var title: String { return L10n.tr("Localizable", "app_intents.automations.automation.title", fallback: "Automation") }
      }
      public enum FailureMessage {
        /// Automation "%@" failed to execute, please check your logs.
        public static func content(_ p1: Any) -> String {
          return L10n.tr("Localizable", "app_intents.automations.failure_message.content", String(describing: p1), fallback: "Automation \"%@\" failed to execute, please check your logs.")
        }
      }
      public enum Icon {
        /// Icon
        public static var title: String { return L10n.tr("Localizable", "app_intents.automations.icon.title", fallback: "Icon") }
      }
      public enum Parameter {
        public enum Automation {
          /// Automation
          public static var title: String { return L10n.tr("Localizable", "app_intents.automations.parameter.automation.title", fallback: "Automation") }
        }
      }
      public enum SuccessMessage {
        /// Automation "%@" executed.
        public static func content(_ p1: Any) -> String {
          return L10n.tr("Localizable", "app_intents.automations.success_message.content", String(describing: p1), fallback: "Automation \"%@\" executed.")
        }
      }
    }
    public enum ClosedStateIcon {
      /// Icon for closed state
      public static var title: String { return L10n.tr("Localizable", "app_intents.closed_state_icon.title", fallback: "Icon for closed state") }
    }
    public enum Controls {
      public enum Assist {
        /// Assist in app
        public static var title: String { return L10n.tr("Localizable", "app_intents.controls.assist.title", fallback: "Assist in app") }
        public enum Parameter {
          /// With voice
          public static var withVoice: String { return L10n.tr("Localizable", "app_intents.controls.assist.parameter.with_voice", fallback: "With voice") }
        }
      }
    }
    public enum Cover {
      /// Cover
      public static var title: String { return L10n.tr("Localizable", "app_intents.cover.title", fallback: "Cover") }
    }
    public enum Fan {
      /// Fan
      public static var title: String { return L10n.tr("Localizable", "app_intents.fan.title", fallback: "Fan") }
      public enum OffStateIcon {
        /// Icon for off state
        public static var title: String { return L10n.tr("Localizable", "app_intents.fan.off_state_icon.title", fallback: "Icon for off state") }
      }
      public enum OnStateIcon {
        /// Icon for on state
        public static var title: String { return L10n.tr("Localizable", "app_intents.fan.on_state_icon.title", fallback: "Icon for on state") }
      }
    }
    public enum HapticConfirmation {
      /// Haptic confirmation
      public static var title: String { return L10n.tr("Localizable", "app_intents.haptic_confirmation.title", fallback: "Haptic confirmation") }
    }
    public enum Icon {
      /// Icon
      public static var title: String { return L10n.tr("Localizable", "app_intents.icon.title", fallback: "Icon") }
    }
    public enum Intent {
      public enum Cover {
        /// Control cover
        public static var title: String { return L10n.tr("Localizable", "app_intents.intent.cover.title", fallback: "Control cover") }
      }
      public enum Fan {
        /// Control fan
        public static var title: String { return L10n.tr("Localizable", "app_intents.intent.fan.title", fallback: "Control fan") }
      }
      public enum Light {
        /// Control light
        public static var title: String { return L10n.tr("Localizable", "app_intents.intent.light.title", fallback: "Control light") }
      }
      public enum Switch {
        /// Control switch
        public static var title: String { return L10n.tr("Localizable", "app_intents.intent.switch.title", fallback: "Control switch") }
      }
    }
    public enum Lights {
      public enum Light {
        /// Target state
        public static var target: String { return L10n.tr("Localizable", "app_intents.lights.light.target", fallback: "Target state") }
        /// Light
        public static var title: String { return L10n.tr("Localizable", "app_intents.lights.light.title", fallback: "Light") }
      }
      public enum OffStateIcon {
        /// Icon for off state
        public static var title: String { return L10n.tr("Localizable", "app_intents.lights.off_state_icon.title", fallback: "Icon for off state") }
      }
      public enum OnStateIcon {
        /// Icon for on state
        public static var title: String { return L10n.tr("Localizable", "app_intents.lights.on_state_icon.title", fallback: "Icon for on state") }
      }
    }
    public enum NotifyWhenRun {
      /// Shows notification after executed
      public static var description: String { return L10n.tr("Localizable", "app_intents.notify_when_run.description", fallback: "Shows notification after executed") }
      /// Notify when run
      public static var title: String { return L10n.tr("Localizable", "app_intents.notify_when_run.title", fallback: "Notify when run") }
    }
    public enum OpenExperimentalDashboard {
      /// Opens the experimental dashboard
      public static var description: String { return L10n.tr("Localizable", "app_intents.open_experimental_dashboard.description", fallback: "Opens the experimental dashboard") }
      /// Open Experimental Dashboard
      public static var title: String { return L10n.tr("Localizable", "app_intents.open_experimental_dashboard.title", fallback: "Open Experimental Dashboard") }
    }
    public enum OpenStateIcon {
      /// Icon for open state
      public static var title: String { return L10n.tr("Localizable", "app_intents.open_state_icon.title", fallback: "Icon for open state") }
    }
    public enum PerformAction {
      /// Which action?
      public static var actionParameterConfiguration: String { return L10n.tr("Localizable", "app_intents.perform_action.action_parameter_configuration", fallback: "Which action?") }
      /// Just to confirm, you wanted ‘%@’?
      public static func actionParameterConfirmation(_ p1: Any) -> String {
        return L10n.tr("Localizable", "app_intents.perform_action.action_parameter_confirmation", String(describing: p1), fallback: "Just to confirm, you wanted ‘%@’?")
      }
      /// There are %@ options matching ‘%@’.
      public static func actionParameterDisambiguationIntro(_ p1: Any, _ p2: Any) -> String {
        return L10n.tr("Localizable", "app_intents.perform_action.action_parameter_disambiguation_intro", String(describing: p1), String(describing: p2), fallback: "There are %@ options matching ‘%@’.")
      }
      /// Failed: %@
      public static func responseFailure(_ p1: Any) -> String {
        return L10n.tr("Localizable", "app_intents.perform_action.response_failure", String(describing: p1), fallback: "Failed: %@")
      }
      /// Done
      public static var responseSuccess: String { return L10n.tr("Localizable", "app_intents.perform_action.response_success", fallback: "Done") }
    }
    public enum Scenes {
      /// Run Scene
      public static var title: String { return L10n.tr("Localizable", "app_intents.scenes.title", fallback: "Run Scene") }
      public enum FailureMessage {
        /// Scene "%@" failed to execute, please check your logs.
        public static func content(_ p1: Any) -> String {
          return L10n.tr("Localizable", "app_intents.scenes.failure_message.content", String(describing: p1), fallback: "Scene \"%@\" failed to execute, please check your logs.")
        }
      }
      public enum Icon {
        /// Icon
        public static var title: String { return L10n.tr("Localizable", "app_intents.scenes.icon.title", fallback: "Icon") }
      }
      public enum Parameter {
        public enum Scene {
          /// Scene
          public static var title: String { return L10n.tr("Localizable", "app_intents.scenes.parameter.scene.title", fallback: "Scene") }
        }
      }
      public enum RequiresConfirmationBeforeRun {
        /// Requires manual confirmation before running the scene.
        public static var description: String { return L10n.tr("Localizable", "app_intents.scenes.requires_confirmation_before_run.description", fallback: "Requires manual confirmation before running the scene.") }
        /// Confirm before run
        public static var title: String { return L10n.tr("Localizable", "app_intents.scenes.requires_confirmation_before_run.title", fallback: "Confirm before run") }
      }
      public enum Scene {
        /// Scene
        public static var title: String { return L10n.tr("Localizable", "app_intents.scenes.scene.title", fallback: "Scene") }
      }
      public enum SuccessMessage {
        /// Scene "%@" executed.
        public static func content(_ p1: Any) -> String {
          return L10n.tr("Localizable", "app_intents.scenes.success_message.content", String(describing: p1), fallback: "Scene \"%@\" executed.")
        }
      }
    }
    public enum Scripts {
      public enum FailureMessage {
        /// Script "%@" failed to execute, please check your logs.
        public static func content(_ p1: Any) -> String {
          return L10n.tr("Localizable", "app_intents.scripts.failure_message.content", String(describing: p1), fallback: "Script \"%@\" failed to execute, please check your logs.")
        }
      }
      public enum HapticConfirmation {
        /// Haptic confirmation
        public static var title: String { return L10n.tr("Localizable", "app_intents.scripts.haptic_confirmation.title", fallback: "Haptic confirmation") }
      }
      public enum Icon {
        /// Icon
        public static var title: String { return L10n.tr("Localizable", "app_intents.scripts.icon.title", fallback: "Icon") }
      }
      public enum RequiresConfirmationBeforeRun {
        /// Requires manual confirmation before running the script.
        public static var description: String { return L10n.tr("Localizable", "app_intents.scripts.requires_confirmation_before_run.description", fallback: "Requires manual confirmation before running the script.") }
        /// Confirm before run
        public static var title: String { return L10n.tr("Localizable", "app_intents.scripts.requires_confirmation_before_run.title", fallback: "Confirm before run") }
      }
      public enum Script {
        /// Run Script
        public static var title: String { return L10n.tr("Localizable", "app_intents.scripts.script.title", fallback: "Run Script") }
      }
      public enum ShowConfirmationDialog {
        /// Shows confirmation notification after executed
        public static var description: String { return L10n.tr("Localizable", "app_intents.scripts.show_confirmation_dialog.description", fallback: "Shows confirmation notification after executed") }
        /// Confirmation notification
        public static var title: String { return L10n.tr("Localizable", "app_intents.scripts.show_confirmation_dialog.title", fallback: "Confirmation notification") }
      }
      public enum SuccessMessage {
        /// Script "%@" executed.
        public static func content(_ p1: Any) -> String {
          return L10n.tr("Localizable", "app_intents.scripts.success_message.content", String(describing: p1), fallback: "Script \"%@\" executed.")
        }
      }
    }
    public enum Server {
      /// Server
      public static var title: String { return L10n.tr("Localizable", "app_intents.server.title", fallback: "Server") }
    }
    public enum ShowConfirmationDialog {
      /// Shows confirmation notification after executed
      public static var description: String { return L10n.tr("Localizable", "app_intents.show_confirmation_dialog.description", fallback: "Shows confirmation notification after executed") }
      /// Confirmation notification
      public static var title: String { return L10n.tr("Localizable", "app_intents.show_confirmation_dialog.title", fallback: "Confirmation notification") }
    }
    public enum State {
      /// Target state
      public static var target: String { return L10n.tr("Localizable", "app_intents.state.target", fallback: "Target state") }
      /// Toggle
      public static var toggle: String { return L10n.tr("Localizable", "app_intents.state.toggle", fallback: "Toggle") }
    }
    public enum Switch {
      /// Switch
      public static var title: String { return L10n.tr("Localizable", "app_intents.switch.title", fallback: "Switch") }
    }
    public enum WidgetAction {
      /// Which actions?
      public static var actionsParameterConfiguration: String { return L10n.tr("Localizable", "app_intents.widget_action.actions_parameter_configuration", fallback: "Which actions?") }
    }
  }
  public enum Assist {
    public enum Button {
      public enum FinishRecording {
        /// Tap to finish recording...
        public static var title: String { return L10n.tr("Localizable", "assist.button.finish_recording.title", fallback: "Tap to finish recording...") }
      }
      public enum Listening {
        /// Listening...
        public static var title: String { return L10n.tr("Localizable", "assist.button.listening.title", fallback: "Listening...") }
      }
    }
    public enum Error {
      /// Failed to obtain Assist pipelines, please check your pipelines configuration.
      public static var pipelinesResponse: String { return L10n.tr("Localizable", "assist.error.pipelines_response", fallback: "Failed to obtain Assist pipelines, please check your pipelines configuration.") }
    }
    public enum ModernUi {
      public enum Header {
        /// Assist
        public static var title: String { return L10n.tr("Localizable", "assist.modern_ui.header.title", fallback: "Assist") }
      }
      public enum Pipeline {
        /// Pipeline
        public static var label: String { return L10n.tr("Localizable", "assist.modern_ui.pipeline.label", fallback: "Pipeline") }
      }
      public enum TextField {
        /// Ask me anything...
        public static var placeholder: String { return L10n.tr("Localizable", "assist.modern_ui.text_field.placeholder", fallback: "Ask me anything...") }
      }
    }
    public enum PipelinesPicker {
      /// Assist Pipelines
      public static var title: String { return L10n.tr("Localizable", "assist.pipelines_picker.title", fallback: "Assist Pipelines") }
    }
    public enum Settings {
      /// Assist Settings
      public static var title: String { return L10n.tr("Localizable", "assist.settings.title", fallback: "Assist Settings") }
      public enum Labs {
        /// Labs
        public static var header: String { return L10n.tr("Localizable", "assist.settings.labs.header", fallback: "Labs") }
      }
      public enum ModernUi {
        /// Enable the new modern interface design for Assist. This is a labs feature and may have limited functionality as well as it can be removed without previous notice.
        public static var footer: String { return L10n.tr("Localizable", "assist.settings.modern_ui.footer", fallback: "Enable the new modern interface design for Assist. This is a labs feature and may have limited functionality as well as it can be removed without previous notice.") }
        /// Labs
        public static var header: String { return L10n.tr("Localizable", "assist.settings.modern_ui.header", fallback: "Labs") }
        /// Experimental UI
        public static var toggle: String { return L10n.tr("Localizable", "assist.settings.modern_ui.toggle", fallback: "Experimental UI") }
        public enum Theme {
          /// Theme
          public static var label: String { return L10n.tr("Localizable", "assist.settings.modern_ui.theme.label", fallback: "Theme") }
        }
      }
      public enum OnDeviceStt {
        /// Use Apple's on-device speech recognition for improved privacy. Your voice will be processed locally and transcribed to text before being sent to your server. Not all languages are supported.
        public static var footer: String { return L10n.tr("Localizable", "assist.settings.on_device_stt.footer", fallback: "Use Apple's on-device speech recognition for improved privacy. Your voice will be processed locally and transcribed to text before being sent to your server. Not all languages are supported.") }
        /// Language
        public static var language: String { return L10n.tr("Localizable", "assist.settings.on_device_stt.language", fallback: "Language") }
        /// On-device STT
        public static var title: String { return L10n.tr("Localizable", "assist.settings.on_device_stt.title", fallback: "On-device STT") }
        /// Enable on-device Speech-to-Text
        public static var toggle: String { return L10n.tr("Localizable", "assist.settings.on_device_stt.toggle", fallback: "Enable on-device Speech-to-Text") }
      }
      public enum OnDeviceTts {
        /// Default
        public static var defaultVoice: String { return L10n.tr("Localizable", "assist.settings.on_device_tts.default_voice", fallback: "Default") }
        /// Use Apple's on-device speech synthesis for improved privacy. Text responses will be spoken locally without sending audio data to your server.
        public static var footer: String { return L10n.tr("Localizable", "assist.settings.on_device_tts.footer", fallback: "Use Apple's on-device speech synthesis for improved privacy. Text responses will be spoken locally without sending audio data to your server.") }
        /// On-device TTS
        public static var title: String { return L10n.tr("Localizable", "assist.settings.on_device_tts.title", fallback: "On-device TTS") }
        /// Voice
        public static var voice: String { return L10n.tr("Localizable", "assist.settings.on_device_tts.voice", fallback: "Voice") }
        public enum Quality {
          /// Enhanced
          public static var enhanced: String { return L10n.tr("Localizable", "assist.settings.on_device_tts.quality.enhanced", fallback: "Enhanced") }
          /// Premium
          public static var premium: String { return L10n.tr("Localizable", "assist.settings.on_device_tts.quality.premium", fallback: "Premium") }
        }
      }
      public enum Section {
        public enum Experimental {
          /// Experimental
          public static var title: String { return L10n.tr("Localizable", "assist.settings.section.experimental.title", fallback: "Experimental") }
        }
      }
      public enum TtsMute {
        /// When enabled, Assist will not play audio responses even if the pipeline has text-to-speech configured. You will still see text responses.
        public static var footer: String { return L10n.tr("Localizable", "assist.settings.tts_mute.footer", fallback: "When enabled, Assist will not play audio responses even if the pipeline has text-to-speech configured. You will still see text responses.") }
        /// Mute voice responses
        public static var toggle: String { return L10n.tr("Localizable", "assist.settings.tts_mute.toggle", fallback: "Mute voice responses") }
      }
    }
    public enum Watch {
      public enum MicButton {
        /// Tap to
        public static var title: String { return L10n.tr("Localizable", "assist.watch.mic_button.title", fallback: "Tap to") }
      }
      public enum NotReachable {
        /// Assist requires iPhone connectivity. Your iPhone is currently unreachable.
        public static var title: String { return L10n.tr("Localizable", "assist.watch.not_reachable.title", fallback: "Assist requires iPhone connectivity. Your iPhone is currently unreachable.") }
      }
      public enum Volume {
        /// Volume control
        public static var title: String { return L10n.tr("Localizable", "assist.watch.volume.title", fallback: "Volume control") }
      }
    }
  }
  public enum AssistPipelinePicker {
    /// No pipelines available
    public static var noPipelines: String { return L10n.tr("Localizable", "assist_pipeline_picker.no_pipelines", fallback: "No pipelines available") }
    /// Pick pipeline
    public static var placeholder: String { return L10n.tr("Localizable", "assist_pipeline_picker.placeholder", fallback: "Pick pipeline") }
  }
  public enum Camera {
    /// Server not found
    public static var serverNotFound: String { return L10n.tr("Localizable", "camera.server_not_found", fallback: "Server not found") }
    /// Failed to load camera snapshot
    public static var snapshotFailed: String { return L10n.tr("Localizable", "camera.snapshot_failed", fallback: "Failed to load camera snapshot") }
  }
  public enum CameraList {
    /// Not in a room
    public static var noArea: String { return L10n.tr("Localizable", "camera_list.no_area", fallback: "Not in a room") }
    /// Search cameras
    public static var searchPlaceholder: String { return L10n.tr("Localizable", "camera_list.search_placeholder", fallback: "Search cameras") }
    /// Cameras
    public static var title: String { return L10n.tr("Localizable", "camera_list.title", fallback: "Cameras") }
    public enum Edit {
      public enum Off {
        /// Edit
        public static var title: String { return L10n.tr("Localizable", "camera_list.edit.off.title", fallback: "Edit") }
      }
      public enum On {
        /// Done
        public static var title: String { return L10n.tr("Localizable", "camera_list.edit.on.title", fallback: "Done") }
      }
    }
    public enum Empty {
      /// No camera entities found in your Home Assistant setup
      public static var message: String { return L10n.tr("Localizable", "camera_list.empty.message", fallback: "No camera entities found in your Home Assistant setup") }
      /// No Cameras
      public static var title: String { return L10n.tr("Localizable", "camera_list.empty.title", fallback: "No Cameras") }
    }
    public enum NoResults {
      /// No cameras match your search
      public static var message: String { return L10n.tr("Localizable", "camera_list.no_results.message", fallback: "No cameras match your search") }
      /// No Results
      public static var title: String { return L10n.tr("Localizable", "camera_list.no_results.title", fallback: "No Results") }
    }
    public enum Reorder {
      public enum Section {
        /// Reorder sections
        public static var title: String { return L10n.tr("Localizable", "camera_list.reorder.section.title", fallback: "Reorder sections") }
      }
    }
    public enum Unavailable {
      /// Camera streaming is not available on Mac.
      public static var message: String { return L10n.tr("Localizable", "camera_list.unavailable.message", fallback: "Camera streaming is not available on Mac.") }
      /// Not Available on Mac
      public static var title: String { return L10n.tr("Localizable", "camera_list.unavailable.title", fallback: "Not Available on Mac") }
    }
  }
  public enum CameraPlayer {
    public enum Errors {
      /// No stream available
      public static var noStreamAvailable: String { return L10n.tr("Localizable", "camera_player.errors.no_stream_available", fallback: "No stream available") }
      /// Unable to connect to Home Assistant
      public static var unableToConnectToServer: String { return L10n.tr("Localizable", "camera_player.errors.unable_to_connect_to_server", fallback: "Unable to connect to Home Assistant") }
      /// Unknown error
      public static var unknown: String { return L10n.tr("Localizable", "camera_player.errors.unknown", fallback: "Unknown error") }
    }
  }
  public enum Cameras {
    /// Drag and drop to reorder
    public static var dragToReorder: String { return L10n.tr("Localizable", "cameras.drag_to_reorder", fallback: "Drag and drop to reorder") }
    /// No server found for camera: %@
    public static func noServerFound(_ p1: Any) -> String {
      return L10n.tr("Localizable", "cameras.no_server_found", String(describing: p1), fallback: "No server found for camera: %@")
    }
  }
  public enum CarPlay {
    public enum Action {
      public enum Intro {
        public enum Item {
          /// Tap to continue on your iPhone
          public static var body: String { return L10n.tr("Localizable", "carPlay.action.intro.item.body", fallback: "Tap to continue on your iPhone") }
          /// Create your first action
          public static var title: String { return L10n.tr("Localizable", "carPlay.action.intro.item.title", fallback: "Create your first action") }
        }
      }
    }
    public enum Config {
      public enum Tabs {
        /// Tabs
        public static var title: String { return L10n.tr("Localizable", "carPlay.config.tabs.title", fallback: "Tabs") }
      }
    }
    public enum Debug {
      public enum DeleteDb {
        public enum Alert {
          /// Are you sure you want to delete CarPlay configuration? This can't be reverted
          public static var title: String { return L10n.tr("Localizable", "carPlay.debug.delete_db.alert.title", fallback: "Are you sure you want to delete CarPlay configuration? This can't be reverted") }
          public enum Failed {
            /// Failed to delete configuration, error: %@
            public static func message(_ p1: Any) -> String {
              return L10n.tr("Localizable", "carPlay.debug.delete_db.alert.failed.message", String(describing: p1), fallback: "Failed to delete configuration, error: %@")
            }
          }
        }
        public enum Button {
          /// Delete CarPlay configuration
          public static var title: String { return L10n.tr("Localizable", "carPlay.debug.delete_db.button.title", fallback: "Delete CarPlay configuration") }
        }
        public enum Reset {
          /// Reset configuration
          public static var title: String { return L10n.tr("Localizable", "carPlay.debug.delete_db.reset.title", fallback: "Reset configuration") }
        }
      }
    }
    public enum Labels {
      /// Already added
      public static var alreadyAddedServer: String { return L10n.tr("Localizable", "carPlay.labels.already_added_server", fallback: "Already added") }
      /// No domains available
      public static var emptyDomainList: String { return L10n.tr("Localizable", "carPlay.labels.empty_domain_list", fallback: "No domains available") }
      /// No servers available. Add a server in the app.
      public static var noServersAvailable: String { return L10n.tr("Localizable", "carPlay.labels.no_servers_available", fallback: "No servers available. Add a server in the app.") }
      /// Select server
      public static var selectServer: String { return L10n.tr("Localizable", "carPlay.labels.select_server", fallback: "Select server") }
      /// Servers
      public static var servers: String { return L10n.tr("Localizable", "carPlay.labels.servers", fallback: "Servers") }
      public enum Settings {
        public enum Advanced {
          public enum Section {
            /// Advanced
            public static var title: String { return L10n.tr("Localizable", "carPlay.labels.settings.advanced.section.title", fallback: "Advanced") }
            public enum Button {
              /// Use this option if your server data is not loaded properly.
              public static var detail: String { return L10n.tr("Localizable", "carPlay.labels.settings.advanced.section.button.detail", fallback: "Use this option if your server data is not loaded properly.") }
              /// Restart App
              public static var title: String { return L10n.tr("Localizable", "carPlay.labels.settings.advanced.section.button.title", fallback: "Restart App") }
            }
          }
        }
      }
      public enum Tab {
        /// Settings
        public static var settings: String { return L10n.tr("Localizable", "carPlay.labels.tab.settings", fallback: "Settings") }
      }
    }
    public enum Lock {
      public enum Confirmation {
        /// Are you sure you want to perform lock action on %@?
        public static func title(_ p1: Any) -> String {
          return L10n.tr("Localizable", "carPlay.lock.confirmation.title", String(describing: p1), fallback: "Are you sure you want to perform lock action on %@?")
        }
      }
    }
    public enum Navigation {
      public enum Button {
        /// Next
        public static var next: String { return L10n.tr("Localizable", "carPlay.navigation.button.next", fallback: "Next") }
        /// Previous
        public static var previous: String { return L10n.tr("Localizable", "carPlay.navigation.button.previous", fallback: "Previous") }
      }
      public enum Tab {
        /// Actions
        public static var actions: String { return L10n.tr("Localizable", "carPlay.navigation.tab.actions", fallback: "Actions") }
        /// Areas
        public static var areas: String { return L10n.tr("Localizable", "carPlay.navigation.tab.areas", fallback: "Areas") }
        /// Control
        public static var domains: String { return L10n.tr("Localizable", "carPlay.navigation.tab.domains", fallback: "Control") }
        /// Quick access
        public static var quickAccess: String { return L10n.tr("Localizable", "carPlay.navigation.tab.quick_access", fallback: "Quick access") }
        /// Settings
        public static var settings: String { return L10n.tr("Localizable", "carPlay.navigation.tab.settings", fallback: "Settings") }
      }
    }
    public enum NoActions {
      /// Open iOS Companion App to create actions for CarPlay.
      public static var title: String { return L10n.tr("Localizable", "carPlay.no_actions.title", fallback: "Open iOS Companion App to create actions for CarPlay.") }
    }
    public enum NoEntities {
      /// No CarPlay compatible entities available.
      public static var title: String { return L10n.tr("Localizable", "carPlay.no_entities.title", fallback: "No CarPlay compatible entities available.") }
    }
    public enum Notification {
      public enum Action {
        public enum Intro {
          /// Tap to create your first iOS Action
          public static var body: String { return L10n.tr("Localizable", "carPlay.notification.action.intro.body", fallback: "Tap to create your first iOS Action") }
          /// Create iOS Action
          public static var title: String { return L10n.tr("Localizable", "carPlay.notification.action.intro.title", fallback: "Create iOS Action") }
        }
      }
      public enum QuickAccess {
        public enum Intro {
          /// Tap to create your CarPlay configuration.
          public static var body: String { return L10n.tr("Localizable", "carPlay.notification.quick_access.intro.body", fallback: "Tap to create your CarPlay configuration.") }
          /// Create CarPlay configuration
          public static var title: String { return L10n.tr("Localizable", "carPlay.notification.quick_access.intro.title", fallback: "Create CarPlay configuration") }
        }
      }
    }
    public enum QuickAccess {
      public enum Intro {
        public enum Item {
          /// Create your CarPlay configuration
          public static var title: String { return L10n.tr("Localizable", "carPlay.quick_access.intro.item.title", fallback: "Create your CarPlay configuration") }
        }
      }
    }
    public enum State {
      public enum Loading {
        /// Loading…
        public static var title: String { return L10n.tr("Localizable", "carPlay.state.loading.title", fallback: "Loading…") }
      }
    }
    public enum Tabs {
      public enum Active {
        /// Active
        public static var title: String { return L10n.tr("Localizable", "carPlay.tabs.active.title", fallback: "Active") }
        public enum DeleteAction {
          /// Swipe left to remove tab
          public static var title: String { return L10n.tr("Localizable", "carPlay.tabs.active.delete_action.title", fallback: "Swipe left to remove tab") }
        }
      }
      public enum Inactive {
        /// Inactive
        public static var title: String { return L10n.tr("Localizable", "carPlay.tabs.inactive.title", fallback: "Inactive") }
      }
    }
    public enum Unlock {
      public enum Confirmation {
        /// Are you sure you want to perform unlock action on %@?
        public static func title(_ p1: Any) -> String {
          return L10n.tr("Localizable", "carPlay.unlock.confirmation.title", String(describing: p1), fallback: "Are you sure you want to perform unlock action on %@?")
        }
      }
    }
  }
  public enum Carplay {
    public enum Labels {
      /// Already added
      public static var alreadyAddedServer: String { return L10n.tr("Localizable", "carplay.labels.already_added_server", fallback: "Already added") }
      /// No domains available
      public static var emptyDomainList: String { return L10n.tr("Localizable", "carplay.labels.empty_domain_list", fallback: "No domains available") }
      /// No servers available. Add a server in the app.
      public static var noServersAvailable: String { return L10n.tr("Localizable", "carplay.labels.no_servers_available", fallback: "No servers available. Add a server in the app.") }
      /// Servers
      public static var servers: String { return L10n.tr("Localizable", "carplay.labels.servers", fallback: "Servers") }
    }
    public enum Lock {
      public enum Confirmation {
        /// Are you sure you want to perform lock action on %@?
        public static func title(_ p1: Any) -> String {
          return L10n.tr("Localizable", "carplay.lock.confirmation.title", String(describing: p1), fallback: "Are you sure you want to perform lock action on %@?")
        }
      }
    }
    public enum Navigation {
      public enum Button {
        /// Next
        public static var next: String { return L10n.tr("Localizable", "carplay.navigation.button.next", fallback: "Next") }
        /// Previous
        public static var previous: String { return L10n.tr("Localizable", "carplay.navigation.button.previous", fallback: "Previous") }
      }
    }
    public enum Unlock {
      public enum Confirmation {
        /// Are you sure you want to perform unlock action on %@?
        public static func title(_ p1: Any) -> String {
          return L10n.tr("Localizable", "carplay.unlock.confirmation.title", String(describing: p1), fallback: "Are you sure you want to perform unlock action on %@?")
        }
      }
    }
  }
  public enum ClError {
    public enum Description {
      /// Deferred mode is not supported for the requested accuracy.
      public static var deferredAccuracyTooLow: String { return L10n.tr("Localizable", "cl_error.description.deferred_accuracy_too_low", fallback: "Deferred mode is not supported for the requested accuracy.") }
      /// The request for deferred updates was canceled by your app or by the location manager.
      public static var deferredCanceled: String { return L10n.tr("Localizable", "cl_error.description.deferred_canceled", fallback: "The request for deferred updates was canceled by your app or by the location manager.") }
      /// Deferred mode does not support distance filters.
      public static var deferredDistanceFiltered: String { return L10n.tr("Localizable", "cl_error.description.deferred_distance_filtered", fallback: "Deferred mode does not support distance filters.") }
      /// The location manager did not enter deferred mode for an unknown reason.
      public static var deferredFailed: String { return L10n.tr("Localizable", "cl_error.description.deferred_failed", fallback: "The location manager did not enter deferred mode for an unknown reason.") }
      /// The manager did not enter deferred mode since updates were already disabled/paused.
      public static var deferredNotUpdatingLocation: String { return L10n.tr("Localizable", "cl_error.description.deferred_not_updating_location", fallback: "The manager did not enter deferred mode since updates were already disabled/paused.") }
      /// Access to the location service was denied by the user.
      public static var denied: String { return L10n.tr("Localizable", "cl_error.description.denied", fallback: "Access to the location service was denied by the user.") }
      /// The geocode request was canceled.
      public static var geocodeCanceled: String { return L10n.tr("Localizable", "cl_error.description.geocode_canceled", fallback: "The geocode request was canceled.") }
      /// The geocode request yielded no result.
      public static var geocodeFoundNoResult: String { return L10n.tr("Localizable", "cl_error.description.geocode_found_no_result", fallback: "The geocode request yielded no result.") }
      /// The geocode request yielded a partial result.
      public static var geocodeFoundPartialResult: String { return L10n.tr("Localizable", "cl_error.description.geocode_found_partial_result", fallback: "The geocode request yielded a partial result.") }
      /// The heading could not be determined.
      public static var headingFailure: String { return L10n.tr("Localizable", "cl_error.description.heading_failure", fallback: "The heading could not be determined.") }
      /// The location manager was unable to obtain a location value right now.
      public static var locationUnknown: String { return L10n.tr("Localizable", "cl_error.description.location_unknown", fallback: "The location manager was unable to obtain a location value right now.") }
      /// The network was unavailable or a network error occurred.
      public static var network: String { return L10n.tr("Localizable", "cl_error.description.network", fallback: "The network was unavailable or a network error occurred.") }
      /// A general ranging error occurred.
      public static var rangingFailure: String { return L10n.tr("Localizable", "cl_error.description.ranging_failure", fallback: "A general ranging error occurred.") }
      /// Ranging is disabled.
      public static var rangingUnavailable: String { return L10n.tr("Localizable", "cl_error.description.ranging_unavailable", fallback: "Ranging is disabled.") }
      /// Access to the region monitoring service was denied by the user.
      public static var regionMonitoringDenied: String { return L10n.tr("Localizable", "cl_error.description.region_monitoring_denied", fallback: "Access to the region monitoring service was denied by the user.") }
      /// A registered region cannot be monitored.
      public static var regionMonitoringFailure: String { return L10n.tr("Localizable", "cl_error.description.region_monitoring_failure", fallback: "A registered region cannot be monitored.") }
      /// Core Location will deliver events but they may be delayed.
      public static var regionMonitoringResponseDelayed: String { return L10n.tr("Localizable", "cl_error.description.region_monitoring_response_delayed", fallback: "Core Location will deliver events but they may be delayed.") }
      /// Core Location could not initialize the region monitoring feature immediately.
      public static var regionMonitoringSetupDelayed: String { return L10n.tr("Localizable", "cl_error.description.region_monitoring_setup_delayed", fallback: "Core Location could not initialize the region monitoring feature immediately.") }
      /// Unknown Core Location error
      public static var unknown: String { return L10n.tr("Localizable", "cl_error.description.unknown", fallback: "Unknown Core Location error") }
    }
  }
  public enum ClientEvents {
    /// No events
    public static var noEvents: String { return L10n.tr("Localizable", "client_events.no_events", fallback: "No events") }
    public enum EventType {
      /// All
      public static var all: String { return L10n.tr("Localizable", "client_events.event_type.all", fallback: "All") }
      /// Background operation
      public static var backgroundOperation: String { return L10n.tr("Localizable", "client_events.event_type.background_operation", fallback: "Background operation") }
      /// Database
      public static var database: String { return L10n.tr("Localizable", "client_events.event_type.database", fallback: "Database") }
      /// Location Update
      public static var locationUpdate: String { return L10n.tr("Localizable", "client_events.event_type.location_update", fallback: "Location Update") }
      /// Network Request
      public static var networkRequest: String { return L10n.tr("Localizable", "client_events.event_type.networkRequest", fallback: "Network Request") }
      /// Notification
      public static var notification: String { return L10n.tr("Localizable", "client_events.event_type.notification", fallback: "Notification") }
      /// Service Call
      public static var serviceCall: String { return L10n.tr("Localizable", "client_events.event_type.service_call", fallback: "Service Call") }
      /// Settings
      public static var settings: String { return L10n.tr("Localizable", "client_events.event_type.settings", fallback: "Settings") }
      /// Unknown
      public static var unknown: String { return L10n.tr("Localizable", "client_events.event_type.unknown", fallback: "Unknown") }
      public enum Notification {
        /// Received a Push Notification: %@
        public static func title(_ p1: Any) -> String {
          return L10n.tr("Localizable", "client_events.event_type.notification.title", String(describing: p1), fallback: "Received a Push Notification: %@")
        }
      }
    }
    public enum View {
      /// Clear
      public static var clear: String { return L10n.tr("Localizable", "client_events.view.clear", fallback: "Clear") }
      public enum ClearConfirm {
        /// This cannot be undone.
        public static var message: String { return L10n.tr("Localizable", "client_events.view.clear_confirm.message", fallback: "This cannot be undone.") }
        /// Are you sure you want to clear all events?
        public static var title: String { return L10n.tr("Localizable", "client_events.view.clear_confirm.title", fallback: "Are you sure you want to clear all events?") }
      }
    }
  }
  public enum Component {
    public enum CollapsibleView {
      /// Collapse
      public static var collapse: String { return L10n.tr("Localizable", "component.collapsible_view.collapse", fallback: "Collapse") }
      /// Expand
      public static var expand: String { return L10n.tr("Localizable", "component.collapsible_view.expand", fallback: "Expand") }
    }
  }
  public enum Connection {
    public enum Error {
      /// Uh oh! Looks like we are unable to establish a connection.
      public static var genericTitle: String { return L10n.tr("Localizable", "connection.error.generic_title", fallback: "Uh oh! Looks like we are unable to establish a connection.") }
      public enum Details {
        /// Connection error
        public static var title: String { return L10n.tr("Localizable", "connection.error.details.title", fallback: "Connection error") }
        public enum Button {
          /// Copy to clipboard
          public static var clipboard: String { return L10n.tr("Localizable", "connection.error.details.button.clipboard", fallback: "Copy to clipboard") }
          /// Ask in Discord
          public static var discord: String { return L10n.tr("Localizable", "connection.error.details.button.discord", fallback: "Ask in Discord") }
          /// Read documentation
          public static var doc: String { return L10n.tr("Localizable", "connection.error.details.button.doc", fallback: "Read documentation") }
          /// Report issue in GitHub
          public static var github: String { return L10n.tr("Localizable", "connection.error.details.button.github", fallback: "Report issue in GitHub") }
          /// Search in GitHub
          public static var searchGithub: String { return L10n.tr("Localizable", "connection.error.details.button.search_github", fallback: "Search in GitHub") }
        }
        public enum Label {
          /// Code
          public static var code: String { return L10n.tr("Localizable", "connection.error.details.label.code", fallback: "Code") }
          /// Description
          public static var description: String { return L10n.tr("Localizable", "connection.error.details.label.description", fallback: "Description") }
          /// Domain
          public static var domain: String { return L10n.tr("Localizable", "connection.error.details.label.domain", fallback: "Domain") }
        }
      }
      public enum FailedConnect {
        /// Check your connection and try again. If you are not at home make sure you have configured remote access.
        public static var subtitle: String { return L10n.tr("Localizable", "connection.error.failed_connect.subtitle", fallback: "Check your connection and try again. If you are not at home make sure you have configured remote access.") }
        /// We couldn't connect to Home Assistant
        public static var title: String { return L10n.tr("Localizable", "connection.error.failed_connect.title", fallback: "We couldn't connect to Home Assistant") }
        /// The app is currently connecting to
        public static var url: String { return L10n.tr("Localizable", "connection.error.failed_connect.url", fallback: "The app is currently connecting to") }
        public enum Cloud {
          /// Make sure your Home Assistant Cloud subscription is active and connected to your server, you can verify that at [Nabu Casa](https://account.nabucasa.com)
          public static var title: String { return L10n.tr("Localizable", "connection.error.failed_connect.cloud.title", fallback: "Make sure your Home Assistant Cloud subscription is active and connected to your server, you can verify that at [Nabu Casa](https://account.nabucasa.com)") }
        }
        public enum CloudInactive {
          /// You have disabled Home Assistant Cloud use in the app, if you need it for remote access please open companion app settings and enable it.
          public static var title: String { return L10n.tr("Localizable", "connection.error.failed_connect.cloud_inactive.title", fallback: "You have disabled Home Assistant Cloud use in the app, if you need it for remote access please open companion app settings and enable it.") }
        }
      }
    }
    public enum Permission {
      public enum InternalUrl {
        /// To access Home Assistant locally in a secure way, you need to grant the location permission ('Always').
        public static var body1: String { return L10n.tr("Localizable", "connection.permission.internal_url.body1", fallback: "To access Home Assistant locally in a secure way, you need to grant the location permission ('Always').") }
        /// This permission allows Home Assistant to detect the wireless network that you're connected to and establish a local connection.
        public static var body2: String { return L10n.tr("Localizable", "connection.permission.internal_url.body2", fallback: "This permission allows Home Assistant to detect the wireless network that you're connected to and establish a local connection.") }
        /// If you still want to use the local URL and don't want to provide location permission, you can tap the button below, but please, be aware of the security risks.
        public static var footer: String { return L10n.tr("Localizable", "connection.permission.internal_url.footer", fallback: "If you still want to use the local URL and don't want to provide location permission, you can tap the button below, but please, be aware of the security risks.") }
        /// Permission access
        public static var title: String { return L10n.tr("Localizable", "connection.permission.internal_url.title", fallback: "Permission access") }
        public enum Ignore {
          public enum Alert {
            /// Are you sure?
            public static var title: String { return L10n.tr("Localizable", "connection.permission.internal_url.ignore.alert.title", fallback: "Are you sure?") }
          }
        }
      }
    }
  }
  public enum ConnectionError {
    public enum AdvancedSection {
      /// Advanced
      public static var title: String { return L10n.tr("Localizable", "connection_error.advanced_section.title", fallback: "Advanced") }
    }
    public enum MoreDetailsSection {
      /// More details
      public static var title: String { return L10n.tr("Localizable", "connection_error.more_details_section.title", fallback: "More details") }
    }
    public enum OpenSettings {
      /// Open settings
      public static var title: String { return L10n.tr("Localizable", "connection_error.open_settings.title", fallback: "Open settings") }
    }
  }
  public enum ConnectionSecurityLevelBlock {
    /// Due to your connection security choice ('Most secure'), there's no URL that we are allowed to use.
    public static var body: String { return L10n.tr("Localizable", "connection_security_level_block.body", fallback: "Due to your connection security choice ('Most secure'), there's no URL that we are allowed to use.") }
    /// Tip: Double check your device settings and app permissions. Make sure the app is allowed local network access and location access is set to 'Always' (so it also works in background) and 'Full' (so the app can identify which network you are using and detect your home network).
    public static var tip: String { return L10n.tr("Localizable", "connection_security_level_block.tip", fallback: "Tip: Double check your device settings and app permissions. Make sure the app is allowed local network access and location access is set to 'Always' (so it also works in background) and 'Full' (so the app can identify which network you are using and detect your home network).") }
    /// You're disconnected
    public static var title: String { return L10n.tr("Localizable", "connection_security_level_block.title", fallback: "You're disconnected") }
    public enum ChangePreference {
      /// Change connection preference
      public static var title: String { return L10n.tr("Localizable", "connection_security_level_block.change_preference.title", fallback: "Change connection preference") }
    }
    public enum OpenSettings {
      /// Open settings
      public static var title: String { return L10n.tr("Localizable", "connection_security_level_block.open_settings.title", fallback: "Open settings") }
    }
    public enum Requirement {
      /// Missing requirements
      public static var title: String { return L10n.tr("Localizable", "connection_security_level_block.requirement.title", fallback: "Missing requirements") }
      public enum HomeNetworkMissing {
        /// Configure local network
        public static var title: String { return L10n.tr("Localizable", "connection_security_level_block.requirement.home_network_missing.title", fallback: "Configure local network") }
      }
      public enum LearnMore {
        /// Learn more
        public static var title: String { return L10n.tr("Localizable", "connection_security_level_block.requirement.learn_more.title", fallback: "Learn more") }
      }
      public enum LocationPermissionMissing {
        /// Grant location permission
        public static var title: String { return L10n.tr("Localizable", "connection_security_level_block.requirement.location_permission_missing.title", fallback: "Grant location permission") }
      }
      public enum NotOnHomeNetwork {
        /// Connect to your home network
        public static var title: String { return L10n.tr("Localizable", "connection_security_level_block.requirement.not_on_home_network.title", fallback: "Connect to your home network") }
      }
    }
  }
  public enum Connectivity {
    public enum Check {
      /// DNS Resolution
      public static var dns: String { return L10n.tr("Localizable", "connectivity.check.dns", fallback: "DNS Resolution") }
      /// Port Reachability
      public static var port: String { return L10n.tr("Localizable", "connectivity.check.port", fallback: "Port Reachability") }
      /// Checking...
      public static var running: String { return L10n.tr("Localizable", "connectivity.check.running", fallback: "Checking...") }
      /// Server Connection
      public static var server: String { return L10n.tr("Localizable", "connectivity.check.server", fallback: "Server Connection") }
      /// Skipped due to previous failure
      public static var skipped: String { return L10n.tr("Localizable", "connectivity.check.skipped", fallback: "Skipped due to previous failure") }
      /// TLS Certificate
      public static var tls: String { return L10n.tr("Localizable", "connectivity.check.tls", fallback: "TLS Certificate") }
      public enum Dns {
        /// Resolving hostname to IP address
        public static var description: String { return L10n.tr("Localizable", "connectivity.check.dns.description", fallback: "Resolving hostname to IP address") }
      }
      public enum Port {
        /// Checking if port is reachable
        public static var description: String { return L10n.tr("Localizable", "connectivity.check.port.description", fallback: "Checking if port is reachable") }
      }
      public enum Server {
        /// Testing server connection
        public static var description: String { return L10n.tr("Localizable", "connectivity.check.server.description", fallback: "Testing server connection") }
      }
      public enum Tls {
        /// Validating TLS certificate
        public static var description: String { return L10n.tr("Localizable", "connectivity.check.tls.description", fallback: "Validating TLS certificate") }
      }
    }
    public enum Diagnostics {
      /// Run checks
      public static var runChecks: String { return L10n.tr("Localizable", "connectivity.diagnostics.run_checks", fallback: "Run checks") }
      /// Start diagnostics
      public static var start: String { return L10n.tr("Localizable", "connectivity.diagnostics.start", fallback: "Start diagnostics") }
      /// Connectivity diagnostics
      public static var title: String { return L10n.tr("Localizable", "connectivity.diagnostics.title", fallback: "Connectivity diagnostics") }
    }
  }
  public enum Database {
    public enum Problem {
      /// Delete Database & Quit App
      public static var delete: String { return L10n.tr("Localizable", "database.problem.delete", fallback: "Delete Database & Quit App") }
      /// Quit App
      public static var quit: String { return L10n.tr("Localizable", "database.problem.quit", fallback: "Quit App") }
      /// Database Error
      public static var title: String { return L10n.tr("Localizable", "database.problem.title", fallback: "Database Error") }
    }
  }
  public enum DatabaseUpdater {
    public enum Toast {
      /// Syncing server data... (%li/%li)
      public static func syncingWithProgress(_ p1: Int, _ p2: Int) -> String {
        return L10n.tr("Localizable", "database_updater.toast.syncing_with_progress", p1, p2, fallback: "Syncing server data... (%li/%li)")
      }
      /// Updating %@
      public static func title(_ p1: Any) -> String {
        return L10n.tr("Localizable", "database_updater.toast.title", String(describing: p1), fallback: "Updating %@")
      }
    }
  }
  public enum Debug {
    public enum Reset {
      public enum EntitiesDatabase {
        /// Reset app entities database
        public static var title: String { return L10n.tr("Localizable", "debug.reset.entities_database.title", fallback: "Reset app entities database") }
      }
    }
  }
  public enum DeviceName {
    /// This is used to identify your device in your Home Assistant.
    public static var subtitle: String { return L10n.tr("Localizable", "device_name.subtitle", fallback: "This is used to identify your device in your Home Assistant.") }
    /// How would you like to name this device?
    public static var title: String { return L10n.tr("Localizable", "device_name.title", fallback: "How would you like to name this device?") }
    public enum PrimaryButton {
      /// Save
      public static var title: String { return L10n.tr("Localizable", "device_name.primary_button.title", fallback: "Save") }
    }
    public enum Textfield {
      /// iPhone/iPad/Mac name
      public static var placeholder: String { return L10n.tr("Localizable", "device_name.textfield.placeholder", fallback: "iPhone/iPad/Mac name") }
    }
  }
  public enum DownloadManager {
    public enum Downloading {
      /// Downloading
      public static var title: String { return L10n.tr("Localizable", "download_manager.downloading.title", fallback: "Downloading") }
    }
    public enum Failed {
      /// Failed to download file, error: %@
      public static func title(_ p1: Any) -> String {
        return L10n.tr("Localizable", "download_manager.failed.title", String(describing: p1), fallback: "Failed to download file, error: %@")
      }
    }
    public enum Finished {
      /// Download finished
      public static var title: String { return L10n.tr("Localizable", "download_manager.finished.title", fallback: "Download finished") }
    }
  }
  public enum EntityPicker {
    /// Pick entity
    public static var placeholder: String { return L10n.tr("Localizable", "entity_picker.placeholder", fallback: "Pick entity") }
    public enum Filter {
      public enum Area {
        /// Area
        public static var title: String { return L10n.tr("Localizable", "entity_picker.filter.area.title", fallback: "Area") }
        public enum All {
          /// All areas
          public static var title: String { return L10n.tr("Localizable", "entity_picker.filter.area.all.title", fallback: "All areas") }
        }
      }
      public enum Domain {
        /// Domain
        public static var title: String { return L10n.tr("Localizable", "entity_picker.filter.domain.title", fallback: "Domain") }
        public enum All {
          /// All domains
          public static var title: String { return L10n.tr("Localizable", "entity_picker.filter.domain.all.title", fallback: "All domains") }
        }
      }
      public enum GroupBy {
        /// Group by
        public static var title: String { return L10n.tr("Localizable", "entity_picker.filter.group_by.title", fallback: "Group by") }
      }
      public enum Server {
        /// Servers
        public static var title: String { return L10n.tr("Localizable", "entity_picker.filter.server.title", fallback: "Servers") }
      }
    }
    public enum List {
      public enum Area {
        public enum NoArea {
          /// No area
          public static var title: String { return L10n.tr("Localizable", "entity_picker.list.area.no_area.title", fallback: "No area") }
        }
      }
    }
    public enum Search {
      /// Entity name, ID, area name, device name...
      public static var placeholder: String { return L10n.tr("Localizable", "entity_picker.search.placeholder", fallback: "Entity name, ID, area name, device name...") }
    }
  }
  public enum Error {
    public enum ClientCertificate {
      /// Client Certificate Authentication required.
      /// 
      /// This server requires a client certificate (mTLS) but the operation was cancelled.
      public static var flowCancelled: String { return L10n.tr("Localizable", "error.client_certificate.flow_cancelled", fallback: "Client Certificate Authentication required.\n\nThis server requires a client certificate (mTLS) but the operation was cancelled.") }
      /// Client Certificate Authentication failed.
      /// 
      /// %@
      public static func flowFailed(_ p1: Any) -> String {
        return L10n.tr("Localizable", "error.client_certificate.flow_failed", String(describing: p1), fallback: "Client Certificate Authentication failed.\n\n%@")
      }
    }
  }
  public enum Experimental {
    public enum Badge {
      /// This is an experimental feature, you may experience unexpected behavior, please report any issues you may encounter.
      public static var body: String { return L10n.tr("Localizable", "experimental.badge.body", fallback: "This is an experimental feature, you may experience unexpected behavior, please report any issues you may encounter.") }
      /// Experimental feature
      public static var title: String { return L10n.tr("Localizable", "experimental.badge.title", fallback: "Experimental feature") }
      public enum ReportIssueButton {
        /// Report issue
        public static var title: String { return L10n.tr("Localizable", "experimental.badge.report_issue_button.title", fallback: "Report issue") }
      }
    }
  }
  public enum Extensions {
    public enum Map {
      public enum Location {
        /// New Location
        public static var new: String { return L10n.tr("Localizable", "extensions.map.location.new", fallback: "New Location") }
        /// Original Location
        public static var original: String { return L10n.tr("Localizable", "extensions.map.location.original", fallback: "Original Location") }
      }
      public enum PayloadMissingHomeassistant {
        /// Payload didn't contain a homeassistant dictionary!
        public static var message: String { return L10n.tr("Localizable", "extensions.map.payload_missing_homeassistant.message", fallback: "Payload didn't contain a homeassistant dictionary!") }
      }
      public enum ValueMissingOrUncastable {
        public enum Latitude {
          /// Latitude wasn't found or couldn't be casted to string!
          public static var message: String { return L10n.tr("Localizable", "extensions.map.value_missing_or_uncastable.latitude.message", fallback: "Latitude wasn't found or couldn't be casted to string!") }
        }
        public enum Longitude {
          /// Longitude wasn't found or couldn't be casted to string!
          public static var message: String { return L10n.tr("Localizable", "extensions.map.value_missing_or_uncastable.longitude.message", fallback: "Longitude wasn't found or couldn't be casted to string!") }
        }
      }
    }
    public enum NotificationContent {
      public enum Error {
        /// No entity_id found in payload!
        public static var noEntityId: String { return L10n.tr("Localizable", "extensions.notification_content.error.no_entity_id", fallback: "No entity_id found in payload!") }
        public enum Request {
          /// Authentication failed!
          public static var authFailed: String { return L10n.tr("Localizable", "extensions.notification_content.error.request.auth_failed", fallback: "Authentication failed!") }
          /// Entity '%@' not found!
          public static func entityNotFound(_ p1: Any) -> String {
            return L10n.tr("Localizable", "extensions.notification_content.error.request.entity_not_found", String(describing: p1), fallback: "Entity '%@' not found!")
          }
          /// HLS stream unavailable
          public static var hlsUnavailable: String { return L10n.tr("Localizable", "extensions.notification_content.error.request.hls_unavailable", fallback: "HLS stream unavailable") }
          /// Got non-200 status code (%li)
          public static func other(_ p1: Int) -> String {
            return L10n.tr("Localizable", "extensions.notification_content.error.request.other", p1, fallback: "Got non-200 status code (%li)")
          }
        }
      }
    }
  }
  public enum Gestures {
    public enum _1Finger {
      /// Using one finger
      public static var title: String { return L10n.tr("Localizable", "gestures.1_finger.title", fallback: "Using one finger") }
    }
    public enum _2Fingers {
      /// Using two fingers
      public static var title: String { return L10n.tr("Localizable", "gestures.2_fingers.title", fallback: "Using two fingers") }
    }
    public enum _2FingersSwipeDown {
      /// 2 👆 swipe down
      public static var title: String { return L10n.tr("Localizable", "gestures.2_fingers_swipe_down.title", fallback: "2 👆 swipe down") }
    }
    public enum _2FingersSwipeLeft {
      /// 2 👆 swipe left
      public static var title: String { return L10n.tr("Localizable", "gestures.2_fingers_swipe_left.title", fallback: "2 👆 swipe left") }
    }
    public enum _2FingersSwipeRight {
      /// 2 👆 swipe right
      public static var title: String { return L10n.tr("Localizable", "gestures.2_fingers_swipe_right.title", fallback: "2 👆 swipe right") }
    }
    public enum _2FingersSwipeUp {
      /// 2 👆 swipe up
      public static var title: String { return L10n.tr("Localizable", "gestures.2_fingers_swipe_up.title", fallback: "2 👆 swipe up") }
    }
    public enum _3Fingers {
      /// Using three fingers
      public static var title: String { return L10n.tr("Localizable", "gestures.3_fingers.title", fallback: "Using three fingers") }
    }
    public enum _3FingersSwipeDown {
      /// 3 👆 swipe down
      public static var title: String { return L10n.tr("Localizable", "gestures.3_fingers_swipe_down.title", fallback: "3 👆 swipe down") }
    }
    public enum _3FingersSwipeLeft {
      /// 3 👆 swipe left
      public static var title: String { return L10n.tr("Localizable", "gestures.3_fingers_swipe_left.title", fallback: "3 👆 swipe left") }
    }
    public enum _3FingersSwipeRight {
      /// 3 👆 swipe right
      public static var title: String { return L10n.tr("Localizable", "gestures.3_fingers_swipe_right.title", fallback: "3 👆 swipe right") }
    }
    public enum _3FingersSwipeUp {
      /// 3 👆 swipe up
      public static var title: String { return L10n.tr("Localizable", "gestures.3_fingers_swipe_up.title", fallback: "3 👆 swipe up") }
    }
    public enum Category {
      /// App
      public static var app: String { return L10n.tr("Localizable", "gestures.category.app", fallback: "App") }
      /// Home Assistant
      public static var homeAssistant: String { return L10n.tr("Localizable", "gestures.category.homeAssistant", fallback: "Home Assistant") }
      /// Other
      public static var other: String { return L10n.tr("Localizable", "gestures.category.other", fallback: "Other") }
      /// Navigation
      public static var page: String { return L10n.tr("Localizable", "gestures.category.page", fallback: "Navigation") }
      /// Servers
      public static var servers: String { return L10n.tr("Localizable", "gestures.category.servers", fallback: "Servers") }
    }
    public enum Footer {
      /// Customize gestures to be used on the frontend.
      public static var title: String { return L10n.tr("Localizable", "gestures.footer.title", fallback: "Customize gestures to be used on the frontend.") }
    }
    public enum Reset {
      /// Reset
      public static var title: String { return L10n.tr("Localizable", "gestures.reset.title", fallback: "Reset") }
      public enum Confirmation {
        /// This will reset all gestures to their default values.
        public static var message: String { return L10n.tr("Localizable", "gestures.reset.confirmation.message", fallback: "This will reset all gestures to their default values.") }
        /// Reset Gestures?
        public static var title: String { return L10n.tr("Localizable", "gestures.reset.confirmation.title", fallback: "Reset Gestures?") }
      }
    }
    public enum Screen {
      /// Gestures below will be applied whenever you are using Home Assistant main UI.
      public static var body: String { return L10n.tr("Localizable", "gestures.screen.body", fallback: "Gestures below will be applied whenever you are using Home Assistant main UI.") }
      /// Gestures
      public static var title: String { return L10n.tr("Localizable", "gestures.screen.title", fallback: "Gestures") }
    }
    public enum Shake {
      /// Shake
      public static var title: String { return L10n.tr("Localizable", "gestures.shake.title", fallback: "Shake") }
    }
    public enum Swipe {
      public enum Down {
        /// Swipe down
        public static var header: String { return L10n.tr("Localizable", "gestures.swipe.down.header", fallback: "Swipe down") }
      }
      public enum Left {
        /// Swipe left
        public static var header: String { return L10n.tr("Localizable", "gestures.swipe.left.header", fallback: "Swipe left") }
      }
      public enum Right {
        /// Swipe right
        public static var header: String { return L10n.tr("Localizable", "gestures.swipe.right.header", fallback: "Swipe right") }
      }
      public enum Up {
        /// Swipe up
        public static var header: String { return L10n.tr("Localizable", "gestures.swipe.up.header", fallback: "Swipe up") }
      }
    }
    public enum SwipeLeft {
      /// Swipe Left
      public static var title: String { return L10n.tr("Localizable", "gestures.swipe_left.title", fallback: "Swipe Left") }
    }
    public enum SwipeRight {
      /// Swipe Right
      public static var title: String { return L10n.tr("Localizable", "gestures.swipe_right.title", fallback: "Swipe Right") }
    }
    public enum Value {
      public enum Option {
        /// Open Assist
        public static var assist: String { return L10n.tr("Localizable", "gestures.value.option.assist", fallback: "Open Assist") }
        /// Back to previous page
        public static var backPage: String { return L10n.tr("Localizable", "gestures.value.option.back_page", fallback: "Back to previous page") }
        /// Go to next page
        public static var nextPage: String { return L10n.tr("Localizable", "gestures.value.option.next_page", fallback: "Go to next page") }
        /// Next server
        public static var nextServer: String { return L10n.tr("Localizable", "gestures.value.option.next_server", fallback: "Next server") }
        /// None
        public static var `none`: String { return L10n.tr("Localizable", "gestures.value.option.none", fallback: "None") }
        /// Open debug
        public static var openDebug: String { return L10n.tr("Localizable", "gestures.value.option.open_debug", fallback: "Open debug") }
        /// Previous server
        public static var previousServer: String { return L10n.tr("Localizable", "gestures.value.option.previous_server", fallback: "Previous server") }
        /// Quick search
        public static var quickSearch: String { return L10n.tr("Localizable", "gestures.value.option.quick_search", fallback: "Quick search") }
        /// Search commands
        public static var searchCommands: String { return L10n.tr("Localizable", "gestures.value.option.search_commands", fallback: "Search commands") }
        /// Search devices
        public static var searchDevices: String { return L10n.tr("Localizable", "gestures.value.option.search_devices", fallback: "Search devices") }
        /// Search entities
        public static var searchEntities: String { return L10n.tr("Localizable", "gestures.value.option.search_entities", fallback: "Search entities") }
        /// Servers list
        public static var serversList: String { return L10n.tr("Localizable", "gestures.value.option.servers_list", fallback: "Servers list") }
        /// Open App settings
        public static var showSettings: String { return L10n.tr("Localizable", "gestures.value.option.show_settings", fallback: "Open App settings") }
        /// Show sidebar
        public static var showSidebar: String { return L10n.tr("Localizable", "gestures.value.option.show_sidebar", fallback: "Show sidebar") }
        public enum MoreInfo {
          /// Quick search
          public static var quickSearch: String { return L10n.tr("Localizable", "gestures.value.option.more_info.quick_search", fallback: "Quick search") }
          /// Search commands
          public static var searchCommands: String { return L10n.tr("Localizable", "gestures.value.option.more_info.search_commands", fallback: "Search commands") }
          /// Search devices
          public static var searchDevices: String { return L10n.tr("Localizable", "gestures.value.option.more_info.search_devices", fallback: "Search devices") }
          /// Search entities
          public static var searchEntities: String { return L10n.tr("Localizable", "gestures.value.option.more_info.search_entities", fallback: "Search entities") }
        }
      }
    }
  }
  public enum Grdb {
    public enum Config {
      public enum MigrationError {
        /// Failed to access database (GRDB), error: %@
        public static func failedAccessGrdb(_ p1: Any) -> String {
          return L10n.tr("Localizable", "grdb.config.migration_error.failed_access_grdb", String(describing: p1), fallback: "Failed to access database (GRDB), error: %@")
        }
        /// Failed to save new config, error: %@
        public static func failedToSave(_ p1: Any) -> String {
          return L10n.tr("Localizable", "grdb.config.migration_error.failed_to_save", String(describing: p1), fallback: "Failed to save new config, error: %@")
        }
      }
    }
  }
  public enum HaApi {
    public enum ApiError {
      /// Cant build API URL
      public static var cantBuildUrl: String { return L10n.tr("Localizable", "ha_api.api_error.cant_build_url", fallback: "Cant build API URL") }
      /// Received invalid response from Home Assistant
      public static var invalidResponse: String { return L10n.tr("Localizable", "ha_api.api_error.invalid_response", fallback: "Received invalid response from Home Assistant") }
      /// HA API Manager is unavailable
      public static var managerNotAvailable: String { return L10n.tr("Localizable", "ha_api.api_error.manager_not_available", fallback: "HA API Manager is unavailable") }
      /// The mobile_app component is not loaded. Please add it to your configuration, restart Home Assistant, and try again.
      public static var mobileAppComponentNotLoaded: String { return L10n.tr("Localizable", "ha_api.api_error.mobile_app_component_not_loaded", fallback: "The mobile_app component is not loaded. Please add it to your configuration, restart Home Assistant, and try again.") }
      /// Your Home Assistant version (%@) is too old, you must upgrade to at least version %@ to use the app.
      public static func mustUpgradeHomeAssistant(_ p1: Any, _ p2: Any) -> String {
        return L10n.tr("Localizable", "ha_api.api_error.must_upgrade_home_assistant", String(describing: p1), String(describing: p2), fallback: "Your Home Assistant version (%@) is too old, you must upgrade to at least version %@ to use the app.")
      }
      /// No API available, double check if internal URL or external URL are available.
      public static var noAvailableApi: String { return L10n.tr("Localizable", "ha_api.api_error.no_available_api", fallback: "No API available, double check if internal URL or external URL are available.") }
      /// HA API not configured
      public static var notConfigured: String { return L10n.tr("Localizable", "ha_api.api_error.not_configured", fallback: "HA API not configured") }
      /// Unacceptable status code %1$li.
      public static func unacceptableStatusCode(_ p1: Int) -> String {
        return L10n.tr("Localizable", "ha_api.api_error.unacceptable_status_code", p1, fallback: "Unacceptable status code %1$li.")
      }
      /// Received response with result of type %1$@ but expected type %2$@.
      public static func unexpectedType(_ p1: Any, _ p2: Any) -> String {
        return L10n.tr("Localizable", "ha_api.api_error.unexpected_type", String(describing: p1), String(describing: p2), fallback: "Received response with result of type %1$@ but expected type %2$@.")
      }
      /// An unknown error occurred.
      public static var unknown: String { return L10n.tr("Localizable", "ha_api.api_error.unknown", fallback: "An unknown error occurred.") }
      /// Operation could not be performed.
      public static var updateNotPossible: String { return L10n.tr("Localizable", "ha_api.api_error.update_not_possible", fallback: "Operation could not be performed.") }
    }
  }
  public enum HomeSectionsReorderView {
    /// Done
    public static var done: String { return L10n.tr("Localizable", "home_sections_reorder_view.done", fallback: "Done") }
    /// Reorder Rooms
    public static var title: String { return L10n.tr("Localizable", "home_sections_reorder_view.title", fallback: "Reorder Rooms") }
  }
  public enum HomeView {
    public enum Areas {
      /// Areas
      public static var title: String { return L10n.tr("Localizable", "home_view.areas.title", fallback: "Areas") }
    }
    public enum CommonControls {
      /// Welcome %@
      public static func title(_ p1: Any) -> String {
        return L10n.tr("Localizable", "home_view.common_controls.title", String(describing: p1), fallback: "Welcome %@")
      }
    }
    public enum ContextMenu {
      /// Hide
      public static var hide: String { return L10n.tr("Localizable", "home_view.context_menu.hide", fallback: "Hide") }
    }
    public enum Customization {
      public enum AreasLayout {
        /// Areas layout
        public static var title: String { return L10n.tr("Localizable", "home_view.customization.areas_layout.title", fallback: "Areas layout") }
        public enum Grid {
          /// Grid
          public static var title: String { return L10n.tr("Localizable", "home_view.customization.areas_layout.grid.title", fallback: "Grid") }
        }
        public enum List {
          /// List
          public static var title: String { return L10n.tr("Localizable", "home_view.customization.areas_layout.list.title", fallback: "List") }
        }
      }
      public enum CommonControls {
        /// Controls prediction section
        public static var title: String { return L10n.tr("Localizable", "home_view.customization.common_controls.title", fallback: "Controls prediction section") }
      }
      public enum Summaries {
        /// Summaries
        public static var title: String { return L10n.tr("Localizable", "home_view.customization.summaries.title", fallback: "Summaries") }
      }
    }
    public enum Menu {
      /// Allow multiple selection
      public static var allowMultipleSelection: String { return L10n.tr("Localizable", "home_view.menu.allow_multiple_selection", fallback: "Allow multiple selection") }
      /// Customize
      public static var customize: String { return L10n.tr("Localizable", "home_view.menu.customize", fallback: "Customize") }
      /// Reorder
      public static var reorder: String { return L10n.tr("Localizable", "home_view.menu.reorder", fallback: "Reorder") }
      /// Settings
      public static var settings: String { return L10n.tr("Localizable", "home_view.menu.settings", fallback: "Settings") }
    }
    public enum Summaries {
      /// %li active
      public static func countActive(_ p1: Int) -> String {
        return L10n.tr("Localizable", "home_view.summaries.count_active", p1, fallback: "%li active")
      }
      /// Summaries
      public static var title: String { return L10n.tr("Localizable", "home_view.summaries.title", fallback: "Summaries") }
      public enum Covers {
        /// %li open
        public static func countOpen(_ p1: Int) -> String {
          return L10n.tr("Localizable", "home_view.summaries.covers.count_open", p1, fallback: "%li open")
        }
        /// Covers
        public static var title: String { return L10n.tr("Localizable", "home_view.summaries.covers.title", fallback: "Covers") }
      }
      public enum Lights {
        /// %li on
        public static func countOn(_ p1: Int) -> String {
          return L10n.tr("Localizable", "home_view.summaries.lights.count_on", p1, fallback: "%li on")
        }
        /// Lights
        public static var title: String { return L10n.tr("Localizable", "home_view.summaries.lights.title", fallback: "Lights") }
      }
    }
  }
  public enum Improv {
    public enum Button {
      /// Continue
      public static var `continue`: String { return L10n.tr("Localizable", "improv.button.continue", fallback: "Continue") }
    }
    public enum ConnectionState {
      /// Setting up Wi-Fi
      public static var authorized: String { return L10n.tr("Localizable", "improv.connection_state.authorized", fallback: "Setting up Wi-Fi") }
      /// Connecting to Wi-Fi
      public static var provisioning: String { return L10n.tr("Localizable", "improv.connection_state.provisioning", fallback: "Connecting to Wi-Fi") }
    }
    public enum ErrorState {
      /// Invalid RPC Packet
      public static var invalidRpcPacket: String { return L10n.tr("Localizable", "improv.error_state.invalid_rpc_packet", fallback: "Invalid RPC Packet") }
      /// Not authorized
      public static var notAuthorized: String { return L10n.tr("Localizable", "improv.error_state.not_authorized", fallback: "Not authorized") }
      /// Unable to connect
      public static var unableToConnect: String { return L10n.tr("Localizable", "improv.error_state.unable_to_connect", fallback: "Unable to connect") }
      /// Unknown error, please try again.
      public static var unknown: String { return L10n.tr("Localizable", "improv.error_state.unknown", fallback: "Unknown error, please try again.") }
      /// Unknown command
      public static var unknownCommand: String { return L10n.tr("Localizable", "improv.error_state.unknown_command", fallback: "Unknown command") }
    }
    public enum List {
      /// Devices ready to set up
      public static var title: String { return L10n.tr("Localizable", "improv.list.title", fallback: "Devices ready to set up") }
    }
    public enum State {
      /// Connected
      public static var connected: String { return L10n.tr("Localizable", "improv.state.connected", fallback: "Connected") }
      /// Connecting...
      public static var connecting: String { return L10n.tr("Localizable", "improv.state.connecting", fallback: "Connecting...") }
      /// Wi-Fi connected successfully
      public static var success: String { return L10n.tr("Localizable", "improv.state.success", fallback: "Wi-Fi connected successfully") }
    }
    public enum Toast {
      /// There are devices available to setup.
      public static var title: String { return L10n.tr("Localizable", "improv.toast.title", fallback: "There are devices available to setup.") }
    }
    public enum Wifi {
      public enum Alert {
        /// Cancel
        public static var cancelButton: String { return L10n.tr("Localizable", "improv.wifi.alert.cancel_button", fallback: "Cancel") }
        /// Connect
        public static var connectButton: String { return L10n.tr("Localizable", "improv.wifi.alert.connect_button", fallback: "Connect") }
        /// Please enter your SSID and password.
        public static var description: String { return L10n.tr("Localizable", "improv.wifi.alert.description", fallback: "Please enter your SSID and password.") }
        /// Password
        public static var passwordPlaceholder: String { return L10n.tr("Localizable", "improv.wifi.alert.password_placeholder", fallback: "Password") }
        /// Network Name
        public static var ssidPlaceholder: String { return L10n.tr("Localizable", "improv.wifi.alert.ssid_placeholder", fallback: "Network Name") }
        /// Connect to WiFi
        public static var title: String { return L10n.tr("Localizable", "improv.wifi.alert.title", fallback: "Connect to WiFi") }
      }
    }
  }
  public enum Intents {
    /// Select a server before picking this value.
    public static var serverRequiredForValue: String { return L10n.tr("Localizable", "intents.server_required_for_value", fallback: "Select a server before picking this value.") }
  }
  public enum Kiosk {
    /// Enable Kiosk Mode
    public static var enableButton: String { return L10n.tr("Localizable", "kiosk.enable_button", fallback: "Enable Kiosk Mode") }
    /// Exit Kiosk Mode
    public static var exitButton: String { return L10n.tr("Localizable", "kiosk.exit_button", fallback: "Exit Kiosk Mode") }
    /// Double-tap to exit kiosk mode. Authentication may be required.
    public static var exitHint: String { return L10n.tr("Localizable", "kiosk.exit_hint", fallback: "Double-tap to exit kiosk mode. Authentication may be required.") }
    /// Screen: %@
    public static func screenLabel(_ p1: Any) -> String {
      return L10n.tr("Localizable", "kiosk.screen_label", String(describing: p1), fallback: "Screen: %@")
    }
    /// Screensaver: %@
    public static func screensaverLabel(_ p1: Any) -> String {
      return L10n.tr("Localizable", "kiosk.screensaver_label", String(describing: p1), fallback: "Screensaver: %@")
    }
    /// Kiosk Mode
    public static var title: String { return L10n.tr("Localizable", "kiosk.title", fallback: "Kiosk Mode") }
    public enum Active {
      /// Kiosk Mode Active
      public static var title: String { return L10n.tr("Localizable", "kiosk.active.title", fallback: "Kiosk Mode Active") }
    }
    public enum Auth {
      /// Authentication Required
      public static var `required`: String { return L10n.tr("Localizable", "kiosk.auth.required", fallback: "Authentication Required") }
      /// Try Again
      public static var tryAgain: String { return L10n.tr("Localizable", "kiosk.auth.try_again", fallback: "Try Again") }
    }
    public enum AuthError {
      /// Authenticate to exit kiosk mode
      public static var reason: String { return L10n.tr("Localizable", "kiosk.auth_error.reason", fallback: "Authenticate to exit kiosk mode") }
      /// Authentication Error
      public static var title: String { return L10n.tr("Localizable", "kiosk.auth_error.title", fallback: "Authentication Error") }
    }
    public enum Brightness {
      /// Brightness Control
      public static var control: String { return L10n.tr("Localizable", "kiosk.brightness.control", fallback: "Brightness Control") }
      /// Day Brightness: %d%%
      public static func day(_ p1: Int) -> String {
        return L10n.tr("Localizable", "kiosk.brightness.day", p1, fallback: "Day Brightness: %d%%")
      }
      /// Day starts
      public static var dayStarts: String { return L10n.tr("Localizable", "kiosk.brightness.day_starts", fallback: "Day starts") }
      /// Manual Brightness: %d%%
      public static func manual(_ p1: Int) -> String {
        return L10n.tr("Localizable", "kiosk.brightness.manual", p1, fallback: "Manual Brightness: %d%%")
      }
      /// Night Brightness: %d%%
      public static func night(_ p1: Int) -> String {
        return L10n.tr("Localizable", "kiosk.brightness.night", p1, fallback: "Night Brightness: %d%%")
      }
      /// Night starts
      public static var nightStarts: String { return L10n.tr("Localizable", "kiosk.brightness.night_starts", fallback: "Night starts") }
      /// Day/Night Schedule
      public static var schedule: String { return L10n.tr("Localizable", "kiosk.brightness.schedule", fallback: "Day/Night Schedule") }
      /// Brightness
      public static var section: String { return L10n.tr("Localizable", "kiosk.brightness.section", fallback: "Brightness") }
    }
    public enum Clock {
      /// 24-Hour Format
      public static var _24hour: String { return L10n.tr("Localizable", "kiosk.clock.24hour", fallback: "24-Hour Format") }
      /// Clock Display
      public static var section: String { return L10n.tr("Localizable", "kiosk.clock.section", fallback: "Clock Display") }
      /// Show Date
      public static var showDate: String { return L10n.tr("Localizable", "kiosk.clock.show_date", fallback: "Show Date") }
      /// Show Seconds
      public static var showSeconds: String { return L10n.tr("Localizable", "kiosk.clock.show_seconds", fallback: "Show Seconds") }
      /// Clock Style
      public static var style: String { return L10n.tr("Localizable", "kiosk.clock.style", fallback: "Clock Style") }
      public enum Style {
        /// Analog
        public static var analog: String { return L10n.tr("Localizable", "kiosk.clock.style.analog", fallback: "Analog") }
        /// Digital
        public static var digital: String { return L10n.tr("Localizable", "kiosk.clock.style.digital", fallback: "Digital") }
        /// Large
        public static var large: String { return L10n.tr("Localizable", "kiosk.clock.style.large", fallback: "Large") }
        /// Minimal
        public static var minimal: String { return L10n.tr("Localizable", "kiosk.clock.style.minimal", fallback: "Minimal") }
      }
    }
    public enum Corner {
      /// Bottom Left
      public static var bottomLeft: String { return L10n.tr("Localizable", "kiosk.corner.bottom_left", fallback: "Bottom Left") }
      /// Bottom Right
      public static var bottomRight: String { return L10n.tr("Localizable", "kiosk.corner.bottom_right", fallback: "Bottom Right") }
      /// Top Left
      public static var topLeft: String { return L10n.tr("Localizable", "kiosk.corner.top_left", fallback: "Top Left") }
      /// Top Right
      public static var topRight: String { return L10n.tr("Localizable", "kiosk.corner.top_right", fallback: "Top Right") }
    }
    public enum Footer {
      /// When enabled, the display will be locked to the dashboard. Use Face ID, Touch ID, or device passcode to exit.
      public static var description: String { return L10n.tr("Localizable", "kiosk.footer.description", fallback: "When enabled, the display will be locked to the dashboard. Use Face ID, Touch ID, or device passcode to exit.") }
    }
    public enum Screensaver {
      /// Dim Level: %d%%
      public static func dimLevel(_ p1: Int) -> String {
        return L10n.tr("Localizable", "kiosk.screensaver.dim_level", p1, fallback: "Dim Level: %d%%")
      }
      /// Mode
      public static var mode: String { return L10n.tr("Localizable", "kiosk.screensaver.mode", fallback: "Mode") }
      /// Pixel Shift (OLED)
      public static var pixelShift: String { return L10n.tr("Localizable", "kiosk.screensaver.pixel_shift", fallback: "Pixel Shift (OLED)") }
      /// Pixel shift helps prevent burn-in on OLED displays by slightly moving content periodically.
      public static var pixelShiftFooter: String { return L10n.tr("Localizable", "kiosk.screensaver.pixel_shift_footer", fallback: "Pixel shift helps prevent burn-in on OLED displays by slightly moving content periodically.") }
      /// Screensaver
      public static var section: String { return L10n.tr("Localizable", "kiosk.screensaver.section", fallback: "Screensaver") }
      /// Timeout
      public static var timeout: String { return L10n.tr("Localizable", "kiosk.screensaver.timeout", fallback: "Timeout") }
      /// Screensaver
      public static var toggle: String { return L10n.tr("Localizable", "kiosk.screensaver.toggle", fallback: "Screensaver") }
      public enum Mode {
        /// Blank
        public static var blank: String { return L10n.tr("Localizable", "kiosk.screensaver.mode.blank", fallback: "Blank") }
        /// Clock
        public static var clock: String { return L10n.tr("Localizable", "kiosk.screensaver.mode.clock", fallback: "Clock") }
        /// Dim
        public static var dim: String { return L10n.tr("Localizable", "kiosk.screensaver.mode.dim", fallback: "Dim") }
      }
      public enum Timeout {
        /// 10 minutes
        public static var _10min: String { return L10n.tr("Localizable", "kiosk.screensaver.timeout.10min", fallback: "10 minutes") }
        /// 15 minutes
        public static var _15min: String { return L10n.tr("Localizable", "kiosk.screensaver.timeout.15min", fallback: "15 minutes") }
        /// 1 minute
        public static var _1min: String { return L10n.tr("Localizable", "kiosk.screensaver.timeout.1min", fallback: "1 minute") }
        /// 2 minutes
        public static var _2min: String { return L10n.tr("Localizable", "kiosk.screensaver.timeout.2min", fallback: "2 minutes") }
        /// 30 minutes
        public static var _30min: String { return L10n.tr("Localizable", "kiosk.screensaver.timeout.30min", fallback: "30 minutes") }
        /// 30 seconds
        public static var _30sec: String { return L10n.tr("Localizable", "kiosk.screensaver.timeout.30sec", fallback: "30 seconds") }
        /// 5 minutes
        public static var _5min: String { return L10n.tr("Localizable", "kiosk.screensaver.timeout.5min", fallback: "5 minutes") }
      }
    }
    public enum Section {
      /// Kiosk Mode
      public static var title: String { return L10n.tr("Localizable", "kiosk.section.title", fallback: "Kiosk Mode") }
    }
    public enum Security {
      /// Device Authentication
      public static var deviceAuth: String { return L10n.tr("Localizable", "kiosk.security.device_auth", fallback: "Device Authentication") }
      /// Exit Gesture Corner
      public static var gestureCorner: String { return L10n.tr("Localizable", "kiosk.security.gesture_corner", fallback: "Exit Gesture Corner") }
      /// Tap the %@ corner %d times to access kiosk settings when locked.
      public static func gestureFooter(_ p1: Any, _ p2: Int) -> String {
        return L10n.tr("Localizable", "kiosk.security.gesture_footer", String(describing: p1), p2, fallback: "Tap the %@ corner %d times to access kiosk settings when locked.")
      }
      /// Hide Status Bar
      public static var hideStatusBar: String { return L10n.tr("Localizable", "kiosk.security.hide_status_bar", fallback: "Hide Status Bar") }
      /// Prevent Auto-Lock
      public static var preventAutolock: String { return L10n.tr("Localizable", "kiosk.security.prevent_autolock", fallback: "Prevent Auto-Lock") }
      /// Secret Exit Gesture
      public static var secretGesture: String { return L10n.tr("Localizable", "kiosk.security.secret_gesture", fallback: "Secret Exit Gesture") }
      /// Security & Display
      public static var section: String { return L10n.tr("Localizable", "kiosk.security.section", fallback: "Security & Display") }
      /// Taps Required: %d
      public static func tapsRequired(_ p1: Int) -> String {
        return L10n.tr("Localizable", "kiosk.security.taps_required", p1, fallback: "Taps Required: %d")
      }
      /// Wake on Touch
      public static var wakeOnTouch: String { return L10n.tr("Localizable", "kiosk.security.wake_on_touch", fallback: "Wake on Touch") }
    }
    public enum Time {
      /// Hour
      public static var hour: String { return L10n.tr("Localizable", "kiosk.time.hour", fallback: "Hour") }
      /// Minute
      public static var minute: String { return L10n.tr("Localizable", "kiosk.time.minute", fallback: "Minute") }
    }
  }
  public enum LegacyActions {
    /// Legacy iOS Actions are not the recommended way to interact with Home Assistant anymore, please use Scripts, Scenes and Automations directly in your Widgets, Apple Watch and CarPlay.
    public static var disclaimer: String { return L10n.tr("Localizable", "legacy_actions.disclaimer", fallback: "Legacy iOS Actions are not the recommended way to interact with Home Assistant anymore, please use Scripts, Scenes and Automations directly in your Widgets, Apple Watch and CarPlay.") }
  }
  public enum LocationChangeNotification {
    /// Location change
    public static var title: String { return L10n.tr("Localizable", "location_change_notification.title", fallback: "Location change") }
    public enum AppShortcut {
      /// Location updated via App Shortcut
      public static var body: String { return L10n.tr("Localizable", "location_change_notification.app_shortcut.body", fallback: "Location updated via App Shortcut") }
    }
    public enum BackgroundFetch {
      /// Current location delivery triggered via background fetch
      public static var body: String { return L10n.tr("Localizable", "location_change_notification.background_fetch.body", fallback: "Current location delivery triggered via background fetch") }
    }
    public enum BeaconRegionEnter {
      /// %@ entered via iBeacon
      public static func body(_ p1: Any) -> String {
        return L10n.tr("Localizable", "location_change_notification.beacon_region_enter.body", String(describing: p1), fallback: "%@ entered via iBeacon")
      }
    }
    public enum BeaconRegionExit {
      /// %@ exited via iBeacon
      public static func body(_ p1: Any) -> String {
        return L10n.tr("Localizable", "location_change_notification.beacon_region_exit.body", String(describing: p1), fallback: "%@ exited via iBeacon")
      }
    }
    public enum Launch {
      /// Location updated via app launch
      public static var body: String { return L10n.tr("Localizable", "location_change_notification.launch.body", fallback: "Location updated via app launch") }
    }
    public enum Manual {
      /// Location update triggered by user
      public static var body: String { return L10n.tr("Localizable", "location_change_notification.manual.body", fallback: "Location update triggered by user") }
    }
    public enum Periodic {
      /// Location updated via periodic update
      public static var body: String { return L10n.tr("Localizable", "location_change_notification.periodic.body", fallback: "Location updated via periodic update") }
    }
    public enum PushNotification {
      /// Location updated via push notification
      public static var body: String { return L10n.tr("Localizable", "location_change_notification.push_notification.body", fallback: "Location updated via push notification") }
    }
    public enum RegionEnter {
      /// %@ entered
      public static func body(_ p1: Any) -> String {
        return L10n.tr("Localizable", "location_change_notification.region_enter.body", String(describing: p1), fallback: "%@ entered")
      }
    }
    public enum RegionExit {
      /// %@ exited
      public static func body(_ p1: Any) -> String {
        return L10n.tr("Localizable", "location_change_notification.region_exit.body", String(describing: p1), fallback: "%@ exited")
      }
    }
    public enum Signaled {
      /// Location updated via update signal
      public static var body: String { return L10n.tr("Localizable", "location_change_notification.signaled.body", fallback: "Location updated via update signal") }
    }
    public enum SignificantLocationUpdate {
      /// Significant location change detected
      public static var body: String { return L10n.tr("Localizable", "location_change_notification.significant_location_update.body", fallback: "Significant location change detected") }
    }
    public enum Siri {
      /// Location update triggered by Siri
      public static var body: String { return L10n.tr("Localizable", "location_change_notification.siri.body", fallback: "Location update triggered by Siri") }
    }
    public enum Unknown {
      /// Location updated via unknown method
      public static var body: String { return L10n.tr("Localizable", "location_change_notification.unknown.body", fallback: "Location updated via unknown method") }
    }
    public enum UrlScheme {
      /// Location updated via URL Scheme
      public static var body: String { return L10n.tr("Localizable", "location_change_notification.url_scheme.body", fallback: "Location updated via URL Scheme") }
    }
    public enum Visit {
      /// Location updated via Visit
      public static var body: String { return L10n.tr("Localizable", "location_change_notification.visit.body", fallback: "Location updated via Visit") }
    }
    public enum WatchContext {
      /// Location updated via watch context sync
      public static var body: String { return L10n.tr("Localizable", "location_change_notification.watch_context.body", fallback: "Location updated via watch context sync") }
    }
    public enum XCallbackUrl {
      /// Location updated via X-Callback-URL
      public static var body: String { return L10n.tr("Localizable", "location_change_notification.x_callback_url.body", fallback: "Location updated via X-Callback-URL") }
    }
  }
  public enum Mac {
    public enum Copy {
      /// Copy
      public static var accessibilityLabel: String { return L10n.tr("Localizable", "mac.copy.accessibility_label", fallback: "Copy") }
    }
    public enum Navigation {
      public enum GoBack {
        /// Navigate back
        public static var accessibilityLabel: String { return L10n.tr("Localizable", "mac.navigation.go_back.accessibility_label", fallback: "Navigate back") }
      }
      public enum GoForward {
        /// Navigate forward
        public static var accessibilityLabel: String { return L10n.tr("Localizable", "mac.navigation.go_forward.accessibility_label", fallback: "Navigate forward") }
      }
    }
    public enum Paste {
      /// Paste
      public static var accessibilityLabel: String { return L10n.tr("Localizable", "mac.paste.accessibility_label", fallback: "Paste") }
    }
  }
  public enum MagicItem {
    /// Action
    public static var action: String { return L10n.tr("Localizable", "magic_item.action", fallback: "Action") }
    /// Add
    public static var add: String { return L10n.tr("Localizable", "magic_item.add", fallback: "Add") }
    /// Save
    public static var edit: String { return L10n.tr("Localizable", "magic_item.edit", fallback: "Save") }
    public enum Action {
      /// On tap
      public static var onTap: String { return L10n.tr("Localizable", "magic_item.action.on_tap", fallback: "On tap") }
      public enum Assist {
        /// Assist
        public static var title: String { return L10n.tr("Localizable", "magic_item.action.assist.title", fallback: "Assist") }
        public enum Pipeline {
          /// Pipeline
          public static var title: String { return L10n.tr("Localizable", "magic_item.action.assist.pipeline.title", fallback: "Pipeline") }
        }
        public enum StartListening {
          /// Start listening
          public static var title: String { return L10n.tr("Localizable", "magic_item.action.assist.start_listening.title", fallback: "Start listening") }
        }
      }
      public enum NavigationPath {
        /// e.g. /lovelace/cameras
        public static var placeholder: String { return L10n.tr("Localizable", "magic_item.action.navigation_path.placeholder", fallback: "e.g. /lovelace/cameras") }
        /// Navigation path
        public static var title: String { return L10n.tr("Localizable", "magic_item.action.navigation_path.title", fallback: "Navigation path") }
      }
      public enum Script {
        /// Script
        public static var title: String { return L10n.tr("Localizable", "magic_item.action.script.title", fallback: "Script") }
      }
    }
    public enum BackgroundColor {
      /// Background color
      public static var title: String { return L10n.tr("Localizable", "magic_item.background_color.title", fallback: "Background color") }
    }
    public enum DisplayText {
      /// Display text
      public static var title: String { return L10n.tr("Localizable", "magic_item.display_text.title", fallback: "Display text") }
    }
    public enum IconColor {
      /// Icon color
      public static var title: String { return L10n.tr("Localizable", "magic_item.icon_color.title", fallback: "Icon color") }
    }
    public enum IconName {
      /// Icon name
      public static var title: String { return L10n.tr("Localizable", "magic_item.icon_name.title", fallback: "Icon name") }
    }
    public enum ItemType {
      public enum Action {
        public enum List {
          /// iOS Actions
          public static var title: String { return L10n.tr("Localizable", "magic_item.item_type.action.list.title", fallback: "iOS Actions") }
          public enum Warning {
            /// We will stop supporting iOS Actions in the future, please consider using Home Assistant scripts or scenes instead.
            public static var title: String { return L10n.tr("Localizable", "magic_item.item_type.action.list.warning.title", fallback: "We will stop supporting iOS Actions in the future, please consider using Home Assistant scripts or scenes instead.") }
          }
        }
      }
      public enum App {
        public enum List {
          /// App
          public static var title: String { return L10n.tr("Localizable", "magic_item.item_type.app.list.title", fallback: "App") }
        }
      }
      public enum Entity {
        public enum List {
          /// Entity
          public static var title: String { return L10n.tr("Localizable", "magic_item.item_type.entity.list.title", fallback: "Entity") }
        }
      }
      public enum Scene {
        public enum List {
          /// Scenes
          public static var title: String { return L10n.tr("Localizable", "magic_item.item_type.scene.list.title", fallback: "Scenes") }
        }
      }
      public enum Script {
        public enum List {
          /// Scripts
          public static var title: String { return L10n.tr("Localizable", "magic_item.item_type.script.list.title", fallback: "Scripts") }
        }
      }
      public enum Selection {
        public enum List {
          /// Item type
          public static var title: String { return L10n.tr("Localizable", "magic_item.item_type.selection.list.title", fallback: "Item type") }
        }
      }
    }
    public enum Name {
      /// Name
      public static var title: String { return L10n.tr("Localizable", "magic_item.name.title", fallback: "Name") }
    }
    public enum NameAndIcon {
      /// Edit script name and icon in frontend under 'Settings' > 'Automations & scenes' > 'Scripts'.
      public static var footer: String { return L10n.tr("Localizable", "magic_item.name_and_icon.footer", fallback: "Edit script name and icon in frontend under 'Settings' > 'Automations & scenes' > 'Scripts'.") }
      public enum Footer {
        /// Edit scene name and icon in frontend under 'Settings' > 'Automations & scenes' > 'Scenes'.
        public static var scenes: String { return L10n.tr("Localizable", "magic_item.name_and_icon.footer.scenes", fallback: "Edit scene name and icon in frontend under 'Settings' > 'Automations & scenes' > 'Scenes'.") }
      }
    }
    public enum RequireConfirmation {
      /// Require confirmation
      public static var title: String { return L10n.tr("Localizable", "magic_item.require_confirmation.title", fallback: "Require confirmation") }
    }
    public enum TextColor {
      /// Text color
      public static var title: String { return L10n.tr("Localizable", "magic_item.text_color.title", fallback: "Text color") }
    }
    public enum UseCustomColors {
      /// Use custom colors
      public static var title: String { return L10n.tr("Localizable", "magic_item.use_custom_colors.title", fallback: "Use custom colors") }
    }
  }
  public enum Menu {
    public enum Actions {
      /// Configure…
      public static var configure: String { return L10n.tr("Localizable", "menu.actions.configure", fallback: "Configure…") }
      /// Actions
      public static var title: String { return L10n.tr("Localizable", "menu.actions.title", fallback: "Actions") }
    }
    public enum Application {
      /// About %@
      public static func about(_ p1: Any) -> String {
        return L10n.tr("Localizable", "menu.application.about", String(describing: p1), fallback: "About %@")
      }
      /// Preferences…
      public static var preferences: String { return L10n.tr("Localizable", "menu.application.preferences", fallback: "Preferences…") }
    }
    public enum File {
      /// Update Sensors
      public static var updateSensors: String { return L10n.tr("Localizable", "menu.file.update_sensors", fallback: "Update Sensors") }
    }
    public enum Help {
      /// %@ Help
      public static func help(_ p1: Any) -> String {
        return L10n.tr("Localizable", "menu.help.help", String(describing: p1), fallback: "%@ Help")
      }
    }
    public enum StatusItem {
      /// Quit
      public static var quit: String { return L10n.tr("Localizable", "menu.status_item.quit", fallback: "Quit") }
      /// Toggle %1$@
      public static func toggle(_ p1: Any) -> String {
        return L10n.tr("Localizable", "menu.status_item.toggle", String(describing: p1), fallback: "Toggle %1$@")
      }
    }
    public enum View {
      /// Find
      public static var find: String { return L10n.tr("Localizable", "menu.view.find", fallback: "Find") }
      /// Reload Page
      public static var reloadPage: String { return L10n.tr("Localizable", "menu.view.reload_page", fallback: "Reload Page") }
    }
  }
  public enum NavBar {
    /// Close
    public static var close: String { return L10n.tr("Localizable", "navBar.close", fallback: "Close") }
  }
  public enum Network {
    public enum Error {
      public enum NoActiveUrl {
        /// Open companion app settings and check your server settings, internal URL will only be used if local network is defined (SSID), if you are using VPN try setting your external URL as the same as internal URL.
        public static var body: String { return L10n.tr("Localizable", "network.error.no_active_url.body", fallback: "Open companion app settings and check your server settings, internal URL will only be used if local network is defined (SSID), if you are using VPN try setting your external URL as the same as internal URL.") }
        /// No URL available to load
        public static var title: String { return L10n.tr("Localizable", "network.error.no_active_url.title", fallback: "No URL available to load") }
      }
    }
  }
  public enum Nfc {
    /// Tag Read
    public static var genericTagRead: String { return L10n.tr("Localizable", "nfc.generic_tag_read", fallback: "Tag Read") }
    /// NFC is not available on this device
    public static var notAvailable: String { return L10n.tr("Localizable", "nfc.not_available", fallback: "NFC is not available on this device") }
    /// NFC Tag Read
    public static var tagRead: String { return L10n.tr("Localizable", "nfc.tag_read", fallback: "NFC Tag Read") }
    public enum Detail {
      /// Copy to Pasteboard
      public static var copy: String { return L10n.tr("Localizable", "nfc.detail.copy", fallback: "Copy to Pasteboard") }
      /// Create a Duplicate
      public static var duplicate: String { return L10n.tr("Localizable", "nfc.detail.duplicate", fallback: "Create a Duplicate") }
      /// Example Trigger
      public static var exampleTrigger: String { return L10n.tr("Localizable", "nfc.detail.example_trigger", fallback: "Example Trigger") }
      /// Fire Event
      public static var fire: String { return L10n.tr("Localizable", "nfc.detail.fire", fallback: "Fire Event") }
      /// Share Identifier
      public static var share: String { return L10n.tr("Localizable", "nfc.detail.share", fallback: "Share Identifier") }
      /// Tag Identifier
      public static var tagValue: String { return L10n.tr("Localizable", "nfc.detail.tag_value", fallback: "Tag Identifier") }
      /// NFC Tag
      public static var title: String { return L10n.tr("Localizable", "nfc.detail.title", fallback: "NFC Tag") }
    }
    public enum List {
      /// NFC tags written by the app will show a notification when you bring your device near them. Activating the notification will launch the app and fire an event.
      /// 
      /// Tags will work on any device with Home Assistant installed which has hardware support to read them.
      public static var description: String { return L10n.tr("Localizable", "nfc.list.description", fallback: "NFC tags written by the app will show a notification when you bring your device near them. Activating the notification will launch the app and fire an event.\n\nTags will work on any device with Home Assistant installed which has hardware support to read them.") }
      /// Learn More
      public static var learnMore: String { return L10n.tr("Localizable", "nfc.list.learn_more", fallback: "Learn More") }
      /// Read Tag
      public static var readTag: String { return L10n.tr("Localizable", "nfc.list.read_tag", fallback: "Read Tag") }
      /// NFC Tags
      public static var title: String { return L10n.tr("Localizable", "nfc.list.title", fallback: "NFC Tags") }
      /// Write Tag
      public static var writeTag: String { return L10n.tr("Localizable", "nfc.list.write_tag", fallback: "Write Tag") }
    }
    public enum Read {
      /// Hold your %@ near an NFC tag
      public static func startMessage(_ p1: Any) -> String {
        return L10n.tr("Localizable", "nfc.read.start_message", String(describing: p1), fallback: "Hold your %@ near an NFC tag")
      }
      public enum Error {
        /// Failed to read tag
        public static var genericFailure: String { return L10n.tr("Localizable", "nfc.read.error.generic_failure", fallback: "Failed to read tag") }
        /// NFC tag is not a Home Assistant tag
        public static var notHomeAssistant: String { return L10n.tr("Localizable", "nfc.read.error.not_home_assistant", fallback: "NFC tag is not a Home Assistant tag") }
        /// NFC tag is invalid
        public static var tagInvalid: String { return L10n.tr("Localizable", "nfc.read.error.tag_invalid", fallback: "NFC tag is invalid") }
      }
    }
    public enum Write {
      /// Hold your %@ near a writable NFC tag
      public static func startMessage(_ p1: Any) -> String {
        return L10n.tr("Localizable", "nfc.write.start_message", String(describing: p1), fallback: "Hold your %@ near a writable NFC tag")
      }
      /// Tag Written!
      public static var successMessage: String { return L10n.tr("Localizable", "nfc.write.success_message", fallback: "Tag Written!") }
      public enum Error {
        /// NFC tag has insufficient capacity: needs %ld but only has %ld
        public static func capacity(_ p1: Int, _ p2: Int) -> String {
          return L10n.tr("Localizable", "nfc.write.error.capacity", p1, p2, fallback: "NFC tag has insufficient capacity: needs %ld but only has %ld")
        }
        /// NFC tag is not NDEF format
        public static var invalidFormat: String { return L10n.tr("Localizable", "nfc.write.error.invalid_format", fallback: "NFC tag is not NDEF format") }
        /// NFC tag is read-only
        public static var notWritable: String { return L10n.tr("Localizable", "nfc.write.error.not_writable", fallback: "NFC tag is read-only") }
      }
      public enum IdentifierChoice {
        /// Manual
        public static var manual: String { return L10n.tr("Localizable", "nfc.write.identifier_choice.manual", fallback: "Manual") }
        /// The identifier helps differentiate various tags.
        public static var message: String { return L10n.tr("Localizable", "nfc.write.identifier_choice.message", fallback: "The identifier helps differentiate various tags.") }
        /// Random (Recommended)
        public static var random: String { return L10n.tr("Localizable", "nfc.write.identifier_choice.random", fallback: "Random (Recommended)") }
        /// What kind of tag identifier?
        public static var title: String { return L10n.tr("Localizable", "nfc.write.identifier_choice.title", fallback: "What kind of tag identifier?") }
      }
      public enum ManualInput {
        /// What identifier for the tag?
        public static var title: String { return L10n.tr("Localizable", "nfc.write.manual_input.title", fallback: "What identifier for the tag?") }
      }
    }
  }
  public enum NotificationService {
    /// Failed to load attachment
    public static var failedToLoad: String { return L10n.tr("Localizable", "notification_service.failed_to_load", fallback: "Failed to load attachment") }
    /// Loading Actions…
    public static var loadingDynamicActions: String { return L10n.tr("Localizable", "notification_service.loading_dynamic_actions", fallback: "Loading Actions…") }
    public enum Parser {
      public enum Camera {
        /// entity_id provided was invalid.
        public static var invalidEntity: String { return L10n.tr("Localizable", "notification_service.parser.camera.invalid_entity", fallback: "entity_id provided was invalid.") }
      }
      public enum Url {
        /// The given URL was invalid.
        public static var invalidUrl: String { return L10n.tr("Localizable", "notification_service.parser.url.invalid_url", fallback: "The given URL was invalid.") }
        /// No URL was provided.
        public static var noUrl: String { return L10n.tr("Localizable", "notification_service.parser.url.no_url", fallback: "No URL was provided.") }
      }
    }
  }
  public enum NotificationsConfigurator {
    /// Identifier
    public static var identifier: String { return L10n.tr("Localizable", "notifications_configurator.identifier", fallback: "Identifier") }
    public enum Action {
      public enum Rows {
        public enum AuthenticationRequired {
          /// When the user selects an action with this option, the system prompts the user to unlock the device. After unlocking, Home Assistant will be notified of the selected action.
          public static var footer: String { return L10n.tr("Localizable", "notifications_configurator.action.rows.authentication_required.footer", fallback: "When the user selects an action with this option, the system prompts the user to unlock the device. After unlocking, Home Assistant will be notified of the selected action.") }
          /// Authentication Required
          public static var title: String { return L10n.tr("Localizable", "notifications_configurator.action.rows.authentication_required.title", fallback: "Authentication Required") }
        }
        public enum Destructive {
          /// When enabled, the action button is displayed with special highlighting to indicate that it performs a destructive task.
          public static var footer: String { return L10n.tr("Localizable", "notifications_configurator.action.rows.destructive.footer", fallback: "When enabled, the action button is displayed with special highlighting to indicate that it performs a destructive task.") }
          /// Destructive
          public static var title: String { return L10n.tr("Localizable", "notifications_configurator.action.rows.destructive.title", fallback: "Destructive") }
        }
        public enum Foreground {
          /// Enabling this will cause the app to launch if it's in the background when tapping a notification
          public static var footer: String { return L10n.tr("Localizable", "notifications_configurator.action.rows.foreground.footer", fallback: "Enabling this will cause the app to launch if it's in the background when tapping a notification") }
          /// Launch app
          public static var title: String { return L10n.tr("Localizable", "notifications_configurator.action.rows.foreground.title", fallback: "Launch app") }
        }
        public enum TextInputButtonTitle {
          /// Button Title
          public static var title: String { return L10n.tr("Localizable", "notifications_configurator.action.rows.text_input_button_title.title", fallback: "Button Title") }
        }
        public enum TextInputPlaceholder {
          /// Placeholder
          public static var title: String { return L10n.tr("Localizable", "notifications_configurator.action.rows.text_input_placeholder.title", fallback: "Placeholder") }
        }
        public enum Title {
          /// Title
          public static var title: String { return L10n.tr("Localizable", "notifications_configurator.action.rows.title.title", fallback: "Title") }
        }
      }
      public enum TextInput {
        /// Text Input
        public static var title: String { return L10n.tr("Localizable", "notifications_configurator.action.text_input.title", fallback: "Text Input") }
      }
    }
    public enum Category {
      public enum ExampleCall {
        /// Example Service Call
        public static var title: String { return L10n.tr("Localizable", "notifications_configurator.category.example_call.title", fallback: "Example Service Call") }
      }
      public enum NavigationBar {
        /// Category Configurator
        public static var title: String { return L10n.tr("Localizable", "notifications_configurator.category.navigation_bar.title", fallback: "Category Configurator") }
      }
      public enum PreviewNotification {
        /// This is a test notification for the %@ notification category
        public static func body(_ p1: Any) -> String {
          return L10n.tr("Localizable", "notifications_configurator.category.preview_notification.body", String(describing: p1), fallback: "This is a test notification for the %@ notification category")
        }
        /// Test notification
        public static var title: String { return L10n.tr("Localizable", "notifications_configurator.category.preview_notification.title", fallback: "Test notification") }
      }
      public enum Rows {
        public enum Actions {
          /// Categories can have a maximum of 10 actions.
          public static var footer: String { return L10n.tr("Localizable", "notifications_configurator.category.rows.actions.footer", fallback: "Categories can have a maximum of 10 actions.") }
          /// Actions
          public static var header: String { return L10n.tr("Localizable", "notifications_configurator.category.rows.actions.header", fallback: "Actions") }
        }
        public enum CategorySummary {
          /// %%u notifications in %%@
          public static var `default`: String { return L10n.tr("Localizable", "notifications_configurator.category.rows.category_summary.default", fallback: "%%u notifications in %%@") }
          /// A format string for the summary description used when the system groups the category’s notifications. You can optionally use '%%u' to show the number of notifications in the group and '%%@' to show the summary argument provided in the push payload.
          public static var footer: String { return L10n.tr("Localizable", "notifications_configurator.category.rows.category_summary.footer", fallback: "A format string for the summary description used when the system groups the category’s notifications. You can optionally use '%%u' to show the number of notifications in the group and '%%@' to show the summary argument provided in the push payload.") }
          /// Category Summary
          public static var header: String { return L10n.tr("Localizable", "notifications_configurator.category.rows.category_summary.header", fallback: "Category Summary") }
        }
        public enum HiddenPreviewPlaceholder {
          /// %%u notifications
          public static var `default`: String { return L10n.tr("Localizable", "notifications_configurator.category.rows.hidden_preview_placeholder.default", fallback: "%%u notifications") }
          /// This text is only displayed if you have notification previews hidden. Use '%%u' for the number of messages with the same thread identifier.
          public static var footer: String { return L10n.tr("Localizable", "notifications_configurator.category.rows.hidden_preview_placeholder.footer", fallback: "This text is only displayed if you have notification previews hidden. Use '%%u' for the number of messages with the same thread identifier.") }
          /// Hidden Preview Placeholder
          public static var header: String { return L10n.tr("Localizable", "notifications_configurator.category.rows.hidden_preview_placeholder.header", fallback: "Hidden Preview Placeholder") }
        }
        public enum Name {
          /// Name
          public static var title: String { return L10n.tr("Localizable", "notifications_configurator.category.rows.name.title", fallback: "Name") }
        }
      }
    }
    public enum NewAction {
      /// New Action
      public static var title: String { return L10n.tr("Localizable", "notifications_configurator.new_action.title", fallback: "New Action") }
    }
    public enum Settings {
      /// Identifier must contain only letters and underscores and be uppercase. It must be globally unique to the app.
      public static var footer: String { return L10n.tr("Localizable", "notifications_configurator.settings.footer", fallback: "Identifier must contain only letters and underscores and be uppercase. It must be globally unique to the app.") }
      /// Settings
      public static var header: String { return L10n.tr("Localizable", "notifications_configurator.settings.header", fallback: "Settings") }
      public enum Footer {
        /// Identifier can not be changed after creation. You must delete and recreate the action to change the identifier.
        public static var idSet: String { return L10n.tr("Localizable", "notifications_configurator.settings.footer.id_set", fallback: "Identifier can not be changed after creation. You must delete and recreate the action to change the identifier.") }
      }
    }
  }
  public enum Onboarding {
    public enum ClientCertificate {
      /// This server requires a client certificate (mTLS) for authentication. Please import your certificate file (.p12 or .pfx).
      public static var description: String { return L10n.tr("Localizable", "onboarding.client_certificate.description", fallback: "This server requires a client certificate (mTLS) for authentication. Please import your certificate file (.p12 or .pfx).") }
      /// Select Certificate File
      public static var selectFileButton: String { return L10n.tr("Localizable", "onboarding.client_certificate.select_file_button", fallback: "Select Certificate File") }
      /// Client Certificate Required
      public static var title: String { return L10n.tr("Localizable", "onboarding.client_certificate.title", fallback: "Client Certificate Required") }
      public enum Error {
        /// Unable to access the selected file
        public static var fileAccess: String { return L10n.tr("Localizable", "onboarding.client_certificate.error.file_access", fallback: "Unable to access the selected file") }
      }
      public enum PasswordPrompt {
        /// Import
        public static var importButton: String { return L10n.tr("Localizable", "onboarding.client_certificate.password_prompt.import_button", fallback: "Import") }
        /// Enter the password for this certificate
        public static var message: String { return L10n.tr("Localizable", "onboarding.client_certificate.password_prompt.message", fallback: "Enter the password for this certificate") }
        /// Password
        public static var placeholder: String { return L10n.tr("Localizable", "onboarding.client_certificate.password_prompt.placeholder", fallback: "Password") }
        /// Certificate Password
        public static var title: String { return L10n.tr("Localizable", "onboarding.client_certificate.password_prompt.title", fallback: "Certificate Password") }
      }
    }
    public enum Connect {
      /// Connecting to %@
      public static func title(_ p1: Any) -> String {
        return L10n.tr("Localizable", "onboarding.connect.title", String(describing: p1), fallback: "Connecting to %@")
      }
      public enum MacSafariWarning {
        /// Try restarting Safari if the login form does not open.
        public static var message: String { return L10n.tr("Localizable", "onboarding.connect.mac_safari_warning.message", fallback: "Try restarting Safari if the login form does not open.") }
        /// Launching Safari
        public static var title: String { return L10n.tr("Localizable", "onboarding.connect.mac_safari_warning.title", fallback: "Launching Safari") }
      }
    }
    public enum ConnectionError {
      /// More Info
      public static var moreInfoButton: String { return L10n.tr("Localizable", "onboarding.connection_error.more_info_button", fallback: "More Info") }
      /// Failed to Connect
      public static var title: String { return L10n.tr("Localizable", "onboarding.connection_error.title", fallback: "Failed to Connect") }
    }
    public enum ConnectionTestResult {
      /// Error Code:
      public static var errorCode: String { return L10n.tr("Localizable", "onboarding.connection_test_result.error_code", fallback: "Error Code:") }
      public enum AuthenticationUnsupported {
        /// Authentication type is unsupported%@.
        public static func description(_ p1: Any) -> String {
          return L10n.tr("Localizable", "onboarding.connection_test_result.authentication_unsupported.description", String(describing: p1), fallback: "Authentication type is unsupported%@.")
        }
      }
      public enum BasicAuth {
        /// HTTP Basic Authentication is unsupported.
        public static var description: String { return L10n.tr("Localizable", "onboarding.connection_test_result.basic_auth.description", fallback: "HTTP Basic Authentication is unsupported.") }
      }
      public enum CertificateError {
        /// Don't Trust
        public static var actionDontTrust: String { return L10n.tr("Localizable", "onboarding.connection_test_result.certificate_error.action_dont_trust", fallback: "Don't Trust") }
        /// Trust Certificate
        public static var actionTrust: String { return L10n.tr("Localizable", "onboarding.connection_test_result.certificate_error.action_trust", fallback: "Trust Certificate") }
        /// Failed to connect securely
        public static var title: String { return L10n.tr("Localizable", "onboarding.connection_test_result.certificate_error.title", fallback: "Failed to connect securely") }
      }
      public enum ClientCertificate {
        /// Client Certificate Authentication is not supported.
        public static var description: String { return L10n.tr("Localizable", "onboarding.connection_test_result.client_certificate.description", fallback: "Client Certificate Authentication is not supported.") }
      }
      public enum LocalNetworkPermission {
        /// "Local Network" privacy permission may have been denied. You can change this in the system Settings app.
        public static var description: String { return L10n.tr("Localizable", "onboarding.connection_test_result.local_network_permission.description", fallback: "\"Local Network\" privacy permission may have been denied. You can change this in the system Settings app.") }
      }
    }
    public enum DeviceNameCheck {
      public enum Error {
        /// What device name should be used instead?
        public static var prompt: String { return L10n.tr("Localizable", "onboarding.device_name_check.error.prompt", fallback: "What device name should be used instead?") }
        /// A device already exists with the name '%1$@'
        public static func title(_ p1: Any) -> String {
          return L10n.tr("Localizable", "onboarding.device_name_check.error.title", String(describing: p1), fallback: "A device already exists with the name '%1$@'")
        }
      }
    }
    public enum Invitation {
      /// Accept
      public static var acceptButton: String { return L10n.tr("Localizable", "onboarding.invitation.accept_button", fallback: "Accept") }
      /// Other options
      public static var otherOptions: String { return L10n.tr("Localizable", "onboarding.invitation.other_options", fallback: "Other options") }
      /// Home Assistant Invite
      public static var title: String { return L10n.tr("Localizable", "onboarding.invitation.title", fallback: "Home Assistant Invite") }
    }
    public enum LocalAccess {
      /// If this app knows when you’re away from home, it can choose a more secure way to connect to your Home Assistant system. This requires location services to be enabled.
      public static var description: String { return L10n.tr("Localizable", "onboarding.local_access.description", fallback: "If this app knows when you’re away from home, it can choose a more secure way to connect to your Home Assistant system. This requires location services to be enabled.") }
      /// Next
      public static var nextButton: String { return L10n.tr("Localizable", "onboarding.local_access.next_button", fallback: "Next") }
      /// This data will never be shared with the Home Assistant project or third parties.
      public static var privacyDisclaimer: String { return L10n.tr("Localizable", "onboarding.local_access.privacy_disclaimer", fallback: "This data will never be shared with the Home Assistant project or third parties.") }
      /// Let us help secure your remote connection
      public static var title: String { return L10n.tr("Localizable", "onboarding.local_access.title", fallback: "Let us help secure your remote connection") }
      public enum LessSecureOption {
        /// Less secure: Do not allow this app to know when you're home
        public static var title: String { return L10n.tr("Localizable", "onboarding.local_access.less_secure_option.title", fallback: "Less secure: Do not allow this app to know when you're home") }
      }
      public enum SecureOption {
        /// Most secure: Allow this app to know when you're home
        public static var title: String { return L10n.tr("Localizable", "onboarding.local_access.secure_option.title", fallback: "Most secure: Allow this app to know when you're home") }
      }
    }
    public enum LocalOnlyDisclaimer {
      /// Your Home Assistant is only accessible on your home network. To control your smart home from anywhere, you can set up remote access later in your settings.
      public static var primaryDescription: String { return L10n.tr("Localizable", "onboarding.local_only_disclaimer.primary_description", fallback: "Your Home Assistant is only accessible on your home network. To control your smart home from anywhere, you can set up remote access later in your settings.") }
      /// For now, you're securely connected to your local network.
      public static var secondaryDescription: String { return L10n.tr("Localizable", "onboarding.local_only_disclaimer.secondary_description", fallback: "For now, you're securely connected to your local network.") }
      /// Local by default.
      /// Remote when you're ready.
      public static var title: String { return L10n.tr("Localizable", "onboarding.local_only_disclaimer.title", fallback: "Local by default.\nRemote when you're ready.") }
      public enum PrimaryButton {
        /// Got it
        public static var title: String { return L10n.tr("Localizable", "onboarding.local_only_disclaimer.primary_button.title", fallback: "Got it") }
      }
    }
    public enum LocationAccess {
      /// Location sharing enables powerful automations, such as turning off the heating when you leave home. This option shares the device’s location only with your Home Assistant system.
      public static var primaryDescription: String { return L10n.tr("Localizable", "onboarding.location_access.primary_description", fallback: "Location sharing enables powerful automations, such as turning off the heating when you leave home. This option shares the device’s location only with your Home Assistant system.") }
      /// This data stays in your home and is never sent to third parties. It also helps strengthen the security of your connection to Home Assistant.
      public static var secondaryDescription: String { return L10n.tr("Localizable", "onboarding.location_access.secondary_description", fallback: "This data stays in your home and is never sent to third parties. It also helps strengthen the security of your connection to Home Assistant.") }
      /// Use this device's location for automations
      public static var title: String { return L10n.tr("Localizable", "onboarding.location_access.title", fallback: "Use this device's location for automations") }
      public enum PrimaryAction {
        /// Share my location
        public static var title: String { return L10n.tr("Localizable", "onboarding.location_access.primary_action.title", fallback: "Share my location") }
      }
      public enum SecondaryAction {
        /// Do not share my location
        public static var title: String { return L10n.tr("Localizable", "onboarding.location_access.secondary_action.title", fallback: "Do not share my location") }
      }
    }
    public enum ManualSetup {
      /// Connect
      public static var connect: String { return L10n.tr("Localizable", "onboarding.manual_setup.connect", fallback: "Connect") }
      /// The URL of your Home Assistant server. Make sure it includes the protocol and port.
      public static var description: String { return L10n.tr("Localizable", "onboarding.manual_setup.description", fallback: "The URL of your Home Assistant server. Make sure it includes the protocol and port.") }
      /// Enter URL
      public static var title: String { return L10n.tr("Localizable", "onboarding.manual_setup.title", fallback: "Enter URL") }
      public enum CouldntMakeUrl {
        /// The value '%@' was not a valid URL.
        public static func message(_ p1: Any) -> String {
          return L10n.tr("Localizable", "onboarding.manual_setup.couldnt_make_url.message", String(describing: p1), fallback: "The value '%@' was not a valid URL.")
        }
        /// Could not create a URL
        public static var title: String { return L10n.tr("Localizable", "onboarding.manual_setup.couldnt_make_url.title", fallback: "Could not create a URL") }
      }
      public enum HelperSection {
        /// Did you mean...
        public static var title: String { return L10n.tr("Localizable", "onboarding.manual_setup.helper_section.title", fallback: "Did you mean...") }
      }
      public enum InputError {
        /// Make sure you have entered a valid URL.
        public static var message: String { return L10n.tr("Localizable", "onboarding.manual_setup.input_error.message", fallback: "Make sure you have entered a valid URL.") }
        /// Invalid URL
        public static var title: String { return L10n.tr("Localizable", "onboarding.manual_setup.input_error.title", fallback: "Invalid URL") }
      }
      public enum NoScheme {
        /// Should we try connecting using http:// or https://?
        public static var message: String { return L10n.tr("Localizable", "onboarding.manual_setup.no_scheme.message", fallback: "Should we try connecting using http:// or https://?") }
        /// URL entered without scheme
        public static var title: String { return L10n.tr("Localizable", "onboarding.manual_setup.no_scheme.title", fallback: "URL entered without scheme") }
      }
      public enum TextField {
        /// e.g. http://homeassistant.local:8123
        public static var placeholder: String { return L10n.tr("Localizable", "onboarding.manual_setup.text_field.placeholder", fallback: "e.g. http://homeassistant.local:8123") }
        /// Your Home Assistant URL
        public static var title: String { return L10n.tr("Localizable", "onboarding.manual_setup.text_field.title", fallback: "Your Home Assistant URL") }
      }
    }
    public enum ManualUrlEntry {
      /// What is your Home Assistant address?
      public static var title: String { return L10n.tr("Localizable", "onboarding.manual_url_entry.title", fallback: "What is your Home Assistant address?") }
      public enum PrimaryAction {
        /// Connect
        public static var title: String { return L10n.tr("Localizable", "onboarding.manual_url_entry.primary_action.title", fallback: "Connect") }
      }
    }
    public enum NetworkInput {
      /// For the best experience, Home Assistant needs to know when you’re connected to your home network.
      public static var primaryDescription: String { return L10n.tr("Localizable", "onboarding.network_input.primary_description", fallback: "For the best experience, Home Assistant needs to know when you’re connected to your home network.") }
      /// What is your home network?
      public static var title: String { return L10n.tr("Localizable", "onboarding.network_input.title", fallback: "What is your home network?") }
      public enum Disclaimer {
        /// Adding public Wi-Fi networks or using multiple ethernet/VPN connections may unintentionally expose information about or access to your app or server.
        public static var body: String { return L10n.tr("Localizable", "onboarding.network_input.disclaimer.body", fallback: "Adding public Wi-Fi networks or using multiple ethernet/VPN connections may unintentionally expose information about or access to your app or server.") }
        /// Make sure to set up your home network correctly.
        public static var title: String { return L10n.tr("Localizable", "onboarding.network_input.disclaimer.title", fallback: "Make sure to set up your home network correctly.") }
      }
      public enum Hardware {
        public enum InputField {
          /// Hardware Address
          public static var title: String { return L10n.tr("Localizable", "onboarding.network_input.hardware.input_field.title", fallback: "Hardware Address") }
        }
      }
      public enum InputField {
        /// Network name
        public static var placeholder: String { return L10n.tr("Localizable", "onboarding.network_input.input_field.placeholder", fallback: "Network name") }
        /// Name of the Wi-Fi network at home
        public static var title: String { return L10n.tr("Localizable", "onboarding.network_input.input_field.title", fallback: "Name of the Wi-Fi network at home") }
      }
      public enum NoNetwork {
        public enum Alert {
          /// Please enter a network name to continue.
          public static var body: String { return L10n.tr("Localizable", "onboarding.network_input.no_network.alert.body", fallback: "Please enter a network name to continue.") }
          /// Network name required
          public static var title: String { return L10n.tr("Localizable", "onboarding.network_input.no_network.alert.title", fallback: "Network name required") }
        }
        public enum Skip {
          public enum Alert {
            /// You haven't set a home network. You can set it up later in the app settings, until that we will only use your remote connection (if it exists) to access Home Assistant.
            public static var body: String { return L10n.tr("Localizable", "onboarding.network_input.no_network.skip.alert.body", fallback: "You haven't set a home network. You can set it up later in the app settings, until that we will only use your remote connection (if it exists) to access Home Assistant.") }
            /// Are you sure?
            public static var title: String { return L10n.tr("Localizable", "onboarding.network_input.no_network.skip.alert.title", fallback: "Are you sure?") }
            public enum PrimaryButton {
              /// Cancel
              public static var title: String { return L10n.tr("Localizable", "onboarding.network_input.no_network.skip.alert.primary_button.title", fallback: "Cancel") }
            }
            public enum SecondaryButton {
              /// Skip
              public static var title: String { return L10n.tr("Localizable", "onboarding.network_input.no_network.skip.alert.secondary_button.title", fallback: "Skip") }
            }
          }
        }
      }
      public enum PrimaryButton {
        /// Next
        public static var title: String { return L10n.tr("Localizable", "onboarding.network_input.primary_button.title", fallback: "Next") }
      }
      public enum SecondaryButton {
        /// Skip
        public static var title: String { return L10n.tr("Localizable", "onboarding.network_input.secondary_button.title", fallback: "Skip") }
      }
    }
    public enum Permission {
      public enum Location {
        /// To identify if you are at home and connect locally to Home Assistant, Apple requires that we ask for your location permission.
        public static var description: String { return L10n.tr("Localizable", "onboarding.permission.location.description", fallback: "To identify if you are at home and connect locally to Home Assistant, Apple requires that we ask for your location permission.") }
        public enum Deny {
          public enum Alert {
            /// If you are sure, please continue and tap 'Deny' on the next popup as well, in case you don't have a remote connection configured, the App will use your local connection configuration to access Home Assistant.
            public static var body: String { return L10n.tr("Localizable", "onboarding.permission.location.deny.alert.body", fallback: "If you are sure, please continue and tap 'Deny' on the next popup as well, in case you don't have a remote connection configured, the App will use your local connection configuration to access Home Assistant.") }
            /// Information
            public static var header: String { return L10n.tr("Localizable", "onboarding.permission.location.deny.alert.header", fallback: "Information") }
            /// Without location permission future versions of the App may deny access to your local Home Assistant server due to privacy concerns. If you are sure, please continue and tap 'Deny' on the next popup as well. By doing that we recommend you use your internal URL as external, since it is the only URL the app will try to access.
            public static var message: String { return L10n.tr("Localizable", "onboarding.permission.location.deny.alert.message", fallback: "Without location permission future versions of the App may deny access to your local Home Assistant server due to privacy concerns. If you are sure, please continue and tap 'Deny' on the next popup as well. By doing that we recommend you use your internal URL as external, since it is the only URL the app will try to access.") }
            /// Are you sure?
            public static var title: String { return L10n.tr("Localizable", "onboarding.permission.location.deny.alert.title", fallback: "Are you sure?") }
          }
        }
      }
    }
    public enum Permissions {
      /// Allow
      public static var allow: String { return L10n.tr("Localizable", "onboarding.permissions.allow", fallback: "Allow") }
      /// Done
      public static var allowed: String { return L10n.tr("Localizable", "onboarding.permissions.allowed", fallback: "Done") }
      /// You can change this permission later in Settings
      public static var changeLaterNote: String { return L10n.tr("Localizable", "onboarding.permissions.change_later_note", fallback: "You can change this permission later in Settings") }
      public enum Focus {
        /// Allow whether you are in focus mode to be sent to Home Assistant
        public static var description: String { return L10n.tr("Localizable", "onboarding.permissions.focus.description", fallback: "Allow whether you are in focus mode to be sent to Home Assistant") }
        /// Allow focus permission to create sensors for your focus status, also known as do-not-disturb.
        public static var grantDescription: String { return L10n.tr("Localizable", "onboarding.permissions.focus.grant_description", fallback: "Allow focus permission to create sensors for your focus status, also known as do-not-disturb.") }
        /// Focus
        public static var title: String { return L10n.tr("Localizable", "onboarding.permissions.focus.title", fallback: "Focus") }
        public enum Bullet {
          /// Focus-based automations
          public static var automations: String { return L10n.tr("Localizable", "onboarding.permissions.focus.bullet.automations", fallback: "Focus-based automations") }
          /// Instant updates when status changes
          public static var instant: String { return L10n.tr("Localizable", "onboarding.permissions.focus.bullet.instant", fallback: "Instant updates when status changes") }
        }
      }
      public enum Location {
        /// Enable location services to allow presence detection automations.
        public static var description: String { return L10n.tr("Localizable", "onboarding.permissions.location.description", fallback: "Enable location services to allow presence detection automations.") }
        /// Allow location permission to create a device_tracker for your device.
        public static var grantDescription: String { return L10n.tr("Localizable", "onboarding.permissions.location.grant_description", fallback: "Allow location permission to create a device_tracker for your device.") }
        /// Location
        public static var title: String { return L10n.tr("Localizable", "onboarding.permissions.location.title", fallback: "Location") }
        public enum Bullet {
          /// Presence-based automations
          public static var automations: String { return L10n.tr("Localizable", "onboarding.permissions.location.bullet.automations", fallback: "Presence-based automations") }
          /// Track location history
          public static var history: String { return L10n.tr("Localizable", "onboarding.permissions.location.bullet.history", fallback: "Track location history") }
          /// Internal URL at home
          public static var wifi: String { return L10n.tr("Localizable", "onboarding.permissions.location.bullet.wifi", fallback: "Internal URL at home") }
        }
      }
      public enum Motion {
        /// Allow motion activity and pedometer data to be sent to Home Assistant
        public static var description: String { return L10n.tr("Localizable", "onboarding.permissions.motion.description", fallback: "Allow motion activity and pedometer data to be sent to Home Assistant") }
        /// Allow motion permission to create sensors for motion and pedometer data.
        public static var grantDescription: String { return L10n.tr("Localizable", "onboarding.permissions.motion.grant_description", fallback: "Allow motion permission to create sensors for motion and pedometer data.") }
        /// Motion & Pedometer
        public static var title: String { return L10n.tr("Localizable", "onboarding.permissions.motion.title", fallback: "Motion & Pedometer") }
        public enum Bullet {
          /// Sensor for current activity type
          public static var activity: String { return L10n.tr("Localizable", "onboarding.permissions.motion.bullet.activity", fallback: "Sensor for current activity type") }
          /// Sensor for distance moved
          public static var distance: String { return L10n.tr("Localizable", "onboarding.permissions.motion.bullet.distance", fallback: "Sensor for distance moved") }
          /// Sensor for step counts
          public static var steps: String { return L10n.tr("Localizable", "onboarding.permissions.motion.bullet.steps", fallback: "Sensor for step counts") }
        }
      }
      public enum Notification {
        /// Allow push notifications to be sent from your Home Assistant
        public static var description: String { return L10n.tr("Localizable", "onboarding.permissions.notification.description", fallback: "Allow push notifications to be sent from your Home Assistant") }
        /// Allow notification permission to create a notify service for your device.
        public static var grantDescription: String { return L10n.tr("Localizable", "onboarding.permissions.notification.grant_description", fallback: "Allow notification permission to create a notify service for your device.") }
        /// Notifications
        public static var title: String { return L10n.tr("Localizable", "onboarding.permissions.notification.title", fallback: "Notifications") }
        public enum Bullet {
          /// Get alerted from notifications
          public static var alert: String { return L10n.tr("Localizable", "onboarding.permissions.notification.bullet.alert", fallback: "Get alerted from notifications") }
          /// Update app icon badge
          public static var badge: String { return L10n.tr("Localizable", "onboarding.permissions.notification.bullet.badge", fallback: "Update app icon badge") }
          /// Send commands to your device
          public static var commands: String { return L10n.tr("Localizable", "onboarding.permissions.notification.bullet.commands", fallback: "Send commands to your device") }
        }
      }
    }
    public enum Scanning {
      /// Discovered: %@
      public static func discoveredAnnouncement(_ p1: Any) -> String {
        return L10n.tr("Localizable", "onboarding.scanning.discovered_announcement", String(describing: p1), fallback: "Discovered: %@")
      }
      /// Enter Address Manually
      public static var manual: String { return L10n.tr("Localizable", "onboarding.scanning.manual", fallback: "Enter Address Manually") }
      /// Scanning for Servers
      public static var title: String { return L10n.tr("Localizable", "onboarding.scanning.title", fallback: "Scanning for Servers") }
      public enum Manual {
        public enum Button {
          /// Enter address manually
          public static var title: String { return L10n.tr("Localizable", "onboarding.scanning.manual.button.title", fallback: "Enter address manually") }
          public enum Divider {
            /// or
            public static var title: String { return L10n.tr("Localizable", "onboarding.scanning.manual.button.divider.title", fallback: "or") }
          }
        }
      }
    }
    public enum Servers {
      /// Searching on home network
      public static var title: String { return L10n.tr("Localizable", "onboarding.servers.title", fallback: "Searching on home network") }
      public enum AutoConnect {
        /// Connect
        public static var button: String { return L10n.tr("Localizable", "onboarding.servers.auto_connect.button", fallback: "Connect") }
      }
      public enum Docs {
        /// Read documentation
        public static var read: String { return L10n.tr("Localizable", "onboarding.servers.docs.read", fallback: "Read documentation") }
      }
      public enum Search {
        /// Looking for servers nearby...
        public static var message: String { return L10n.tr("Localizable", "onboarding.servers.search.message", fallback: "Looking for servers nearby...") }
        public enum Loader {
          /// Check that your Home Assistant is powered on and you're connected to the same network. You can enter the address manually if you know it.
          public static var text: String { return L10n.tr("Localizable", "onboarding.servers.search.loader.text", fallback: "Check that your Home Assistant is powered on and you're connected to the same network. You can enter the address manually if you know it.") }
        }
      }
    }
    public enum Welcome {
      /// Allows you to access your Home Assistant installation on the go. It runs locally in your home via a device like the Home Assistant Green or Raspberry Pi.
      public static var body: String { return L10n.tr("Localizable", "onboarding.welcome.body", fallback: "Allows you to access your Home Assistant installation on the go. It runs locally in your home via a device like the Home Assistant Green or Raspberry Pi.") }
      /// This app connects to your Home Assistant server and allows integrating data about you and your phone.
      /// 
      /// Home Assistant is free and open source home automation software with a focus on local control and privacy.
      public static var description: String { return L10n.tr("Localizable", "onboarding.welcome.description", fallback: "This app connects to your Home Assistant server and allows integrating data about you and your phone.\n\nHome Assistant is free and open source home automation software with a focus on local control and privacy.") }
      /// Home Assistant Companion App
      public static var header: String { return L10n.tr("Localizable", "onboarding.welcome.header", fallback: "Home Assistant Companion App") }
      /// Learn more
      public static var learnMore: String { return L10n.tr("Localizable", "onboarding.welcome.learn_more", fallback: "Learn more") }
      /// Connect to my Home Assistant
      public static var primaryButton: String { return L10n.tr("Localizable", "onboarding.welcome.primary_button", fallback: "Connect to my Home Assistant") }
      /// Getting started
      public static var secondaryButton: String { return L10n.tr("Localizable", "onboarding.welcome.secondary_button", fallback: "Getting started") }
      /// Welcome to Home Assistant %@!
      public static func title(_ p1: Any) -> String {
        return L10n.tr("Localizable", "onboarding.welcome.title", String(describing: p1), fallback: "Welcome to Home Assistant %@!")
      }
      public enum Logo {
        /// Home Assistant logo
        public static var accessibilityLabel: String { return L10n.tr("Localizable", "onboarding.welcome.logo.accessibility_label", fallback: "Home Assistant logo") }
      }
      public enum Updated {
        /// Access your Home Assistant server on the go. 
        /// 
        /// Home Assistant is open source, advocates for privacy and runs locally in your home.
        public static var body: String { return L10n.tr("Localizable", "onboarding.welcome.updated.body", fallback: "Access your Home Assistant server on the go. \n\nHome Assistant is open source, advocates for privacy and runs locally in your home.") }
        /// Learn more
        public static var secondaryButton: String { return L10n.tr("Localizable", "onboarding.welcome.updated.secondary_button", fallback: "Learn more") }
      }
    }
  }
  public enum Permission {
    public enum Notification {
      /// Enable notifications and get what's happening in your home, from detecting leaks to doors left open, you have full control over what it tells you.
      public static var body: String { return L10n.tr("Localizable", "permission.notification.body", fallback: "Enable notifications and get what's happening in your home, from detecting leaks to doors left open, you have full control over what it tells you.") }
      /// Allow notifications
      public static var primaryButton: String { return L10n.tr("Localizable", "permission.notification.primary_button", fallback: "Allow notifications") }
      /// Do not allow
      public static var secondaryButton: String { return L10n.tr("Localizable", "permission.notification.secondary_button", fallback: "Do not allow") }
      /// Allow notifications?
      public static var title: String { return L10n.tr("Localizable", "permission.notification.title", fallback: "Allow notifications?") }
    }
    public enum Screen {
      public enum Bluetooth {
        /// Skip
        public static var secondaryButton: String { return L10n.tr("Localizable", "permission.screen.bluetooth.secondary_button", fallback: "Skip") }
        /// The Home Assistant app can find devices using Bluetooth of this device. Allow Bluetooth access for the Home Assistant app.
        public static var subtitle: String { return L10n.tr("Localizable", "permission.screen.bluetooth.subtitle", fallback: "The Home Assistant app can find devices using Bluetooth of this device. Allow Bluetooth access for the Home Assistant app.") }
        /// Search devices
        public static var title: String { return L10n.tr("Localizable", "permission.screen.bluetooth.title", fallback: "Search devices") }
      }
    }
  }
  public enum PostOnboarding {
    public enum Permission {
      public enum Notification {
        /// Notifications can be useful in your automations. Tap the icon to allow or deny.
        public static var message: String { return L10n.tr("Localizable", "post_onboarding.permission.notification.message", fallback: "Notifications can be useful in your automations. Tap the icon to allow or deny.") }
        /// Do you want to receive notifications?
        public static var title: String { return L10n.tr("Localizable", "post_onboarding.permission.notification.title", fallback: "Do you want to receive notifications?") }
      }
    }
  }
  public enum RoomView {
    public enum Section {
      /// Hidden
      public static var hidden: String { return L10n.tr("Localizable", "room_view.section.hidden", fallback: "Hidden") }
      /// Visible
      public static var visible: String { return L10n.tr("Localizable", "room_view.section.visible", fallback: "Visible") }
    }
  }
  public enum Sensors {
    public enum Active {
      public enum Setting {
        /// Time Until Idle
        public static var timeUntilIdle: String { return L10n.tr("Localizable", "sensors.active.setting.time_until_idle", fallback: "Time Until Idle") }
      }
    }
    public enum GeocodedLocation {
      public enum Setting {
        /// Use Zone Name
        public static var useZones: String { return L10n.tr("Localizable", "sensors.geocoded_location.setting.use_zones", fallback: "Use Zone Name") }
      }
    }
  }
  public enum ServersSelection {
    /// Servers
    public static var title: String { return L10n.tr("Localizable", "servers_selection.title", fallback: "Servers") }
  }
  public enum Settings {
    public enum ConnectionSection {
      /// Activate
      public static var activateServer: String { return L10n.tr("Localizable", "settings.connection_section.activate_server", fallback: "Activate") }
      /// Add Server
      public static var addServer: String { return L10n.tr("Localizable", "settings.connection_section.add_server", fallback: "Add Server") }
      /// All Servers
      public static var allServers: String { return L10n.tr("Localizable", "settings.connection_section.all_servers", fallback: "All Servers") }
      /// When connecting via Cloud, the External URL will not be used. You do not need to configure one unless you want to disable Cloud.
      public static var cloudOverridesExternal: String { return L10n.tr("Localizable", "settings.connection_section.cloud_overrides_external", fallback: "When connecting via Cloud, the External URL will not be used. You do not need to configure one unless you want to disable Cloud.") }
      /// Connected via
      public static var connectingVia: String { return L10n.tr("Localizable", "settings.connection_section.connecting_via", fallback: "Connected via") }
      /// Details
      public static var details: String { return L10n.tr("Localizable", "settings.connection_section.details", fallback: "Details") }
      /// Connection
      public static var header: String { return L10n.tr("Localizable", "settings.connection_section.header", fallback: "Connection") }
      /// Directly connect to the Home Assistant server for push notifications when on internal SSIDs.
      public static var localPushDescription: String { return L10n.tr("Localizable", "settings.connection_section.local_push_description", fallback: "Directly connect to the Home Assistant server for push notifications when on internal SSIDs.") }
      /// Logged in as
      public static var loggedInAs: String { return L10n.tr("Localizable", "settings.connection_section.logged_in_as", fallback: "Logged in as") }
      /// Update server information
      public static var refreshServer: String { return L10n.tr("Localizable", "settings.connection_section.refresh_server", fallback: "Update server information") }
      /// Servers
      public static var servers: String { return L10n.tr("Localizable", "settings.connection_section.servers", fallback: "Servers") }
      /// Reorder to define default server
      public static var serversFooter: String { return L10n.tr("Localizable", "settings.connection_section.servers_footer", fallback: "Reorder to define default server") }
      /// Servers
      public static var serversHeader: String { return L10n.tr("Localizable", "settings.connection_section.servers_header", fallback: "Servers") }
      /// Accessing SSIDs in the background requires 'Always' location permission and 'Full' location accuracy. Tap here to change your settings.
      public static var ssidPermissionAndAccuracyMessage: String { return L10n.tr("Localizable", "settings.connection_section.ssid_permission_and_accuracy_message", fallback: "Accessing SSIDs in the background requires 'Always' location permission and 'Full' location accuracy. Tap here to change your settings.") }
      public enum AlwaysFallbackInternal {
        /// Enabling this with an unsecure URL (http) may compromise your security on public networks.
        public static var footer: String { return L10n.tr("Localizable", "settings.connection_section.always_fallback_internal.footer", fallback: "Enabling this with an unsecure URL (http) may compromise your security on public networks.") }
        /// Always fallback to internal URL
        public static var title: String { return L10n.tr("Localizable", "settings.connection_section.always_fallback_internal.title", fallback: "Always fallback to internal URL") }
        public enum Confirmation {
          /// If you have an unsecure connection this can expose your authentication token on public networks.
          public static var message: String { return L10n.tr("Localizable", "settings.connection_section.always_fallback_internal.confirmation.message", fallback: "If you have an unsecure connection this can expose your authentication token on public networks.") }
          /// Are you sure?
          public static var title: String { return L10n.tr("Localizable", "settings.connection_section.always_fallback_internal.confirmation.title", fallback: "Are you sure?") }
        }
      }
      public enum ClientCertificate {
        /// Certificate expired
        public static var expired: String { return L10n.tr("Localizable", "settings.connection_section.client_certificate.expired", fallback: "Certificate expired") }
        /// Expires %@
        public static func expiresAt(_ p1: Any) -> String {
          return L10n.tr("Localizable", "settings.connection_section.client_certificate.expires_at", String(describing: p1), fallback: "Expires %@")
        }
        /// Import a PKCS#12 (.p12) certificate for mutual TLS authentication. Required when your Home Assistant server requires client certificates.
        public static var footer: String { return L10n.tr("Localizable", "settings.connection_section.client_certificate.footer", fallback: "Import a PKCS#12 (.p12) certificate for mutual TLS authentication. Required when your Home Assistant server requires client certificates.") }
        /// Client Certificate
        public static var header: String { return L10n.tr("Localizable", "settings.connection_section.client_certificate.header", fallback: "Client Certificate") }
        /// Import Certificate
        public static var `import`: String { return L10n.tr("Localizable", "settings.connection_section.client_certificate.import", fallback: "Import Certificate") }
        /// Importing...
        public static var importing: String { return L10n.tr("Localizable", "settings.connection_section.client_certificate.importing", fallback: "Importing...") }
        /// Remove Certificate
        public static var remove: String { return L10n.tr("Localizable", "settings.connection_section.client_certificate.remove", fallback: "Remove Certificate") }
        public enum ImportError {
          /// Import Failed
          public static var title: String { return L10n.tr("Localizable", "settings.connection_section.client_certificate.import_error.title", fallback: "Import Failed") }
        }
        public enum PasswordPrompt {
          /// Import
          public static var importButton: String { return L10n.tr("Localizable", "settings.connection_section.client_certificate.password_prompt.import_button", fallback: "Import") }
          /// Enter the password for the certificate file
          public static var message: String { return L10n.tr("Localizable", "settings.connection_section.client_certificate.password_prompt.message", fallback: "Enter the password for the certificate file") }
          /// Password
          public static var placeholder: String { return L10n.tr("Localizable", "settings.connection_section.client_certificate.password_prompt.placeholder", fallback: "Password") }
          /// Certificate Password
          public static var title: String { return L10n.tr("Localizable", "settings.connection_section.client_certificate.password_prompt.title", fallback: "Certificate Password") }
        }
        public enum RemoveConfirmation {
          /// The certificate will be removed from the device. You will need to import it again to use mTLS authentication.
          public static var message: String { return L10n.tr("Localizable", "settings.connection_section.client_certificate.remove_confirmation.message", fallback: "The certificate will be removed from the device. You will need to import it again to use mTLS authentication.") }
          /// Remove
          public static var remove: String { return L10n.tr("Localizable", "settings.connection_section.client_certificate.remove_confirmation.remove", fallback: "Remove") }
          /// Remove Certificate?
          public static var title: String { return L10n.tr("Localizable", "settings.connection_section.client_certificate.remove_confirmation.title", fallback: "Remove Certificate?") }
        }
      }
      public enum ConnectionAccessSecurityLevel {
        /// Connection security level
        public static var title: String { return L10n.tr("Localizable", "settings.connection_section.connection_access_security_level.title", fallback: "Connection security level") }
        public enum LessSecure {
          /// Less secure
          public static var title: String { return L10n.tr("Localizable", "settings.connection_section.connection_access_security_level.less_secure.title", fallback: "Less secure") }
        }
        public enum MostSecure {
          /// Most secure
          public static var title: String { return L10n.tr("Localizable", "settings.connection_section.connection_access_security_level.most_secure.title", fallback: "Most secure") }
        }
        public enum Undefined {
          /// Not configured
          public static var title: String { return L10n.tr("Localizable", "settings.connection_section.connection_access_security_level.undefined.title", fallback: "Not configured") }
        }
      }
      public enum DeleteServer {
        /// Are you sure you wish to delete this server?
        public static var message: String { return L10n.tr("Localizable", "settings.connection_section.delete_server.message", fallback: "Are you sure you wish to delete this server?") }
        /// Deleting Server…
        public static var progress: String { return L10n.tr("Localizable", "settings.connection_section.delete_server.progress", fallback: "Deleting Server…") }
        /// Delete Server
        public static var title: String { return L10n.tr("Localizable", "settings.connection_section.delete_server.title", fallback: "Delete Server") }
      }
      public enum Errors {
        /// You cannot remove only available URL.
        public static var cannotRemoveLastUrl: String { return L10n.tr("Localizable", "settings.connection_section.errors.cannot_remove_last_url", fallback: "You cannot remove only available URL.") }
      }
      public enum ExternalBaseUrl {
        /// https://homeassistant.myhouse.com
        public static var placeholder: String { return L10n.tr("Localizable", "settings.connection_section.external_base_url.placeholder", fallback: "https://homeassistant.myhouse.com") }
        /// External URL
        public static var title: String { return L10n.tr("Localizable", "settings.connection_section.external_base_url.title", fallback: "External URL") }
      }
      public enum HomeAssistantCloud {
        /// Home Assistant Cloud
        public static var title: String { return L10n.tr("Localizable", "settings.connection_section.home_assistant_cloud.title", fallback: "Home Assistant Cloud") }
      }
      public enum InternalBaseUrl {
        /// e.g. http://homeassistant.local:8123/
        public static var placeholder: String { return L10n.tr("Localizable", "settings.connection_section.internal_base_url.placeholder", fallback: "e.g. http://homeassistant.local:8123/") }
        /// Internal URL
        public static var title: String { return L10n.tr("Localizable", "settings.connection_section.internal_base_url.title", fallback: "Internal URL") }
        public enum RequiresSetup {
          /// Requires setup
          public static var title: String { return L10n.tr("Localizable", "settings.connection_section.internal_base_url.requires_setup.title", fallback: "Requires setup") }
        }
        public enum SsidBssidRequired {
          /// To use internal URL you need to specify your Wifi network name (SSID) or hardware addresses, otherwise the App will always default to external URL.
          public static var title: String { return L10n.tr("Localizable", "settings.connection_section.internal_base_url.ssid_bssid_required.title", fallback: "To use internal URL you need to specify your Wifi network name (SSID) or hardware addresses, otherwise the App will always default to external URL.") }
        }
        public enum SsidRequired {
          /// To use internal URL you need to specify your Wifi network name (SSID), otherwise the App will always default to external URL.
          public static var title: String { return L10n.tr("Localizable", "settings.connection_section.internal_base_url.ssid_required.title", fallback: "To use internal URL you need to specify your Wifi network name (SSID), otherwise the App will always default to external URL.") }
        }
      }
      public enum InternalUrlHardwareAddresses {
        /// Add New Hardware Address
        public static var addNewSsid: String { return L10n.tr("Localizable", "settings.connection_section.internal_url_hardware_addresses.add_new_ssid", fallback: "Add New Hardware Address") }
        /// Internal URL will be used when the primary network interface has a MAC address matching one of these hardware addresses.
        public static var footer: String { return L10n.tr("Localizable", "settings.connection_section.internal_url_hardware_addresses.footer", fallback: "Internal URL will be used when the primary network interface has a MAC address matching one of these hardware addresses.") }
        /// Hardware Addresses
        public static var header: String { return L10n.tr("Localizable", "settings.connection_section.internal_url_hardware_addresses.header", fallback: "Hardware Addresses") }
        /// Hardware addresses must look like aa:bb:cc:dd:ee:ff
        public static var invalid: String { return L10n.tr("Localizable", "settings.connection_section.internal_url_hardware_addresses.invalid", fallback: "Hardware addresses must look like aa:bb:cc:dd:ee:ff") }
      }
      public enum InternalUrlSsids {
        /// Add new SSID
        public static var addNewSsid: String { return L10n.tr("Localizable", "settings.connection_section.internal_url_ssids.add_new_ssid", fallback: "Add new SSID") }
        /// Internal URL will be used when connected to listed SSIDs
        public static var footer: String { return L10n.tr("Localizable", "settings.connection_section.internal_url_ssids.footer", fallback: "Internal URL will be used when connected to listed SSIDs") }
        /// SSIDs
        public static var header: String { return L10n.tr("Localizable", "settings.connection_section.internal_url_ssids.header", fallback: "SSIDs") }
        /// MyFunnyNetworkName
        public static var placeholder: String { return L10n.tr("Localizable", "settings.connection_section.internal_url_ssids.placeholder", fallback: "MyFunnyNetworkName") }
      }
      public enum LocalAccessSecurityLevel {
        /// Local access security
        public static var title: String { return L10n.tr("Localizable", "settings.connection_section.local_access_security_level.title", fallback: "Local access security") }
        public enum LessSecure {
          /// Less secure
          public static var title: String { return L10n.tr("Localizable", "settings.connection_section.local_access_security_level.less_secure.title", fallback: "Less secure") }
        }
        public enum MostSecure {
          /// Most secure
          public static var title: String { return L10n.tr("Localizable", "settings.connection_section.local_access_security_level.most_secure.title", fallback: "Most secure") }
        }
        public enum Undefined {
          /// Not configured
          public static var title: String { return L10n.tr("Localizable", "settings.connection_section.local_access_security_level.undefined.title", fallback: "Not configured") }
        }
      }
      public enum LocationSendType {
        /// Location Sent
        public static var title: String { return L10n.tr("Localizable", "settings.connection_section.location_send_type.title", fallback: "Location Sent") }
        public enum Setting {
          /// Exact
          public static var exact: String { return L10n.tr("Localizable", "settings.connection_section.location_send_type.setting.exact", fallback: "Exact") }
          /// Never
          public static var never: String { return L10n.tr("Localizable", "settings.connection_section.location_send_type.setting.never", fallback: "Never") }
          /// Zone only
          public static var zoneOnly: String { return L10n.tr("Localizable", "settings.connection_section.location_send_type.setting.zone_only", fallback: "Zone only") }
        }
      }
      public enum NoBaseUrl {
        /// No URL
        public static var title: String { return L10n.tr("Localizable", "settings.connection_section.no_base_url.title", fallback: "No URL") }
      }
      public enum RemoteUiUrl {
        /// Remote UI URL
        public static var title: String { return L10n.tr("Localizable", "settings.connection_section.remote_ui_url.title", fallback: "Remote UI URL") }
      }
      public enum SensorSendType {
        /// Sensors Sent
        public static var title: String { return L10n.tr("Localizable", "settings.connection_section.sensor_send_type.title", fallback: "Sensors Sent") }
        public enum Setting {
          /// All
          public static var all: String { return L10n.tr("Localizable", "settings.connection_section.sensor_send_type.setting.all", fallback: "All") }
          /// None
          public static var `none`: String { return L10n.tr("Localizable", "settings.connection_section.sensor_send_type.setting.none", fallback: "None") }
        }
      }
      public enum ValidateError {
        /// Edit URL
        public static var editUrl: String { return L10n.tr("Localizable", "settings.connection_section.validate_error.edit_url", fallback: "Edit URL") }
        /// Error Saving URL
        public static var title: String { return L10n.tr("Localizable", "settings.connection_section.validate_error.title", fallback: "Error Saving URL") }
        /// Use Anyway
        public static var useAnyway: String { return L10n.tr("Localizable", "settings.connection_section.validate_error.use_anyway", fallback: "Use Anyway") }
      }
      public enum Websocket {
        /// WebSocket
        public static var title: String { return L10n.tr("Localizable", "settings.connection_section.websocket.title", fallback: "WebSocket") }
        public enum Status {
          /// Authenticating
          public static var authenticating: String { return L10n.tr("Localizable", "settings.connection_section.websocket.status.authenticating", fallback: "Authenticating") }
          /// Connected
          public static var connected: String { return L10n.tr("Localizable", "settings.connection_section.websocket.status.connected", fallback: "Connected") }
          /// Connecting
          public static var connecting: String { return L10n.tr("Localizable", "settings.connection_section.websocket.status.connecting", fallback: "Connecting") }
          public enum Disconnected {
            /// Error: %1$@
            public static func error(_ p1: Any) -> String {
              return L10n.tr("Localizable", "settings.connection_section.websocket.status.disconnected.error", String(describing: p1), fallback: "Error: %1$@")
            }
            /// Next Retry: %1$@
            public static func nextRetry(_ p1: Any) -> String {
              return L10n.tr("Localizable", "settings.connection_section.websocket.status.disconnected.next_retry", String(describing: p1), fallback: "Next Retry: %1$@")
            }
            /// Retry Count: %1$li
            public static func retryCount(_ p1: Int) -> String {
              return L10n.tr("Localizable", "settings.connection_section.websocket.status.disconnected.retry_count", p1, fallback: "Retry Count: %1$li")
            }
            /// Disconnected
            public static var title: String { return L10n.tr("Localizable", "settings.connection_section.websocket.status.disconnected.title", fallback: "Disconnected") }
          }
          public enum Rejected {
            /// Rejected
            public static var title: String { return L10n.tr("Localizable", "settings.connection_section.websocket.status.rejected.title", fallback: "Rejected") }
          }
        }
      }
    }
    public enum DatabaseExplorer {
      /// +%li more fields
      public static func moreFields(_ p1: Int) -> String {
        return L10n.tr("Localizable", "settings.database_explorer.more_fields", p1, fallback: "+%li more fields")
      }
      /// No entries found
      public static var noEntries: String { return L10n.tr("Localizable", "settings.database_explorer.no_entries", fallback: "No entries found") }
      /// Row Details
      public static var rowDetail: String { return L10n.tr("Localizable", "settings.database_explorer.row_detail", fallback: "Row Details") }
      /// Database Explorer
      public static var title: String { return L10n.tr("Localizable", "settings.database_explorer.title", fallback: "Database Explorer") }
    }
    public enum Debugging {
      /// Debugging
      public static var title: String { return L10n.tr("Localizable", "settings.debugging.title", fallback: "Debugging") }
      public enum CriticalSection {
        /// Make sure you are aware that these operations cannot be reverted.
        public static var footer: String { return L10n.tr("Localizable", "settings.debugging.critical_section.footer", fallback: "Make sure you are aware that these operations cannot be reverted.") }
      }
      public enum Header {
        /// Let's fix that 🐞
        public static var subtitle: String { return L10n.tr("Localizable", "settings.debugging.header.subtitle", fallback: "Let's fix that 🐞") }
        /// Debug
        public static var title: String { return L10n.tr("Localizable", "settings.debugging.header.title", fallback: "Debug") }
      }
      public enum ShakeDisclaimer {
        /// Now when you shake the app you can access debug features.
        public static var title: String { return L10n.tr("Localizable", "settings.debugging.shake_disclaimer.title", fallback: "Now when you shake the app you can access debug features.") }
      }
      public enum ShakeDisclaimerOptional {
        /// Shake the App to open debug
        public static var title: String { return L10n.tr("Localizable", "settings.debugging.shake_disclaimer_optional.title", fallback: "Shake the App to open debug") }
      }
      public enum Thread {
        /// Check what Thread credentials are inside Apple Keychain, you can also import in Home Assistant or delete from Keychain.
        public static var footer: String { return L10n.tr("Localizable", "settings.debugging.thread.footer", fallback: "Check what Thread credentials are inside Apple Keychain, you can also import in Home Assistant or delete from Keychain.") }
      }
    }
    public enum DetailsSection {
      public enum LocationSettingsRow {
        /// Location
        public static var title: String { return L10n.tr("Localizable", "settings.details_section.location_settings_row.title", fallback: "Location") }
      }
      public enum NotificationSettingsRow {
        /// Notifications
        public static var title: String { return L10n.tr("Localizable", "settings.details_section.notification_settings_row.title", fallback: "Notifications") }
      }
      public enum WatchRow {
        /// Apple Watch
        public static var title: String { return L10n.tr("Localizable", "settings.details_section.watch_row.title", fallback: "Apple Watch") }
      }
      public enum WatchRowComplications {
        /// Complications
        public static var title: String { return L10n.tr("Localizable", "settings.details_section.watch_row_complications.title", fallback: "Complications") }
      }
      public enum WatchRowConfiguration {
        /// Configuration
        public static var title: String { return L10n.tr("Localizable", "settings.details_section.watch_row_configuration.title", fallback: "Configuration") }
      }
    }
    public enum Developer {
      /// Don't use these if you don't know what you are doing!
      public static var footer: String { return L10n.tr("Localizable", "settings.developer.footer", fallback: "Don't use these if you don't know what you are doing!") }
      /// Developer
      public static var header: String { return L10n.tr("Localizable", "settings.developer.header", fallback: "Developer") }
      public enum AnnoyingBackgroundNotifications {
        /// Annoying Background Info
        public static var title: String { return L10n.tr("Localizable", "settings.developer.annoying_background_notifications.title", fallback: "Annoying Background Info") }
      }
      public enum CameraNotification {
        /// Show camera notification content extension
        public static var title: String { return L10n.tr("Localizable", "settings.developer.camera_notification.title", fallback: "Show camera notification content extension") }
        public enum Notification {
          /// Expand this to show the camera content extension
          public static var body: String { return L10n.tr("Localizable", "settings.developer.camera_notification.notification.body", fallback: "Expand this to show the camera content extension") }
        }
      }
      public enum CopyRealm {
        /// Copy Realm from app group to Documents
        public static var title: String { return L10n.tr("Localizable", "settings.developer.copy_realm.title", fallback: "Copy Realm from app group to Documents") }
        public enum Alert {
          /// Copied Realm from %@ to %@
          public static func message(_ p1: Any, _ p2: Any) -> String {
            return L10n.tr("Localizable", "settings.developer.copy_realm.alert.message", String(describing: p1), String(describing: p2), fallback: "Copied Realm from %@ to %@")
          }
          /// Copied Realm
          public static var title: String { return L10n.tr("Localizable", "settings.developer.copy_realm.alert.title", fallback: "Copied Realm") }
        }
      }
      public enum CrashlyticsTest {
        public enum Fatal {
          /// Test Crashlytics Fatal Error
          public static var title: String { return L10n.tr("Localizable", "settings.developer.crashlytics_test.fatal.title", fallback: "Test Crashlytics Fatal Error") }
          public enum Notification {
            /// NOTE: This will not work if the debugger is connected! When you press OK, the app will crash. You must then re-open the app and wait up to 5 minutes for the crash to appear in the console
            public static var body: String { return L10n.tr("Localizable", "settings.developer.crashlytics_test.fatal.notification.body", fallback: "NOTE: This will not work if the debugger is connected! When you press OK, the app will crash. You must then re-open the app and wait up to 5 minutes for the crash to appear in the console") }
            /// About to crash
            public static var title: String { return L10n.tr("Localizable", "settings.developer.crashlytics_test.fatal.notification.title", fallback: "About to crash") }
          }
        }
        public enum NonFatal {
          /// Test Crashlytics Non-Fatal Error
          public static var title: String { return L10n.tr("Localizable", "settings.developer.crashlytics_test.non_fatal.title", fallback: "Test Crashlytics Non-Fatal Error") }
          public enum Notification {
            /// When you press OK, a non-fatal error will be sent to Crashlytics. It may take up to 5 minutes to appear in the console.
            public static var body: String { return L10n.tr("Localizable", "settings.developer.crashlytics_test.non_fatal.notification.body", fallback: "When you press OK, a non-fatal error will be sent to Crashlytics. It may take up to 5 minutes to appear in the console.") }
            /// About to submit a non-fatal error
            public static var title: String { return L10n.tr("Localizable", "settings.developer.crashlytics_test.non_fatal.notification.title", fallback: "About to submit a non-fatal error") }
          }
        }
      }
      public enum DebugStrings {
        /// Debug strings
        public static var title: String { return L10n.tr("Localizable", "settings.developer.debug_strings.title", fallback: "Debug strings") }
      }
      public enum ExportLogFiles {
        /// Export log files
        public static var title: String { return L10n.tr("Localizable", "settings.developer.export_log_files.title", fallback: "Export log files") }
      }
      public enum MapNotification {
        /// Show map notification content extension
        public static var title: String { return L10n.tr("Localizable", "settings.developer.map_notification.title", fallback: "Show map notification content extension") }
        public enum Notification {
          /// Expand this to show the map content extension
          public static var body: String { return L10n.tr("Localizable", "settings.developer.map_notification.notification.body", fallback: "Expand this to show the map content extension") }
        }
      }
      public enum MockThreadCredentialsSharing {
        /// Simulator Thread Credentials Sharing
        public static var title: String { return L10n.tr("Localizable", "settings.developer.mock_thread_credentials_sharing.title", fallback: "Simulator Thread Credentials Sharing") }
      }
      public enum ShowLogFiles {
        /// Show log files in Finder
        public static var title: String { return L10n.tr("Localizable", "settings.developer.show_log_files.title", fallback: "Show log files in Finder") }
      }
      public enum SyncWatchContext {
        /// Sync Watch Context
        public static var title: String { return L10n.tr("Localizable", "settings.developer.sync_watch_context.title", fallback: "Sync Watch Context") }
      }
    }
    public enum EventLog {
      /// Event Log
      public static var title: String { return L10n.tr("Localizable", "settings.event_log.title", fallback: "Event Log") }
    }
    public enum LocationHistory {
      /// No Location History
      public static var empty: String { return L10n.tr("Localizable", "settings.location_history.empty", fallback: "No Location History") }
      /// Location History
      public static var title: String { return L10n.tr("Localizable", "settings.location_history.title", fallback: "Location History") }
      public enum Detail {
        /// The purple circle is your location and its accuracy. Blue circles are your zones. You are inside a zone if the purple circle overlaps a blue circle. Orange circles are additional regions used for sub-100 m zones.
        public static var explanation: String { return L10n.tr("Localizable", "settings.location_history.detail.explanation", fallback: "The purple circle is your location and its accuracy. Blue circles are your zones. You are inside a zone if the purple circle overlaps a blue circle. Orange circles are additional regions used for sub-100 m zones.") }
      }
    }
    public enum NavigationBar {
      /// Settings
      public static var title: String { return L10n.tr("Localizable", "settings.navigation_bar.title", fallback: "Settings") }
      public enum AboutButton {
        /// About
        public static var title: String { return L10n.tr("Localizable", "settings.navigation_bar.about_button.title", fallback: "About") }
      }
    }
    public enum ResetSection {
      public enum ResetAlert {
        /// Your settings will be reset and this device will be unregistered from push notifications as well as removed from your Home Assistant configuration.
        public static var message: String { return L10n.tr("Localizable", "settings.reset_section.reset_alert.message", fallback: "Your settings will be reset and this device will be unregistered from push notifications as well as removed from your Home Assistant configuration.") }
        /// Reset
        public static var title: String { return L10n.tr("Localizable", "settings.reset_section.reset_alert.title", fallback: "Reset") }
      }
      public enum ResetApp {
        /// Reset App (Remove servers and data)
        public static var title: String { return L10n.tr("Localizable", "settings.reset_section.reset_app.title", fallback: "Reset App (Remove servers and data)") }
      }
      public enum ResetRow {
        /// Reset
        public static var title: String { return L10n.tr("Localizable", "settings.reset_section.reset_row.title", fallback: "Reset") }
      }
      public enum ResetWebCache {
        /// Reset frontend cache
        public static var title: String { return L10n.tr("Localizable", "settings.reset_section.reset_web_cache.title", fallback: "Reset frontend cache") }
      }
    }
    public enum ServerSelect {
      /// Server
      public static var title: String { return L10n.tr("Localizable", "settings.server_select.title", fallback: "Server") }
    }
    public enum StatusSection {
      /// Status
      public static var header: String { return L10n.tr("Localizable", "settings.status_section.header", fallback: "Status") }
      public enum LocationNameRow {
        /// My Home Assistant
        public static var placeholder: String { return L10n.tr("Localizable", "settings.status_section.location_name_row.placeholder", fallback: "My Home Assistant") }
        /// Name
        public static var title: String { return L10n.tr("Localizable", "settings.status_section.location_name_row.title", fallback: "Name") }
      }
      public enum VersionRow {
        /// 0.92.0
        public static var placeholder: String { return L10n.tr("Localizable", "settings.status_section.version_row.placeholder", fallback: "0.92.0") }
        /// Version
        public static var title: String { return L10n.tr("Localizable", "settings.status_section.version_row.title", fallback: "Version") }
      }
    }
    public enum TemplateEdit {
      /// Edit Template
      public static var title: String { return L10n.tr("Localizable", "settings.template_edit.title", fallback: "Edit Template") }
    }
    public enum WhatsNew {
      /// What's new?
      public static var title: String { return L10n.tr("Localizable", "settings.whats_new.title", fallback: "What's new?") }
    }
    public enum Widgets {
      /// Widgets
      public static var title: String { return L10n.tr("Localizable", "settings.widgets.title", fallback: "Widgets") }
      public enum Create {
        /// Create widget
        public static var title: String { return L10n.tr("Localizable", "settings.widgets.create.title", fallback: "Create widget") }
        public enum AddItem {
          /// Add item
          public static var title: String { return L10n.tr("Localizable", "settings.widgets.create.add_item.title", fallback: "Add item") }
        }
        public enum Footer {
          /// While the widget preview only displays one widget size, your custom widget will be available on multiple sizes respecting the limit of items per size.
          public static var title: String { return L10n.tr("Localizable", "settings.widgets.create.footer.title", fallback: "While the widget preview only displays one widget size, your custom widget will be available on multiple sizes respecting the limit of items per size.") }
        }
        public enum Items {
          /// Items
          public static var title: String { return L10n.tr("Localizable", "settings.widgets.create.items.title", fallback: "Items") }
        }
        public enum Name {
          /// e.g. Living room favorites
          public static var placeholder: String { return L10n.tr("Localizable", "settings.widgets.create.name.placeholder", fallback: "e.g. Living room favorites") }
          /// Name
          public static var title: String { return L10n.tr("Localizable", "settings.widgets.create.name.title", fallback: "Name") }
        }
        public enum NoItems {
          /// No items
          public static var title: String { return L10n.tr("Localizable", "settings.widgets.create.no_items.title", fallback: "No items") }
        }
      }
      public enum Custom {
        public enum DeleteAll {
          /// Reset all custom widgets
          public static var title: String { return L10n.tr("Localizable", "settings.widgets.custom.delete_all.title", fallback: "Reset all custom widgets") }
        }
      }
      public enum Select {
        /// Add to Widget
        public static var title: String { return L10n.tr("Localizable", "settings.widgets.select.title", fallback: "Add to Widget") }
        public enum Empty {
          /// Create your first widget to add this entity.
          public static var subtitle: String { return L10n.tr("Localizable", "settings.widgets.select.empty.subtitle", fallback: "Create your first widget to add this entity.") }
          /// No Widgets Yet
          public static var title: String { return L10n.tr("Localizable", "settings.widgets.select.empty.title", fallback: "No Widgets Yet") }
        }
        public enum Footer {
          /// Select a widget to add this entity to.
          public static var title: String { return L10n.tr("Localizable", "settings.widgets.select.footer.title", fallback: "Select a widget to add this entity to.") }
        }
        public enum ItemCount {
          /// %li items
          public static func title(_ p1: Int) -> String {
            return L10n.tr("Localizable", "settings.widgets.select.item_count.title", p1, fallback: "%li items")
          }
        }
      }
      public enum YourWidgets {
        /// Your widgets
        public static var title: String { return L10n.tr("Localizable", "settings.widgets.your_widgets.title", fallback: "Your widgets") }
      }
    }
  }
  public enum SettingsDetails {
    /// Learn more
    public static var learnMore: String { return L10n.tr("Localizable", "settings_details.learn_more", fallback: "Learn more") }
    public enum Actions {
      /// Actions are used in the Apple Watch app, App Icon Actions, the Today widget and CarPlay.
      public static var footer: String { return L10n.tr("Localizable", "settings_details.actions.footer", fallback: "Actions are used in the Apple Watch app, App Icon Actions, the Today widget and CarPlay.") }
      /// Actions
      public static var title: String { return L10n.tr("Localizable", "settings_details.actions.title", fallback: "Actions") }
      public enum ActionsSynced {
        /// No Synced Actions
        public static var empty: String { return L10n.tr("Localizable", "settings_details.actions.actions_synced.empty", fallback: "No Synced Actions") }
        /// Actions defined in .yaml are not editable on device.
        public static var footer: String { return L10n.tr("Localizable", "settings_details.actions.actions_synced.footer", fallback: "Actions defined in .yaml are not editable on device.") }
        /// Actions may be also defined in the .yaml configuration.
        public static var footerNoActions: String { return L10n.tr("Localizable", "settings_details.actions.actions_synced.footer_no_actions", fallback: "Actions may be also defined in the .yaml configuration.") }
        /// Synced Actions
        public static var header: String { return L10n.tr("Localizable", "settings_details.actions.actions_synced.header", fallback: "Synced Actions") }
      }
      public enum CarPlay {
        public enum Available {
          /// Show in CarPlay
          public static var title: String { return L10n.tr("Localizable", "settings_details.actions.carPlay.available.title", fallback: "Show in CarPlay") }
        }
      }
      public enum Learn {
        public enum Button {
          /// Introduction to iOS Actions
          public static var title: String { return L10n.tr("Localizable", "settings_details.actions.learn.button.title", fallback: "Introduction to iOS Actions") }
        }
      }
      public enum Scenes {
        /// Customize
        public static var customizeAction: String { return L10n.tr("Localizable", "settings_details.actions.scenes.customize_action", fallback: "Customize") }
        /// No Scenes
        public static var empty: String { return L10n.tr("Localizable", "settings_details.actions.scenes.empty", fallback: "No Scenes") }
        /// When enabled, Scenes display alongside actions. When performed, they trigger scene changes.
        public static var footer: String { return L10n.tr("Localizable", "settings_details.actions.scenes.footer", fallback: "When enabled, Scenes display alongside actions. When performed, they trigger scene changes.") }
        /// Select All
        public static var selectAll: String { return L10n.tr("Localizable", "settings_details.actions.scenes.select_all", fallback: "Select All") }
        /// Scene Actions
        public static var title: String { return L10n.tr("Localizable", "settings_details.actions.scenes.title", fallback: "Scene Actions") }
      }
      public enum ServerControlled {
        public enum Update {
          /// Update server Actions
          public static var title: String { return L10n.tr("Localizable", "settings_details.actions.server_controlled.update.title", fallback: "Update server Actions") }
        }
      }
      public enum UseCustomColors {
        /// Use custom colors
        public static var title: String { return L10n.tr("Localizable", "settings_details.actions.use_custom_colors.title", fallback: "Use custom colors") }
      }
      public enum Watch {
        public enum Available {
          /// Show in Watch
          public static var title: String { return L10n.tr("Localizable", "settings_details.actions.watch.available.title", fallback: "Show in Watch") }
        }
      }
    }
    public enum General {
      /// Basic App configuration, App Icon and web page settings.
      public static var body: String { return L10n.tr("Localizable", "settings_details.general.body", fallback: "Basic App configuration, App Icon and web page settings.") }
      /// General
      public static var title: String { return L10n.tr("Localizable", "settings_details.general.title", fallback: "General") }
      public enum AppIcon {
        /// App Icon
        public static var title: String { return L10n.tr("Localizable", "settings_details.general.app_icon.title", fallback: "App Icon") }
        public enum CurrentSelected {
          /// - Selected
          public static var title: String { return L10n.tr("Localizable", "settings_details.general.app_icon.current_selected.title", fallback: "- Selected") }
        }
        public enum Enum {
          /// Beta
          public static var beta: String { return L10n.tr("Localizable", "settings_details.general.app_icon.enum.beta", fallback: "Beta") }
          /// Black
          public static var black: String { return L10n.tr("Localizable", "settings_details.general.app_icon.enum.black", fallback: "Black") }
          /// Blue
          public static var blue: String { return L10n.tr("Localizable", "settings_details.general.app_icon.enum.blue", fallback: "Blue") }
          /// Caribbean Green
          public static var caribbeanGreen: String { return L10n.tr("Localizable", "settings_details.general.app_icon.enum.caribbean_green", fallback: "Caribbean Green") }
          /// Classic
          public static var classic: String { return L10n.tr("Localizable", "settings_details.general.app_icon.enum.classic", fallback: "Classic") }
          /// Cornflower Blue
          public static var cornflowerBlue: String { return L10n.tr("Localizable", "settings_details.general.app_icon.enum.cornflower_blue", fallback: "Cornflower Blue") }
          /// Crimson
          public static var crimson: String { return L10n.tr("Localizable", "settings_details.general.app_icon.enum.crimson", fallback: "Crimson") }
          /// Dev
          public static var dev: String { return L10n.tr("Localizable", "settings_details.general.app_icon.enum.dev", fallback: "Dev") }
          /// Electric Violet
          public static var electricViolet: String { return L10n.tr("Localizable", "settings_details.general.app_icon.enum.electric_violet", fallback: "Electric Violet") }
          /// Fire Orange
          public static var fireOrange: String { return L10n.tr("Localizable", "settings_details.general.app_icon.enum.fire_orange", fallback: "Fire Orange") }
          /// Green
          public static var green: String { return L10n.tr("Localizable", "settings_details.general.app_icon.enum.green", fallback: "Green") }
          /// Old Beta
          public static var oldBeta: String { return L10n.tr("Localizable", "settings_details.general.app_icon.enum.old_beta", fallback: "Old Beta") }
          /// Old Dev
          public static var oldDev: String { return L10n.tr("Localizable", "settings_details.general.app_icon.enum.old_dev", fallback: "Old Dev") }
          /// Old Release
          public static var oldRelease: String { return L10n.tr("Localizable", "settings_details.general.app_icon.enum.old_release", fallback: "Old Release") }
          /// Orange
          public static var orange: String { return L10n.tr("Localizable", "settings_details.general.app_icon.enum.orange", fallback: "Orange") }
          /// Pink
          public static var pink: String { return L10n.tr("Localizable", "settings_details.general.app_icon.enum.pink", fallback: "Pink") }
          /// Pride: Bi
          public static var prideBi: String { return L10n.tr("Localizable", "settings_details.general.app_icon.enum.pride_bi", fallback: "Pride: Bi") }
          /// Pride: Non Binary
          public static var prideNonBinary: String { return L10n.tr("Localizable", "settings_details.general.app_icon.enum.pride_non_binary", fallback: "Pride: Non Binary") }
          /// Pride: 8-Color
          public static var pridePoc: String { return L10n.tr("Localizable", "settings_details.general.app_icon.enum.pride_poc", fallback: "Pride: 8-Color") }
          /// Pride: Rainbow
          public static var prideRainbow: String { return L10n.tr("Localizable", "settings_details.general.app_icon.enum.pride_rainbow", fallback: "Pride: Rainbow") }
          /// Pride: Trans
          public static var prideTrans: String { return L10n.tr("Localizable", "settings_details.general.app_icon.enum.pride_trans", fallback: "Pride: Trans") }
          /// Purple
          public static var purple: String { return L10n.tr("Localizable", "settings_details.general.app_icon.enum.purple", fallback: "Purple") }
          /// Red
          public static var red: String { return L10n.tr("Localizable", "settings_details.general.app_icon.enum.red", fallback: "Red") }
          /// Release
          public static var release: String { return L10n.tr("Localizable", "settings_details.general.app_icon.enum.release", fallback: "Release") }
          /// White
          public static var white: String { return L10n.tr("Localizable", "settings_details.general.app_icon.enum.white", fallback: "White") }
        }
        public enum Explanation {
          /// Each icon has 3 variants (iOS 18+), default, dark and tinted to react according to the selected iOS home screen style. Some icons are the same in dark mode or handled automatically by iOS.
          public static var title: String { return L10n.tr("Localizable", "settings_details.general.app_icon.explanation.title", fallback: "Each icon has 3 variants (iOS 18+), default, dark and tinted to react according to the selected iOS home screen style. Some icons are the same in dark mode or handled automatically by iOS.") }
        }
      }
      public enum DeviceName {
        /// Device Name
        public static var title: String { return L10n.tr("Localizable", "settings_details.general.device_name.title", fallback: "Device Name") }
      }
      public enum FullScreen {
        /// Full Screen
        public static var title: String { return L10n.tr("Localizable", "settings_details.general.full_screen.title", fallback: "Full Screen") }
      }
      public enum LaunchOnLogin {
        /// Launch App on Login
        public static var title: String { return L10n.tr("Localizable", "settings_details.general.launch_on_login.title", fallback: "Launch App on Login") }
      }
      public enum Links {
        /// Links
        public static var title: String { return L10n.tr("Localizable", "settings_details.general.links.title", fallback: "Links") }
      }
      public enum MenuBarText {
        /// Menu Bar Text
        public static var title: String { return L10n.tr("Localizable", "settings_details.general.menu_bar_text.title", fallback: "Menu Bar Text") }
      }
      public enum OpenInBrowser {
        /// Google Chrome
        public static var chrome: String { return L10n.tr("Localizable", "settings_details.general.open_in_browser.chrome", fallback: "Google Chrome") }
        /// System Default
        public static var `default`: String { return L10n.tr("Localizable", "settings_details.general.open_in_browser.default", fallback: "System Default") }
        /// Mozilla Firefox
        public static var firefox: String { return L10n.tr("Localizable", "settings_details.general.open_in_browser.firefox", fallback: "Mozilla Firefox") }
        /// Mozilla Firefox Focus
        public static var firefoxFocus: String { return L10n.tr("Localizable", "settings_details.general.open_in_browser.firefoxFocus", fallback: "Mozilla Firefox Focus") }
        /// Mozilla Firefox Klar
        public static var firefoxKlar: String { return L10n.tr("Localizable", "settings_details.general.open_in_browser.firefoxKlar", fallback: "Mozilla Firefox Klar") }
        /// Apple Safari
        public static var safari: String { return L10n.tr("Localizable", "settings_details.general.open_in_browser.safari", fallback: "Apple Safari") }
        /// Apple Safari (in app)
        public static var safariInApp: String { return L10n.tr("Localizable", "settings_details.general.open_in_browser.safari_in_app", fallback: "Apple Safari (in app)") }
        /// Open Links In
        public static var title: String { return L10n.tr("Localizable", "settings_details.general.open_in_browser.title", fallback: "Open Links In") }
      }
      public enum OpenInPrivateTab {
        /// Open in Private Tab
        public static var title: String { return L10n.tr("Localizable", "settings_details.general.open_in_private_tab.title", fallback: "Open in Private Tab") }
      }
      public enum Page {
        /// Page
        public static var title: String { return L10n.tr("Localizable", "settings_details.general.page.title", fallback: "Page") }
      }
      public enum PageZoom {
        /// %@ (Default)
        public static func `default`(_ p1: Any) -> String {
          return L10n.tr("Localizable", "settings_details.general.page_zoom.default", String(describing: p1), fallback: "%@ (Default)")
        }
        /// Page Zoom
        public static var title: String { return L10n.tr("Localizable", "settings_details.general.page_zoom.title", fallback: "Page Zoom") }
      }
      public enum PinchToZoom {
        /// Pinch to Zoom
        public static var title: String { return L10n.tr("Localizable", "settings_details.general.pinch_to_zoom.title", fallback: "Pinch to Zoom") }
      }
      public enum RefreshAfterInactive {
        /// Refresh After 5 Min Inactive
        public static var title: String { return L10n.tr("Localizable", "settings_details.general.refresh_after_inactive.title", fallback: "Refresh After 5 Min Inactive") }
      }
      public enum Restoration {
        /// Remember Last Page
        public static var title: String { return L10n.tr("Localizable", "settings_details.general.restoration.title", fallback: "Remember Last Page") }
      }
      public enum Visibility {
        /// Show App In…
        public static var title: String { return L10n.tr("Localizable", "settings_details.general.visibility.title", fallback: "Show App In…") }
        public enum Options {
          /// Dock
          public static var dock: String { return L10n.tr("Localizable", "settings_details.general.visibility.options.dock", fallback: "Dock") }
          /// Dock and Menu Bar
          public static var dockAndMenuBar: String { return L10n.tr("Localizable", "settings_details.general.visibility.options.dock_and_menu_bar", fallback: "Dock and Menu Bar") }
          /// Menu Bar
          public static var menuBar: String { return L10n.tr("Localizable", "settings_details.general.visibility.options.menu_bar", fallback: "Menu Bar") }
        }
      }
    }
    public enum Http {
      public enum Warning {
        /// Unencrypted connections expose your credentials and personal data to potential interception. Always use HTTPS for remote access to protect your privacy and security.
        public static var message: String { return L10n.tr("Localizable", "settings_details.http.warning.message", fallback: "Unencrypted connections expose your credentials and personal data to potential interception. Always use HTTPS for remote access to protect your privacy and security.") }
        /// Security Warning
        public static var title: String { return L10n.tr("Localizable", "settings_details.http.warning.title", fallback: "Security Warning") }
      }
    }
    public enum LegacyActions {
      /// (Legacy) iOS Actions
      public static var title: String { return L10n.tr("Localizable", "settings_details.legacy_actions.title", fallback: "(Legacy) iOS Actions") }
    }
    public enum Location {
      /// Location
      public static var title: String { return L10n.tr("Localizable", "settings_details.location.title", fallback: "Location") }
      /// Update Location
      public static var updateLocation: String { return L10n.tr("Localizable", "settings_details.location.update_location", fallback: "Update Location") }
      public enum BackgroundRefresh {
        /// Disabled
        public static var disabled: String { return L10n.tr("Localizable", "settings_details.location.background_refresh.disabled", fallback: "Disabled") }
        /// Enabled
        public static var enabled: String { return L10n.tr("Localizable", "settings_details.location.background_refresh.enabled", fallback: "Enabled") }
        /// Background Refresh
        public static var title: String { return L10n.tr("Localizable", "settings_details.location.background_refresh.title", fallback: "Background Refresh") }
      }
      public enum FocusPermission {
        /// Denied
        public static var denied: String { return L10n.tr("Localizable", "settings_details.location.focus_permission.denied", fallback: "Denied") }
        /// Enabled
        public static var enabled: String { return L10n.tr("Localizable", "settings_details.location.focus_permission.enabled", fallback: "Enabled") }
        /// Disabled
        public static var needsRequest: String { return L10n.tr("Localizable", "settings_details.location.focus_permission.needs_request", fallback: "Disabled") }
        /// Restricted
        public static var restricted: String { return L10n.tr("Localizable", "settings_details.location.focus_permission.restricted", fallback: "Restricted") }
      }
      public enum LocationAccuracy {
        /// Full
        public static var full: String { return L10n.tr("Localizable", "settings_details.location.location_accuracy.full", fallback: "Full") }
        /// Reduced
        public static var reduced: String { return L10n.tr("Localizable", "settings_details.location.location_accuracy.reduced", fallback: "Reduced") }
        /// Location Accuracy
        public static var title: String { return L10n.tr("Localizable", "settings_details.location.location_accuracy.title", fallback: "Location Accuracy") }
      }
      public enum LocationPermission {
        /// Always
        public static var always: String { return L10n.tr("Localizable", "settings_details.location.location_permission.always", fallback: "Always") }
        /// Disabled
        public static var needsRequest: String { return L10n.tr("Localizable", "settings_details.location.location_permission.needs_request", fallback: "Disabled") }
        /// Never
        public static var never: String { return L10n.tr("Localizable", "settings_details.location.location_permission.never", fallback: "Never") }
        /// Location Permission
        public static var title: String { return L10n.tr("Localizable", "settings_details.location.location_permission.title", fallback: "Location Permission") }
        /// While In Use
        public static var whileInUse: String { return L10n.tr("Localizable", "settings_details.location.location_permission.while_in_use", fallback: "While In Use") }
      }
      public enum MotionPermission {
        /// Denied
        public static var denied: String { return L10n.tr("Localizable", "settings_details.location.motion_permission.denied", fallback: "Denied") }
        /// Enabled
        public static var enabled: String { return L10n.tr("Localizable", "settings_details.location.motion_permission.enabled", fallback: "Enabled") }
        /// Disabled
        public static var needsRequest: String { return L10n.tr("Localizable", "settings_details.location.motion_permission.needs_request", fallback: "Disabled") }
        /// Restricted
        public static var restricted: String { return L10n.tr("Localizable", "settings_details.location.motion_permission.restricted", fallback: "Restricted") }
        /// Motion Permission
        public static var title: String { return L10n.tr("Localizable", "settings_details.location.motion_permission.title", fallback: "Motion Permission") }
      }
      public enum Notifications {
        /// Location Notifications
        public static var header: String { return L10n.tr("Localizable", "settings_details.location.notifications.header", fallback: "Location Notifications") }
        public enum BackgroundFetch {
          /// Background Fetch Notifications
          public static var title: String { return L10n.tr("Localizable", "settings_details.location.notifications.background_fetch.title", fallback: "Background Fetch Notifications") }
        }
        public enum BeaconEnter {
          /// Enter Zone via iBeacon Notifications
          public static var title: String { return L10n.tr("Localizable", "settings_details.location.notifications.beacon_enter.title", fallback: "Enter Zone via iBeacon Notifications") }
        }
        public enum BeaconExit {
          /// Exit Zone via iBeacon Notifications
          public static var title: String { return L10n.tr("Localizable", "settings_details.location.notifications.beacon_exit.title", fallback: "Exit Zone via iBeacon Notifications") }
        }
        public enum Enter {
          /// Enter Zone Notifications
          public static var title: String { return L10n.tr("Localizable", "settings_details.location.notifications.enter.title", fallback: "Enter Zone Notifications") }
        }
        public enum Exit {
          /// Exit Zone Notifications
          public static var title: String { return L10n.tr("Localizable", "settings_details.location.notifications.exit.title", fallback: "Exit Zone Notifications") }
        }
        public enum LocationChange {
          /// Significant Location Change Notifications
          public static var title: String { return L10n.tr("Localizable", "settings_details.location.notifications.location_change.title", fallback: "Significant Location Change Notifications") }
        }
        public enum PushNotification {
          /// Pushed Location Request Notifications
          public static var title: String { return L10n.tr("Localizable", "settings_details.location.notifications.push_notification.title", fallback: "Pushed Location Request Notifications") }
        }
        public enum UrlScheme {
          /// URL Scheme Location Notifications
          public static var title: String { return L10n.tr("Localizable", "settings_details.location.notifications.url_scheme.title", fallback: "URL Scheme Location Notifications") }
        }
        public enum XCallbackUrl {
          /// X-Callback-URL Location Notifications
          public static var title: String { return L10n.tr("Localizable", "settings_details.location.notifications.x_callback_url.title", fallback: "X-Callback-URL Location Notifications") }
        }
      }
      public enum Updates {
        /// Manual location updates can always be triggered
        public static var footer: String { return L10n.tr("Localizable", "settings_details.location.updates.footer", fallback: "Manual location updates can always be triggered") }
        /// Update sources
        public static var header: String { return L10n.tr("Localizable", "settings_details.location.updates.header", fallback: "Update sources") }
        public enum Background {
          /// Background fetch
          public static var title: String { return L10n.tr("Localizable", "settings_details.location.updates.background.title", fallback: "Background fetch") }
        }
        public enum Notification {
          /// Push notification request
          public static var title: String { return L10n.tr("Localizable", "settings_details.location.updates.notification.title", fallback: "Push notification request") }
        }
        public enum Significant {
          /// Significant location change
          public static var title: String { return L10n.tr("Localizable", "settings_details.location.updates.significant.title", fallback: "Significant location change") }
        }
        public enum Zone {
          /// Zone enter/exit
          public static var title: String { return L10n.tr("Localizable", "settings_details.location.updates.zone.title", fallback: "Zone enter/exit") }
        }
      }
      public enum Zones {
        /// To disable location tracking add track_ios: false to each zones settings or under customize.
        public static var footer: String { return L10n.tr("Localizable", "settings_details.location.zones.footer", fallback: "To disable location tracking add track_ios: false to each zones settings or under customize.") }
        public enum Beacon {
          public enum PropNotSet {
            /// Not set
            public static var value: String { return L10n.tr("Localizable", "settings_details.location.zones.beacon.prop_not_set.value", fallback: "Not set") }
          }
        }
        public enum BeaconMajor {
          /// iBeacon Major
          public static var title: String { return L10n.tr("Localizable", "settings_details.location.zones.beacon_major.title", fallback: "iBeacon Major") }
        }
        public enum BeaconMinor {
          /// iBeacon Minor
          public static var title: String { return L10n.tr("Localizable", "settings_details.location.zones.beacon_minor.title", fallback: "iBeacon Minor") }
        }
        public enum BeaconUuid {
          /// iBeacon UUID
          public static var title: String { return L10n.tr("Localizable", "settings_details.location.zones.beacon_uuid.title", fallback: "iBeacon UUID") }
        }
        public enum EnterExitTracked {
          /// Enter/exit tracked
          public static var title: String { return L10n.tr("Localizable", "settings_details.location.zones.enter_exit_tracked.title", fallback: "Enter/exit tracked") }
        }
        public enum Location {
          /// Location
          public static var title: String { return L10n.tr("Localizable", "settings_details.location.zones.location.title", fallback: "Location") }
        }
        public enum Radius {
          /// %li m
          public static func label(_ p1: Int) -> String {
            return L10n.tr("Localizable", "settings_details.location.zones.radius.label", p1, fallback: "%li m")
          }
          /// Radius
          public static var title: String { return L10n.tr("Localizable", "settings_details.location.zones.radius.title", fallback: "Radius") }
        }
      }
    }
    public enum MacNativeFeatures {
      /// This will open Safari instead of the App webview, while keeping the native features such as widgets working.
      public static var footer: String { return L10n.tr("Localizable", "settings_details.mac_native_features.footer", fallback: "This will open Safari instead of the App webview, while keeping the native features such as widgets working.") }
      /// Native Features Only (Experimental)
      public static var title: String { return L10n.tr("Localizable", "settings_details.mac_native_features.title", fallback: "Native Features Only (Experimental)") }
    }
    public enum Notifications {
      /// Use the mobile_app notify service to send notifications to your device.
      public static var info: String { return L10n.tr("Localizable", "settings_details.notifications.info", fallback: "Use the mobile_app notify service to send notifications to your device.") }
      /// Notifications
      public static var title: String { return L10n.tr("Localizable", "settings_details.notifications.title", fallback: "Notifications") }
      public enum BadgeSection {
        public enum AutomaticSetting {
          /// Resets the badge to 0 every time you launch the app.
          public static var description: String { return L10n.tr("Localizable", "settings_details.notifications.badge_section.automatic_setting.description", fallback: "Resets the badge to 0 every time you launch the app.") }
          /// Automatically
          public static var title: String { return L10n.tr("Localizable", "settings_details.notifications.badge_section.automatic_setting.title", fallback: "Automatically") }
        }
        public enum Button {
          /// Reset Badge
          public static var title: String { return L10n.tr("Localizable", "settings_details.notifications.badge_section.button.title", fallback: "Reset Badge") }
        }
      }
      public enum Categories {
        /// Categories are no longer required for actionable notifications and will be removed in a future release.
        public static var deprecatedNote: String { return L10n.tr("Localizable", "settings_details.notifications.categories.deprecated_note", fallback: "Categories are no longer required for actionable notifications and will be removed in a future release.") }
        /// Categories
        public static var header: String { return L10n.tr("Localizable", "settings_details.notifications.categories.header", fallback: "Categories") }
      }
      public enum CategoriesSynced {
        /// No Synced Categories
        public static var empty: String { return L10n.tr("Localizable", "settings_details.notifications.categories_synced.empty", fallback: "No Synced Categories") }
        /// Categories defined in .yaml are not editable on device.
        public static var footer: String { return L10n.tr("Localizable", "settings_details.notifications.categories_synced.footer", fallback: "Categories defined in .yaml are not editable on device.") }
        /// Categories may be also defined in the .yaml configuration.
        public static var footerNoCategories: String { return L10n.tr("Localizable", "settings_details.notifications.categories_synced.footer_no_categories", fallback: "Categories may be also defined in the .yaml configuration.") }
        /// Synced Categories
        public static var header: String { return L10n.tr("Localizable", "settings_details.notifications.categories_synced.header", fallback: "Synced Categories") }
      }
      public enum LocalPush {
        /// Local Push
        public static var title: String { return L10n.tr("Localizable", "settings_details.notifications.local_push.title", fallback: "Local Push") }
        public enum Status {
          /// Available (%1$@)
          public static func available(_ p1: Any) -> String {
            return L10n.tr("Localizable", "settings_details.notifications.local_push.status.available", String(describing: p1), fallback: "Available (%1$@)")
          }
          /// Disabled
          public static var disabled: String { return L10n.tr("Localizable", "settings_details.notifications.local_push.status.disabled", fallback: "Disabled") }
          /// Establishing
          public static var establishing: String { return L10n.tr("Localizable", "settings_details.notifications.local_push.status.establishing", fallback: "Establishing") }
          /// Unavailable
          public static var unavailable: String { return L10n.tr("Localizable", "settings_details.notifications.local_push.status.unavailable", fallback: "Unavailable") }
          /// Unsupported
          public static var unsupported: String { return L10n.tr("Localizable", "settings_details.notifications.local_push.status.unsupported", fallback: "Unsupported") }
        }
      }
      public enum NewCategory {
        /// New Category
        public static var title: String { return L10n.tr("Localizable", "settings_details.notifications.new_category.title", fallback: "New Category") }
      }
      public enum Permission {
        /// Denied
        public static var disabled: String { return L10n.tr("Localizable", "settings_details.notifications.permission.disabled", fallback: "Denied") }
        /// Enabled
        public static var enabled: String { return L10n.tr("Localizable", "settings_details.notifications.permission.enabled", fallback: "Enabled") }
        /// Disabled
        public static var needsRequest: String { return L10n.tr("Localizable", "settings_details.notifications.permission.needs_request", fallback: "Disabled") }
        /// Permission
        public static var title: String { return L10n.tr("Localizable", "settings_details.notifications.permission.title", fallback: "Permission") }
      }
      public enum PromptToOpenUrls {
        /// Confirm before opening URL
        public static var title: String { return L10n.tr("Localizable", "settings_details.notifications.prompt_to_open_urls.title", fallback: "Confirm before opening URL") }
      }
      public enum PushIdSection {
        /// Push ID
        public static var header: String { return L10n.tr("Localizable", "settings_details.notifications.push_id_section.header", fallback: "Push ID") }
        /// Not registered for remote notifications
        public static var notRegistered: String { return L10n.tr("Localizable", "settings_details.notifications.push_id_section.not_registered", fallback: "Not registered for remote notifications") }
      }
      public enum RateLimits {
        /// Attempts
        public static var attempts: String { return L10n.tr("Localizable", "settings_details.notifications.rate_limits.attempts", fallback: "Attempts") }
        /// Delivered
        public static var delivered: String { return L10n.tr("Localizable", "settings_details.notifications.rate_limits.delivered", fallback: "Delivered") }
        /// Errors
        public static var errors: String { return L10n.tr("Localizable", "settings_details.notifications.rate_limits.errors", fallback: "Errors") }
        /// You are allowed 300 push notifications per 24 hours. Rate limits reset at midnight Universal Coordinated Time (UTC).
        public static var footer: String { return L10n.tr("Localizable", "settings_details.notifications.rate_limits.footer", fallback: "You are allowed 300 push notifications per 24 hours. Rate limits reset at midnight Universal Coordinated Time (UTC).") }
        /// You are allowed %u push notifications per 24 hours. Rate limits reset at midnight Universal Coordinated Time (UTC).
        public static func footerWithParam(_ p1: Int) -> String {
          return L10n.tr("Localizable", "settings_details.notifications.rate_limits.footer_with_param", p1, fallback: "You are allowed %u push notifications per 24 hours. Rate limits reset at midnight Universal Coordinated Time (UTC).")
        }
        /// Rate Limits
        public static var header: String { return L10n.tr("Localizable", "settings_details.notifications.rate_limits.header", fallback: "Rate Limits") }
        /// Resets In
        public static var resetsIn: String { return L10n.tr("Localizable", "settings_details.notifications.rate_limits.resets_in", fallback: "Resets In") }
        /// Total
        public static var total: String { return L10n.tr("Localizable", "settings_details.notifications.rate_limits.total", fallback: "Total") }
      }
      public enum Sounds {
        /// Bundled
        public static var bundled: String { return L10n.tr("Localizable", "settings_details.notifications.sounds.bundled", fallback: "Bundled") }
        /// Built-in, system, or custom sounds can be used with your notifications.
        public static var footer: String { return L10n.tr("Localizable", "settings_details.notifications.sounds.footer", fallback: "Built-in, system, or custom sounds can be used with your notifications.") }
        /// Import custom sound
        public static var importCustom: String { return L10n.tr("Localizable", "settings_details.notifications.sounds.import_custom", fallback: "Import custom sound") }
        /// Import sounds from iTunes File Sharing
        public static var importFileSharing: String { return L10n.tr("Localizable", "settings_details.notifications.sounds.import_file_sharing", fallback: "Import sounds from iTunes File Sharing") }
        /// Add custom sounds to your Sounds folder to use them in notifications. Use their filename as the sound value in the service call.
        public static var importMacInstructions: String { return L10n.tr("Localizable", "settings_details.notifications.sounds.import_mac_instructions", fallback: "Add custom sounds to your Sounds folder to use them in notifications. Use their filename as the sound value in the service call.") }
        /// Open Folder in Finder
        public static var importMacOpenFolder: String { return L10n.tr("Localizable", "settings_details.notifications.sounds.import_mac_open_folder", fallback: "Open Folder in Finder") }
        /// Import system sounds
        public static var importSystem: String { return L10n.tr("Localizable", "settings_details.notifications.sounds.import_system", fallback: "Import system sounds") }
        /// Imported
        public static var imported: String { return L10n.tr("Localizable", "settings_details.notifications.sounds.imported", fallback: "Imported") }
        /// System
        public static var system: String { return L10n.tr("Localizable", "settings_details.notifications.sounds.system", fallback: "System") }
        /// Sounds
        public static var title: String { return L10n.tr("Localizable", "settings_details.notifications.sounds.title", fallback: "Sounds") }
        public enum Error {
          /// Can't build ~/Library/Sounds path: %@
          public static func cantBuildLibrarySoundsPath(_ p1: Any) -> String {
            return L10n.tr("Localizable", "settings_details.notifications.sounds.error.cant_build_library_sounds_path", String(describing: p1), fallback: "Can't build ~/Library/Sounds path: %@")
          }
          /// Can't list directory contents: %@
          public static func cantGetDirectoryContents(_ p1: Any) -> String {
            return L10n.tr("Localizable", "settings_details.notifications.sounds.error.cant_get_directory_contents", String(describing: p1), fallback: "Can't list directory contents: %@")
          }
          /// Can't access file sharing sounds directory: %@
          public static func cantGetFileSharingPath(_ p1: Any) -> String {
            return L10n.tr("Localizable", "settings_details.notifications.sounds.error.cant_get_file_sharing_path", String(describing: p1), fallback: "Can't access file sharing sounds directory: %@")
          }
          /// Failed to convert audio to PCM 32 bit 48khz: %@
          public static func conversionFailed(_ p1: Any) -> String {
            return L10n.tr("Localizable", "settings_details.notifications.sounds.error.conversion_failed", String(describing: p1), fallback: "Failed to convert audio to PCM 32 bit 48khz: %@")
          }
          /// Failed to copy file: %@
          public static func copyError(_ p1: Any) -> String {
            return L10n.tr("Localizable", "settings_details.notifications.sounds.error.copy_error", String(describing: p1), fallback: "Failed to copy file: %@")
          }
          /// Failed to delete file: %@
          public static func deleteError(_ p1: Any) -> String {
            return L10n.tr("Localizable", "settings_details.notifications.sounds.error.delete_error", String(describing: p1), fallback: "Failed to delete file: %@")
          }
        }
        public enum ImportedAlert {
          /// %li sounds were imported. Please restart your phone to complete the import.
          public static func message(_ p1: Int) -> String {
            return L10n.tr("Localizable", "settings_details.notifications.sounds.imported_alert.message", p1, fallback: "%li sounds were imported. Please restart your phone to complete the import.")
          }
          /// Sounds Imported
          public static var title: String { return L10n.tr("Localizable", "settings_details.notifications.sounds.imported_alert.title", fallback: "Sounds Imported") }
        }
      }
    }
    public enum Privacy {
      /// You are in control of your data.
      public static var body: String { return L10n.tr("Localizable", "settings_details.privacy.body", fallback: "You are in control of your data.") }
      /// Privacy
      public static var title: String { return L10n.tr("Localizable", "settings_details.privacy.title", fallback: "Privacy") }
      public enum Alerts {
        /// Allows checking for important alerts like security vulnerabilities.
        public static var description: String { return L10n.tr("Localizable", "settings_details.privacy.alerts.description", fallback: "Allows checking for important alerts like security vulnerabilities.") }
        /// Alerts
        public static var title: String { return L10n.tr("Localizable", "settings_details.privacy.alerts.title", fallback: "Alerts") }
      }
      public enum Analytics {
        /// Allows collection of basic information about your device and interactions with the app. No user identifiable data is shared, including your Home Assistant URLs and tokens. You must restart the app for changes to this setting to take effect.
        public static var genericDescription: String { return L10n.tr("Localizable", "settings_details.privacy.analytics.generic_description", fallback: "Allows collection of basic information about your device and interactions with the app. No user identifiable data is shared, including your Home Assistant URLs and tokens. You must restart the app for changes to this setting to take effect.") }
        /// Analytics
        public static var genericTitle: String { return L10n.tr("Localizable", "settings_details.privacy.analytics.generic_title", fallback: "Analytics") }
      }
      public enum CrashReporting {
        /// Allows for deeper tracking of crashes and other errors in the app, leading to faster fixes being published. No user identifiable information is sent, other than basic device information. You must restart the app for changes to this setting to take effect.
        public static var description: String { return L10n.tr("Localizable", "settings_details.privacy.crash_reporting.description", fallback: "Allows for deeper tracking of crashes and other errors in the app, leading to faster fixes being published. No user identifiable information is sent, other than basic device information. You must restart the app for changes to this setting to take effect.") }
        /// Crash Reporting
        public static var title: String { return L10n.tr("Localizable", "settings_details.privacy.crash_reporting.title", fallback: "Crash Reporting") }
      }
      public enum Messaging {
        /// Firebase Cloud Messaging must be enabled for push notifications to function.
        public static var description: String { return L10n.tr("Localizable", "settings_details.privacy.messaging.description", fallback: "Firebase Cloud Messaging must be enabled for push notifications to function.") }
        /// Firebase Cloud Messaging
        public static var title: String { return L10n.tr("Localizable", "settings_details.privacy.messaging.title", fallback: "Firebase Cloud Messaging") }
      }
    }
    public enum Thread {
      /// Thread
      public static var title: String { return L10n.tr("Localizable", "settings_details.thread.title", fallback: "Thread") }
      public enum DeleteCredential {
        public enum Confirmation {
          /// Are you sure you want to delete this credential from your Apple Keychain? This can't be reverted and should only be executed if you know what you're doing.
          public static var title: String { return L10n.tr("Localizable", "settings_details.thread.delete_credential.confirmation.title", fallback: "Are you sure you want to delete this credential from your Apple Keychain? This can't be reverted and should only be executed if you know what you're doing.") }
        }
      }
    }
    public enum Updates {
      public enum CheckForUpdates {
        /// Include Beta Releases
        public static var includeBetas: String { return L10n.tr("Localizable", "settings_details.updates.check_for_updates.include_betas", fallback: "Include Beta Releases") }
        /// Automatically Check for Updates
        public static var title: String { return L10n.tr("Localizable", "settings_details.updates.check_for_updates.title", fallback: "Automatically Check for Updates") }
      }
    }
    public enum Watch {
      /// Apple Watch
      public static var title: String { return L10n.tr("Localizable", "settings_details.watch.title", fallback: "Apple Watch") }
    }
    public enum Widgets {
      public enum ReloadAll {
        /// This will reload all widgets timelines, use this in case your widgets are stuck in a blank state or not updating for some reason.
        public static var description: String { return L10n.tr("Localizable", "settings_details.widgets.reload_all.description", fallback: "This will reload all widgets timelines, use this in case your widgets are stuck in a blank state or not updating for some reason.") }
        /// Reload all widgets
        public static var title: String { return L10n.tr("Localizable", "settings_details.widgets.reload_all.title", fallback: "Reload all widgets") }
      }
    }
  }
  public enum SettingsSensors {
    /// Decide which of your device sensors you want to share with Home Assistant.
    public static var body: String { return L10n.tr("Localizable", "settings_sensors.body", fallback: "Decide which of your device sensors you want to share with Home Assistant.") }
    /// Disabled
    public static var disabledStateReplacement: String { return L10n.tr("Localizable", "settings_sensors.disabled_state_replacement", fallback: "Disabled") }
    /// Sensors
    public static var title: String { return L10n.tr("Localizable", "settings_sensors.title", fallback: "Sensors") }
    public enum Detail {
      /// Attributes
      public static var attributes: String { return L10n.tr("Localizable", "settings_sensors.detail.attributes", fallback: "Attributes") }
      /// Device Class
      public static var deviceClass: String { return L10n.tr("Localizable", "settings_sensors.detail.device_class", fallback: "Device Class") }
      /// Enabled
      public static var enabled: String { return L10n.tr("Localizable", "settings_sensors.detail.enabled", fallback: "Enabled") }
      /// Icon
      public static var icon: String { return L10n.tr("Localizable", "settings_sensors.detail.icon", fallback: "Icon") }
      /// State
      public static var state: String { return L10n.tr("Localizable", "settings_sensors.detail.state", fallback: "State") }
    }
    public enum FocusPermission {
      /// Focus Permission
      public static var title: String { return L10n.tr("Localizable", "settings_sensors.focus_permission.title", fallback: "Focus Permission") }
    }
    public enum LastUpdated {
      /// Last Updated %@
      public static func footer(_ p1: Any) -> String {
        return L10n.tr("Localizable", "settings_sensors.last_updated.footer", String(describing: p1), fallback: "Last Updated %@")
      }
      /// Last Updated
      public static var `prefix`: String { return L10n.tr("Localizable", "settings_sensors.last_updated.prefix", fallback: "Last Updated") }
    }
    public enum LoadingError {
      /// Failed to load sensors
      public static var title: String { return L10n.tr("Localizable", "settings_sensors.loading_error.title", fallback: "Failed to load sensors") }
    }
    public enum PeriodicUpdate {
      /// When enabled, these sensors will update with this frequency while the app is open in the foreground.
      public static var description: String { return L10n.tr("Localizable", "settings_sensors.periodic_update.description", fallback: "When enabled, these sensors will update with this frequency while the app is open in the foreground.") }
      /// When enabled, these sensors will update with this frequency while the app is open. Some sensors will update automatically more often.
      public static var descriptionMac: String { return L10n.tr("Localizable", "settings_sensors.periodic_update.description_mac", fallback: "When enabled, these sensors will update with this frequency while the app is open. Some sensors will update automatically more often.") }
      /// Off
      public static var off: String { return L10n.tr("Localizable", "settings_sensors.periodic_update.off", fallback: "Off") }
      /// Periodic Update
      public static var title: String { return L10n.tr("Localizable", "settings_sensors.periodic_update.title", fallback: "Periodic Update") }
    }
    public enum Permissions {
      /// Permissions
      public static var header: String { return L10n.tr("Localizable", "settings_sensors.permissions.header", fallback: "Permissions") }
    }
    public enum Sensors {
      /// Enable all sensors
      public static var enableAll: String { return L10n.tr("Localizable", "settings_sensors.sensors.enable_all", fallback: "Enable all sensors") }
      /// Sensors
      public static var header: String { return L10n.tr("Localizable", "settings_sensors.sensors.header", fallback: "Sensors") }
    }
    public enum Settings {
      /// Changes will be applied on the next update.
      public static var footer: String { return L10n.tr("Localizable", "settings_sensors.settings.footer", fallback: "Changes will be applied on the next update.") }
      /// Settings
      public static var header: String { return L10n.tr("Localizable", "settings_sensors.settings.header", fallback: "Settings") }
    }
  }
  public enum ShareExtension {
    /// 'entered' in event
    public static var enteredPlaceholder: String { return L10n.tr("Localizable", "share_extension.entered_placeholder", fallback: "'entered' in event") }
    public enum Error {
      /// Couldn't Send
      public static var title: String { return L10n.tr("Localizable", "share_extension.error.title", fallback: "Couldn't Send") }
    }
  }
  public enum ShortcutItem {
    public enum OpenSettings {
      /// Open Settings
      public static var title: String { return L10n.tr("Localizable", "shortcut_item.open_settings.title", fallback: "Open Settings") }
    }
  }
  public enum Thread {
    public enum ActiveOperationalDataSet {
      /// Active operational data set
      public static var title: String { return L10n.tr("Localizable", "thread.active_operational_data_set.title", fallback: "Active operational data set") }
    }
    public enum BorderAgentId {
      /// Border Agent ID
      public static var title: String { return L10n.tr("Localizable", "thread.border_agent_id.title", fallback: "Border Agent ID") }
    }
    public enum Credentials {
      public enum ShareCredentials {
        /// Make sure your are logged in with your iCloud account which is owner of a Home in Apple Home.
        public static var noCredentialsMessage: String { return L10n.tr("Localizable", "thread.credentials.share_credentials.no_credentials_message", fallback: "Make sure your are logged in with your iCloud account which is owner of a Home in Apple Home.") }
        /// You don't have credentials to share
        public static var noCredentialsTitle: String { return L10n.tr("Localizable", "thread.credentials.share_credentials.no_credentials_title", fallback: "You don't have credentials to share") }
      }
    }
    public enum ExtendedPanId {
      /// Extended PAN ID
      public static var title: String { return L10n.tr("Localizable", "thread.extended_pan_id.title", fallback: "Extended PAN ID") }
    }
    public enum Management {
      /// Thread Credentials
      public static var title: String { return L10n.tr("Localizable", "thread.management.title", fallback: "Thread Credentials") }
    }
    public enum NetworkKey {
      /// Network Key
      public static var title: String { return L10n.tr("Localizable", "thread.network_key.title", fallback: "Network Key") }
    }
    public enum SaveCredential {
      public enum Fail {
        public enum Alert {
          /// Failed to save thread network credential.
          public static var message: String { return L10n.tr("Localizable", "thread.save_credential.fail.alert.message", fallback: "Failed to save thread network credential.") }
          /// Failed to save thread network credential, error: %@
          public static func title(_ p1: Any) -> String {
            return L10n.tr("Localizable", "thread.save_credential.fail.alert.title", String(describing: p1), fallback: "Failed to save thread network credential, error: %@")
          }
        }
        public enum Continue {
          /// Continue
          public static var button: String { return L10n.tr("Localizable", "thread.save_credential.fail.continue.button", fallback: "Continue") }
        }
      }
    }
    public enum StoreInKeychain {
      public enum Error {
        /// Failed to store thread credential in keychain, error: %@
        public static func message(_ p1: Any) -> String {
          return L10n.tr("Localizable", "thread.store_in_keychain.error.message", String(describing: p1), fallback: "Failed to store thread credential in keychain, error: %@")
        }
        /// Operation failed
        public static var title: String { return L10n.tr("Localizable", "thread.store_in_keychain.error.title", fallback: "Operation failed") }
        public enum Generic {
          /// Failed to store thread credential in keychain, check logs for more information.
          public static var body: String { return L10n.tr("Localizable", "thread.store_in_keychain.error.generic.body", fallback: "Failed to store thread credential in keychain, check logs for more information.") }
        }
        public enum HexadecimalConversion {
          /// Failed to convert input to hexadecimal while storing thread credential in keychain
          public static var body: String { return L10n.tr("Localizable", "thread.store_in_keychain.error.hexadecimal_conversion.body", fallback: "Failed to convert input to hexadecimal while storing thread credential in keychain") }
        }
      }
    }
    public enum TransterToApple {
      /// Transfer to Apple Keychain
      public static var title: String { return L10n.tr("Localizable", "thread.transter_to_apple.title", fallback: "Transfer to Apple Keychain") }
    }
    public enum TransterToHomeassistant {
      /// Transfer to Home Assistant
      public static var title: String { return L10n.tr("Localizable", "thread.transter_to_homeassistant.title", fallback: "Transfer to Home Assistant") }
    }
  }
  public enum TokenError {
    /// Connection failed.
    public static var connectionFailed: String { return L10n.tr("Localizable", "token_error.connection_failed", fallback: "Connection failed.") }
    /// Token is expired.
    public static var expired: String { return L10n.tr("Localizable", "token_error.expired", fallback: "Token is expired.") }
    /// Token is unavailable.
    public static var tokenUnavailable: String { return L10n.tr("Localizable", "token_error.token_unavailable", fallback: "Token is unavailable.") }
  }
  public enum Unauthenticated {
    public enum Message {
      /// This could be temporary if you are behind a proxy or network restriction, otherwise if it persists remove your server and add it back in.
      public static var body: String { return L10n.tr("Localizable", "unauthenticated.message.body", fallback: "This could be temporary if you are behind a proxy or network restriction, otherwise if it persists remove your server and add it back in.") }
      /// You are unauthenticated
      public static var title: String { return L10n.tr("Localizable", "unauthenticated.message.title", fallback: "You are unauthenticated") }
    }
  }
  public enum Updater {
    public enum CheckForUpdatesMenu {
      /// Check for Updates…
      public static var title: String { return L10n.tr("Localizable", "updater.check_for_updates_menu.title", fallback: "Check for Updates…") }
    }
    public enum NoUpdatesAvailable {
      /// You're on the latest version!
      public static var onLatestVersion: String { return L10n.tr("Localizable", "updater.no_updates_available.on_latest_version", fallback: "You're on the latest version!") }
      /// Check for Updates
      public static var title: String { return L10n.tr("Localizable", "updater.no_updates_available.title", fallback: "Check for Updates") }
    }
    public enum UpdateAvailable {
      /// View '%@'
      public static func `open`(_ p1: Any) -> String {
        return L10n.tr("Localizable", "updater.update_available.open", String(describing: p1), fallback: "View '%@'")
      }
      /// Update Available
      public static var title: String { return L10n.tr("Localizable", "updater.update_available.title", fallback: "Update Available") }
    }
  }
  public enum UrlHandler {
    public enum CallService {
      public enum Confirm {
        /// Do you want to call the service %@?
        public static func message(_ p1: Any) -> String {
          return L10n.tr("Localizable", "url_handler.call_service.confirm.message", String(describing: p1), fallback: "Do you want to call the service %@?")
        }
        /// Call service?
        public static var title: String { return L10n.tr("Localizable", "url_handler.call_service.confirm.title", fallback: "Call service?") }
      }
      public enum Error {
        /// An error occurred while attempting to call service %@: %@
        public static func message(_ p1: Any, _ p2: Any) -> String {
          return L10n.tr("Localizable", "url_handler.call_service.error.message", String(describing: p1), String(describing: p2), fallback: "An error occurred while attempting to call service %@: %@")
        }
      }
      public enum Success {
        /// Successfully called %@
        public static func message(_ p1: Any) -> String {
          return L10n.tr("Localizable", "url_handler.call_service.success.message", String(describing: p1), fallback: "Successfully called %@")
        }
        /// Called service
        public static var title: String { return L10n.tr("Localizable", "url_handler.call_service.success.title", fallback: "Called service") }
      }
    }
    public enum Error {
      /// Action Not Found
      public static var actionNotFound: String { return L10n.tr("Localizable", "url_handler.error.action_not_found", fallback: "Action Not Found") }
    }
    public enum FireEvent {
      public enum Confirm {
        /// Do you want to fire the event %@?
        public static func message(_ p1: Any) -> String {
          return L10n.tr("Localizable", "url_handler.fire_event.confirm.message", String(describing: p1), fallback: "Do you want to fire the event %@?")
        }
        /// Fire event?
        public static var title: String { return L10n.tr("Localizable", "url_handler.fire_event.confirm.title", fallback: "Fire event?") }
      }
      public enum Error {
        /// An error occurred while attempting to fire event %@: %@
        public static func message(_ p1: Any, _ p2: Any) -> String {
          return L10n.tr("Localizable", "url_handler.fire_event.error.message", String(describing: p1), String(describing: p2), fallback: "An error occurred while attempting to fire event %@: %@")
        }
      }
      public enum Success {
        /// Successfully fired event %@
        public static func message(_ p1: Any) -> String {
          return L10n.tr("Localizable", "url_handler.fire_event.success.message", String(describing: p1), fallback: "Successfully fired event %@")
        }
        /// Fired event
        public static var title: String { return L10n.tr("Localizable", "url_handler.fire_event.success.title", fallback: "Fired event") }
      }
    }
    public enum NoService {
      /// %@ is not a valid route
      public static func message(_ p1: Any) -> String {
        return L10n.tr("Localizable", "url_handler.no_service.message", String(describing: p1), fallback: "%@ is not a valid route")
      }
    }
    public enum RenderTemplate {
      public enum Confirm {
        /// Do you want to render %@?
        public static func message(_ p1: Any) -> String {
          return L10n.tr("Localizable", "url_handler.render_template.confirm.message", String(describing: p1), fallback: "Do you want to render %@?")
        }
        /// Render template?
        public static var title: String { return L10n.tr("Localizable", "url_handler.render_template.confirm.title", fallback: "Render template?") }
      }
    }
    public enum SendLocation {
      public enum Confirm {
        /// Do you want to send your location?
        public static var message: String { return L10n.tr("Localizable", "url_handler.send_location.confirm.message", fallback: "Do you want to send your location?") }
        /// Send location?
        public static var title: String { return L10n.tr("Localizable", "url_handler.send_location.confirm.title", fallback: "Send location?") }
      }
      public enum Error {
        /// An unknown error occurred while attempting to send location: %@
        public static func message(_ p1: Any) -> String {
          return L10n.tr("Localizable", "url_handler.send_location.error.message", String(describing: p1), fallback: "An unknown error occurred while attempting to send location: %@")
        }
      }
      public enum Success {
        /// Sent a one shot location
        public static var message: String { return L10n.tr("Localizable", "url_handler.send_location.success.message", fallback: "Sent a one shot location") }
        /// Sent location
        public static var title: String { return L10n.tr("Localizable", "url_handler.send_location.success.title", fallback: "Sent location") }
      }
    }
    public enum XCallbackUrl {
      public enum Error {
        /// eventName must be defined
        public static var eventNameMissing: String { return L10n.tr("Localizable", "url_handler.x_callback_url.error.eventNameMissing", fallback: "eventName must be defined") }
        /// A general error occurred
        public static var general: String { return L10n.tr("Localizable", "url_handler.x_callback_url.error.general", fallback: "A general error occurred") }
        /// service (e.g. homeassistant.turn_on) must be defined
        public static var serviceMissing: String { return L10n.tr("Localizable", "url_handler.x_callback_url.error.serviceMissing", fallback: "service (e.g. homeassistant.turn_on) must be defined") }
        /// A renderable template must be defined
        public static var templateMissing: String { return L10n.tr("Localizable", "url_handler.x_callback_url.error.templateMissing", fallback: "A renderable template must be defined") }
      }
    }
  }
  public enum Watch {
    /// Placeholder
    public static var placeholderComplicationName: String { return L10n.tr("Localizable", "watch.placeholder_complication_name", fallback: "Placeholder") }
    public enum Assist {
      public enum Button {
        public enum Recording {
          /// Recording...
          public static var title: String { return L10n.tr("Localizable", "watch.assist.button.recording.title", fallback: "Recording...") }
        }
        public enum SendRequest {
          /// Tap to send request
          public static var title: String { return L10n.tr("Localizable", "watch.assist.button.send_request.title", fallback: "Tap to send request") }
        }
      }
      public enum LackConfig {
        public enum Error {
          /// Please configure Assist using iOS companion App
          public static var title: String { return L10n.tr("Localizable", "watch.assist.lack_config.error.title", fallback: "Please configure Assist using iOS companion App") }
        }
      }
    }
    public enum Config {
      public enum Assist {
        /// Server
        public static var selectServer: String { return L10n.tr("Localizable", "watch.config.assist.select_server", fallback: "Server") }
      }
      public enum Cache {
        public enum Error {
          /// Failed to load watch config from cache.
          public static var message: String { return L10n.tr("Localizable", "watch.config.cache.error.message", fallback: "Failed to load watch config from cache.") }
        }
      }
      public enum Error {
        /// Failed to load watch config, error: %@
        public static func message(_ p1: Any) -> String {
          return L10n.tr("Localizable", "watch.config.error.message", String(describing: p1), fallback: "Failed to load watch config, error: %@")
        }
      }
      public enum MigrationError {
        /// Failed to access database (GRDB), error: %@
        public static func failedAccessGrdb(_ p1: Any) -> String {
          return L10n.tr("Localizable", "watch.config.migration_error.failed_access_grdb", String(describing: p1), fallback: "Failed to access database (GRDB), error: %@")
        }
        /// Failed to save initial watch config, error: %@
        public static func failedCreateNewConfig(_ p1: Any) -> String {
          return L10n.tr("Localizable", "watch.config.migration_error.failed_create_new_config", String(describing: p1), fallback: "Failed to save initial watch config, error: %@")
        }
        /// Failed to migrate actions to watch config, error: %@
        public static func failedMigrateActions(_ p1: Any) -> String {
          return L10n.tr("Localizable", "watch.config.migration_error.failed_migrate_actions", String(describing: p1), fallback: "Failed to migrate actions to watch config, error: %@")
        }
        /// Failed to save new Watch config, error: %@
        public static func failedToSave(_ p1: Any) -> String {
          return L10n.tr("Localizable", "watch.config.migration_error.failed_to_save", String(describing: p1), fallback: "Failed to save new Watch config, error: %@")
        }
      }
    }
    public enum Configuration {
      public enum AddFolder {
        /// Add Folder
        public static var title: String { return L10n.tr("Localizable", "watch.configuration.add_folder.title", fallback: "Add Folder") }
      }
      public enum AddItem {
        /// Add item
        public static var title: String { return L10n.tr("Localizable", "watch.configuration.add_item.title", fallback: "Add item") }
      }
      public enum Folder {
        /// Folder
        public static var defaultName: String { return L10n.tr("Localizable", "watch.configuration.folder.default_name", fallback: "Folder") }
      }
      public enum FolderName {
        /// Folder Name
        public static var title: String { return L10n.tr("Localizable", "watch.configuration.folder_name.title", fallback: "Folder Name") }
      }
      public enum Items {
        /// Items
        public static var title: String { return L10n.tr("Localizable", "watch.configuration.items.title", fallback: "Items") }
      }
      public enum NewFolder {
        /// New Folder
        public static var title: String { return L10n.tr("Localizable", "watch.configuration.new_folder.title", fallback: "New Folder") }
      }
      public enum Save {
        /// Save
        public static var title: String { return L10n.tr("Localizable", "watch.configuration.save.title", fallback: "Save") }
      }
      public enum ShowAssist {
        /// Show Assist
        public static var title: String { return L10n.tr("Localizable", "watch.configuration.show_assist.title", fallback: "Show Assist") }
      }
    }
    public enum Configurator {
      public enum Delete {
        /// Delete Complication
        public static var button: String { return L10n.tr("Localizable", "watch.configurator.delete.button", fallback: "Delete Complication") }
        /// Are you sure you want to delete this Complication? This cannot be undone.
        public static var message: String { return L10n.tr("Localizable", "watch.configurator.delete.message", fallback: "Are you sure you want to delete this Complication? This cannot be undone.") }
        /// Delete Complication?
        public static var title: String { return L10n.tr("Localizable", "watch.configurator.delete.title", fallback: "Delete Complication?") }
      }
      public enum List {
        /// Configure a new Complication using the Add button. Once saved, you can choose it on your Apple Watch or in the Watch app.
        public static var description: String { return L10n.tr("Localizable", "watch.configurator.list.description", fallback: "Configure a new Complication using the Add button. Once saved, you can choose it on your Apple Watch or in the Watch app.") }
        public enum ManualUpdates {
          /// Automatic updates occur 4 times per hour. Manual updates can also be done using notifications.
          public static var footer: String { return L10n.tr("Localizable", "watch.configurator.list.manual_updates.footer", fallback: "Automatic updates occur 4 times per hour. Manual updates can also be done using notifications.") }
          /// Update Complications
          public static var manuallyUpdate: String { return L10n.tr("Localizable", "watch.configurator.list.manual_updates.manually_update", fallback: "Update Complications") }
          /// Remaining
          public static var remaining: String { return L10n.tr("Localizable", "watch.configurator.list.manual_updates.remaining", fallback: "Remaining") }
          /// Manual Updates
          public static var title: String { return L10n.tr("Localizable", "watch.configurator.list.manual_updates.title", fallback: "Manual Updates") }
          public enum State {
            /// Not Enabled
            public static var notEnabled: String { return L10n.tr("Localizable", "watch.configurator.list.manual_updates.state.not_enabled", fallback: "Not Enabled") }
            /// Not Installed
            public static var notInstalled: String { return L10n.tr("Localizable", "watch.configurator.list.manual_updates.state.not_installed", fallback: "Not Installed") }
            /// No Device
            public static var notPaired: String { return L10n.tr("Localizable", "watch.configurator.list.manual_updates.state.not_paired", fallback: "No Device") }
          }
        }
      }
      public enum New {
        /// Adding another Complication for the same type as an existing one requires watchOS 7 or newer.
        public static var multipleComplicationInfo: String { return L10n.tr("Localizable", "watch.configurator.new.multiple_complication_info", fallback: "Adding another Complication for the same type as an existing one requires watchOS 7 or newer.") }
        /// New Complication
        public static var title: String { return L10n.tr("Localizable", "watch.configurator.new.title", fallback: "New Complication") }
      }
      public enum PreviewError {
        /// Expected a number but got %1$@: '%2$@'
        public static func notNumber(_ p1: Any, _ p2: Any) -> String {
          return L10n.tr("Localizable", "watch.configurator.preview_error.not_number", String(describing: p1), String(describing: p2), fallback: "Expected a number but got %1$@: '%2$@'")
        }
        /// Expected a number between 0.0 and 1.0 but got %1$f
        public static func outOfRange(_ p1: Float) -> String {
          return L10n.tr("Localizable", "watch.configurator.preview_error.out_of_range", p1, fallback: "Expected a number between 0.0 and 1.0 but got %1$f")
        }
      }
      public enum Rows {
        public enum Color {
          /// Color
          public static var title: String { return L10n.tr("Localizable", "watch.configurator.rows.color.title", fallback: "Color") }
        }
        public enum Column2Alignment {
          /// Column 2 Alignment
          public static var title: String { return L10n.tr("Localizable", "watch.configurator.rows.column_2_alignment.title", fallback: "Column 2 Alignment") }
          public enum Options {
            /// Leading
            public static var leading: String { return L10n.tr("Localizable", "watch.configurator.rows.column_2_alignment.options.leading", fallback: "Leading") }
            /// Trailing
            public static var trailing: String { return L10n.tr("Localizable", "watch.configurator.rows.column_2_alignment.options.trailing", fallback: "Trailing") }
          }
        }
        public enum DisplayName {
          /// Display Name
          public static var title: String { return L10n.tr("Localizable", "watch.configurator.rows.display_name.title", fallback: "Display Name") }
        }
        public enum Gauge {
          /// Gauge
          public static var title: String { return L10n.tr("Localizable", "watch.configurator.rows.gauge.title", fallback: "Gauge") }
          public enum Color {
            /// Color
            public static var title: String { return L10n.tr("Localizable", "watch.configurator.rows.gauge.color.title", fallback: "Color") }
          }
          public enum GaugeType {
            /// Type
            public static var title: String { return L10n.tr("Localizable", "watch.configurator.rows.gauge.gauge_type.title", fallback: "Type") }
            public enum Options {
              /// Closed
              public static var closed: String { return L10n.tr("Localizable", "watch.configurator.rows.gauge.gauge_type.options.closed", fallback: "Closed") }
              /// Open
              public static var `open`: String { return L10n.tr("Localizable", "watch.configurator.rows.gauge.gauge_type.options.open", fallback: "Open") }
            }
          }
          public enum Style {
            /// Style
            public static var title: String { return L10n.tr("Localizable", "watch.configurator.rows.gauge.style.title", fallback: "Style") }
            public enum Options {
              /// Fill
              public static var fill: String { return L10n.tr("Localizable", "watch.configurator.rows.gauge.style.options.fill", fallback: "Fill") }
              /// Ring
              public static var ring: String { return L10n.tr("Localizable", "watch.configurator.rows.gauge.style.options.ring", fallback: "Ring") }
            }
          }
        }
        public enum Icon {
          public enum Choose {
            /// Choose an icon
            public static var title: String { return L10n.tr("Localizable", "watch.configurator.rows.icon.choose.title", fallback: "Choose an icon") }
          }
          public enum Color {
            /// Color
            public static var title: String { return L10n.tr("Localizable", "watch.configurator.rows.icon.color.title", fallback: "Color") }
          }
        }
        public enum IsPublic {
          /// Show When Locked
          public static var title: String { return L10n.tr("Localizable", "watch.configurator.rows.is_public.title", fallback: "Show When Locked") }
        }
        public enum Ring {
          public enum Color {
            /// Color
            public static var title: String { return L10n.tr("Localizable", "watch.configurator.rows.ring.color.title", fallback: "Color") }
          }
          public enum RingType {
            /// Type
            public static var title: String { return L10n.tr("Localizable", "watch.configurator.rows.ring.ring_type.title", fallback: "Type") }
            public enum Options {
              /// Closed
              public static var closed: String { return L10n.tr("Localizable", "watch.configurator.rows.ring.ring_type.options.closed", fallback: "Closed") }
              /// Open
              public static var `open`: String { return L10n.tr("Localizable", "watch.configurator.rows.ring.ring_type.options.open", fallback: "Open") }
            }
          }
          public enum Value {
            /// Fractional value
            public static var title: String { return L10n.tr("Localizable", "watch.configurator.rows.ring.value.title", fallback: "Fractional value") }
          }
        }
        public enum Template {
          /// Choose a template
          public static var selectorTitle: String { return L10n.tr("Localizable", "watch.configurator.rows.template.selector_title", fallback: "Choose a template") }
          /// Template
          public static var title: String { return L10n.tr("Localizable", "watch.configurator.rows.template.title", fallback: "Template") }
        }
      }
      public enum Sections {
        public enum Gauge {
          /// The gauge to display in the complication.
          public static var footer: String { return L10n.tr("Localizable", "watch.configurator.sections.gauge.footer", fallback: "The gauge to display in the complication.") }
          /// Gauge
          public static var header: String { return L10n.tr("Localizable", "watch.configurator.sections.gauge.header", fallback: "Gauge") }
        }
        public enum Icon {
          /// The image to display in the complication.
          public static var footer: String { return L10n.tr("Localizable", "watch.configurator.sections.icon.footer", fallback: "The image to display in the complication.") }
          /// Icon
          public static var header: String { return L10n.tr("Localizable", "watch.configurator.sections.icon.header", fallback: "Icon") }
        }
        public enum Ring {
          /// The ring showing progress surrounding the text.
          public static var footer: String { return L10n.tr("Localizable", "watch.configurator.sections.ring.footer", fallback: "The ring showing progress surrounding the text.") }
          /// Ring
          public static var header: String { return L10n.tr("Localizable", "watch.configurator.sections.ring.header", fallback: "Ring") }
        }
      }
      public enum Warning {
        /// ATTENTION: For templating in watch complications the user needs to have admin role.
        public static var templatingAdmin: String { return L10n.tr("Localizable", "watch.configurator.warning.templating_admin", fallback: "ATTENTION: For templating in watch complications the user needs to have admin role.") }
      }
    }
    public enum Debug {
      public enum DeleteDb {
        /// Delete watch configuration
        public static var title: String { return L10n.tr("Localizable", "watch.debug.delete_db.title", fallback: "Delete watch configuration") }
        public enum Alert {
          /// Are you sure you want to delete watch configuration? This can't be reverted
          public static var title: String { return L10n.tr("Localizable", "watch.debug.delete_db.alert.title", fallback: "Are you sure you want to delete watch configuration? This can't be reverted") }
          public enum Failed {
            /// Failed to delete configuration, error: %@
            public static func message(_ p1: Any) -> String {
              return L10n.tr("Localizable", "watch.debug.delete_db.alert.failed.message", String(describing: p1), fallback: "Failed to delete configuration, error: %@")
            }
          }
        }
        public enum Reset {
          /// Reset configuration
          public static var title: String { return L10n.tr("Localizable", "watch.debug.delete_db.reset.title", fallback: "Reset configuration") }
        }
      }
    }
    public enum Home {
      public enum CancelAndUseCache {
        /// Cancel and use cache
        public static var title: String { return L10n.tr("Localizable", "watch.home.cancel_and_use_cache.title", fallback: "Cancel and use cache") }
      }
      public enum Loading {
        public enum Skip {
          /// Skip
          public static var title: String { return L10n.tr("Localizable", "watch.home.loading.skip.title", fallback: "Skip") }
        }
      }
      public enum Run {
        public enum Confirmation {
          /// Are you sure you want to run "%@"?
          public static func title(_ p1: Any) -> String {
            return L10n.tr("Localizable", "watch.home.run.confirmation.title", String(describing: p1), fallback: "Are you sure you want to run \"%@\"?")
          }
        }
      }
    }
    public enum Labels {
      /// No watch configuration available, open the iOS App and create your configuration under companion app settings.
      public static var noConfig: String { return L10n.tr("Localizable", "watch.labels.no_config", fallback: "No watch configuration available, open the iOS App and create your configuration under companion app settings.") }
      public enum ComplicationGroup {
        public enum CircularSmall {
          /// Use circular small complications to display content in the corners of the Color watch face.
          public static var description: String { return L10n.tr("Localizable", "watch.labels.complication_group.circular_small.description", fallback: "Use circular small complications to display content in the corners of the Color watch face.") }
          /// Circular Small
          public static var name: String { return L10n.tr("Localizable", "watch.labels.complication_group.circular_small.name", fallback: "Circular Small") }
        }
        public enum ExtraLarge {
          /// Use the extra large complications to display content on the X-Large watch faces.
          public static var description: String { return L10n.tr("Localizable", "watch.labels.complication_group.extra_large.description", fallback: "Use the extra large complications to display content on the X-Large watch faces.") }
          /// Extra Large
          public static var name: String { return L10n.tr("Localizable", "watch.labels.complication_group.extra_large.name", fallback: "Extra Large") }
        }
        public enum Graphic {
          /// Use graphic complications to display visually rich content in the Infograph and Infograph Modular clock faces.
          public static var description: String { return L10n.tr("Localizable", "watch.labels.complication_group.graphic.description", fallback: "Use graphic complications to display visually rich content in the Infograph and Infograph Modular clock faces.") }
          /// Graphic
          public static var name: String { return L10n.tr("Localizable", "watch.labels.complication_group.graphic.name", fallback: "Graphic") }
        }
        public enum Modular {
          /// Use modular small complications to display content in the Modular watch face.
          public static var description: String { return L10n.tr("Localizable", "watch.labels.complication_group.modular.description", fallback: "Use modular small complications to display content in the Modular watch face.") }
          /// Modular
          public static var name: String { return L10n.tr("Localizable", "watch.labels.complication_group.modular.name", fallback: "Modular") }
        }
        public enum Utilitarian {
          /// Use the utilitarian complications to display content in the Utility, Motion, Mickey Mouse, and Minnie Mouse watch faces.
          public static var description: String { return L10n.tr("Localizable", "watch.labels.complication_group.utilitarian.description", fallback: "Use the utilitarian complications to display content in the Utility, Motion, Mickey Mouse, and Minnie Mouse watch faces.") }
          /// Utilitarian
          public static var name: String { return L10n.tr("Localizable", "watch.labels.complication_group.utilitarian.name", fallback: "Utilitarian") }
        }
      }
      public enum ComplicationGroupMember {
        public enum CircularSmall {
          /// A small circular area used in the Color clock face.
          public static var description: String { return L10n.tr("Localizable", "watch.labels.complication_group_member.circular_small.description", fallback: "A small circular area used in the Color clock face.") }
          /// Circular Small
          public static var name: String { return L10n.tr("Localizable", "watch.labels.complication_group_member.circular_small.name", fallback: "Circular Small") }
          /// Circular Small
          public static var shortName: String { return L10n.tr("Localizable", "watch.labels.complication_group_member.circular_small.short_name", fallback: "Circular Small") }
        }
        public enum ExtraLarge {
          /// A large square area used in the X-Large clock face.
          public static var description: String { return L10n.tr("Localizable", "watch.labels.complication_group_member.extra_large.description", fallback: "A large square area used in the X-Large clock face.") }
          /// Extra Large
          public static var name: String { return L10n.tr("Localizable", "watch.labels.complication_group_member.extra_large.name", fallback: "Extra Large") }
          /// Extra Large
          public static var shortName: String { return L10n.tr("Localizable", "watch.labels.complication_group_member.extra_large.short_name", fallback: "Extra Large") }
        }
        public enum GraphicBezel {
          /// A small square area used in the Modular clock face.
          public static var description: String { return L10n.tr("Localizable", "watch.labels.complication_group_member.graphic_bezel.description", fallback: "A small square area used in the Modular clock face.") }
          /// Graphic Bezel
          public static var name: String { return L10n.tr("Localizable", "watch.labels.complication_group_member.graphic_bezel.name", fallback: "Graphic Bezel") }
          /// Bezel
          public static var shortName: String { return L10n.tr("Localizable", "watch.labels.complication_group_member.graphic_bezel.short_name", fallback: "Bezel") }
        }
        public enum GraphicCircular {
          /// A large rectangular area used in the Modular clock face.
          public static var description: String { return L10n.tr("Localizable", "watch.labels.complication_group_member.graphic_circular.description", fallback: "A large rectangular area used in the Modular clock face.") }
          /// Graphic Circular
          public static var name: String { return L10n.tr("Localizable", "watch.labels.complication_group_member.graphic_circular.name", fallback: "Graphic Circular") }
          /// Circular
          public static var shortName: String { return L10n.tr("Localizable", "watch.labels.complication_group_member.graphic_circular.short_name", fallback: "Circular") }
        }
        public enum GraphicCorner {
          /// A small square or rectangular area used in the Utility, Mickey, Chronograph, and Simple clock faces.
          public static var description: String { return L10n.tr("Localizable", "watch.labels.complication_group_member.graphic_corner.description", fallback: "A small square or rectangular area used in the Utility, Mickey, Chronograph, and Simple clock faces.") }
          /// Graphic Corner
          public static var name: String { return L10n.tr("Localizable", "watch.labels.complication_group_member.graphic_corner.name", fallback: "Graphic Corner") }
          /// Corner
          public static var shortName: String { return L10n.tr("Localizable", "watch.labels.complication_group_member.graphic_corner.short_name", fallback: "Corner") }
        }
        public enum GraphicRectangular {
          /// A small rectangular area used in the in the Photos, Motion, and Timelapse clock faces.
          public static var description: String { return L10n.tr("Localizable", "watch.labels.complication_group_member.graphic_rectangular.description", fallback: "A small rectangular area used in the in the Photos, Motion, and Timelapse clock faces.") }
          /// Graphic Rectangular
          public static var name: String { return L10n.tr("Localizable", "watch.labels.complication_group_member.graphic_rectangular.name", fallback: "Graphic Rectangular") }
          /// Rectangular
          public static var shortName: String { return L10n.tr("Localizable", "watch.labels.complication_group_member.graphic_rectangular.short_name", fallback: "Rectangular") }
        }
        public enum ModularLarge {
          /// A large rectangular area that spans the width of the screen in the Utility and Mickey clock faces.
          public static var description: String { return L10n.tr("Localizable", "watch.labels.complication_group_member.modular_large.description", fallback: "A large rectangular area that spans the width of the screen in the Utility and Mickey clock faces.") }
          /// Modular Large
          public static var name: String { return L10n.tr("Localizable", "watch.labels.complication_group_member.modular_large.name", fallback: "Modular Large") }
          /// Large
          public static var shortName: String { return L10n.tr("Localizable", "watch.labels.complication_group_member.modular_large.short_name", fallback: "Large") }
        }
        public enum ModularSmall {
          /// A curved area that fills the corners in the Infograph clock face.
          public static var description: String { return L10n.tr("Localizable", "watch.labels.complication_group_member.modular_small.description", fallback: "A curved area that fills the corners in the Infograph clock face.") }
          /// Modular Small
          public static var name: String { return L10n.tr("Localizable", "watch.labels.complication_group_member.modular_small.name", fallback: "Modular Small") }
          /// Small
          public static var shortName: String { return L10n.tr("Localizable", "watch.labels.complication_group_member.modular_small.short_name", fallback: "Small") }
        }
        public enum UtilitarianLarge {
          /// A circular area used in the Infograph and Infograph Modular clock faces.
          public static var description: String { return L10n.tr("Localizable", "watch.labels.complication_group_member.utilitarian_large.description", fallback: "A circular area used in the Infograph and Infograph Modular clock faces.") }
          /// Utilitarian Large
          public static var name: String { return L10n.tr("Localizable", "watch.labels.complication_group_member.utilitarian_large.name", fallback: "Utilitarian Large") }
          /// Large
          public static var shortName: String { return L10n.tr("Localizable", "watch.labels.complication_group_member.utilitarian_large.short_name", fallback: "Large") }
        }
        public enum UtilitarianSmall {
          /// A circular area with optional curved text placed along the bezel of the Infograph clock face.
          public static var description: String { return L10n.tr("Localizable", "watch.labels.complication_group_member.utilitarian_small.description", fallback: "A circular area with optional curved text placed along the bezel of the Infograph clock face.") }
          /// Utilitarian Small
          public static var name: String { return L10n.tr("Localizable", "watch.labels.complication_group_member.utilitarian_small.name", fallback: "Utilitarian Small") }
          /// Small
          public static var shortName: String { return L10n.tr("Localizable", "watch.labels.complication_group_member.utilitarian_small.short_name", fallback: "Small") }
        }
        public enum UtilitarianSmallFlat {
          /// A large rectangular area used in the Infograph Modular clock face.
          public static var description: String { return L10n.tr("Localizable", "watch.labels.complication_group_member.utilitarian_small_flat.description", fallback: "A large rectangular area used in the Infograph Modular clock face.") }
          /// Utilitarian Small Flat
          public static var name: String { return L10n.tr("Localizable", "watch.labels.complication_group_member.utilitarian_small_flat.name", fallback: "Utilitarian Small Flat") }
          /// Small Flat
          public static var shortName: String { return L10n.tr("Localizable", "watch.labels.complication_group_member.utilitarian_small_flat.short_name", fallback: "Small Flat") }
        }
      }
      public enum ComplicationTemplate {
        public enum CircularSmallRingImage {
          /// A template for displaying a single image surrounded by a configurable progress ring.
          public static var description: String { return L10n.tr("Localizable", "watch.labels.complication_template.circular_small_ring_image.description", fallback: "A template for displaying a single image surrounded by a configurable progress ring.") }
        }
        public enum CircularSmallRingText {
          /// A template for displaying a short text string encircled by a configurable progress ring.
          public static var description: String { return L10n.tr("Localizable", "watch.labels.complication_template.circular_small_ring_text.description", fallback: "A template for displaying a short text string encircled by a configurable progress ring.") }
        }
        public enum CircularSmallSimpleImage {
          /// A template for displaying a single image.
          public static var description: String { return L10n.tr("Localizable", "watch.labels.complication_template.circular_small_simple_image.description", fallback: "A template for displaying a single image.") }
        }
        public enum CircularSmallSimpleText {
          /// A template for displaying a short text string.
          public static var description: String { return L10n.tr("Localizable", "watch.labels.complication_template.circular_small_simple_text.description", fallback: "A template for displaying a short text string.") }
        }
        public enum CircularSmallStackImage {
          /// A template for displaying an image with a line of text below it.
          public static var description: String { return L10n.tr("Localizable", "watch.labels.complication_template.circular_small_stack_image.description", fallback: "A template for displaying an image with a line of text below it.") }
        }
        public enum CircularSmallStackText {
          /// A template for displaying two text strings stacked on top of each other.
          public static var description: String { return L10n.tr("Localizable", "watch.labels.complication_template.circular_small_stack_text.description", fallback: "A template for displaying two text strings stacked on top of each other.") }
        }
        public enum ExtraLargeColumnsText {
          /// A template for displaying two rows and two columns of text.
          public static var description: String { return L10n.tr("Localizable", "watch.labels.complication_template.extra_large_columns_text.description", fallback: "A template for displaying two rows and two columns of text.") }
        }
        public enum ExtraLargeRingImage {
          /// A template for displaying an image encircled by a configurable progress ring.
          public static var description: String { return L10n.tr("Localizable", "watch.labels.complication_template.extra_large_ring_image.description", fallback: "A template for displaying an image encircled by a configurable progress ring.") }
        }
        public enum ExtraLargeRingText {
          /// A template for displaying text encircled by a configurable progress ring.
          public static var description: String { return L10n.tr("Localizable", "watch.labels.complication_template.extra_large_ring_text.description", fallback: "A template for displaying text encircled by a configurable progress ring.") }
        }
        public enum ExtraLargeSimpleImage {
          /// A template for displaying an image.
          public static var description: String { return L10n.tr("Localizable", "watch.labels.complication_template.extra_large_simple_image.description", fallback: "A template for displaying an image.") }
        }
        public enum ExtraLargeSimpleText {
          /// A template for displaying a small amount of text
          public static var description: String { return L10n.tr("Localizable", "watch.labels.complication_template.extra_large_simple_text.description", fallback: "A template for displaying a small amount of text") }
        }
        public enum ExtraLargeStackImage {
          /// A template for displaying a single image with a short line of text below it.
          public static var description: String { return L10n.tr("Localizable", "watch.labels.complication_template.extra_large_stack_image.description", fallback: "A template for displaying a single image with a short line of text below it.") }
        }
        public enum ExtraLargeStackText {
          /// A template for displaying two strings stacked one on top of the other.
          public static var description: String { return L10n.tr("Localizable", "watch.labels.complication_template.extra_large_stack_text.description", fallback: "A template for displaying two strings stacked one on top of the other.") }
        }
        public enum GraphicBezelCircularText {
          /// A template for displaying a circular complication with text along the bezel.
          public static var description: String { return L10n.tr("Localizable", "watch.labels.complication_template.graphic_bezel_circular_text.description", fallback: "A template for displaying a circular complication with text along the bezel.") }
        }
        public enum GraphicCircularClosedGaugeImage {
          /// A template for displaying a full-color circular image and a closed circular gauge.
          public static var description: String { return L10n.tr("Localizable", "watch.labels.complication_template.graphic_circular_closed_gauge_image.description", fallback: "A template for displaying a full-color circular image and a closed circular gauge.") }
        }
        public enum GraphicCircularClosedGaugeText {
          /// A template for displaying text inside a closed circular gauge.
          public static var description: String { return L10n.tr("Localizable", "watch.labels.complication_template.graphic_circular_closed_gauge_text.description", fallback: "A template for displaying text inside a closed circular gauge.") }
        }
        public enum GraphicCircularImage {
          /// A template for displaying a full-color circular image.
          public static var description: String { return L10n.tr("Localizable", "watch.labels.complication_template.graphic_circular_image.description", fallback: "A template for displaying a full-color circular image.") }
        }
        public enum GraphicCircularOpenGaugeImage {
          /// A template for displaying a full-color circular image, an open gauge, and text.
          public static var description: String { return L10n.tr("Localizable", "watch.labels.complication_template.graphic_circular_open_gauge_image.description", fallback: "A template for displaying a full-color circular image, an open gauge, and text.") }
        }
        public enum GraphicCircularOpenGaugeRangeText {
          /// A template for displaying text inside an open gauge, with leading and trailing text for the gauge.
          public static var description: String { return L10n.tr("Localizable", "watch.labels.complication_template.graphic_circular_open_gauge_range_text.description", fallback: "A template for displaying text inside an open gauge, with leading and trailing text for the gauge.") }
        }
        public enum GraphicCircularOpenGaugeSimpleText {
          /// A template for displaying text inside an open gauge, with a single piece of text for the gauge.
          public static var description: String { return L10n.tr("Localizable", "watch.labels.complication_template.graphic_circular_open_gauge_simple_text.description", fallback: "A template for displaying text inside an open gauge, with a single piece of text for the gauge.") }
        }
        public enum GraphicCornerCircularImage {
          /// A template for displaying an image in the clock face’s corner.
          public static var description: String { return L10n.tr("Localizable", "watch.labels.complication_template.graphic_corner_circular_image.description", fallback: "A template for displaying an image in the clock face’s corner.") }
        }
        public enum GraphicCornerGaugeImage {
          /// A template for displaying an image and a gauge in the clock face’s corner.
          public static var description: String { return L10n.tr("Localizable", "watch.labels.complication_template.graphic_corner_gauge_image.description", fallback: "A template for displaying an image and a gauge in the clock face’s corner.") }
        }
        public enum GraphicCornerGaugeText {
          /// A template for displaying text and a gauge in the clock face’s corner.
          public static var description: String { return L10n.tr("Localizable", "watch.labels.complication_template.graphic_corner_gauge_text.description", fallback: "A template for displaying text and a gauge in the clock face’s corner.") }
        }
        public enum GraphicCornerStackText {
          /// A template for displaying stacked text in the clock face’s corner.
          public static var description: String { return L10n.tr("Localizable", "watch.labels.complication_template.graphic_corner_stack_text.description", fallback: "A template for displaying stacked text in the clock face’s corner.") }
        }
        public enum GraphicCornerTextImage {
          /// A template for displaying an image and text in the clock face’s corner.
          public static var description: String { return L10n.tr("Localizable", "watch.labels.complication_template.graphic_corner_text_image.description", fallback: "A template for displaying an image and text in the clock face’s corner.") }
        }
        public enum GraphicRectangularLargeImage {
          /// A template for displaying a large rectangle containing header text and an image.
          public static var description: String { return L10n.tr("Localizable", "watch.labels.complication_template.graphic_rectangular_large_image.description", fallback: "A template for displaying a large rectangle containing header text and an image.") }
        }
        public enum GraphicRectangularStandardBody {
          /// A template for displaying a large rectangle containing text.
          public static var description: String { return L10n.tr("Localizable", "watch.labels.complication_template.graphic_rectangular_standard_body.description", fallback: "A template for displaying a large rectangle containing text.") }
        }
        public enum GraphicRectangularTextGauge {
          /// A template for displaying a large rectangle containing text and a gauge.
          public static var description: String { return L10n.tr("Localizable", "watch.labels.complication_template.graphic_rectangular_text_gauge.description", fallback: "A template for displaying a large rectangle containing text and a gauge.") }
        }
        public enum ModularLargeColumns {
          /// A template for displaying multiple columns of data.
          public static var description: String { return L10n.tr("Localizable", "watch.labels.complication_template.modular_large_columns.description", fallback: "A template for displaying multiple columns of data.") }
        }
        public enum ModularLargeStandardBody {
          /// A template for displaying a header row and two lines of text
          public static var description: String { return L10n.tr("Localizable", "watch.labels.complication_template.modular_large_standard_body.description", fallback: "A template for displaying a header row and two lines of text") }
        }
        public enum ModularLargeTable {
          /// A template for displaying a header row and columns
          public static var description: String { return L10n.tr("Localizable", "watch.labels.complication_template.modular_large_table.description", fallback: "A template for displaying a header row and columns") }
        }
        public enum ModularLargeTallBody {
          /// A template for displaying a header row and a tall row of body text.
          public static var description: String { return L10n.tr("Localizable", "watch.labels.complication_template.modular_large_tall_body.description", fallback: "A template for displaying a header row and a tall row of body text.") }
        }
        public enum ModularSmallColumnsText {
          /// A template for displaying two rows and two columns of text
          public static var description: String { return L10n.tr("Localizable", "watch.labels.complication_template.modular_small_columns_text.description", fallback: "A template for displaying two rows and two columns of text") }
        }
        public enum ModularSmallRingImage {
          /// A template for displaying an image encircled by a configurable progress ring
          public static var description: String { return L10n.tr("Localizable", "watch.labels.complication_template.modular_small_ring_image.description", fallback: "A template for displaying an image encircled by a configurable progress ring") }
        }
        public enum ModularSmallRingText {
          /// A template for displaying text encircled by a configurable progress ring
          public static var description: String { return L10n.tr("Localizable", "watch.labels.complication_template.modular_small_ring_text.description", fallback: "A template for displaying text encircled by a configurable progress ring") }
        }
        public enum ModularSmallSimpleImage {
          /// A template for displaying an image.
          public static var description: String { return L10n.tr("Localizable", "watch.labels.complication_template.modular_small_simple_image.description", fallback: "A template for displaying an image.") }
        }
        public enum ModularSmallSimpleText {
          /// A template for displaying a small amount of text.
          public static var description: String { return L10n.tr("Localizable", "watch.labels.complication_template.modular_small_simple_text.description", fallback: "A template for displaying a small amount of text.") }
        }
        public enum ModularSmallStackImage {
          /// A template for displaying a single image with a short line of text below it.
          public static var description: String { return L10n.tr("Localizable", "watch.labels.complication_template.modular_small_stack_image.description", fallback: "A template for displaying a single image with a short line of text below it.") }
        }
        public enum ModularSmallStackText {
          /// A template for displaying two strings stacked one on top of the other.
          public static var description: String { return L10n.tr("Localizable", "watch.labels.complication_template.modular_small_stack_text.description", fallback: "A template for displaying two strings stacked one on top of the other.") }
        }
        public enum Style {
          /// Circular Image
          public static var circularImage: String { return L10n.tr("Localizable", "watch.labels.complication_template.style.circular_image", fallback: "Circular Image") }
          /// Circular Text
          public static var circularText: String { return L10n.tr("Localizable", "watch.labels.complication_template.style.circular_text", fallback: "Circular Text") }
          /// Closed Gauge Image
          public static var closedGaugeImage: String { return L10n.tr("Localizable", "watch.labels.complication_template.style.closed_gauge_image", fallback: "Closed Gauge Image") }
          /// Closed Gauge Text
          public static var closedGaugeText: String { return L10n.tr("Localizable", "watch.labels.complication_template.style.closed_gauge_text", fallback: "Closed Gauge Text") }
          /// Columns
          public static var columns: String { return L10n.tr("Localizable", "watch.labels.complication_template.style.columns", fallback: "Columns") }
          /// Columns Text
          public static var columnsText: String { return L10n.tr("Localizable", "watch.labels.complication_template.style.columns_text", fallback: "Columns Text") }
          /// Flat
          public static var flat: String { return L10n.tr("Localizable", "watch.labels.complication_template.style.flat", fallback: "Flat") }
          /// Gauge Image
          public static var gaugeImage: String { return L10n.tr("Localizable", "watch.labels.complication_template.style.gauge_image", fallback: "Gauge Image") }
          /// Gauge Text
          public static var gaugeText: String { return L10n.tr("Localizable", "watch.labels.complication_template.style.gauge_text", fallback: "Gauge Text") }
          /// Large Image
          public static var largeImage: String { return L10n.tr("Localizable", "watch.labels.complication_template.style.large_image", fallback: "Large Image") }
          /// Open Gauge Image
          public static var openGaugeImage: String { return L10n.tr("Localizable", "watch.labels.complication_template.style.open_gauge_image", fallback: "Open Gauge Image") }
          /// Open Gauge Range Text
          public static var openGaugeRangeText: String { return L10n.tr("Localizable", "watch.labels.complication_template.style.open_gauge_range_text", fallback: "Open Gauge Range Text") }
          /// Open Gauge Simple Text
          public static var openGaugeSimpleText: String { return L10n.tr("Localizable", "watch.labels.complication_template.style.open_gauge_simple_text", fallback: "Open Gauge Simple Text") }
          /// Ring Image
          public static var ringImage: String { return L10n.tr("Localizable", "watch.labels.complication_template.style.ring_image", fallback: "Ring Image") }
          /// Ring Text
          public static var ringText: String { return L10n.tr("Localizable", "watch.labels.complication_template.style.ring_text", fallback: "Ring Text") }
          /// Simple Image
          public static var simpleImage: String { return L10n.tr("Localizable", "watch.labels.complication_template.style.simple_image", fallback: "Simple Image") }
          /// Simple Text
          public static var simpleText: String { return L10n.tr("Localizable", "watch.labels.complication_template.style.simple_text", fallback: "Simple Text") }
          /// Square
          public static var square: String { return L10n.tr("Localizable", "watch.labels.complication_template.style.square", fallback: "Square") }
          /// Stack Image
          public static var stackImage: String { return L10n.tr("Localizable", "watch.labels.complication_template.style.stack_image", fallback: "Stack Image") }
          /// Stack Text
          public static var stackText: String { return L10n.tr("Localizable", "watch.labels.complication_template.style.stack_text", fallback: "Stack Text") }
          /// Standard Body
          public static var standardBody: String { return L10n.tr("Localizable", "watch.labels.complication_template.style.standard_body", fallback: "Standard Body") }
          /// Table
          public static var table: String { return L10n.tr("Localizable", "watch.labels.complication_template.style.table", fallback: "Table") }
          /// Tall Body
          public static var tallBody: String { return L10n.tr("Localizable", "watch.labels.complication_template.style.tall_body", fallback: "Tall Body") }
          /// Text Gauge
          public static var textGauge: String { return L10n.tr("Localizable", "watch.labels.complication_template.style.text_gauge", fallback: "Text Gauge") }
          /// Text Image
          public static var textImage: String { return L10n.tr("Localizable", "watch.labels.complication_template.style.text_image", fallback: "Text Image") }
        }
        public enum UtilitarianLargeFlat {
          /// A template for displaying an image and string in a single long line.
          public static var description: String { return L10n.tr("Localizable", "watch.labels.complication_template.utilitarian_large_flat.description", fallback: "A template for displaying an image and string in a single long line.") }
        }
        public enum UtilitarianSmallFlat {
          /// A template for displaying an image and text in a single line.
          public static var description: String { return L10n.tr("Localizable", "watch.labels.complication_template.utilitarian_small_flat.description", fallback: "A template for displaying an image and text in a single line.") }
        }
        public enum UtilitarianSmallRingImage {
          /// A template for displaying an image encircled by a configurable progress ring
          public static var description: String { return L10n.tr("Localizable", "watch.labels.complication_template.utilitarian_small_ring_image.description", fallback: "A template for displaying an image encircled by a configurable progress ring") }
        }
        public enum UtilitarianSmallRingText {
          /// A template for displaying text encircled by a configurable progress ring.
          public static var description: String { return L10n.tr("Localizable", "watch.labels.complication_template.utilitarian_small_ring_text.description", fallback: "A template for displaying text encircled by a configurable progress ring.") }
        }
        public enum UtilitarianSmallSquare {
          /// A template for displaying a single square image.
          public static var description: String { return L10n.tr("Localizable", "watch.labels.complication_template.utilitarian_small_square.description", fallback: "A template for displaying a single square image.") }
        }
      }
      public enum ComplicationTextAreas {
        public enum Body1 {
          /// The main body text to display in the complication.
          public static var description: String { return L10n.tr("Localizable", "watch.labels.complication_text_areas.body1.description", fallback: "The main body text to display in the complication.") }
          /// Body 1
          public static var label: String { return L10n.tr("Localizable", "watch.labels.complication_text_areas.body1.label", fallback: "Body 1") }
        }
        public enum Body2 {
          /// The secondary body text to display in the complication.
          public static var description: String { return L10n.tr("Localizable", "watch.labels.complication_text_areas.body2.description", fallback: "The secondary body text to display in the complication.") }
          /// Body 2
          public static var label: String { return L10n.tr("Localizable", "watch.labels.complication_text_areas.body2.label", fallback: "Body 2") }
        }
        public enum Bottom {
          /// The text to display at the bottom of the gauge.
          public static var description: String { return L10n.tr("Localizable", "watch.labels.complication_text_areas.bottom.description", fallback: "The text to display at the bottom of the gauge.") }
          /// Bottom
          public static var label: String { return L10n.tr("Localizable", "watch.labels.complication_text_areas.bottom.label", fallback: "Bottom") }
        }
        public enum Center {
          /// The text to display in the complication.
          public static var description: String { return L10n.tr("Localizable", "watch.labels.complication_text_areas.center.description", fallback: "The text to display in the complication.") }
          /// Center
          public static var label: String { return L10n.tr("Localizable", "watch.labels.complication_text_areas.center.label", fallback: "Center") }
        }
        public enum Header {
          /// The header text to display in the complication.
          public static var description: String { return L10n.tr("Localizable", "watch.labels.complication_text_areas.header.description", fallback: "The header text to display in the complication.") }
          /// Header
          public static var label: String { return L10n.tr("Localizable", "watch.labels.complication_text_areas.header.label", fallback: "Header") }
        }
        public enum Inner {
          /// The inner text to display in the complication.
          public static var description: String { return L10n.tr("Localizable", "watch.labels.complication_text_areas.inner.description", fallback: "The inner text to display in the complication.") }
          /// Inner
          public static var label: String { return L10n.tr("Localizable", "watch.labels.complication_text_areas.inner.label", fallback: "Inner") }
        }
        public enum InsideRing {
          /// The text to display in the ring of the complication.
          public static var description: String { return L10n.tr("Localizable", "watch.labels.complication_text_areas.inside_ring.description", fallback: "The text to display in the ring of the complication.") }
          /// Inside Ring
          public static var label: String { return L10n.tr("Localizable", "watch.labels.complication_text_areas.inside_ring.label", fallback: "Inside Ring") }
        }
        public enum Leading {
          /// The text to display on the leading edge of the gauge.
          public static var description: String { return L10n.tr("Localizable", "watch.labels.complication_text_areas.leading.description", fallback: "The text to display on the leading edge of the gauge.") }
          /// Leading
          public static var label: String { return L10n.tr("Localizable", "watch.labels.complication_text_areas.leading.label", fallback: "Leading") }
        }
        public enum Line1 {
          /// The text to display on the top line of the complication.
          public static var description: String { return L10n.tr("Localizable", "watch.labels.complication_text_areas.line1.description", fallback: "The text to display on the top line of the complication.") }
          /// Line 1
          public static var label: String { return L10n.tr("Localizable", "watch.labels.complication_text_areas.line1.label", fallback: "Line 1") }
        }
        public enum Line2 {
          /// The text to display on the bottom line of the complication.
          public static var description: String { return L10n.tr("Localizable", "watch.labels.complication_text_areas.line2.description", fallback: "The text to display on the bottom line of the complication.") }
          /// Line 2
          public static var label: String { return L10n.tr("Localizable", "watch.labels.complication_text_areas.line2.label", fallback: "Line 2") }
        }
        public enum Outer {
          /// The outer text to display in the complication.
          public static var description: String { return L10n.tr("Localizable", "watch.labels.complication_text_areas.outer.description", fallback: "The outer text to display in the complication.") }
          /// Outer
          public static var label: String { return L10n.tr("Localizable", "watch.labels.complication_text_areas.outer.label", fallback: "Outer") }
        }
        public enum Row1Column1 {
          /// The text to display in the first column of the first row.
          public static var description: String { return L10n.tr("Localizable", "watch.labels.complication_text_areas.row1_column1.description", fallback: "The text to display in the first column of the first row.") }
          /// Row 1, Column 1
          public static var label: String { return L10n.tr("Localizable", "watch.labels.complication_text_areas.row1_column1.label", fallback: "Row 1, Column 1") }
        }
        public enum Row1Column2 {
          /// The text to display in the second column of the first row.
          public static var description: String { return L10n.tr("Localizable", "watch.labels.complication_text_areas.row1_column2.description", fallback: "The text to display in the second column of the first row.") }
          /// Row 1, Column 2
          public static var label: String { return L10n.tr("Localizable", "watch.labels.complication_text_areas.row1_column2.label", fallback: "Row 1, Column 2") }
        }
        public enum Row2Column1 {
          /// The text to display in the first column of the second row.
          public static var description: String { return L10n.tr("Localizable", "watch.labels.complication_text_areas.row2_column1.description", fallback: "The text to display in the first column of the second row.") }
          /// Row 2, Column 1
          public static var label: String { return L10n.tr("Localizable", "watch.labels.complication_text_areas.row2_column1.label", fallback: "Row 2, Column 1") }
        }
        public enum Row2Column2 {
          /// The text to display in the second column of the second row.
          public static var description: String { return L10n.tr("Localizable", "watch.labels.complication_text_areas.row2_column2.description", fallback: "The text to display in the second column of the second row.") }
          /// Row 2, Column 2
          public static var label: String { return L10n.tr("Localizable", "watch.labels.complication_text_areas.row2_column2.label", fallback: "Row 2, Column 2") }
        }
        public enum Row3Column1 {
          /// The text to display in the first column of the third row.
          public static var description: String { return L10n.tr("Localizable", "watch.labels.complication_text_areas.row3_column1.description", fallback: "The text to display in the first column of the third row.") }
          /// Row 3, Column 1
          public static var label: String { return L10n.tr("Localizable", "watch.labels.complication_text_areas.row3_column1.label", fallback: "Row 3, Column 1") }
        }
        public enum Row3Column2 {
          /// The text to display in the second column of the third row.
          public static var description: String { return L10n.tr("Localizable", "watch.labels.complication_text_areas.row3_column2.description", fallback: "The text to display in the second column of the third row.") }
          /// Row 3, Column 2
          public static var label: String { return L10n.tr("Localizable", "watch.labels.complication_text_areas.row3_column2.label", fallback: "Row 3, Column 2") }
        }
        public enum Trailing {
          /// The text to display on the trailing edge of the gauge.
          public static var description: String { return L10n.tr("Localizable", "watch.labels.complication_text_areas.trailing.description", fallback: "The text to display on the trailing edge of the gauge.") }
          /// Trailing
          public static var label: String { return L10n.tr("Localizable", "watch.labels.complication_text_areas.trailing.label", fallback: "Trailing") }
        }
      }
      public enum SelectedPipeline {
        /// Pipeline
        public static var title: String { return L10n.tr("Localizable", "watch.labels.selected_pipeline.title", fallback: "Pipeline") }
      }
    }
    public enum Settings {
      public enum NoItems {
        public enum Phone {
          /// No items configured, please choose items below.
          public static var title: String { return L10n.tr("Localizable", "watch.settings.no_items.phone.title", fallback: "No items configured, please choose items below.") }
        }
      }
    }
  }
  public enum WebView {
    public enum AddTo {
      public enum Option {
        public enum AppleWatch {
          /// Apple Watch
          public static var title: String { return L10n.tr("Localizable", "web_view.add_to.option.AppleWatch.title", fallback: "Apple Watch") }
        }
        public enum CarPlay {
          /// CarPlay
          public static var title: String { return L10n.tr("Localizable", "web_view.add_to.option.CarPlay.title", fallback: "CarPlay") }
        }
        public enum Widget {
          /// Widget
          public static var title: String { return L10n.tr("Localizable", "web_view.add_to.option.Widget.title", fallback: "Widget") }
        }
      }
    }
    public enum EmptyState {
      /// Please check your connection or try again later. If Home Assistant is restarting it will reconnect after it is back online.
      public static var body: String { return L10n.tr("Localizable", "web_view.empty_state.body", fallback: "Please check your connection or try again later. If Home Assistant is restarting it will reconnect after it is back online.") }
      /// Open App settings
      public static var openSettingsButton: String { return L10n.tr("Localizable", "web_view.empty_state.open_settings_button", fallback: "Open App settings") }
      /// Retry
      public static var retryButton: String { return L10n.tr("Localizable", "web_view.empty_state.retry_button", fallback: "Retry") }
      /// You're disconnected
      public static var title: String { return L10n.tr("Localizable", "web_view.empty_state.title", fallback: "You're disconnected") }
    }
    public enum NoUrlAvailable {
      /// 🔐  Due to your security choices, there's no URL that we are allowed to use. 
      /// 
      ///  ➡️  Please open the App settings and update your security choices or URLs.
      public static var body: String { return L10n.tr("Localizable", "web_view.no_url_available.body", fallback: "🔐  Due to your security choices, there's no URL that we are allowed to use. \n\n ➡️  Please open the App settings and update your security choices or URLs.") }
      /// We can't connect to Home Assistant
      public static var title: String { return L10n.tr("Localizable", "web_view.no_url_available.title", fallback: "We can't connect to Home Assistant") }
      public enum PrimaryButton {
        /// Open App settings
        public static var title: String { return L10n.tr("Localizable", "web_view.no_url_available.primary_button.title", fallback: "Open App settings") }
      }
    }
    public enum ServerSelection {
      /// Choose server
      public static var title: String { return L10n.tr("Localizable", "web_view.server_selection.title", fallback: "Choose server") }
    }
    public enum UniqueServerSelection {
      /// Choose one server
      public static var title: String { return L10n.tr("Localizable", "web_view.unique_server_selection.title", fallback: "Choose one server") }
    }
  }
  public enum WebrtcPlayer {
    public enum KnownIssues {
      /// Known Issues
      public static var title: String { return L10n.tr("Localizable", "webrtc_player.known_issues.title", fallback: "Known Issues") }
    }
  }
  public enum Widgets {
    public enum Action {
      public enum Name {
        /// Assist
        public static var assist: String { return L10n.tr("Localizable", "widgets.action.name.assist", fallback: "Assist") }
        /// Default
        public static var `default`: String { return L10n.tr("Localizable", "widgets.action.name.default", fallback: "Default") }
        /// More info
        public static var moreInfoDialog: String { return L10n.tr("Localizable", "widgets.action.name.moreInfoDialog", fallback: "More info") }
        /// Navigate
        public static var navigate: String { return L10n.tr("Localizable", "widgets.action.name.navigate", fallback: "Navigate") }
        /// Nothing
        public static var nothing: String { return L10n.tr("Localizable", "widgets.action.name.nothing", fallback: "Nothing") }
        /// Run Script
        public static var runScript: String { return L10n.tr("Localizable", "widgets.action.name.run_script", fallback: "Run Script") }
      }
    }
    public enum Actions {
      /// Perform Home Assistant actions.
      public static var description: String { return L10n.tr("Localizable", "widgets.actions.description", fallback: "Perform Home Assistant actions.") }
      /// No Actions Configured
      public static var notConfigured: String { return L10n.tr("Localizable", "widgets.actions.not_configured", fallback: "No Actions Configured") }
      /// Actions
      public static var title: String { return L10n.tr("Localizable", "widgets.actions.title", fallback: "Actions") }
      public enum Parameters {
        /// Action
        public static var action: String { return L10n.tr("Localizable", "widgets.actions.parameters.action", fallback: "Action") }
      }
    }
    public enum Assist {
      /// Ask Assist
      public static var actionTitle: String { return L10n.tr("Localizable", "widgets.assist.action_title", fallback: "Ask Assist") }
      /// Open Assist in the app
      public static var description: String { return L10n.tr("Localizable", "widgets.assist.description", fallback: "Open Assist in the app") }
      /// Assist
      public static var title: String { return L10n.tr("Localizable", "widgets.assist.title", fallback: "Assist") }
      /// Configure
      public static var unknownConfiguration: String { return L10n.tr("Localizable", "widgets.assist.unknown_configuration", fallback: "Configure") }
    }
    public enum Automation {
      public enum Trigger {
        /// Trigger automation
        public static var title: String { return L10n.tr("Localizable", "widgets.automation.trigger.title", fallback: "Trigger automation") }
      }
    }
    public enum Automations {
      /// Run Automation
      public static var description: String { return L10n.tr("Localizable", "widgets.automations.description", fallback: "Run Automation") }
    }
    public enum Button {
      /// Reload all widgets
      public static var reloadTimeline: String { return L10n.tr("Localizable", "widgets.button.reload_timeline", fallback: "Reload all widgets") }
    }
    public enum CommonlyUsedEntities {
      /// Display your commonly used entities based on your usage patterns.
      public static var description: String { return L10n.tr("Localizable", "widgets.commonly_used_entities.description", fallback: "Display your commonly used entities based on your usage patterns.") }
      /// Common Controls
      public static var title: String { return L10n.tr("Localizable", "widgets.commonly_used_entities.title", fallback: "Common Controls") }
      public enum Empty {
        /// No commonly used entities found. Use Home Assistant to build your usage history.
        public static var description: String { return L10n.tr("Localizable", "widgets.commonly_used_entities.empty.description", fallback: "No commonly used entities found. Use Home Assistant to build your usage history.") }
      }
    }
    public enum Controls {
      public enum Assist {
        /// Open Assist in Home Assistant app
        public static var description: String { return L10n.tr("Localizable", "widgets.controls.assist.description", fallback: "Open Assist in Home Assistant app") }
        /// Assist
        public static var title: String { return L10n.tr("Localizable", "widgets.controls.assist.title", fallback: "Assist") }
        public enum Pipeline {
          /// Choose a pipeline
          public static var placeholder: String { return L10n.tr("Localizable", "widgets.controls.assist.pipeline.placeholder", fallback: "Choose a pipeline") }
        }
      }
      public enum Automation {
        /// Run automation
        public static var description: String { return L10n.tr("Localizable", "widgets.controls.automation.description", fallback: "Run automation") }
        /// Automation
        public static var displayName: String { return L10n.tr("Localizable", "widgets.controls.automation.display_name", fallback: "Automation") }
      }
      public enum Automations {
        /// Choose automation
        public static var pendingConfiguration: String { return L10n.tr("Localizable", "widgets.controls.automations.pending_configuration", fallback: "Choose automation") }
        /// Choose automation
        public static var placeholderTitle: String { return L10n.tr("Localizable", "widgets.controls.automations.placeholder_title", fallback: "Choose automation") }
      }
      public enum Button {
        /// Press button
        public static var description: String { return L10n.tr("Localizable", "widgets.controls.button.description", fallback: "Press button") }
        /// Choose button
        public static var pendingConfiguration: String { return L10n.tr("Localizable", "widgets.controls.button.pending_configuration", fallback: "Choose button") }
        /// Choose button
        public static var placeholderTitle: String { return L10n.tr("Localizable", "widgets.controls.button.placeholder_title", fallback: "Choose button") }
        /// Button
        public static var title: String { return L10n.tr("Localizable", "widgets.controls.button.title", fallback: "Button") }
      }
      public enum Cover {
        /// Toggle cover
        public static var description: String { return L10n.tr("Localizable", "widgets.controls.cover.description", fallback: "Toggle cover") }
        /// Choose cover
        public static var pendingConfiguration: String { return L10n.tr("Localizable", "widgets.controls.cover.pending_configuration", fallback: "Choose cover") }
        /// Choose cover
        public static var placeholderTitle: String { return L10n.tr("Localizable", "widgets.controls.cover.placeholder_title", fallback: "Choose cover") }
        /// Cover
        public static var title: String { return L10n.tr("Localizable", "widgets.controls.cover.title", fallback: "Cover") }
      }
      public enum Fan {
        /// Turn on/off your fan
        public static var description: String { return L10n.tr("Localizable", "widgets.controls.fan.description", fallback: "Turn on/off your fan") }
        /// Choose fan
        public static var pendingConfiguration: String { return L10n.tr("Localizable", "widgets.controls.fan.pending_configuration", fallback: "Choose fan") }
        /// Choose fan
        public static var placeholderTitle: String { return L10n.tr("Localizable", "widgets.controls.fan.placeholder_title", fallback: "Choose fan") }
        /// Fan
        public static var title: String { return L10n.tr("Localizable", "widgets.controls.fan.title", fallback: "Fan") }
      }
      public enum Light {
        /// Turn on/off your light
        public static var description: String { return L10n.tr("Localizable", "widgets.controls.light.description", fallback: "Turn on/off your light") }
        /// Choose light
        public static var pendingConfiguration: String { return L10n.tr("Localizable", "widgets.controls.light.pending_configuration", fallback: "Choose light") }
        /// Choose Light
        public static var placeholderTitle: String { return L10n.tr("Localizable", "widgets.controls.light.placeholder_title", fallback: "Choose Light") }
        /// Light
        public static var title: String { return L10n.tr("Localizable", "widgets.controls.light.title", fallback: "Light") }
      }
      public enum OpenCamera {
        /// Opens the selected camera entity inside the app
        public static var description: String { return L10n.tr("Localizable", "widgets.controls.open_camera.description", fallback: "Opens the selected camera entity inside the app") }
        /// Choose camera
        public static var pendingConfiguration: String { return L10n.tr("Localizable", "widgets.controls.open_camera.pending_configuration", fallback: "Choose camera") }
        public enum Configuration {
          /// Open Camera
          public static var title: String { return L10n.tr("Localizable", "widgets.controls.open_camera.configuration.title", fallback: "Open Camera") }
          public enum Parameter {
            /// Camera
            public static var entity: String { return L10n.tr("Localizable", "widgets.controls.open_camera.configuration.parameter.entity", fallback: "Camera") }
          }
        }
      }
      public enum OpenCamerasList {
        /// Opens a list of all cameras
        public static var description: String { return L10n.tr("Localizable", "widgets.controls.open_cameras_list.description", fallback: "Opens a list of all cameras") }
      }
      public enum OpenCover {
        /// Opens the selected cover entity inside the app
        public static var description: String { return L10n.tr("Localizable", "widgets.controls.open_cover.description", fallback: "Opens the selected cover entity inside the app") }
        public enum Configuration {
          /// Open Cover
          public static var title: String { return L10n.tr("Localizable", "widgets.controls.open_cover.configuration.title", fallback: "Open Cover") }
          public enum Parameter {
            /// Cover
            public static var entity: String { return L10n.tr("Localizable", "widgets.controls.open_cover.configuration.parameter.entity", fallback: "Cover") }
          }
        }
      }
      public enum OpenCoverEntity {
        /// Choose cover
        public static var pendingConfiguration: String { return L10n.tr("Localizable", "widgets.controls.open_cover_entity.pending_configuration", fallback: "Choose cover") }
      }
      public enum OpenEntity {
        /// Choose entity
        public static var pendingConfiguration: String { return L10n.tr("Localizable", "widgets.controls.open_entity.pending_configuration", fallback: "Choose entity") }
        public enum Configuration {
          /// Open Entity
          public static var title: String { return L10n.tr("Localizable", "widgets.controls.open_entity.configuration.title", fallback: "Open Entity") }
          public enum Parameter {
            /// Entity
            public static var entity: String { return L10n.tr("Localizable", "widgets.controls.open_entity.configuration.parameter.entity", fallback: "Entity") }
          }
        }
      }
      public enum OpenExperimentalDashboard {
        /// Opens the experimental dashboard for the selected server
        public static var description: String { return L10n.tr("Localizable", "widgets.controls.open_experimental_dashboard.description", fallback: "Opens the experimental dashboard for the selected server") }
        public enum Configuration {
          /// Open Experimental Dashboard
          public static var title: String { return L10n.tr("Localizable", "widgets.controls.open_experimental_dashboard.configuration.title", fallback: "Open Experimental Dashboard") }
          public enum Parameter {
            /// Server
            public static var server: String { return L10n.tr("Localizable", "widgets.controls.open_experimental_dashboard.configuration.parameter.server", fallback: "Server") }
          }
        }
      }
      public enum OpenInputBoolean {
        /// Opens the selected input boolean entity inside the app
        public static var description: String { return L10n.tr("Localizable", "widgets.controls.open_input_boolean.description", fallback: "Opens the selected input boolean entity inside the app") }
        /// Choose input boolean
        public static var pendingConfiguration: String { return L10n.tr("Localizable", "widgets.controls.open_input_boolean.pending_configuration", fallback: "Choose input boolean") }
        public enum Configuration {
          /// Open Input Boolean
          public static var title: String { return L10n.tr("Localizable", "widgets.controls.open_input_boolean.configuration.title", fallback: "Open Input Boolean") }
          public enum Parameter {
            /// Input Boolean
            public static var entity: String { return L10n.tr("Localizable", "widgets.controls.open_input_boolean.configuration.parameter.entity", fallback: "Input Boolean") }
          }
        }
      }
      public enum OpenLight {
        /// Opens the selected light entity inside the app
        public static var description: String { return L10n.tr("Localizable", "widgets.controls.open_light.description", fallback: "Opens the selected light entity inside the app") }
        /// Choose light
        public static var pendingConfiguration: String { return L10n.tr("Localizable", "widgets.controls.open_light.pending_configuration", fallback: "Choose light") }
        public enum Configuration {
          /// Open Light
          public static var title: String { return L10n.tr("Localizable", "widgets.controls.open_light.configuration.title", fallback: "Open Light") }
          public enum Parameter {
            /// Light
            public static var entity: String { return L10n.tr("Localizable", "widgets.controls.open_light.configuration.parameter.entity", fallback: "Light") }
          }
        }
      }
      public enum OpenLock {
        /// Opens the selected lock entity inside the app
        public static var description: String { return L10n.tr("Localizable", "widgets.controls.open_lock.description", fallback: "Opens the selected lock entity inside the app") }
        /// Choose lock
        public static var pendingConfiguration: String { return L10n.tr("Localizable", "widgets.controls.open_lock.pending_configuration", fallback: "Choose lock") }
        public enum Configuration {
          /// Open Lock
          public static var title: String { return L10n.tr("Localizable", "widgets.controls.open_lock.configuration.title", fallback: "Open Lock") }
          public enum Parameter {
            /// Lock
            public static var entity: String { return L10n.tr("Localizable", "widgets.controls.open_lock.configuration.parameter.entity", fallback: "Lock") }
          }
        }
      }
      public enum OpenPage {
        /// Choose page
        public static var pendingConfiguration: String { return L10n.tr("Localizable", "widgets.controls.open_page.pending_configuration", fallback: "Choose page") }
        public enum Configuration {
          /// Open Page
          public static var title: String { return L10n.tr("Localizable", "widgets.controls.open_page.configuration.title", fallback: "Open Page") }
          public enum Parameter {
            /// Page
            public static var page: String { return L10n.tr("Localizable", "widgets.controls.open_page.configuration.parameter.page", fallback: "Page") }
          }
        }
      }
      public enum OpenSensor {
        /// Opens the selected sensor entity inside the app
        public static var description: String { return L10n.tr("Localizable", "widgets.controls.open_sensor.description", fallback: "Opens the selected sensor entity inside the app") }
        /// Choose sensor
        public static var pendingConfiguration: String { return L10n.tr("Localizable", "widgets.controls.open_sensor.pending_configuration", fallback: "Choose sensor") }
        public enum Configuration {
          /// Open Sensor
          public static var title: String { return L10n.tr("Localizable", "widgets.controls.open_sensor.configuration.title", fallback: "Open Sensor") }
          public enum Parameter {
            /// Sensor
            public static var entity: String { return L10n.tr("Localizable", "widgets.controls.open_sensor.configuration.parameter.entity", fallback: "Sensor") }
          }
        }
      }
      public enum OpenSwitch {
        /// Opens the selected switch entity inside the app
        public static var description: String { return L10n.tr("Localizable", "widgets.controls.open_switch.description", fallback: "Opens the selected switch entity inside the app") }
        /// Choose switch
        public static var pendingConfiguration: String { return L10n.tr("Localizable", "widgets.controls.open_switch.pending_configuration", fallback: "Choose switch") }
        public enum Configuration {
          /// Open Switch
          public static var title: String { return L10n.tr("Localizable", "widgets.controls.open_switch.configuration.title", fallback: "Open Switch") }
          public enum Parameter {
            /// Switch
            public static var entity: String { return L10n.tr("Localizable", "widgets.controls.open_switch.configuration.parameter.entity", fallback: "Switch") }
          }
        }
      }
      public enum Scene {
        /// Run scene
        public static var description: String { return L10n.tr("Localizable", "widgets.controls.scene.description", fallback: "Run scene") }
        /// Scene
        public static var displayName: String { return L10n.tr("Localizable", "widgets.controls.scene.display_name", fallback: "Scene") }
      }
      public enum Scenes {
        /// Choose scene
        public static var pendingConfiguration: String { return L10n.tr("Localizable", "widgets.controls.scenes.pending_configuration", fallback: "Choose scene") }
        /// Choose scene
        public static var placeholderTitle: String { return L10n.tr("Localizable", "widgets.controls.scenes.placeholder_title", fallback: "Choose scene") }
      }
      public enum Script {
        /// Run script
        public static var description: String { return L10n.tr("Localizable", "widgets.controls.script.description", fallback: "Run script") }
        /// Script
        public static var displayName: String { return L10n.tr("Localizable", "widgets.controls.script.display_name", fallback: "Script") }
      }
      public enum Scripts {
        /// Choose script
        public static var pendingConfiguration: String { return L10n.tr("Localizable", "widgets.controls.scripts.pending_configuration", fallback: "Choose script") }
        /// Choose script
        public static var placeholderTitle: String { return L10n.tr("Localizable", "widgets.controls.scripts.placeholder_title", fallback: "Choose script") }
      }
      public enum Switch {
        /// Turn on/off your switch
        public static var description: String { return L10n.tr("Localizable", "widgets.controls.switch.description", fallback: "Turn on/off your switch") }
        /// Choose switch
        public static var pendingConfiguration: String { return L10n.tr("Localizable", "widgets.controls.switch.pending_configuration", fallback: "Choose switch") }
        /// Choose switch
        public static var placeholderTitle: String { return L10n.tr("Localizable", "widgets.controls.switch.placeholder_title", fallback: "Choose switch") }
        /// Switch
        public static var title: String { return L10n.tr("Localizable", "widgets.controls.switch.title", fallback: "Switch") }
      }
    }
    public enum Custom {
      /// Create widgets with your own style
      public static var subtitle: String { return L10n.tr("Localizable", "widgets.custom.subtitle", fallback: "Create widgets with your own style") }
      /// Custom widgets
      public static var title: String { return L10n.tr("Localizable", "widgets.custom.title", fallback: "Custom widgets") }
      public enum IntentActivateFailed {
        /// Please try again
        public static var body: String { return L10n.tr("Localizable", "widgets.custom.intent_activate_failed.body", fallback: "Please try again") }
        /// Failed to 'activate' entity
        public static var title: String { return L10n.tr("Localizable", "widgets.custom.intent_activate_failed.title", fallback: "Failed to 'activate' entity") }
      }
      public enum IntentPressFailed {
        /// Please try again
        public static var body: String { return L10n.tr("Localizable", "widgets.custom.intent_press_failed.body", fallback: "Please try again") }
        /// Failed to 'press' entity
        public static var title: String { return L10n.tr("Localizable", "widgets.custom.intent_press_failed.title", fallback: "Failed to 'press' entity") }
      }
      public enum IntentToggleFailed {
        /// Please try again
        public static var body: String { return L10n.tr("Localizable", "widgets.custom.intent_toggle_failed.body", fallback: "Please try again") }
        /// Failed to 'toggle' entity
        public static var title: String { return L10n.tr("Localizable", "widgets.custom.intent_toggle_failed.title", fallback: "Failed to 'toggle' entity") }
      }
      public enum RequireConfirmation {
        /// Widget confirmation and state display are currently in BETA, if you experience issues please disable 'Require confirmation' and save.
        public static var footer: String { return L10n.tr("Localizable", "widgets.custom.require_confirmation.footer", fallback: "Widget confirmation and state display are currently in BETA, if you experience issues please disable 'Require confirmation' and save.") }
      }
      public enum ShowLastUpdateTime {
        public enum Param {
          /// Show last update time
          public static var title: String { return L10n.tr("Localizable", "widgets.custom.show_last_update_time.param.title", fallback: "Show last update time") }
        }
      }
      public enum ShowStates {
        /// Displaying latest states is not 100% guaranteed, you can give it a try and check the companion App documentation for more information.
        public static func description(_ p1: Float) -> String {
          return L10n.tr("Localizable", "widgets.custom.show_states.description", p1, fallback: "Displaying latest states is not 100% guaranteed, you can give it a try and check the companion App documentation for more information.")
        }
        public enum Param {
          /// Show states (BETA)
          public static var title: String { return L10n.tr("Localizable", "widgets.custom.show_states.param.title", fallback: "Show states (BETA)") }
        }
      }
      public enum ShowUpdateTime {
        /// Last update:
        public static var title: String { return L10n.tr("Localizable", "widgets.custom.show_update_time.title", fallback: "Last update:") }
      }
    }
    public enum Details {
      /// Display states using from Home Assistant in text
      public static var description: String { return L10n.tr("Localizable", "widgets.details.description", fallback: "Display states using from Home Assistant in text") }
      /// Display states using from Home Assistant in text. ATTENTION: User needs to be admin for templating access
      public static var descriptionWithWarning: String { return L10n.tr("Localizable", "widgets.details.description_with_warning", fallback: "Display states using from Home Assistant in text. ATTENTION: User needs to be admin for templating access") }
      /// Details
      public static var title: String { return L10n.tr("Localizable", "widgets.details.title", fallback: "Details") }
      public enum Parameters {
        /// Action
        public static var action: String { return L10n.tr("Localizable", "widgets.details.parameters.action", fallback: "Action") }
        /// Details Text Template (only in rectangular family)
        public static var detailsTemplate: String { return L10n.tr("Localizable", "widgets.details.parameters.details_template", fallback: "Details Text Template (only in rectangular family)") }
        /// Lower Text Template
        public static var lowerTemplate: String { return L10n.tr("Localizable", "widgets.details.parameters.lower_template", fallback: "Lower Text Template") }
        /// Run Script (only in rectangular family)
        public static var runScript: String { return L10n.tr("Localizable", "widgets.details.parameters.run_script", fallback: "Run Script (only in rectangular family)") }
        /// Script
        public static var script: String { return L10n.tr("Localizable", "widgets.details.parameters.script", fallback: "Script") }
        /// Server
        public static var server: String { return L10n.tr("Localizable", "widgets.details.parameters.server", fallback: "Server") }
        /// Upper Text Template
        public static var upperTemplate: String { return L10n.tr("Localizable", "widgets.details.parameters.upper_template", fallback: "Upper Text Template") }
      }
    }
    public enum EntityState {
      /// Entity state
      public static var placeholder: String { return L10n.tr("Localizable", "widgets.entity_state.placeholder", fallback: "Entity state") }
    }
    public enum Gauge {
      /// Display numeric states from Home Assistant in a gauge
      public static var description: String { return L10n.tr("Localizable", "widgets.gauge.description", fallback: "Display numeric states from Home Assistant in a gauge") }
      /// Display numeric states from Home Assistant in a gauge. ATTENTION: User needs to be admin for templating access
      public static var descriptionWithWarning: String { return L10n.tr("Localizable", "widgets.gauge.description_with_warning", fallback: "Display numeric states from Home Assistant in a gauge. ATTENTION: User needs to be admin for templating access") }
      /// Gauge
      public static var title: String { return L10n.tr("Localizable", "widgets.gauge.title", fallback: "Gauge") }
      public enum Parameters {
        /// Action
        public static var action: String { return L10n.tr("Localizable", "widgets.gauge.parameters.action", fallback: "Action") }
        /// Gauge Type
        public static var gaugeType: String { return L10n.tr("Localizable", "widgets.gauge.parameters.gauge_type", fallback: "Gauge Type") }
        /// Max Label Template
        public static var maxLabelTemplate: String { return L10n.tr("Localizable", "widgets.gauge.parameters.max_label_template", fallback: "Max Label Template") }
        /// Min Label Template
        public static var minLabelTemplate: String { return L10n.tr("Localizable", "widgets.gauge.parameters.min_label_template", fallback: "Min Label Template") }
        /// Run Script
        public static var runScript: String { return L10n.tr("Localizable", "widgets.gauge.parameters.run_script", fallback: "Run Script") }
        /// Script
        public static var script: String { return L10n.tr("Localizable", "widgets.gauge.parameters.script", fallback: "Script") }
        /// Server
        public static var server: String { return L10n.tr("Localizable", "widgets.gauge.parameters.server", fallback: "Server") }
        /// Value Label Template
        public static var valueLabelTemplate: String { return L10n.tr("Localizable", "widgets.gauge.parameters.value_label_template", fallback: "Value Label Template") }
        /// Value Template (0-1)
        public static var valueTemplate: String { return L10n.tr("Localizable", "widgets.gauge.parameters.value_template", fallback: "Value Template (0-1)") }
        public enum GaugeType {
          /// Capacity
          public static var capacity: String { return L10n.tr("Localizable", "widgets.gauge.parameters.gauge_type.capacity", fallback: "Capacity") }
          /// Normal
          public static var normal: String { return L10n.tr("Localizable", "widgets.gauge.parameters.gauge_type.normal", fallback: "Normal") }
        }
      }
    }
    public enum Lights {
      /// Turn on/off light
      public static var description: String { return L10n.tr("Localizable", "widgets.lights.description", fallback: "Turn on/off light") }
    }
    public enum OpenEntity {
      /// Open Entity
      public static var title: String { return L10n.tr("Localizable", "widgets.open_entity.title", fallback: "Open Entity") }
    }
    public enum OpenPage {
      /// Open a frontend page in Home Assistant.
      public static var description: String { return L10n.tr("Localizable", "widgets.open_page.description", fallback: "Open a frontend page in Home Assistant.") }
      /// No Pages Available
      public static var notConfigured: String { return L10n.tr("Localizable", "widgets.open_page.not_configured", fallback: "No Pages Available") }
      /// Open Page
      public static var title: String { return L10n.tr("Localizable", "widgets.open_page.title", fallback: "Open Page") }
    }
    public enum Param {
      public enum Server {
        /// Server
        public static var title: String { return L10n.tr("Localizable", "widgets.param.server.title", fallback: "Server") }
      }
    }
    public enum Preview {
      public enum Custom {
        /// Create your own widget inside the App and then display it here.
        public static var description: String { return L10n.tr("Localizable", "widgets.preview.custom.description", fallback: "Create your own widget inside the App and then display it here.") }
        /// Custom widget
        public static var title: String { return L10n.tr("Localizable", "widgets.preview.custom.title", fallback: "Custom widget") }
      }
      public enum Empty {
        public enum Create {
          /// Create widget
          public static var button: String { return L10n.tr("Localizable", "widgets.preview.empty.create.button", fallback: "Create widget") }
        }
      }
    }
    public enum ReloadWidgets {
      public enum AppIntent {
        /// Reload all widgets timelines.
        public static var description: String { return L10n.tr("Localizable", "widgets.reload_widgets.app_intent.description", fallback: "Reload all widgets timelines.") }
        /// Reload widgets
        public static var title: String { return L10n.tr("Localizable", "widgets.reload_widgets.app_intent.title", fallback: "Reload widgets") }
      }
    }
    public enum Scene {
      public enum Activate {
        /// Activate scene
        public static var title: String { return L10n.tr("Localizable", "widgets.scene.activate.title", fallback: "Activate scene") }
      }
      public enum Description {
        /// Run Scene
        public static var title: String { return L10n.tr("Localizable", "widgets.scene.description.title", fallback: "Run Scene") }
      }
    }
    public enum Scripts {
      /// Run Scripts
      public static var description: String { return L10n.tr("Localizable", "widgets.scripts.description", fallback: "Run Scripts") }
      /// No Scripts Configured
      public static var notConfigured: String { return L10n.tr("Localizable", "widgets.scripts.not_configured", fallback: "No Scripts Configured") }
      /// Scripts
      public static var title: String { return L10n.tr("Localizable", "widgets.scripts.title", fallback: "Scripts") }
    }
    public enum Sensors {
      /// Display state of sensors
      public static var description: String { return L10n.tr("Localizable", "widgets.sensors.description", fallback: "Display state of sensors") }
      /// No Sensors Configured
      public static var notConfigured: String { return L10n.tr("Localizable", "widgets.sensors.not_configured", fallback: "No Sensors Configured") }
      /// Sensors
      public static var title: String { return L10n.tr("Localizable", "widgets.sensors.title", fallback: "Sensors") }
    }
    public enum TodoList {
      /// All done! 🎉
      public static var allDone: String { return L10n.tr("Localizable", "widgets.todo_list.all_done", fallback: "All done! 🎉") }
      /// Complete To-do Item
      public static var completeItemTitle: String { return L10n.tr("Localizable", "widgets.todo_list.complete_item_title", fallback: "Complete To-do Item") }
      /// Check your lists and add items
      public static var description: String { return L10n.tr("Localizable", "widgets.todo_list.description", fallback: "Check your lists and add items") }
      /// Refresh To-do List
      public static var refreshTitle: String { return L10n.tr("Localizable", "widgets.todo_list.refresh_title", fallback: "Refresh To-do List") }
      /// Edit widget to select list.
      public static var selectList: String { return L10n.tr("Localizable", "widgets.todo_list.select_list", fallback: "Edit widget to select list.") }
      /// To-do List
      public static var title: String { return L10n.tr("Localizable", "widgets.todo_list.title", fallback: "To-do List") }
      public enum DueDate {
        /// %@ ago
        public static func agoFormat(_ p1: Any) -> String {
          return L10n.tr("Localizable", "widgets.todo_list.due_date.ago_format", String(describing: p1), fallback: "%@ ago")
        }
        /// In %@
        public static func inFormat(_ p1: Any) -> String {
          return L10n.tr("Localizable", "widgets.todo_list.due_date.in_format", String(describing: p1), fallback: "In %@")
        }
        /// Now
        public static var now: String { return L10n.tr("Localizable", "widgets.todo_list.due_date.now", fallback: "Now") }
        /// Today
        public static var today: String { return L10n.tr("Localizable", "widgets.todo_list.due_date.today", fallback: "Today") }
      }
      public enum Parameter {
        /// Item ID
        public static var itemId: String { return L10n.tr("Localizable", "widgets.todo_list.parameter.item_id", fallback: "Item ID") }
        /// List
        public static var list: String { return L10n.tr("Localizable", "widgets.todo_list.parameter.list", fallback: "List") }
        /// List ID
        public static var listId: String { return L10n.tr("Localizable", "widgets.todo_list.parameter.list_id", fallback: "List ID") }
        /// Server
        public static var server: String { return L10n.tr("Localizable", "widgets.todo_list.parameter.server", fallback: "Server") }
        /// Server ID
        public static var serverId: String { return L10n.tr("Localizable", "widgets.todo_list.parameter.server_id", fallback: "Server ID") }
      }
    }
  }
}
// swiftlint:enable explicit_type_interface function_parameter_count identifier_name line_length
// swiftlint:enable nesting type_body_length type_name vertical_whitespace_opening_braces

// MARK: - Implementation Details

extension L10n {
  private static func tr(_ table: String, _ key: String, _ args: CVarArg..., fallback value: String) -> String {
    let format = Current.localized.string(key, table, value)
    return String(format: format, locale: Locale.current, arguments: args)
  }
}
