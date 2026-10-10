#if os(macOS)
import AppKit

/// One screen shown through `NSViewController.presentSheet(_:)`: the controller it was handed over in, the
/// hidden host that presents it and the model that closes it.
final class MacSwiftUISheetPresentation {
    /// The controller the screen arrived in. It is never put on screen itself; it stands for the sheet in
    /// code that tracks what is presented.
    let carrier: NSViewController
    let model: MacSwiftUISheetModel
    let host: NSViewController
    /// The controller SwiftUI hosts the screen in, once the sheet is up.
    weak var contentController: NSViewController?

    init(carrier: NSViewController, model: MacSwiftUISheetModel, host: NSViewController) {
        self.carrier = carrier
        self.model = model
        self.host = host
    }
}
#endif
