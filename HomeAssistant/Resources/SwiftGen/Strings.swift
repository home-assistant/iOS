// Generated using SwiftGen, by O.Halligon — https://github.com/AliSoftware/SwiftGen

import Foundation

// swiftlint:disable file_length
// swiftlint:disable line_length

// swiftlint:disable type_body_length
// swiftlint:disable nesting
// swiftlint:disable variable_name
// swiftlint:disable valid_docs

enum L10n {

  enum LocationChangeNotification {
    /// Location change
    static let title = L10n.tr("location_change_notification.title")
  }

  enum ManualLocationUpdateFailedNotification {
    /// Failed to send current location to server. The error was %@
    static func message(_ p1: String) -> String {
      return L10n.tr("manual_location_update_failed_notification.message", p1)
    }
    /// Location failed to update
    static let title = L10n.tr("manual_location_update_failed_notification.title")
  }

  enum ManualLocationUpdateNotification {
    /// Successfully sent a one shot location to the server
    static let message = L10n.tr("manual_location_update_notification.message")
    /// Location updated
    static let title = L10n.tr("manual_location_update_notification.title")
  }

  enum Permissions {

    enum Location {
      /// We use this to inform\r\nHome Assistant of your device location and state.
      static let message = L10n.tr("permissions.location.message")
    }

    enum Notification {
      /// We use this to let you\r\nsend notifications to your device.
      static let message = L10n.tr("permissions.notification.message")
    }
  }

  enum Settings {

    enum CertificateErrorNotification {
      /// A self-signed or invalid SSL certificate has been detected. Certificates of this kind are not supported by Home Assistant for iOS. Please tap the More Info button for further information.
      static let message = L10n.tr("settings.certificate_error_notification.message")
      /// Self-signed or invalid certificate detected
      static let title = L10n.tr("settings.certificate_error_notification.title")
    }

    enum ConnectionErrorNotification {
      /// There was an error connecting to Home Assistant. Please confirm the settings are correct and save to attempt to reconnect. The error was:\n\n %@
      static func message(_ p1: String) -> String {
        return L10n.tr("settings.connection_error_notification.message", p1)
      }
      /// Connection Error
      static let title = L10n.tr("settings.connection_error_notification.title")
    }

    enum ConnectionSection {
      /// Connection
      static let header = L10n.tr("settings.connection_section.header")

      enum ApiPasswordRow {
        /// password
        static let placeholder = L10n.tr("settings.connection_section.api_password_row.placeholder")
        /// Password
        static let title = L10n.tr("settings.connection_section.api_password_row.title")
      }

      enum ConnectRow {
        /// Connect
        static let title = L10n.tr("settings.connection_section.connect_row.title")
      }

      enum InvalidUrlSchemeNotification {
        /// The URL must begin with either http:// or https://.
        static let message = L10n.tr("settings.connection_section.invalid_url_scheme_notification.message")
        /// Invalid URL
        static let title = L10n.tr("settings.connection_section.invalid_url_scheme_notification.title")
      }
    }

    enum DetailsSection {

      enum EnableLocationRow {
        /// Enable location tracking
        static let title = L10n.tr("settings.details_section.enable_location_row.title")
      }

      enum EnableNotificationRow {
        /// Enable notifications
        static let title = L10n.tr("settings.details_section.enable_notification_row.title")
      }

      enum LocationSettingsRow {
        /// Location Settings
        static let title = L10n.tr("settings.details_section.location_settings_row.title")
      }

      enum NotificationSettingsRow {
        /// Notification Settings
        static let title = L10n.tr("settings.details_section.notification_settings_row.title")
      }
    }

    enum DeviceIdSection {
      /// Device ID is the identifier used when sending location updates to Home Assistant, as well as the target to send push notifications to.
      static let footer = L10n.tr("settings.device_id_section.footer")

      enum DeviceIdRow {
        /// Device ID
        static let title = L10n.tr("settings.device_id_section.device_id_row.title")
      }
    }

    enum DiscoverySection {
      /// Discovered Home Assistants
      static let header = L10n.tr("settings.discovery_section.header")
    }

    enum ResetSection {

      enum ResetAlert {
        /// Your settings will be reset and this device will be unregistered from push notifications as well as removed from your Home Assistant configuration.
        static let message = L10n.tr("settings.reset_section.reset_alert.message")
        /// Reset
        static let title = L10n.tr("settings.reset_section.reset_alert.title")
      }

      enum ResetRow {
        /// Reset
        static let title = L10n.tr("settings.reset_section.reset_row.title")
      }
    }

    enum StatusSection {
      /// Status
      static let header = L10n.tr("settings.status_section.header")

      enum ConnectedToSseRow {
        /// Connected
        static let title = L10n.tr("settings.status_section.connected_to_sse_row.title")
      }

      enum DeviceTrackerComponentLoadedRow {
        /// Device Tracker Component Loaded
        static let title = L10n.tr("settings.status_section.device_tracker_component_loaded_row.title")
      }

      enum IosComponentLoadedRow {
        /// iOS Component Loaded
        static let title = L10n.tr("settings.status_section.ios_component_loaded_row.title")
      }

      enum LocationNameRow {
        /// My Home Assistant
        static let placeholder = L10n.tr("settings.status_section.location_name_row.placeholder")
        /// Name
        static let title = L10n.tr("settings.status_section.location_name_row.title")
      }

      enum NotifyPlatformLoadedRow {
        /// iOS Notify Platform Loaded
        static let title = L10n.tr("settings.status_section.notify_platform_loaded_row.title")
      }

      enum VersionRow {
        /// 0.35.0
        static let placeholder = L10n.tr("settings.status_section.version_row.placeholder")
        /// Version
        static let title = L10n.tr("settings.status_section.version_row.title")
      }
    }
  }

  enum SignificantLocationChangeNotification {
    /// Significant location change detected, notifying Home Assistant
    static let message = L10n.tr("significant_location_change_notification.message")
  }

  enum ZoneEnteredNotification {
    /// %@ entered
    static func message(_ p1: String) -> String {
      return L10n.tr("zone_entered_notification.message", p1)
    }
  }
}

extension L10n {
  fileprivate static func tr(_ key: String, _ args: CVarArg...) -> String {
    let format = NSLocalizedString(key, comment: "")
    return String(format: format, locale: Locale.current, arguments: args)
  }
}

// swiftlint:enable type_body_length
// swiftlint:enable nesting
// swiftlint:enable variable_name
// swiftlint:enable valid_docs
