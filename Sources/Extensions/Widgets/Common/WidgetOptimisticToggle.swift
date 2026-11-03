import Shared
import SwiftUI

struct WidgetOptimisticToggle: Hashable, Encodable {
    let isOn: Bool
    let onColor: Color
    let offColor: Color

    init?(domain: Domain?, state: WidgetEntityState?, customColor: Color? = nil) {
        guard let domain, Self.supports(domain), let state,
              state.rawState == "on" || state.rawState == "off" else { return nil }
        self.isOn = state.rawState == "on"
        self.onColor = state.iconColor(domain: domain, customColor: customColor, stateOverride: "on")
        self.offColor = state.iconColor(domain: domain, customColor: customColor, stateOverride: "off")
    }

    static func supports(_ domain: Domain) -> Bool {
        switch domain {
        case .light, .switch, .inputBoolean, .fan:
            return true
        default:
            return false
        }
    }
}
