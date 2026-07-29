import Combine
import Foundation

/// Clears everything the app presents over its own content — SwiftUI sheets, full-screen covers and pushed
/// destinations — so an incoming navigation (deep link, universal link, App Intent or notification tap)
/// always lands on the frontend instead of happening invisibly behind whatever the user had open.
///
/// Before the SwiftUI migration every one of those overlays was a `UIViewController` presented over the web
/// view, so `dismissOverlayController()` was enough to clear the screen. They are now driven by
/// `@State`/`@Published` bindings, and dismissing their controllers through UIKit alone leaves the bindings
/// stuck at `true`: the state is stranded and the next presentation is silently swallowed. Views therefore
/// clear their own binding in response to `dismissAllPublisher` (see `View.dismissesOnAppNavigation(_:)`),
/// and `AppCoordinator.dismissPresentedContent(completion:)` tears down whatever is still on screen.
final class AppPresentationDismisser {
    static let shared = AppPresentationDismisser()

    /// Fires when the screen has to be cleared for an incoming navigation. Views observing it drop their
    /// own presentation state; they are only subscribed while they are in the hierarchy, so nothing that
    /// isn't on screen is touched.
    let dismissAllPublisher = PassthroughSubject<Void, Never>()

    private init() {}

    /// Asks every presentation currently on screen to go away. Call on the main thread.
    func dismissAll() {
        // Settings lives above the kiosk/container swap in a shared presenter rather than in a view's own
        // state, so it is cleared directly instead of through the publisher.
        AppSettingsPresenter.shared.isSheetPresented = false
        AppSettingsPresenter.shared.isPushPresented = false
        dismissAllPublisher.send(())
    }
}
