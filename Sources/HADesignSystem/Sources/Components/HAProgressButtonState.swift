#if !os(watchOS)
import Foundation

/// What an ``HAProgressButton`` is currently showing, mirroring the states the frontend's
/// `ha-progress-button` moves through.
///
/// The frontend clears a result after two seconds from inside the component. Here the caller owns
/// the state, so it decides how long a result stays up — which is also what makes the states
/// snapshottable.
public enum HAProgressButtonState: String, CaseIterable, Sendable {
    /// Ready to be pressed.
    case idle
    /// Work is running: the label is replaced by a spinner and the button stops accepting taps.
    case inProgress
    /// The work finished; a check covers the label.
    case success
    /// The work failed; a warning covers the label.
    case failure
}

extension HAProgressButtonState: FrontendComponent {
    public static var frontendComponentName: String { "ha-progress-button" }
}

#endif
