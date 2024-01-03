// swiftlint:disable all
// Generated using SwiftGen — https://github.com/SwiftGen/SwiftGen

import Foundation

// swiftlint:disable superfluous_disable_command file_length implicit_return

// MARK: - Strings

// swiftlint:disable explicit_type_interface function_parameter_count identifier_name line_length
// swiftlint:disable nesting type_body_length type_name vertical_whitespace_opening_braces
public enum CoreStrings {
  /// Button
  public static var componentButtonTitle: String { return CoreStrings.tr("Core", "component::button::title") }
  /// Cover
  public static var componentCoverTitle: String { return CoreStrings.tr("Core", "component::cover::title") }
  /// Input boolean
  public static var componentInputBooleanTitle: String { return CoreStrings.tr("Core", "component::input_boolean::title") }
  /// Input button
  public static var componentInputButtonTitle: String { return CoreStrings.tr("Core", "component::input_button::title") }
  /// Light
  public static var componentLightTitle: String { return CoreStrings.tr("Core", "component::light::title") }
  /// Lock
  public static var componentLockTitle: String { return CoreStrings.tr("Core", "component::lock::title") }
  /// Scene
  public static var componentSceneTitle: String { return CoreStrings.tr("Core", "component::scene::title") }
  /// Script
  public static var componentScriptTitle: String { return CoreStrings.tr("Core", "component::script::title") }
  /// Switch
  public static var componentSwitchTitle: String { return CoreStrings.tr("Core", "component::switch::title") }
}
// swiftlint:enable explicit_type_interface function_parameter_count identifier_name line_length
// swiftlint:enable nesting type_body_length type_name vertical_whitespace_opening_braces

// MARK: - Implementation Details

extension CoreStrings {
  private static func tr(_ table: String, _ key: String, _ args: CVarArg...) -> String {
    let format = Current.localized.string(key, table)
    return String(format: format, locale: Locale.current, arguments: args)
  }
}
