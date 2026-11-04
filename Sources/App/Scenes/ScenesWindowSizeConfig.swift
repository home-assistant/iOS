import Foundation
import Shared
import UIKit

/// Stores the last known Mac window frame per window kind, so each window reopens where the user left it.
enum ScenesWindowSizeConfig {
    private static let mainSceneKey = "default-scene-latest-system-frame-data"

    static func latestSystemFrame(for activity: SceneActivity) -> CGRect? {
        guard let savedData = prefs.data(forKey: key(for: activity)) else { return nil }
        return try? JSONDecoder().decode(CGRect.self, from: savedData)
    }

    static func setLatestSystemFrame(_ systemFrame: CGRect?, for activity: SceneActivity) {
        guard let systemFrame else {
            prefs.removeObject(forKey: key(for: activity))
            return
        }
        guard let newData = try? JSONEncoder().encode(systemFrame) else { return }
        prefs.set(newData, forKey: key(for: activity))
    }

    /// The main window shipped before secondary windows had geometry memory, so it keeps the original,
    /// unsuffixed key and users' saved frame survives the upgrade.
    static func key(for activity: SceneActivity) -> String {
        activity == .webView ? mainSceneKey : "\(mainSceneKey)-\(activity.activityIdentifier)"
    }
}
