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
        #if !targetEnvironment(macCatalyst)
        if #available(iOS 27.1, *) {
            // The bars can move into a column after the first layout, as when the device unfolds or the
            // tab bar comes up after the frontend; the traits behind the edge announce that.
            let traits = UITraitCollection.systemTraitsAffectingVerticalBarEdge
            registerForTraitChanges(traits, action: #selector(barTraitsDidChange))
        }
        #endif
    }

    @objc func barTraitsDidChange() {
        report()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        report()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        report()
    }

    /// The scene's traits carry the edge: a tab's content can have it overridden to unspecified while the
    /// window around it, as on a folded iPhone Duo's outer display, still runs its bars vertically.
    private var sceneTraits: UITraitCollection {
        view.window?.windowScene?.traitCollection ?? view.window?.traitCollection ?? traitCollection
    }

    private func report() {
        let value = Self.hasVerticalBar(in: sceneTraits)
        guard value != lastReported else { return }
        lastReported = value
        onChange?(value)
    }
}
