import SFSafeSymbols
import SwiftUI

/// Preset toast styles for common use cases.
@available(iOS 18, *)
public enum ToastStyle {
    case success
    case error
    case warning
    case info
    case syncing

    var symbol: String {
        switch self {
        case .success: "checkmark.circle.fill"
        case .error: "xmark.circle.fill"
        case .warning: "exclamationmark.triangle.fill"
        case .info: "info.circle.fill"
        case .syncing: "arrow.triangle.2.circlepath.circle.fill"
        }
    }

    var colors: (Color, Color) {
        switch self {
        case .success: (.white, .green)
        case .error: (.white, .red)
        case .warning: (.white, .orange)
        case .info: (.white, .haPrimary)
        case .syncing: (.white, .blue)
        }
    }
}

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
public final class ToastManager {
    /// The shared singleton instance of the toast manager.
    public static let shared = ToastManager()

    public static var toastComponentVersion = 1
    private var overlayWindow: PassThroughWindow?
    private var overlayController: ToastHostingController?
    private var autoDismissTask: Task<Void, Never>?
    public init() {}

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
    public func show(
        id: String,
        symbol: String,
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
    public func show(toast: Toast, duration: TimeInterval? = nil) {
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
                self?.hide(id: toast.id)
            }
        }
    }

    /// Shows a styled toast with the specified parameters.
    ///
    /// - Parameters:
    ///   - style: The preset style for the toast (success, error, warning, info, syncing).
    ///   - title: The title text displayed in the toast.
    ///   - message: Optional message text displayed below the title.
    ///   - duration: Optional duration in seconds after which the toast auto-dismisses.
    ///               Defaults to 2 seconds for non-syncing styles.
    public func showStyled(
        _ style: ToastStyle,
        title: String,
        message: String? = nil,
        duration: TimeInterval? = 2.0
    ) {
        let id = "toast-\(style)-\(UUID().uuidString)"
        show(
            id: id,
            symbol: style.symbol,
            symbolForegroundStyle: style.colors,
            title: title,
            message: message,
            duration: duration
        )
    }

    /// Shows a success toast.
    ///
    /// - Parameters:
    ///   - title: The title text displayed in the toast.
    ///   - message: Optional message text displayed below the title.
    ///   - duration: Optional duration in seconds. Defaults to 2 seconds.
    public func showSuccess(title: String, message: String? = nil, duration: TimeInterval? = 2.0) {
        showStyled(.success, title: title, message: message, duration: duration)
    }

    /// Shows an error toast.
    ///
    /// - Parameters:
    ///   - title: The title text displayed in the toast.
    ///   - message: Optional message text displayed below the title.
    ///   - duration: Optional duration in seconds. Defaults to 3 seconds for errors.
    public func showError(title: String, message: String? = nil, duration: TimeInterval? = 3.0) {
        showStyled(.error, title: title, message: message, duration: duration)
    }

    /// Hides the toast with the specified ID.
    ///
    /// - Parameter id: The identifier of the toast to hide.
    public func hide(id: String) {
        guard let overlayWindow, overlayWindow.toast?.id == id else { return }
        hideCurrentToast()
    }

    /// Hides any currently displayed toast.
    public func hideCurrentToast() {
        autoDismissTask?.cancel()
        autoDismissTask = nil

        overlayWindow?.isPresented = false
        overlayController?.isStatusBarHidden = false
    }

    // MARK: - Private Methods

    private func ensureOverlayWindow() {
        #if os(iOS)
        // Try to find an existing window first
        if let windowScene = Current.application?().connectedScenes
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
        #endif
    }
}
