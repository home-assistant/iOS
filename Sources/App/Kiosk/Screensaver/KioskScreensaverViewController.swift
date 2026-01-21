import Combine
import Shared
import SwiftUI
import UIKit

// MARK: - Kiosk Screensaver View Controller

/// Main view controller that hosts and manages screensaver views
/// Supports screensaver modes: blank, dim, clock
/// TODO: Add photo and custom URL screensaver modes
public final class KioskScreensaverViewController: UIViewController, UIGestureRecognizerDelegate, KioskModeObserver {
    // MARK: - Properties

    private var currentMode: ScreensaverMode?
    private var hostingController: UIHostingController<AnyView>?
    private var secretExitGestureController: KioskSecretExitGestureViewController?
    private var cancellables = Set<AnyCancellable>()
    private var pixelShiftOffset: CGPoint = .zero
    private var wakeGesture: UITapGestureRecognizer?

    /// Callback when secret exit gesture wants to show settings
    public var onShowSettings: (() -> Void)?

    // MARK: - Lifecycle

    override public func viewDidLoad() {
        super.viewDidLoad()

        view.backgroundColor = .black
        view.isUserInteractionEnabled = true

        // Add tap gesture to wake screen
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(handleTap))
        tapGesture.delegate = self
        wakeGesture = tapGesture
        view.addGestureRecognizer(tapGesture)

        // Add swipe gesture for additional wake trigger
        let swipeGesture = UISwipeGestureRecognizer(target: self, action: #selector(handleSwipe))
        swipeGesture.direction = [.up, .down, .left, .right]
        view.addGestureRecognizer(swipeGesture)

        setupObservers()
        setupSecretExitGesture()
    }

    // MARK: - Gesture Recognizer Delegate

    public func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
        // Don't let the wake gesture intercept taps in the secret exit corner
        guard gestureRecognizer === wakeGesture else { return true }

        let settings = KioskModeManager.shared.settings
        guard settings.secretExitGestureEnabled, KioskModeManager.shared.isKioskModeActive else {
            return true
        }

        let location = touch.location(in: view)
        let cornerSize: CGFloat = 80
        let corner = settings.secretExitGestureCorner

        let cornerRect: CGRect
        switch corner {
        case .topLeft:
            cornerRect = CGRect(x: 0, y: 0, width: cornerSize, height: cornerSize)
        case .topRight:
            cornerRect = CGRect(x: view.bounds.width - cornerSize, y: 0, width: cornerSize, height: cornerSize)
        case .bottomLeft:
            cornerRect = CGRect(x: 0, y: view.bounds.height - cornerSize, width: cornerSize, height: cornerSize)
        case .bottomRight:
            cornerRect = CGRect(
                x: view.bounds.width - cornerSize,
                y: view.bounds.height - cornerSize,
                width: cornerSize,
                height: cornerSize
            )
        }

        // If touch is in the corner, don't let wake gesture receive it
        return !cornerRect.contains(location)
    }

    // MARK: - Secret Exit Gesture

    private func setupSecretExitGesture() {
        let controller = KioskSecretExitGestureViewController()
        secretExitGestureController = controller

        // Forward the callback
        controller.onShowSettings = { [weak self] in
            self?.onShowSettings?()
        }

        addChild(controller)
        view.addSubview(controller.view)
        controller.view.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            controller.view.topAnchor.constraint(equalTo: view.topAnchor),
            controller.view.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            controller.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            controller.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
        ])

        controller.didMove(toParent: self)

        // Bring to front so it can receive taps
        view.bringSubviewToFront(controller.view)
    }

    // Note: No need to explicitly remove observer in deinit - KioskModeManager uses weak references
    // that automatically clean up when this object is deallocated

    override public var prefersStatusBarHidden: Bool {
        true
    }

    override public var prefersHomeIndicatorAutoHidden: Bool {
        true
    }

    // MARK: - Public Methods

    /// Show the screensaver with the specified mode
    public func show(mode: ScreensaverMode) {
        guard currentMode != mode else { return }

        Current.Log.info("Showing screensaver: \(mode.rawValue)")
        currentMode = mode

        // Remove existing content
        hostingController?.view.removeFromSuperview()
        hostingController?.removeFromParent()
        hostingController = nil

        // Configure view based on mode
        switch mode {
        case .blank:
            showBlankScreensaver()

        case .dim:
            showDimScreensaver()

        case .clock, .clockWithEntities:
            // TODO: Add entity display support for clockWithEntities mode
            showClockScreensaver()

        case .photos, .photosWithClock:
            // TODO: Implement photo screensaver
            Current.Log.warning("Photo screensaver not yet implemented, falling back to clock")
            showClockScreensaver()

        case .customURL:
            // TODO: Implement custom URL screensaver
            Current.Log.warning("Custom URL screensaver not yet implemented, falling back to clock")
            showClockScreensaver()
        }

        // Fade in
        view.alpha = 0
        UIView.animate(withDuration: 0.5) {
            self.view.alpha = 1
        }
    }

    /// Hide the screensaver
    public func hide() {
        Current.Log.info("Hiding screensaver")

        UIView.animate(withDuration: 0.3) {
            self.view.alpha = 0
        } completion: { _ in
            self.currentMode = nil
            self.hostingController?.view.removeFromSuperview()
            self.hostingController?.removeFromParent()
            self.hostingController = nil
        }
    }

    /// Apply pixel shift offset
    public func applyPixelShift() {
        let manager = KioskModeManager.shared
        guard manager.settings.pixelShiftEnabled else { return }

        let amount = manager.settings.pixelShiftAmount

        // Random offset within range
        let newOffset = CGPoint(
            x: CGFloat.random(in: -amount ... amount),
            y: CGFloat.random(in: -amount ... amount)
        )

        pixelShiftOffset = newOffset

        // Apply transform to hosting controller view
        UIView.animate(withDuration: 1.0) {
            self.hostingController?.view.transform = CGAffineTransform(
                translationX: newOffset.x,
                y: newOffset.y
            )
        }
    }

    // MARK: - Private Methods

    private func setupObservers() {
        // Register as kiosk mode observer for pixel shift notifications
        KioskModeManager.shared.addObserver(self)
    }

    // MARK: - KioskModeObserver

    public func kioskPixelShiftDidTrigger(amount: CGFloat) {
        applyPixelShift()
    }

    @objc private func handleTap() {
        let manager = KioskModeManager.shared
        if manager.settings.wakeOnTouch {
            manager.wakeScreen(source: "touch")
        }
    }

    @objc private func handleSwipe() {
        let manager = KioskModeManager.shared
        if manager.settings.wakeOnTouch {
            manager.wakeScreen(source: "swipe")
        }
    }

    // MARK: - Screensaver Mode Views

    private func showBlankScreensaver() {
        // Just black screen - view.backgroundColor is already black
        view.backgroundColor = .black
    }

    private func showDimScreensaver() {
        // Dim overlay on top of existing content
        // The actual dimming is handled by brightness control in KioskModeManager
        view.backgroundColor = UIColor.black.withAlphaComponent(0.7)
    }

    private func showClockScreensaver() {
        let clockView = KioskClockScreensaverView()
        embedSwiftUIView(AnyView(clockView))
    }

    private func embedSwiftUIView(_ content: AnyView) {
        let hosting = UIHostingController(rootView: content)
        hosting.view.backgroundColor = .clear

        addChild(hosting)
        view.addSubview(hosting.view)
        hosting.view.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            hosting.view.topAnchor.constraint(equalTo: view.topAnchor),
            hosting.view.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            hosting.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            hosting.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
        ])

        hosting.didMove(toParent: self)
        hostingController = hosting

        // Bring secret exit gesture back to front so it can receive taps
        if let secretView = secretExitGestureController?.view {
            view.bringSubviewToFront(secretView)
        }
    }
}
