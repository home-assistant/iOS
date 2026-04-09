// swiftlint:disable all
// Generated using SwiftGen — https://github.com/SwiftGen/SwiftGen

import Foundation

// swiftlint:disable superfluous_disable_command file_length implicit_return prefer_self_in_static_references

// MARK: - Strings

// swiftlint:disable explicit_type_interface function_parameter_count identifier_name line_length
// swiftlint:disable nesting type_body_length type_name vertical_whitespace_opening_braces
public enum FrontendStrings {
  /// Calendar
  public static var panelCalendar: String { return FrontendStrings.tr("Frontend", "panel::calendar", fallback: "Calendar") }
  /// Settings
  public static var panelConfig: String { return FrontendStrings.tr("Frontend", "panel::config", fallback: "Settings") }
  /// Developer tools
  public static var panelDeveloperTools: String { return FrontendStrings.tr("Frontend", "panel::developer_tools", fallback: "Developer tools") }
  /// Energy
  public static var panelEnergy: String { return FrontendStrings.tr("Frontend", "panel::energy", fallback: "Energy") }
  /// History
  public static var panelHistory: String { return FrontendStrings.tr("Frontend", "panel::history", fallback: "History") }
  /// Activity
  public static var panelLogbook: String { return FrontendStrings.tr("Frontend", "panel::logbook", fallback: "Activity") }
  /// Mailbox
  public static var panelMailbox: String { return FrontendStrings.tr("Frontend", "panel::mailbox", fallback: "Mailbox") }
  /// Map
  public static var panelMap: String { return FrontendStrings.tr("Frontend", "panel::map", fallback: "Map") }
  /// Media
  public static var panelMediaBrowser: String { return FrontendStrings.tr("Frontend", "panel::media_browser", fallback: "Media") }
  /// Profile
  public static var panelProfile: String { return FrontendStrings.tr("Frontend", "panel::profile", fallback: "Profile") }
  /// Shopping list
  public static var panelShoppingList: String { return FrontendStrings.tr("Frontend", "panel::shopping_list", fallback: "Shopping list") }
  /// Overview
  public static var panelStates: String { return FrontendStrings.tr("Frontend", "panel::states", fallback: "Overview") }
  /// Unavailable
  public static var stateDefaultUnavailable: String { return FrontendStrings.tr("Frontend", "state::default::unavailable", fallback: "Unavailable") }
  /// Unknown
  public static var stateDefaultUnknown: String { return FrontendStrings.tr("Frontend", "state::default::unknown", fallback: "Unknown") }
}
// swiftlint:enable explicit_type_interface function_parameter_count identifier_name line_length
// swiftlint:enable nesting type_body_length type_name vertical_whitespace_opening_braces

// MARK: - Implementation Details

extension FrontendStrings {
  private static func tr(_ table: String, _ key: String, _ args: CVarArg..., fallback value: String) -> String {
    let format = Current.localized.string(key, table, value)
    return String(format: format, locale: Locale.current, arguments: args)
  }
}
