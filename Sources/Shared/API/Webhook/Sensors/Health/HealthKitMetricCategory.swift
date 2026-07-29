#if os(iOS) && !targetEnvironment(macCatalyst)
import Foundation

/// Groups Apple Health metrics the same way the Health app does, so the sensor list stays browsable
/// now that every HealthKit quantity type is exposed.
public enum HealthKitMetricCategory: String, CaseIterable, Sendable {
    case activity
    case body
    case heart
    case hearing
    case mobility
    case nutrition
    case respiratory
    case vitals
    case other

    public var name: String {
        switch self {
        case .activity: return L10n.SettingsSensors.Health.Category.activity
        case .body: return L10n.SettingsSensors.Health.Category.body
        case .heart: return L10n.SettingsSensors.Health.Category.heart
        case .hearing: return L10n.SettingsSensors.Health.Category.hearing
        case .mobility: return L10n.SettingsSensors.Health.Category.mobility
        case .nutrition: return L10n.SettingsSensors.Health.Category.nutrition
        case .respiratory: return L10n.SettingsSensors.Health.Category.respiratory
        case .vitals: return L10n.SettingsSensors.Health.Category.vitals
        case .other: return L10n.SettingsSensors.Health.Category.other
        }
    }
}
#endif
