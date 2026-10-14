import Shared
import UIKit

extension WebViewController {
    /// Starts reporting this device's hinge into `Current.hinge`, which is where the hinge sensors
    /// read it from.
    ///
    /// The interaction lives on the root view controller's view rather than on whichever screen is
    /// in front, so updates keep arriving while settings or a dashboard is presented over it. The
    /// handler runs once with the initial state as soon as the interaction is attached, so a device
    /// with no hinge reports `nil` straight away and the sensors drop out instead of sitting
    /// unavailable forever.
    func setupHingeObservation() {
        guard #available(iOS 27.1, *),
              let interaction = HingeInteractionFactory.makeInteraction(onUpdate: { Current.hinge.setState($0) }) else {
            return
        }
        view.addInteraction(interaction)
    }
}
