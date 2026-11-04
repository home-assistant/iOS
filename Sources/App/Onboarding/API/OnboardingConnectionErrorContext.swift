import Foundation

/// Payload for the connection-error page pushed on Mac Catalyst when the auth flow fails —
/// sheets don't receive mouse events reliably there, so the error is a page instead.
/// Identity-based so it can live inside the `Hashable` `OnboardingDestination`.
final class OnboardingConnectionErrorContext {
    let error: Error

    init(error: Error) {
        self.error = error
    }
}
