import Foundation
import Shared
import UIKit

final class WindowSizeObserver: NSObject {
    @objc private(set) var observedScene: UIWindowScene?
    private var observation: NSKeyValueObservation?

    init(windowScene: UIWindowScene) {
        self.observedScene = windowScene
        super.init()

        guard Current.isCatalyst else { return }
        startObserving()
    }

    private func startObserving() {
        #if targetEnvironment(macCatalyst)
        guard #available(macCatalyst 16.0, *) else { return }
        observation = observe(\.observedScene?.effectiveGeometry, options: [.new]) { _, change in
            guard let newSystemFrame = change.newValue??.systemFrame,
                  newSystemFrame.size != .zero, newSystemFrame.origin != .zero else { return }
            ScenesWindowSizeConfig.defaultSceneLatestSystemFrame = newSystemFrame
        }
        #endif
    }

    public func stopObserving() {
        observation?.invalidate()
        observation = nil
    }
}

enum ScenesWindowSizeConfig {
    private static let defaultSceneLatestSystemFrameDataKey = "default-scene-latest-system-frame-data"
    private static var defaultSceneLatestSystemFrameData: Data? {
        get {
            prefs.data(forKey: ScenesWindowSizeConfig.defaultSceneLatestSystemFrameDataKey)
        }
        set {
            prefs.set(newValue, forKey: ScenesWindowSizeConfig.defaultSceneLatestSystemFrameDataKey)
        }
    }

    static var defaultSceneLatestSystemFrame: CGRect? {
        get {
            guard let savedData = defaultSceneLatestSystemFrameData else { return nil }
            return try? JSONDecoder().decode(CGRect.self, from: savedData)
        }
        set {
            if let newValue {
                if let newData = try? JSONEncoder().encode(newValue) {
                    defaultSceneLatestSystemFrameData = newData
                }
            } else {
                defaultSceneLatestSystemFrameData = nil
            }
        }
    }
}
