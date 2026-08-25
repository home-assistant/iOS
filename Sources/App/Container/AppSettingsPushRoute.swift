import Foundation

/// Every destination the container's own navigation stack pushes: app Settings (opened by the frontend
/// external bus) and the screens `SettingsView` pushes below it, wrapped in `item`. The whole stack is
/// value-driven — a boolean `navigationDestination(isPresented:)` sharing a stack with value-based
/// destinations makes SwiftUI resolve the wrong view for the pushes that follow it — and single-typed:
/// SwiftUI's path diffing fatally errors (`AnyNavigationPath.Error.comparisonTypeMismatch`) if it ever
/// compares path elements of different types at the same position, so `SettingsItem` is never appended
/// to the path directly.
enum AppSettingsPushRoute: Hashable {
    case settings
    case item(SettingsItem)
}
