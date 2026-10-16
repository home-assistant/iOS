import SwiftUI
import UIKit

extension View {
    /// Presents the system share sheet for `item` and clears it once the sheet goes away.
    ///
    /// The `UIActivityViewController` is presented from the top-most view controller instead of being
    /// hosted inside a SwiftUI `.sheet`: hosted, it comes up as an empty sheet the first time it is
    /// shown and only renders on the second attempt.
    func shareSheet(item: Binding<ShareWrapper?>, onDismiss: (() -> Void)? = nil) -> some View {
        background(ShareSheetPresenter(item: item, onDismiss: onDismiss))
    }
}

struct ShareSheetPresenter: UIViewRepresentable {
    @Binding var item: ShareWrapper?
    let onDismiss: (() -> Void)?

    func makeUIView(context: Context) -> UIView {
        let view = UIView(frame: .zero)
        view.isUserInteractionEnabled = false
        return view
    }

    func updateUIView(_ view: UIView, context: Context) {
        context.coordinator.present(item, from: view, clear: { item = nil }, onDismiss: onDismiss)
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    final class Coordinator {
        private var presentedID: UUID?

        func present(_ item: ShareWrapper?, from view: UIView, clear: @escaping () -> Void, onDismiss: (() -> Void)?) {
            guard let item else {
                presentedID = nil
                return
            }
            guard presentedID != item.id else { return }
            presentedID = item.id

            DispatchQueue.main.async { [weak self] in
                guard var presenter = view.window?.rootViewController else { return }
                while let presented = presenter.presentedViewController {
                    presenter = presented
                }
                self?.presentActivity(for: item, on: presenter, anchor: view, clear: clear, onDismiss: onDismiss)
            }
        }

        func presentActivity(
            for item: ShareWrapper,
            on presenter: UIViewController,
            anchor: UIView,
            clear: @escaping () -> Void,
            onDismiss: (() -> Void)?
        ) {
            let controller = UIActivityViewController(activityItems: item.items, applicationActivities: nil)
            controller.popoverPresentationController?.sourceView = anchor
            controller.popoverPresentationController?.sourceRect = anchor.bounds
            controller.completionWithItemsHandler = { [weak self] _, _, _, _ in
                self?.presentedID = nil
                clear()
                onDismiss?()
            }
            presenter.present(controller, animated: true)
        }
    }
}
