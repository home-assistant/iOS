import Foundation

/// Every destination the container's navigation stack (driven by `AppSettingsPresenter.pushPath`)
/// pushes: app Settings (opened by the frontend external bus) and the screens `SettingsView` pushes
/// below it, wrapped in `item`. The stack is deliberately value-driven — presenting Settings through a
/// boolean `navigationDestination(isPresented:)` previously made SwiftUI resolve the wrong view for the
/// value-based pushes that followed it — and single-typed: SwiftUI's path diffing fatally errors
/// (`AnyNavigationPath.Error.comparisonTypeMismatch`) if it ever compares path elements of different
/// types at the same position, so `SettingsItem` is never appended to the path directly.
enum AppSettingsPushRoute: Hashable {
    case settings
    case item(SettingsItem)
}
