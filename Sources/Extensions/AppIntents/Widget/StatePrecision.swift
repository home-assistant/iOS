import Foundation
import GRDB

public enum StatePrecision {
    public static func adjustPrecision(serverId: String, entityId: String, stateValue: String) -> String {
        if let decimalPlacesForEntityId: Int = {
            do {
                return try Current.database().read { db in
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
            return adjustPrecision(
                stateValue: stateValue,
                decimalPlaces: decimalPlacesForEntityId
            )
        } else {
            return stateValue
        }
    }

    static func adjustPrecision(
        stateValue: String,
        decimalPlaces: Int,
        locale: Locale = .current
    ) -> String {
        let trimmedStateValue = stateValue.trimmingCharacters(in: .whitespacesAndNewlines)

        if decimalPlaces == 0,
           let groupedIntegerValue = groupedIntegerValue(from: trimmedStateValue) {
            return format(number: groupedIntegerValue, decimalPlaces: 0, locale: locale) ?? stateValue
        }

        guard let number = number(from: trimmedStateValue, locale: locale) else {
            return stateValue
        }

        return format(number: number, decimalPlaces: decimalPlaces, locale: locale) ?? stateValue
    }

    private static func number(from stateValue: String, locale: Locale) -> NSNumber? {
        let machineFormatter = NumberFormatter()
        machineFormatter.numberStyle = .decimal
        machineFormatter.locale = Locale(identifier: "en_US_POSIX")
        machineFormatter.usesGroupingSeparator = false
        if let machineNumber = machineFormatter.number(from: stateValue) {
            return machineNumber
        }

        let localeFormatter = NumberFormatter()
        localeFormatter.numberStyle = .decimal
        localeFormatter.locale = locale
        return localeFormatter.number(from: stateValue)
    }

    private static func groupedIntegerValue(from stateValue: String) -> NSNumber? {
        let groupedIntegerRegex = #"^[+-]?\d{1,3}([.,]\d{3})+$"#
        guard stateValue.range(of: groupedIntegerRegex, options: .regularExpression) != nil else {
            return nil
        }

        let sign = stateValue.hasPrefix("-") ? "-" : ""
        let unsignedValue = stateValue.trimmingCharacters(in: CharacterSet(charactersIn: "+-"))
        let normalized = sign + unsignedValue
            .replacingOccurrences(of: ".", with: "")
            .replacingOccurrences(of: ",", with: "")
        guard let decimal = Decimal(string: normalized, locale: Locale(identifier: "en_US_POSIX")) else {
            return nil
        }

        return NSDecimalNumber(decimal: decimal)
    }

    private static func format(number: NSNumber, decimalPlaces: Int, locale: Locale) -> String? {
        let safeDecimalPlaces = max(0, decimalPlaces)

        let numberFormatter = NumberFormatter()
        numberFormatter.numberStyle = .decimal
        numberFormatter.locale = locale
        numberFormatter.maximumFractionDigits = safeDecimalPlaces
        numberFormatter.minimumFractionDigits = safeDecimalPlaces
        numberFormatter.usesGroupingSeparator = true
        return numberFormatter.string(from: number)
    }
}
