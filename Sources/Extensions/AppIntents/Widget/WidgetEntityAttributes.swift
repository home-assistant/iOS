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

    /// Resolves the displayed value + unit for a widget's entity source. When `attribute` is set, reads
    /// that attribute (unit via the shared `attributeUnit` map); otherwise reads the entity state (which
    /// already carries Home Assistant's precision + unit). Returns nil when the value can't be fetched.
    static func resolvedValue(
        entityId: String,
        attribute: String?,
        server: Server
    ) async -> (value: String, unit: String?)? {
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
            return (String(describing: raw), unit)
        }
        guard let state = await provider.state(server: server, entityId: entityId) else {
            return nil
        }
        return (state.value, state.unitOfMeasurement)
    }
}
