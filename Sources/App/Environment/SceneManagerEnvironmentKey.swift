import Shared
import SwiftUI

// SwiftUI `@Environment` access to the app-level `SceneManager` / `NotificationManager`. Additive: both
// default to the `Current.*` instances owned by the `AppDelegate`, so they resolve without explicit
// injection and can be overridden in tests/previews via `.environment(\.sceneManager, …)`.

private struct SceneManagerEnvironmentKey: EnvironmentKey {
    static var defaultValue: SceneManager { Current.sceneManager }
}

private struct NotificationManagerEnvironmentKey: EnvironmentKey {
    static var defaultValue: NotificationManager { Current.notificationManager }
}

extension EnvironmentValues {
    var sceneManager: SceneManager {
        get { self[SceneManagerEnvironmentKey.self] }
        set { self[SceneManagerEnvironmentKey.self] = newValue }
    }

    var notificationManager: NotificationManager {
        get { self[NotificationManagerEnvironmentKey.self] }
        set { self[NotificationManagerEnvironmentKey.self] = newValue }
    }
}
