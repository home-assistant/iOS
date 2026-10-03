import Foundation
import HADesignSystem
import SwiftUI

#if os(macOS)
public extension View {
    func embeddedInHostingController() -> NSHostingController<some View> {
        let provider = ViewControllerProvider()
        // Every AppKit-hosted SwiftUI screen flows through here, so the brand toggle style applies
        // app-wide from this single seam (the SwiftUI scene roots in HAApp apply it themselves). A Mac
        // form otherwise lays out in two columns, which the screens written as iOS forms are not shaped for.
        let hostingAccessingView = environmentObject(provider)
            .toggleStyle(.haStyle)
            .formStyle(.grouped)
        let hostingController = NSHostingController(rootView: hostingAccessingView)
        provider.viewController = hostingController
        return hostingController
    }
}

public final class ViewControllerProvider: ObservableObject {
    public fileprivate(set) weak var viewController: NSViewController?
}

// MARK: - NSViewController in SwiftUI

public struct ViewControllerWrapper<T: NSViewController>: NSViewControllerRepresentable {
    private let viewController: T
    private let configure: ((T) -> Void)?

    public init(_ viewController: T, configure: ((T) -> Void)? = nil) {
        self.viewController = viewController
        self.configure = configure
    }

    public func makeNSViewController(context: Context) -> T {
        configure?(viewController)
        return viewController
    }

    public func updateNSViewController(_ nsViewController: T, context: Context) {
        // Update the view controller if needed
        configure?(nsViewController)
    }
}

public extension View {
    func embed<T: NSViewController>(_ viewController: T, configure: ((T) -> Void)? = nil) -> some View {
        ViewControllerWrapper(viewController, configure: configure)
    }
}

// MARK: - ViewControllerProvider for SwiftUI-presented views

public extension View {
    /// Injects a `ViewControllerProvider` whose `viewController` resolves to the AppKit controller hosting
    /// this view, for SwiftUI-presented contexts (e.g. a `.sheet`) that render a provider-dependent view
    /// directly rather than through `embeddedInHostingController()`.
    func injectingViewControllerProvider() -> some View {
        modifier(InjectViewControllerProvider())
    }
}

private struct InjectViewControllerProvider: ViewModifier {
    @StateObject private var provider = ViewControllerProvider()

    func body(content: Content) -> some View {
        content
            .environmentObject(provider)
            .toggleStyle(.haStyle)
            .formStyle(.grouped)
            .background(ViewControllerResolver { provider.viewController = $0 })
    }
}

/// Reports the AppKit view controller hosting it so a sibling SwiftUI view can use it as a presenter.
public struct ViewControllerResolver: NSViewControllerRepresentable {
    private let onResolve: (NSViewController) -> Void

    public init(onResolve: @escaping (NSViewController) -> Void) {
        self.onResolve = onResolve
    }

    public func makeNSViewController(context: Context) -> NSViewController {
        let controller = ResolverViewController()
        controller.onResolve = onResolve
        return controller
    }

    public func updateNSViewController(_ nsViewController: NSViewController, context: Context) {}
}

private final class ResolverViewController: NSViewController {
    var onResolve: ((NSViewController) -> Void)?

    override func loadView() {
        view = NSView()
    }

    override func viewDidAppear() {
        super.viewDidAppear()
        // The window's content controller is the one hosting the SwiftUI presentation (e.g. the sheet);
        // it can present AppKit sheets on the view's behalf.
        onResolve?(parent ?? view.window?.contentViewController ?? self)
    }
}
#else
public extension View {
    func embeddedInHostingController() -> UIHostingController<some View> {
        let provider = ViewControllerProvider()
        // Every UIKit-hosted SwiftUI screen flows through here, so the brand toggle style applies
        // app-wide from this single seam (the SwiftUI scene roots in HAApp apply it themselves).
        let hostingAccessingView = environmentObject(provider)
            .toggleStyle(.haStyle)
        let hostingController = UIHostingController(rootView: hostingAccessingView)
        provider.viewController = hostingController
        return hostingController
    }

    /// `embeddedInHostingController()` with a caller-supplied hosting controller, for screens that need a
    /// subclass (e.g. to observe their own presentation lifecycle). The view is type-erased so the subclass
    /// needs no generic parameter of its own.
    func embeddedInHostingController<Controller: UIHostingController<AnyView>>(
        _ makeController: (AnyView) -> Controller
    ) -> Controller {
        let provider = ViewControllerProvider()
        let hostingAccessingView = AnyView(
            environmentObject(provider)
                .toggleStyle(.haStyle)
        )
        let hostingController = makeController(hostingAccessingView)
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
            .toggleStyle(.haStyle)
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
#endif
