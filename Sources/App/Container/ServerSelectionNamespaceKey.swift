import SwiftUI

/// Carries the namespace backing the zoom transition into the server picker. The transition source lives deep
/// in the frontend's stand-by view while the sheet is presented from `ConditionalContainerView`, so the two
/// only meet through the environment.
private struct ServerSelectionNamespaceKey: EnvironmentKey {
    static let defaultValue: Namespace.ID? = nil
}

extension EnvironmentValues {
    var serverSelectionNamespace: Namespace.ID? {
        get { self[ServerSelectionNamespaceKey.self] }
        set { self[ServerSelectionNamespaceKey.self] = newValue }
    }
}
