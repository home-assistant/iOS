import Foundation
import SwiftUI
import Shared

final class WatchHostingController: WKHostingController<WatchHomeView> {

    override init() {
        super.init()
        MaterialDesignIcons.register()
    }

    override var body: WatchHomeView {
        WatchHomeView()
    }
}
