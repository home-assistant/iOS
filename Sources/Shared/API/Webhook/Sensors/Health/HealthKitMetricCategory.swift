#if os(iOS) && !targetEnvironment(macCatalyst)
import Foundation

/// Groups Apple Health metrics the same way the Health app does, so the sensor list stays browsable.
public enum HealthKitMetricCategory: String, CaseIterable, Sendable {
    case activity
    case body
    case heart
    case nutrition
    case respiratory
    case sleep
    case vitals

    public var name: String {
        switch self {
        case .activity: return L10n.SettingsSensors.Health.Category.activity
        case .body: return L10n.SettingsSensors.Health.Category.body
        case .heart: return L10n.SettingsSensors.Health.Category.heart
        case .nutrition: return L10n.SettingsSensors.Health.Category.nutrition
        case .respiratory: return L10n.SettingsSensors.Health.Category.respiratory
        case .sleep: return L10n.SettingsSensors.Health.Category.sleep
        case .vitals: return L10n.SettingsSensors.Health.Category.vitals
        }
    }
}
#endif
