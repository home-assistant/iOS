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
    ///
    /// This is the only part of the feature that needs the iOS 27.1 SDK. It reads the two values
    /// off `UIHinge` and hands them to `HingeState`, so the mapping itself stays in `Shared` where
    /// it is tested.
    func setupHingeObservation() {
        guard #available(iOS 27.1, *) else { return }
        let interaction = UIHingeInteraction { _, update in
            Current.hinge.setState(update.hinge.map { hinge in
                HingeState(angleRadians: hinge.angle, uiKitStatusRawValue: hinge.status.rawValue)
            })
        }
        view.addInteraction(interaction)
    }
}
