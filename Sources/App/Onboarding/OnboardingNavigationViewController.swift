import Eureka
import Reachability
import Shared
import UIKit

class OnboardingNavigationViewController: UINavigationController, RowControllerType {
    public var onDismissCallback: ((UIViewController) -> Void)?

    // swiftlint:disable:next force_try
    let reachability = try! Reachability()

    override var childForStatusBarStyle: UIViewController? {
        nil
    }

    override var preferredStatusBarStyle: UIStatusBarStyle {
        .lightContent
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        if #available(iOS 13.0, *) {
            // Always adopt a light interface style.
            overrideUserInterfaceStyle = .light
            view.tintColor = .white
        }

        if viewControllers.isEmpty {
            viewControllers = [ StoryboardScene.Onboarding.welcome.instantiate() ]
        }
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        do {
            try reachability.startNotifier()
        } catch {
            Current.Log.error("Unable to start Reachability notifier: \(error)")
        }
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        reachability.stopNotifier()
    }

    func dismiss() {
        dismiss(animated: true, completion: nil)
        onDismissCallback?(self)
    }

    func styleButton(_ button: UIButton) {
        button.layer.cornerRadius = 6.0
        button.layer.masksToBounds = true
        button.contentEdgeInsets = UIEdgeInsets(top: 16, left: 16, bottom: 16, right: 16)
        button.titleLabel?.font = UIFont.systemFont(
            ofSize: UIFont.preferredFont(forTextStyle: .callout).pointSize,
            weight: .bold
        )
        button.setTitleColor(Constants.tintColor, for: .normal)

        if #available(iOS 13, *) {
            button.setBackgroundImage(
                UIImage(size: CGSize(width: 1, height: 1), color: .systemBackground),
                for: .normal
            )
        } else {
            button.setBackgroundImage(
                UIImage(size: CGSize(width: 1, height: 1), color: .white),
                for: .normal
            )
        }

        if let title = button.title(for: .normal) {
            button.setTitle(title.localizedUppercase, for: .normal)
        }
    }
}
