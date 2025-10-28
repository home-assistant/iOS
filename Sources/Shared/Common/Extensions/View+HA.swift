import Foundation
import SwiftUI

public extension View {
    func embeddedInHostingController() -> UIHostingController<some View> {
        let provider = ViewControllerProvider()
        let hostingAccessingView = environmentObject(provider)
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
