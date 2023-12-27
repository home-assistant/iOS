import Eureka
import Shared
import UIKit

enum OnboardingBarAppearance {
    case normal
    case hidden
}

protocol OnboardingViewController {
    var preferredBarAppearance: OnboardingBarAppearance { get }
}

class OnboardingNavigationViewController: UINavigationController, RowControllerType {
    enum OnboardingStyle {
        enum RequiredType {
            case full
            case permissions
        }

        case initial
        case required(RequiredType)
        case secondary

        var insertsCancelButton: Bool {
            switch self {
            case .initial, .required: return false
            case .secondary: return true
            }
        }

        var modalPresentationStyle: UIModalPresentationStyle {
            switch self {
            case .initial, .required: return .fullScreen
            case .secondary:
                return .automatic
            }
        }
    }

    public static var requiredOnboardingStyle: OnboardingStyle? {
        if Current.servers.all.isEmpty {
            return .required(.full)
        } else if OnboardingPermissionViewControllerFactory.hasControllers {
            return .required(.permissions)
        } else {
            return nil
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
        case let .required(type):
            switch type {
            case .full:
                rootViewController = OnboardingWelcomeViewController()
            case .permissions:
                rootViewController = OnboardingPermissionViewControllerFactory.next(server: nil)
            }
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

        overrideUserInterfaceStyle = .dark

        let appearance = with(UINavigationBarAppearance()) {
            $0.configureWithOpaqueBackground()
            $0.backgroundColor = Current.style.onboardingBackground
            $0.shadowColor = .clear
            $0.titleTextAttributes = [.foregroundColor: UIColor.white]
        }
        navigationBar.standardAppearance = appearance
        navigationBar.scrollEdgeAppearance = appearance
        navigationBar.tintColor = .white
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
        } else if sender as? UIViewController == topViewController {
            super.show(vc, sender: sender)
        } else {
            Current.Log.error("unknown sender \(String(describing: sender)) wanted us to present: \(vc)")
        }
    }
}

extension OnboardingNavigationViewController: UINavigationControllerDelegate {
    private func updateNavigationBar(for controller: UIViewController?, animated: Bool) {
        let appearance: OnboardingBarAppearance

        if let controller = controller as? OnboardingViewController {
            appearance = controller.preferredBarAppearance
        } else {
            appearance = .normal
        }

        switch appearance {
        case .normal:
            setNavigationBarHidden(false, animated: animated)
        case .hidden:
            setNavigationBarHidden(true, animated: animated)
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
