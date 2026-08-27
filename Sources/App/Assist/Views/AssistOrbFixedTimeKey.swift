import SwiftUI

/// Freezes `AssistVoiceOrbView`'s blobs at one point of its animation timeline. Previews and snapshot
/// tests set it so every render places the blobs identically; the app leaves it `nil` and the orb runs.
/// It travels through the environment because the orb is drawn deep inside `AssistView`, which snapshot
/// tests reach only from the outside.
private struct AssistOrbFixedTimeKey: EnvironmentKey {
    static let defaultValue: TimeInterval? = nil
}

extension EnvironmentValues {
    var assistOrbFixedTime: TimeInterval? {
        get { self[AssistOrbFixedTimeKey.self] }
        set { self[AssistOrbFixedTimeKey.self] = newValue }
    }
}
