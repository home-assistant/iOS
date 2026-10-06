import SwiftUI

/// Carries the scene's `AppSettingsPresenter` down to everything that opens or closes app Settings. Each
/// window has its own presenter (`ConditionalContainerView` owns it), so a request has to reach the one
/// belonging to the window it came from rather than a shared instance every window would react to.
/// Nil outside a container scene — the Mac Settings window and previews host Settings on their own.
private struct AppSettingsPresenterKey: EnvironmentKey {
    static let defaultValue: AppSettingsPresenter? = nil
}

extension EnvironmentValues {
    var appSettingsPresenter: AppSettingsPresenter? {
        get { self[AppSettingsPresenterKey.self] }
        set { self[AppSettingsPresenterKey.self] = newValue }
    }
}
