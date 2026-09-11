import Foundation
import Shared

/// Shared helper for the widgets' entity source: fetches the sorted attribute keys of a picked entity
/// so the attribute pickers can offer them (mirrors the watch complication builder's attribute list).
@available(iOS 17.0, macOS 14.0, watchOS 10.0, *)
enum WidgetEntityAttributes {
    static func keys(for entity: HAAppEntityAppIntentEntity?) async -> [String] {
        guard let entity,
              let server = Current.servers.all.first(where: { $0.identifier.rawValue == entity.serverId }) else {
            return []
        }
        let attributes = await ControlEntityProvider(domains: []).attributes(server: server, entityId: entity.entityId)
        return attributes?.keys.sorted() ?? []
    }

    /// The value a widget's entity source displays, with its unit and, when it is numeric, the number
    /// behind it (a gauge maps that onto its range). When `attribute` is set, reads that attribute
    /// (unit via the shared `attributeUnit` map); otherwise reads the entity state.
    ///
    /// Numeric values are rounded the way the frontend rounds them: to `decimalPlaces` when the user
    /// set it on the widget, otherwise to Home Assistant's display precision for the entity from the
    /// local registry. Without that rounding a unit-converted state such as `78.99999999999999` shows
    /// every digit where the app and the web UI show `79.0`. Returns nil when the value can't be fetched.
    static func resolvedValue(
        entityId: String,
        attribute: String?,
        decimalPlaces: Int? = nil,
        server: Server
    ) async -> (value: String, unit: String?, number: Double?)? {
        let provider = ControlEntityProvider(domains: [])
        if let attribute {
            guard let attributes = await provider.attributes(server: server, entityId: entityId),
                  let raw = attributes[attribute] else {
                return nil
            }
            let unit = WatchComplicationConfig.attributeUnit(
                attribute: attribute,
                attributes: attributes,
                domain: entityId.components(separatedBy: ".").first
            )
            let rawValue = String(describing: raw)
            return (
                displayValue(raw: rawValue, entityId: entityId, decimalPlaces: decimalPlaces, server: server),
                unit,
                Double(rawValue)
            )
        }
        guard let state = await provider.state(server: server, entityId: entityId) else {
            return nil
        }
        // The provider already applied the registry precision (and the device-class wording of a
        // non-numeric state) to `value`, so a user override re-formats the raw state instead: the
        // rounding never runs twice, and a non-numeric state keeps its wording.
        let number = Double(state.rawState)
        guard let decimalPlaces, number != nil else {
            return (state.value, state.unitOfMeasurement, number)
        }
        return (
            StatePrecision.adjustPrecision(stateValue: state.rawState, decimalPlaces: decimalPlaces),
            state.unitOfMeasurement,
            number
        )
    }

    /// Rounds a raw numeric value to the user's decimal places, or to the entity's registry display
    /// precision when they left it automatic; anything non-numeric passes through unchanged.
    private static func displayValue(
        raw: String,
        entityId: String,
        decimalPlaces: Int?,
        server: Server
    ) -> String {
        if let decimalPlaces {
            return StatePrecision.adjustPrecision(stateValue: raw, decimalPlaces: decimalPlaces)
        }
        return StatePrecision.adjustPrecision(
            serverId: server.identifier.rawValue,
            entityId: entityId,
            stateValue: raw
        )
    }
}
