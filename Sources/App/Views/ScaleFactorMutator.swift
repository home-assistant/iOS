import Foundation
import Shared

class ScaleFactorMutator {
    fileprivate static var sceneIdentifiers = Set<String>()
    public static func record(sceneIdentifier: String) {
        swizzleIfNeeded()
        sceneIdentifiers.insert(sceneIdentifier)
    }

    static private var hasSwizzled = false
    static private func swizzleIfNeeded() {
        guard !hasSwizzled else { return }
        defer { hasSwizzled = true }

        #if targetEnvironment(macCatalyst)
        func exchange(for klassString: String, original: Selector, with replacement: Selector) {
            guard
                let klass = objc_getClass(klassString) as? AnyClass,
                let originalMethod = class_getInstanceMethod(klass, original),
                let replacementMethod = class_getInstanceMethod(klass, replacement)
            else {
                Current.Log.error("couldn't get \(klassString) method \(original) and \(replacement)")
                return
            }

            method_exchangeImplementations(originalMethod, replacementMethod)
        }

        exchange(
            for: "UINSSceneView",
            original: Selector(("setScaleFactor:")),
            with: #selector(NSObject.setHa_scaleFactor(_:))
        )
        exchange(
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
        if let identifier = sceneIdentifier, ScaleFactorMutator.sceneIdentifiers.contains(identifier) {
            setHa_scaleFactor(1.0)
        } else {
            setHa_scaleFactor(scaleFactor)
        }
    }

    @objc func setHa_sceneIdentifier(_ identifier: String) {
        setHa_sceneIdentifier(identifier)

        if ScaleFactorMutator.sceneIdentifiers.contains(identifier) {
            // this calls the UIKit/AppKit version
            setHa_scaleFactor(1.0)
        }
    }
}
#endif
