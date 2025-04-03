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
