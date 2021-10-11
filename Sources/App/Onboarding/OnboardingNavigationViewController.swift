import Eureka
import Reachability
import Shared
import UIKit

class OnboardingNavigationViewController: UINavigationController, RowControllerType {
    enum OnboardingStyle {
        case initial
        case secondary

        var insertsCancelButton: Bool {
            switch self {
            case .initial: return false
            case .secondary: return true
            }
        }

        var modalPresentationStyle: UIModalPresentationStyle {
            switch self {
            case .initial: return .fullScreen
            case .secondary:
                if #available(iOS 13, *) {
                    return .automatic
                } else {
                    return .fullScreen
                }
            }
        }
    }

    public let onboardingStyle: OnboardingStyle
    public var onDismissCallback: ((UIViewController) -> Void)?

    public init(onboardingStyle: OnboardingStyle) {
        self.onboardingStyle = onboardingStyle

        let rootViewController: UIViewController

        switch onboardingStyle {
        case .initial: rootViewController = WelcomeViewController()
        case .secondary: rootViewController = DiscoverInstancesViewController()
        }

        super.init(rootViewController: rootViewController)

        modalPresentationStyle = onboardingStyle.modalPresentationStyle

        if onboardingStyle.insertsCancelButton {
            var leftItems = rootViewController.navigationItem.leftBarButtonItems ?? []
            leftItems.append(
                UIBarButtonItem(
                    barButtonSystemItem: .cancel,
                    target: self,
                    action: #selector(cancelTapped(_:))
                )
            )
            rootViewController.navigationItem.leftBarButtonItems = leftItems
        }
    }

    @available(*, unavailable)
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

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

        delegate = self
        view.tintColor = Current.style.onboardingTintColor

        if #available(iOS 13, *) {
            overrideUserInterfaceStyle = .dark
        }

        if #available(iOS 13, *) {
            let appearance = with(UINavigationBarAppearance()) {
                $0.configureWithOpaqueBackground()
                $0.backgroundColor = Current.style.onboardingBackground
                $0.shadowColor = .clear
                $0.titleTextAttributes = [.foregroundColor: UIColor.white]
            }
            navigationBar.standardAppearance = appearance
            navigationBar.scrollEdgeAppearance = appearance
            navigationBar.tintColor = .white
        } else {
            navigationBar.setBackgroundImage(
                UIImage(size: CGSize(width: 1, height: 1), color: Current.style.onboardingBackground),
                for: .default
            )
            navigationBar.shadowImage = UIImage(size: CGSize(width: 1, height: 1), color: .clear)
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

    @objc private func cancelTapped(_ sender: UIBarButtonItem) {
        dismiss()
    }

    func dismiss() {
        dismiss(animated: true, completion: nil)
        onDismissCallback?(self)
    }

    func styleButton(_ button: UIButton) {
        Current.style.onboardingButtonPrimary(button)
    }

    override func show(_ vc: UIViewController, sender: Any?) {
        if let vc = vc as? ConnectionErrorViewController, let sender = sender as? UIViewController {
            // we don't check if we're _going_ to replace, in case the user tapped 'back' first
            setViewControllers(viewControllers.map {
                if $0 == sender {
                    return vc
                } else {
                    return $0
                }
            }, animated: false)
        } else {
            super.show(vc, sender: sender)
        }
    }
}

extension OnboardingNavigationViewController: UINavigationControllerDelegate {
    private func updateNavigationBar(for controller: UIViewController?, animated: Bool) {
        let hiddenNavigationBarClasses: [UIViewController.Type] = [
            WelcomeViewController.self,
            IndividualPermissionViewController.self,
            ConnectInstanceViewController.self,
        ]

        if let controller = controller,
           hiddenNavigationBarClasses.contains(where: { type(of: controller) == $0 }) {
            setNavigationBarHidden(true, animated: animated)
        } else {
            setNavigationBarHidden(false, animated: animated)
        }
    }

    func navigationController(
        _ navigationController: UINavigationController,
        willShow viewController: UIViewController,
        animated: Bool
    ) {
        updateNavigationBar(for: viewController, animated: animated)

        transitionCoordinator?.animate(alongsideTransition: { _ in
            // putting the navigation bar change here causes the bar to animate in/out
        }, completion: { [weak self] context in
            if context.isCancelled {
                self?.updateNavigationBar(for: self?.topViewController, animated: animated)
            }
        })
    }
}
