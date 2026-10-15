import Foundation
import Shared
import SwiftUI
import UIKit

/// Walks the user through guided sign-in for every token-less server a configuration file listed, one
/// after another, so "open one file → add all my sites" works for the login path and not just the
/// first server.
///
/// Each server is onboarded through the normal flow (`OnboardingNavigationView` with the URL
/// pre-filled), presented by this type itself so it also works on a fresh install, where there is no
/// web view yet to present an invitation over. A flow counts as finished when onboarding announces
/// `.complete` through `Current.onboardingObservation`; the next server is presented once that flow is
/// off screen. If the user cancels or swipes a flow away before it completes, the rest of the queue is
/// dropped: the chain unregisters and releases itself, so a later, unrelated onboarding can't pick up
/// where an abandoned import left off.
///
/// A single instance owns one chain. It keeps itself alive for the chain's duration by holding a
/// strong self-reference, released when the chain ends — the presenter that starts it does not need
/// to retain it.
@MainActor
final class ServerConfigurationGuidedSignIn: OnboardingStateObserver {
    enum Outcome: Equatable {
        /// Every queued server's sign-in completed.
        case completed
        /// A sign-in was cancelled or dismissed before completing; the servers after it were dropped.
        case abandoned
    }

    /// Presents sign-in for a server's URL and calls `onDismissed` once that flow is off screen again,
    /// whether it completed or was abandoned. Production presents `OnboardingNavigationView`; a test
    /// substitutes a recorder so the queue logic can be exercised without UI.
    typealias Present = (_ url: URL, _ onDismissed: @escaping () -> Void) -> Void

    private var queue: [ServerConfigurationImport.ServerEntry]
    private let present: Present

    /// Set while a flow this chain presented is on screen, so a stray `.complete` from something else
    /// is ignored and one dismissal can't advance the queue twice.
    private var isAwaitingDismissal = false
    /// Whether the flow currently on screen announced `.complete` before going away.
    private var currentFlowCompleted = false

    /// Held so the instance survives for the whole chain even though the presenter doesn't keep it.
    private var selfReference: ServerConfigurationGuidedSignIn?

    /// Called once when the chain ends. Optional; used by tests.
    var onFinished: ((Outcome) -> Void)?

    convenience init(servers: [ServerConfigurationImport.ServerEntry], coordinator: AppCoordinator) {
        self.init(servers: servers) { [weak coordinator] url, onDismissed in
            guard let coordinator else {
                onDismissed()
                return
            }
            Self.presentOnboarding(for: url, coordinator: coordinator, onDismissed: onDismissed)
        }
    }

    init(servers: [ServerConfigurationImport.ServerEntry], present: @escaping Present) {
        self.queue = servers
        self.present = present
    }

    /// Begins the chain: registers for onboarding completion and presents the first server. Finishes
    /// straight away if there is nothing queued.
    func start() {
        guard !queue.isEmpty else {
            finish(.completed)
            return
        }
        selfReference = self
        Current.onboardingObservation.register(observer: self)
        presentNext()
    }

    private func presentNext() {
        let next = queue.removeFirst()
        isAwaitingDismissal = true
        currentFlowCompleted = false
        Current.Log.info("Guided sign-in: presenting \(next.name) (\(queue.count) remaining)")
        present(next.externalURL) { [weak self] in
            self?.currentFlowDismissed()
        }
    }

    private func currentFlowDismissed() {
        guard isAwaitingDismissal else { return }
        isAwaitingDismissal = false

        guard currentFlowCompleted else {
            Current.Log.info("Guided sign-in: abandoned, dropping \(queue.count) remaining server(s)")
            queue.removeAll()
            finish(.abandoned)
            return
        }

        if queue.isEmpty {
            finish(.completed)
        } else {
            presentNext()
        }
    }

    private func finish(_ outcome: Outcome) {
        Current.onboardingObservation.unregister(observer: self)
        let completion = onFinished
        onFinished = nil
        selfReference = nil
        completion?(outcome)
    }

    // MARK: - OnboardingStateObserver

    nonisolated func onboardingStateDidChange(to state: OnboardingState) {
        guard state == .complete else { return }
        // The observation can fire from a background context; hop to the main actor to touch state.
        Task { @MainActor [weak self] in
            guard let self, isAwaitingDismissal else { return }
            currentFlowCompleted = true
        }
    }

    // MARK: - Presentation

    /// Presents the add-server onboarding flow for `url` over whatever is on screen (the same flow an
    /// invitation link opens) and reports when it has been dismissed for any reason.
    private static func presentOnboarding(
        for url: URL,
        coordinator: AppCoordinator,
        onDismissed: @escaping () -> Void
    ) {
        let onboarding = OnboardingNavigationView(
            onboardingStyle: .secondary,
            prefillURL: url,
            shouldDismissOnSuccess: true
        )
        let controller = onboarding.embeddedInHostingController {
            DismissalReportingHostingController(rootView: $0)
        }
        controller.onDismiss = onDismissed

        coordinator.dismissPresentedContent {
            guard coordinator.presentedViewController != nil else {
                Current.Log.error("Guided sign-in: nothing to present onboarding over")
                onDismissed()
                return
            }
            coordinator.present(controller, animated: true, completion: nil)
        }
    }
}
