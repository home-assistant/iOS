#if os(macOS)
import AppKit

/// The tick a Force Touch trackpad plays as something snaps into alignment.
public final class UISelectionFeedbackGenerator {
    public init() {}

    public func prepare() {}

    public func selectionChanged() {
        NSHapticFeedbackManager.defaultPerformer.perform(.alignment, performanceTime: .default)
    }
}
#endif
