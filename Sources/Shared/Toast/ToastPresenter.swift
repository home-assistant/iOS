import SFSafeSymbols
import SwiftUI

/// Holds the currently presented toast and drives auto-dismissal. Pure state — the toast is rendered
/// by the SwiftUI `toastOverlay()` modifier attached at the app root, with no UIKit window involved.
///
/// Example:
/// ```swift
/// if #available(iOS 18, *) {
///     ToastPresenter.shared.show(
///         id: "my-toast",
///         symbol: .checkmarkSealFill,
///         symbolForegroundStyle: (.white, .green),
///         title: "Success",
///         message: "Operation completed",
///         duration: 4
///     )
/// }
/// ```
@available(iOS 18, *)
@MainActor
public final class ToastPresenter: ObservableObject {
    public static let shared = ToastPresenter()

    /// Frontend can use this to know whether the app's toast component has what it needs.
    public static var toastComponentVersion = 1

    @Published public private(set) var toast: Toast?

    private var autoDismissTask: Task<Void, Never>?

    public init() {}

    public func show(
        id: String,
        symbol: SFSymbol,
        symbolFont: Font = .system(size: 35),
        symbolForegroundStyle: (Color, Color),
        title: String,
        message: String? = nil,
        duration: TimeInterval? = nil
    ) {
        show(
            toast: Toast(
                id: id,
                symbol: symbol,
                symbolFont: symbolFont,
                symbolForegroundStyle: symbolForegroundStyle,
                title: title,
                message: message ?? ""
            ),
            duration: duration
        )
    }

    public func show(toast: Toast, duration: TimeInterval? = nil) {
        autoDismissTask?.cancel()
        autoDismissTask = nil
        self.toast = toast

        guard let duration else { return }
        autoDismissTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(duration))
            guard !Task.isCancelled else { return }
            self?.hide(id: toast.id)
        }
    }

    public func hide(id: String) {
        guard toast?.id == id else { return }
        hideCurrent()
    }

    public func hideCurrent() {
        autoDismissTask?.cancel()
        autoDismissTask = nil
        toast = nil
    }
}
