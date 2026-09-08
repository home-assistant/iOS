import Shared
import SwiftUI
import UIKit

/// Hosts the single web frontend inside a tab: the slot whose tab is selected adopts the `WebViewController`,
/// so the frontend moves between tabs instead of being rebuilt, which would be a full page load.
struct NativeTabBarFrontendSlot: UIViewControllerRepresentable {
    let controller: WebViewController?
    let isActive: Bool
    /// Called when the slot is on screen with no frontend to show yet; the owner creates one.
    let onNeedsController: () -> Void

    func makeUIViewController(context: Context) -> SlotViewController {
        SlotViewController()
    }

    func updateUIViewController(_ slot: SlotViewController, context: Context) {
        slot.update(controller: controller, isActive: isActive, onNeedsController: onNeedsController)
    }

    final class SlotViewController: UIViewController {
        private weak var hostedController: WebViewController?
        private var controller: WebViewController?
        private var isActive = false
        private var onNeedsController: (() -> Void)?

        func update(controller: WebViewController?, isActive: Bool, onNeedsController: @escaping () -> Void) {
            self.controller = controller
            self.isActive = isActive
            self.onNeedsController = onNeedsController
            apply()
        }

        override func viewWillAppear(_ animated: Bool) {
            super.viewWillAppear(animated)
            apply()
        }

        private func apply() {
            if let hostedController, hostedController !== controller {
                detach(hostedController)
            }
            guard isActive else { return }
            guard let controller else {
                DispatchQueue.main.async { [weak self] in
                    self?.onNeedsController?()
                }
                return
            }
            guard controller.parent !== self else { return }
            if controller.parent != nil {
                controller.willMove(toParent: nil)
            }
            controller.view.removeFromSuperview()
            controller.removeFromParent()
            addChild(controller)
            controller.view.translatesAutoresizingMaskIntoConstraints = false
            view.addSubview(controller.view)
            NSLayoutConstraint.activate([
                controller.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
                controller.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
                controller.view.topAnchor.constraint(equalTo: view.topAnchor),
                controller.view.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            ])
            controller.didMove(toParent: self)
            hostedController = controller
        }

        private func detach(_ controller: WebViewController) {
            guard controller.parent === self else {
                hostedController = nil
                return
            }
            controller.willMove(toParent: nil)
            controller.view.removeFromSuperview()
            controller.removeFromParent()
            hostedController = nil
        }
    }
}
