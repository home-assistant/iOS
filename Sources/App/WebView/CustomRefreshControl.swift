import SwiftUI
import Shared
import UIKit

class CustomRefreshControl: UIRefreshControl {
    private var hostingController: UIHostingController<HAProgressView>?

    override init() {
        super.init()
        setupCustomSpinner()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupCustomSpinner()
    }

    private func setupCustomSpinner() {
        let spinner = HAProgressView(style: .refreshControl)
        let hostingController = UIHostingController(rootView: spinner)
        hostingController.view.backgroundColor = .clear
        hostingController.view.translatesAutoresizingMaskIntoConstraints = false

        addSubview(hostingController.view)
        NSLayoutConstraint.activate([
            hostingController.view.centerYAnchor.constraint(equalTo: centerYAnchor),
            hostingController.view.leadingAnchor.constraint(equalTo: leadingAnchor),
            hostingController.view.trailingAnchor.constraint(equalTo: trailingAnchor),
            hostingController.view.heightAnchor.constraint(equalToConstant: 60),
        ])
        tintColor = .clear // Hide default spinner
        self.hostingController = hostingController
    }
}
