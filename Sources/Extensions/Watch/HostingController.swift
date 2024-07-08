import Foundation
import SwiftUI

final class HostingController: WKHostingController<WatchHomeView<WatchHomeViewModel>> {
    override var body: WatchHomeView<WatchHomeViewModel> {
        WatchHomeView(viewModel: .init())
    }
}
