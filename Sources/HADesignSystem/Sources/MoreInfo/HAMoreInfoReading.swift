import Foundation

/// One reading over a more-info dialog's dial: "Current temperature · 18 °C".
///
/// Frontend counterpart: one `div` of the `.current` row in `more-info-climate`,
/// `more-info-humidifier` and `more-info-water_heater`, each a formatted attribute name over its
/// formatted value.
public struct HAMoreInfoReading: Identifiable, Hashable {
    public let label: String
    public let value: String

    public var id: String { label }

    public init(label: String, value: String) {
        self.label = label
        self.value = value
    }
}
