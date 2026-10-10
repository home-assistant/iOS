#if os(iOS)
import UIKit

/// Reports whether its traits put the system bars in a vertical column, once per change.
final class VerticalBarObserverViewController: UIViewController {
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
#endif
