import Foundation
import HAKit
@testable import Shared

/// The sample home's states as the `HAEntity` values the app actually holds, so the snapshots can be
/// drawn through the app's own presenter — the icons, colours and wording that ship — rather than
/// through the design system's English stand-in.
enum HomeDashboardEntityFixtures {
    static let entities: [String: HAEntity] = Dictionary(
        uniqueKeysWithValues: HomeDashboardSampleHome.states.compactMap { state in
            entity(from: state).map { (state.id, $0) }
        }
    )

    /// A fixed date, because a snapshot of "2 minutes ago" is a snapshot that fails tomorrow.
    private static let timestamp = Date(timeIntervalSince1970: 1_700_000_000)

    private static func entity(from state: HomeEntityState) -> HAEntity? {
        try? HAEntity(
            entityId: state.id,
            state: state.state,
            lastChanged: timestamp,
            lastUpdated: timestamp,
            attributes: attributes(of: state),
            context: .init(id: "fixture", userId: nil, parentId: nil)
        )
    }

    private static func attributes(of state: HomeEntityState) -> [String: Any] {
        var attributes: [String: Any] = [:]
        attributes["friendly_name"] = state.attributes.friendlyName
        attributes["device_class"] = state.attributes.deviceClass
        attributes["icon"] = state.attributes.icon
        attributes["unit_of_measurement"] = state.attributes.unitOfMeasurement
        attributes["supported_features"] = state.attributes.supportedFeatures
        attributes["brightness"] = state.attributes.brightness
        attributes["current_temperature"] = state.attributes.currentTemperature
        attributes["temperature"] = state.attributes.targetTemperature
        attributes["hvac_action"] = state.attributes.hvacAction
        attributes["media_title"] = state.attributes.mediaTitle
        attributes["supported_color_modes"] = state.attributes.supportedColorModes
        return attributes.compactMapValues { $0 }
    }
}
