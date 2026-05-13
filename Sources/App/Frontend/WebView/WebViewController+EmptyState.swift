import Shared
import SwiftUI
import UIKit

// MARK: - Empty State

extension WebViewController {
    func setupEmptyState() {
        let emptyState = WebViewEmptyStateWrapperView(
            style: emptyStateStyle(for: connectionState),
            server: server,
            showsErrorDetailsButton: shouldShowErrorDetailsButton,
            retryAction: { [weak self] in
                self?.hideEmptyState()
                self?.refresh()
            },
            settingsAction: { [weak self] in
                self?.showSettingsViewController()
            },
            errorDetailsAction: { [weak self] in
                self?.presentLatestLoadErrorDetails()
            },
            reauthAction: { [weak self] urlType in
                self?.performReauthentication(using: urlType)
            },
            dismissAction: { [weak self] in
                self?.hideEmptyState()
            }
        )

        addChild(emptyState.hostingViewController)
        view.addSubview(emptyState)

        emptyState.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            emptyState.leftAnchor.constraint(equalTo: view.leftAnchor),
            emptyState.rightAnchor.constraint(equalTo: view.rightAnchor),
            emptyState.topAnchor.constraint(equalTo: view.topAnchor),
            emptyState.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])

        emptyState.alpha = 0
        emptyStateView = emptyState
        emptyState.hostingViewController.didMove(toParent: self)
    }

    func emptyStateStyle(for connectionState: FrontEndConnectionState) -> WebViewEmptyStateStyle {
        switch connectionState {
        case .authInvalid:
            .unauthenticated
        case .connected, .disconnected, .unknown:
            .disconnected
        }
    }

    func showEmptyState() {
        emptyStateView?.update(
            style: emptyStateStyle(for: connectionState),
            showsErrorDetailsButton: shouldShowErrorDetailsButton
        )
        UIView.animate(withDuration: emptyStateTransitionDuration, delay: 0, options: .curveEaseInOut, animations: {
            self.emptyStateView?.alpha = 1
        }, completion: nil)
    }

    var shouldShowErrorDetailsButton: Bool {
        connectionState == .disconnected && latestLoadError != nil
    }

    func presentLatestLoadErrorDetails() {
        guard let latestLoadError else { return }
        presentOverlayController(
            controller: UIHostingController(rootView: ConnectionErrorDetailsView(
                server: server,
                error: latestLoadError
            )),
            animated: true
        )
    }

    @objc func hideEmptyState() {
        UIView.animate(withDuration: emptyStateTransitionDuration, delay: 0, options: .curveEaseInOut, animations: {
            self.emptyStateView?.alpha = 0
        }, completion: nil)
    }

    // To avoid keeping the empty state on screen when user is disconnected in background
    // due to inactivity, we reset the empty state timer
    @objc func resetEmptyStateTimerWithLatestConnectedState() {
        let state: FrontEndConnectionState = if connectionState == .authInvalid {
            .authInvalid
        } else {
            isConnected ? .connected : .disconnected
        }
        updateFrontendConnectionState(state: state.rawValue)
    }

    func emptyStateObservations() {
        // Hide empty state when enter background
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(hideEmptyState),
            name: UIApplication.didEnterBackgroundNotification,
            object: nil
        )

        // Show empty state again if after entering foreground it is not connected
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(resetEmptyStateTimerWithLatestConnectedState),
            name: UIApplication.willEnterForegroundNotification,
            object: nil
        )
    }

    func removeEmptyStateObservations() {
        NotificationCenter.default.removeObserver(self, name: UIApplication.didEnterBackgroundNotification, object: nil)
        NotificationCenter.default.removeObserver(
            self,
            name: UIApplication.willEnterForegroundNotification,
            object: nil
        )
    }
}
