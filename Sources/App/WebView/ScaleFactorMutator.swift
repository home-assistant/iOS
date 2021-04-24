import Foundation
import Shared

class ScaleFactorMutator {
    fileprivate static var sceneIdentifiers = Set<String>()
    public static func record(sceneIdentifier: String) {
        swizzleIfNeeded()
        sceneIdentifiers.insert(sceneIdentifier)
    }

    private static var hasSwizzled = false
    fileprivate static var didSwizzleScaleFactor = false
    fileprivate static var didSwizzleSceneIdentifier = false

    private static func swizzleIfNeeded() {
        guard !hasSwizzled else { return }
        defer { hasSwizzled = true }

        if #available(iOS 14, *), UIDevice.current.userInterfaceIdiom == .mac {
            // we do not need to swizzle when using the mac idiom on macOS 11
            return
        }

        #if targetEnvironment(macCatalyst)
        func exchange(for klassString: String, original: Selector, with replacement: Selector) -> Bool {
            guard
                let klass = objc_getClass(klassString) as? AnyClass,
                let originalMethod = class_getInstanceMethod(klass, original),
                let replacementMethod = class_getInstanceMethod(klass, replacement) else {
                Current.Log.error("couldn't get \(klassString) method \(original) and \(replacement)")
                return false
            }

            method_exchangeImplementations(originalMethod, replacementMethod)
            return true
        }

        // macOS 10.15 through 11.2
        didSwizzleScaleFactor = exchange(
            for: "UINSSceneView",
            original: Selector(("setScaleFactor:")),
            with: #selector(NSObject.setHa_scaleFactor(_:))
        )

        if !didSwizzleScaleFactor {
            // macOS 11.3+
            didSwizzleScaleFactor = exchange(
                for: "UINSSceneView",
                original: Selector(("setFixedSceneToSceneViewScaleFactor:")),
                with: #selector(NSObject.setHa_scaleFactor(_:))
            )
        }

        didSwizzleSceneIdentifier = exchange(
            for: "UINSSceneView",
            original: Selector(("setSceneIdentifier:")),
            with: #selector(NSObject.setHa_sceneIdentifier(_:))
        )
        #endif
    }
}

#if targetEnvironment(macCatalyst)
fileprivate extension NSObject {
    var sceneIdentifier: String? {
        if responds(to: Selector(("sceneIdentifier"))) {
            return value(forKey: "sceneIdentifier") as? String
        } else {
            return nil
        }
    }

    @objc func setHa_scaleFactor(_ scaleFactor: CGFloat) {
        guard ScaleFactorMutator.didSwizzleScaleFactor else {
            return
        }

        if let identifier = sceneIdentifier, ScaleFactorMutator.sceneIdentifiers.contains(identifier) {
            setHa_scaleFactor(1.0)
        } else {
            setHa_scaleFactor(scaleFactor)
        }
    }

    @objc func setHa_sceneIdentifier(_ identifier: String) {
        guard ScaleFactorMutator.didSwizzleSceneIdentifier else {
            return
        }

        setHa_sceneIdentifier(identifier)

        if ScaleFactorMutator.sceneIdentifiers.contains(identifier) {
            // this calls the UIKit/AppKit version
            setHa_scaleFactor(1.0)
        }
    }
}
#endif
