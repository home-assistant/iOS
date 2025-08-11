import Foundation
import Shared
import SwiftUI

final class WatchHostingController: WKHostingController<WatchHomeView> {
    override init() {
        super.init()
        MaterialDesignIcons.register()
    }

    override var body: WatchHomeView {
        WatchHomeView()
    }
}
