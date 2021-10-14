import Eureka
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
        case .initial: rootViewController = OnboardingWelcomeViewController()
        case .secondary: rootViewController = OnboardingScanningViewController()
        }

        if #available(iOS 13, *) {
            super.init(rootViewController: rootViewController)
        } else {
            // iOS 12 won't create this initializer even though init(rootViewController:) calls it
            super.init(nibName: nil, bundle: nil)
            viewControllers = [rootViewController]
        }

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

    @objc private func cancelTapped(_ sender: UIBarButtonItem) {
        dismiss()
    }

    func dismiss() {
        dismiss(animated: true, completion: nil)
        onDismissCallback?(self)
    }

    override func show(_ vc: UIViewController, sender: Any?) {
        if vc is OnboardingTerminalViewController {
            Current.onboardingObservation.complete()
            dismiss()
        } else {
            super.show(vc, sender: sender)
        }
    }
}

extension OnboardingNavigationViewController: UINavigationControllerDelegate {
    private func updateNavigationBar(for controller: UIViewController?, animated: Bool) {
        let hiddenNavigationBarClasses: [UIViewController.Type] = [
            OnboardingWelcomeViewController.self,
            OnboardingPermissionViewController.self,
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
