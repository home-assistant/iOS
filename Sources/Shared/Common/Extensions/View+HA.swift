import Foundation
import HADesignSystem
import SwiftUI

public extension View {
    func embeddedInHostingController() -> UIHostingController<some View> {
        let provider = ViewControllerProvider()
        // Every UIKit-hosted SwiftUI screen flows through here, so the brand toggle style applies
        // app-wide from this single seam (the SwiftUI scene roots in HAApp apply it themselves).
        let hostingAccessingView = environmentObject(provider)
            .toggleStyle(BrandedSwitchToggleStyle())
        let hostingController = UIHostingController(rootView: hostingAccessingView)
        provider.viewController = hostingController
        return hostingController
    }
}

public final class ViewControllerProvider: ObservableObject {
    public fileprivate(set) weak var viewController: UIViewController?
}

// MARK: - UIViewController in SwiftUI

public struct ViewControllerWrapper<T: UIViewController>: UIViewControllerRepresentable {
    private let viewController: T
    private let configure: ((T) -> Void)?

    public init(_ viewController: T, configure: ((T) -> Void)? = nil) {
        self.viewController = viewController
        self.configure = configure
    }

    public func makeUIViewController(context: Context) -> T {
        configure?(viewController)
        return viewController
    }

    public func updateUIViewController(_ uiViewController: T, context: Context) {
        // Update the view controller if needed
        configure?(uiViewController)
    }
}

public extension View {
    func embed<T: UIViewController>(_ viewController: T, configure: ((T) -> Void)? = nil) -> some View {
        ViewControllerWrapper(viewController, configure: configure)
    }
}

// MARK: - ViewControllerProvider for SwiftUI-presented views

public extension View {
    /// Injects a `ViewControllerProvider` whose `viewController` resolves to the UIKit controller hosting this
    /// view, for SwiftUI-presented contexts (e.g. a `.sheet`) that render a provider-dependent view directly
    /// rather than through `embeddedInHostingController()`. The view keeps SwiftUI's own `\.dismiss` working
    /// while still getting a presenter for UIKit modals / the in-app browser.
    func injectingViewControllerProvider() -> some View {
        modifier(InjectViewControllerProvider())
    }
}

private struct InjectViewControllerProvider: ViewModifier {
    @StateObject private var provider = ViewControllerProvider()

    func body(content: Content) -> some View {
        content
            .environmentObject(provider)
            .background(ViewControllerResolver { provider.viewController = $0 })
    }
}

/// Reports the UIKit view controller hosting it so a sibling SwiftUI view can use it as a presenter.
private struct ViewControllerResolver: UIViewControllerRepresentable {
    let onResolve: (UIViewController) -> Void

    func makeUIViewController(context: Context) -> ResolverViewController {
        let controller = ResolverViewController()
        controller.onResolve = onResolve
        return controller
    }

    func updateUIViewController(_ uiViewController: ResolverViewController, context: Context) {}
}

private final class ResolverViewController: UIViewController {
    var onResolve: ((UIViewController) -> Void)?

    override func didMove(toParent parent: UIViewController?) {
        super.didMove(toParent: parent)
        // Our parent is the controller hosting the SwiftUI presentation (e.g. the sheet); it can present
        // UIKit modals and serves as the in-app browser sender.
        guard let parent else { return }
        onResolve?(parent)
    }
}
