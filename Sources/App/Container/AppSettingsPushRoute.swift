import Foundation

/// The only destination the container's own navigation stack pushes: app Settings, opened by the frontend
/// external bus. Every screen below it is pushed by `SettingsView` as a `SettingsItem` onto the same path, so
/// the whole stack is value-driven — a boolean `navigationDestination(isPresented:)` sharing a stack with
/// value-based destinations makes SwiftUI resolve the wrong view for the pushes that follow it.
enum AppSettingsPushRoute: Hashable {
    case settings
}
