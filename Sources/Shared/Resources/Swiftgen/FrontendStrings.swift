// swiftlint:disable all
// Generated using SwiftGen — https://github.com/SwiftGen/SwiftGen

import Foundation

// swiftlint:disable superfluous_disable_command file_length implicit_return

// MARK: - Strings

// swiftlint:disable explicit_type_interface function_parameter_count identifier_name line_length
// swiftlint:disable nesting type_body_length type_name vertical_whitespace_opening_braces
public enum FrontendStrings {
  /// Calendar
  public static var panelCalendar: String { return FrontendStrings.tr("Frontend", "panel::calendar") }
  /// Settings
  public static var panelConfig: String { return FrontendStrings.tr("Frontend", "panel::config") }
  /// Developer tools
  public static var panelDeveloperTools: String { return FrontendStrings.tr("Frontend", "panel::developer_tools") }
  /// Energy
  public static var panelEnergy: String { return FrontendStrings.tr("Frontend", "panel::energy") }
  /// History
  public static var panelHistory: String { return FrontendStrings.tr("Frontend", "panel::history") }
  /// Logbook
  public static var panelLogbook: String { return FrontendStrings.tr("Frontend", "panel::logbook") }
  /// Mailbox
  public static var panelMailbox: String { return FrontendStrings.tr("Frontend", "panel::mailbox") }
  /// Map
  public static var panelMap: String { return FrontendStrings.tr("Frontend", "panel::map") }
  /// Media
  public static var panelMediaBrowser: String { return FrontendStrings.tr("Frontend", "panel::media_browser") }
  /// Profile
  public static var panelProfile: String { return FrontendStrings.tr("Frontend", "panel::profile") }
  /// Shopping list
  public static var panelShoppingList: String { return FrontendStrings.tr("Frontend", "panel::shopping_list") }
  /// Overview
  public static var panelStates: String { return FrontendStrings.tr("Frontend", "panel::states") }
  /// Unavailable
  public static var stateDefaultUnavailable: String { return FrontendStrings.tr("Frontend", "state::default::unavailable") }
  /// Unknown
  public static var stateDefaultUnknown: String { return FrontendStrings.tr("Frontend", "state::default::unknown") }
}
// swiftlint:enable explicit_type_interface function_parameter_count identifier_name line_length
// swiftlint:enable nesting type_body_length type_name vertical_whitespace_opening_braces

// MARK: - Implementation Details

extension FrontendStrings {
  private static func tr(_ table: String, _ key: String, _ args: CVarArg...) -> String {
    let format = Current.localized.string(key, table)
    return String(format: format, locale: Locale.current, arguments: args)
  }
}
