import Foundation
import Shared
import SwiftUI
import UIKit
import WatchKit

struct VolumeView: WKInterfaceObjectRepresentable {
    typealias WKInterfaceObjectType = WKInterfaceVolumeControl

    func makeWKInterfaceObject(context: Self.Context) -> WKInterfaceVolumeControl {
        let view = WKInterfaceVolumeControl(origin: .local)
        view.setTintColor(UIColor(Color.haPrimary))
        return view
    }

    func updateWKInterfaceObject(
        _ wkInterfaceObject: WKInterfaceVolumeControl,
        context: WKInterfaceObjectRepresentableContext<VolumeView>
    ) {}
}
