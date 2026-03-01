import Foundation
import Shared
import SwiftUI
import UIKit

extension UIWindow {
    private static var hasActivatedInitialScene = false

    convenience init(haScene scene: UIWindowScene) {
        self.init(windowScene: scene)
        self.tintColor = UIColor(Color.haPrimary)

        #if targetEnvironment(macCatalyst)
        // On Mac Catalyst, check if we should launch silently in the background
        // This only applies to the first scene connection after app launch
        let isInitialScene = !Self.hasActivatedInitialScene
        let shouldLaunchInBackground = Current.settingsStore.launchInBackground && isInitialScene

        if shouldLaunchInBackground {
            // Make the window visible but don't activate it (keep it in background)
            isHidden = false
            Self.hasActivatedInitialScene = true
        } else {
            // Normal behavior: activate and bring to front
            makeKeyAndVisible()
            if isInitialScene {
                Self.hasActivatedInitialScene = true
            }
        }
        #else
        makeKeyAndVisible()
        #endif
    }
}
