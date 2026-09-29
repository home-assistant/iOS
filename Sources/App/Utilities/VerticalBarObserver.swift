import SwiftUI
import UIKit

/// Follows whether the system lays the bars out in a vertical column, as on an unfolded iPhone.
struct VerticalBarObserver: UIViewControllerRepresentable {
    @Binding var hasVerticalBar: Bool

    func makeUIViewController(context: Context) -> ObserverViewController {
        ObserverViewController()
    }

    func updateUIViewController(_ controller: ObserverViewController, context: Context) {
        controller.onChange = { value in
            DispatchQueue.main.async {
                hasVerticalBar = value
            }
        }
    }

    final class ObserverViewController: UIViewController {
        private static let verticalBarEdgeKey = "verticalBarEdge"

        var onChange: ((Bool) -> Void)?
        private var lastReported: Bool?

        static func hasVerticalBar(in traits: UITraitCollection) -> Bool {
            guard #available(iOS 27.1, *), traits.responds(to: NSSelectorFromString(verticalBarEdgeKey)) else {
                return false
            }
            let edge = traits.value(forKey: verticalBarEdgeKey) as? Int ?? 0
            return edge != 0
        }

        override func viewDidLoad() {
            super.viewDidLoad()
            view.isUserInteractionEnabled = false
            view.backgroundColor = .clear
        }

        override func viewWillAppear(_ animated: Bool) {
            super.viewWillAppear(animated)
            report()
        }

        override func viewDidLayoutSubviews() {
            super.viewDidLayoutSubviews()
            report()
        }

        private func report() {
            let value = Self.hasVerticalBar(in: traitCollection)
            guard value != lastReported else { return }
            lastReported = value
            onChange?(value)
        }
    }
}
