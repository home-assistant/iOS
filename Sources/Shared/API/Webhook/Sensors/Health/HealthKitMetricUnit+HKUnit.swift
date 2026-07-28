#if os(iOS) && !targetEnvironment(macCatalyst)
import Foundation
import HealthKit

public extension HealthKitMetricUnit {
    /// The matching `HKUnit`, or `nil` when the running OS is too old to provide it. Callers skip the
    /// metric in that case rather than falling back to a unit HealthKit would reject.
    var hkUnit: HKUnit? {
        switch self {
        case .count:
            return HKUnit.count()
        case .countPerMinute:
            return HKUnit.count().unitDivided(by: .minute())
        case .percent:
            return HKUnit.percent()
        case .centimeter:
            return HKUnit.meterUnit(with: .centi)
        case .meter:
            return HKUnit.meter()
        case .kilometer:
            return HKUnit.meterUnit(with: .kilo)
        case .meterPerSecond:
            return HKUnit.meter().unitDivided(by: .second())
        case .gram:
            return HKUnit.gram()
        case .kilogram:
            return HKUnit.gramUnit(with: .kilo)
        case .milligram:
            return HKUnit.gramUnit(with: .milli)
        case .microgram:
            return HKUnit.gramUnit(with: .micro)
        case .liter:
            return HKUnit.liter()
        case .milliliter:
            return HKUnit.literUnit(with: .milli)
        case .literPerMinute:
            return HKUnit.liter().unitDivided(by: .minute())
        case .milliliterPerKilogramPerMinute:
            return HKUnit.literUnit(with: .milli)
                .unitDivided(by: HKUnit.gramUnit(with: .kilo).unitMultiplied(by: .minute()))
        case .kilocalorie:
            return HKUnit.kilocalorie()
        case .kilocaloriePerKilogramPerHour:
            return HKUnit.kilocalorie()
                .unitDivided(by: HKUnit.gramUnit(with: .kilo).unitMultiplied(by: .hour()))
        case .millisecond:
            return HKUnit.secondUnit(with: .milli)
        case .minute:
            return HKUnit.minute()
        case .watt:
            return HKUnit.watt()
        case .degreeCelsius:
            return HKUnit.degreeCelsius()
        case .millimeterOfMercury:
            return HKUnit.millimeterOfMercury()
        case .milligramPerDeciliter:
            return HKUnit.gramUnit(with: .milli).unitDivided(by: HKUnit.literUnit(with: .deci))
        case .decibelSoundPressureLevel:
            return HKUnit.decibelAWeightedSoundPressureLevel()
        case .microsiemens:
            return HKUnit.siemensUnit(with: .micro)
        case .internationalUnit:
            return HKUnit.internationalUnit()
        case .effortScore:
            if #available(iOS 18.0, *) {
                return HKUnit.appleEffortScore()
            } else {
                return nil
            }
        }
    }
}
#endif
