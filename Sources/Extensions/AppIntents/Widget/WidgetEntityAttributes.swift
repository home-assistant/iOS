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

    /// Resolves the displayed value + unit for a widget's entity source, with the number behind a
    /// numeric value for the gauge's fill (the displayed value is locale-formatted, with grouping, so it
    /// is not parseable back). When `attribute` is set, reads that attribute (unit via the shared
    /// `attributeUnit` map); otherwise reads the entity state.
    ///
    /// Numeric values are rounded the way the frontend rounds them, to the entity's display precision
    /// from the entity registry mirrored in GRDB. The state provider already does that for the state;
    /// an attribute gets the same treatment here, as on the watch, so a unit-converted temperature such
    /// as `78.99999999999999` reads `79.0` like it does in the app and the web UI. Returns nil when the
    /// value can't be fetched.
    static func resolvedValue(
        entityId: String,
        attribute: String?,
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
            let value = StatePrecision.adjustPrecision(
                serverId: server.identifier.rawValue,
                entityId: entityId,
                stateValue: rawValue
            )
            return (value, unit, Double(rawValue))
        }
        guard let state = await provider.state(server: server, entityId: entityId) else {
            return nil
        }
        return (state.value, state.unitOfMeasurement, Double(state.rawState))
    }
}
