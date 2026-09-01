import Foundation
import Shared
import UIKit

final class WindowSizeObserver: NSObject {
    @objc private(set) var observedScene: UIWindowScene?
    let activity: SceneActivity
    private var observation: NSKeyValueObservation?

    init(windowScene: UIWindowScene, activity: SceneActivity) {
        self.observedScene = windowScene
        self.activity = activity
        super.init()

        guard Current.isCatalyst else { return }
        startObserving()
    }

    private func startObserving() {
        #if targetEnvironment(macCatalyst)
        guard #available(macCatalyst 16.0, *) else { return }
        observation = observe(\.observedScene?.effectiveGeometry, options: [.new]) { [activity] _, change in
            guard let newSystemFrame = change.newValue??.systemFrame,
                  newSystemFrame.size != .zero, newSystemFrame.origin != .zero else { return }
            ScenesWindowSizeConfig.setLatestSystemFrame(newSystemFrame, for: activity)
        }
        #endif
    }

    public func stopObserving() {
        observation?.invalidate()
        observation = nil
    }
}
