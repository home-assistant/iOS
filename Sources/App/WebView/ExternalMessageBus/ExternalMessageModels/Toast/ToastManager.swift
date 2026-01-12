import SFSafeSymbols
import SwiftUI

/// A manager class that provides imperative control over toast presentation.
///
/// Use this class to show and hide toasts from UIKit contexts where SwiftUI view modifiers
/// are not applicable. The manager maintains a shared overlay window that displays toasts
/// using the Dynamic Island-style animation.
///
/// Example usage:
/// ```swift
/// if #available(iOS 18, *) {
///     ToastManager.shared.show(
///         id: "my-toast",
///         symbol: .checkmarkSealFill,
///         symbolForegroundStyle: (.white, .green),
///         title: "Success",
///         message: "Operation completed"
///     )
///
///     // Later, to hide:
///     ToastManager.shared.hide(id: "my-toast")
/// }
/// ```
@available(iOS 18, *)
@MainActor
final class ToastManager {
    static var toastComponentVersion = 1

    /// The shared singleton instance of the toast manager.
    static let shared = ToastManager()

    private var overlayWindow: PassThroughWindow?
    private var overlayController: ToastHostingController?
    private var autoDismissTask: Task<Void, Never>?

    private init() {}

    /// Shows a toast with the specified parameters.
    ///
    /// - Parameters:
    ///   - id: A unique identifier for the toast. Used to hide a specific toast later.
    ///   - symbol: The SF Symbol to display in the toast.
    ///   - symbolFont: The font for the symbol. Defaults to system size 35.
    ///   - symbolForegroundStyle: A tuple of colors for the symbol's primary and secondary styles.
    ///   - title: The title text displayed in the toast.
    ///   - message: The message text displayed below the title.
    ///   - duration: Optional duration in seconds after which the toast auto-dismisses.
    ///               Pass `nil` for a permanent toast that must be dismissed manually.
    func show(
        id: String,
        symbol: SFSymbol,
        symbolFont: Font = .system(size: 35),
        symbolForegroundStyle: (Color, Color),
        title: String,
        message: String? = nil,
        duration: TimeInterval? = nil
    ) {
        let toast = Toast(
            id: id,
            symbol: symbol,
            symbolFont: symbolFont,
            symbolForegroundStyle: symbolForegroundStyle,
            title: title,
            message: message ?? ""
        )
        show(toast: toast, duration: duration)
    }

    /// Shows the specified toast.
    ///
    /// - Parameters:
    ///   - toast: The toast to display.
    ///   - duration: Optional duration in seconds after which the toast auto-dismisses.
    ///               Pass `nil` for a permanent toast that must be dismissed manually.
    func show(toast: Toast, duration: TimeInterval? = nil) {
        // Cancel any pending auto-dismiss
        autoDismissTask?.cancel()
        autoDismissTask = nil

        // Create or get the overlay window
        ensureOverlayWindow()

        guard let overlayWindow else { return }

        // Set the toast and present it
        overlayWindow.toast = toast
        overlayWindow.isPresented = true
        overlayController?.isStatusBarHidden = true

        // Schedule auto-dismiss if duration is provided
        if let duration {
            autoDismissTask = Task { [weak self] in
                try? await Task.sleep(for: .seconds(duration))
                guard !Task.isCancelled else { return }
                await self?.hide(id: toast.id)
            }
        }
    }

    /// Hides the toast with the specified ID.
    ///
    /// - Parameter id: The identifier of the toast to hide.
    func hide(id: String) {
        guard let overlayWindow, overlayWindow.toast?.id == id else { return }
        hideCurrentToast()
    }

    /// Hides any currently displayed toast.
    func hideCurrentToast() {
        autoDismissTask?.cancel()
        autoDismissTask = nil

        overlayWindow?.isPresented = false
        overlayController?.isStatusBarHidden = false
    }

    // MARK: - Private Methods

    private func ensureOverlayWindow() {
        // Try to find an existing window first
        if let windowScene = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .first(where: { $0.activationState == .foregroundActive }) {
            if let existingWindow = windowScene.windows.first(where: { $0.tag == 1009 }) as? PassThroughWindow {
                overlayWindow = existingWindow
                overlayController = existingWindow.rootViewController as? ToastHostingController
                return
            }

            // Create a new overlay window
            let window = PassThroughWindow(windowScene: windowScene)
            window.backgroundColor = .clear
            window.isHidden = false
            window.isUserInteractionEnabled = true
            window.tag = 1009
            window.windowLevel = .statusBar + 1

            let hostingController = ToastHostingController(rootView: ToastView(window: window))
            hostingController.view.backgroundColor = .clear
            window.rootViewController = hostingController

            overlayWindow = window
            overlayController = hostingController
        }
    }
}
