import Foundation
import GRDB

public enum StatePrecision {
    public static func adjustPrecision(serverId: String, entityId: String, stateValue: String) -> String {
        guard let stateValueFloat = Float(stateValue) else {
            return stateValue
        }
        if let decimalPlacesForEntityId: Int = {
            do {
                return try Current.database.read { db in
                    try AppEntityRegistryListForDisplay
                        .filter(
                            Column(DatabaseTables.AppEntityRegistryListForDisplay.id.rawValue) == ServerEntity
                                .uniqueId(
                                    serverId: serverId,
                                    entityId: entityId
                                )
                        )
                        .fetchOne(db)?.registry.decimalPlaces
                }
            } catch {
                Current.Log.error("Failed to fetch decimal places for entity ID: \(entityId)")
                return nil
            }
        }() {
            let numberFormatter = NumberFormatter()
            numberFormatter.numberStyle = .decimal
            numberFormatter.locale = Locale.current
            numberFormatter.maximumFractionDigits = decimalPlacesForEntityId
            numberFormatter.minimumFractionDigits = decimalPlacesForEntityId
            return numberFormatter.string(from: NSNumber(value: stateValueFloat)) ?? stateValue
        } else {
            return stateValue
        }
    }
}
