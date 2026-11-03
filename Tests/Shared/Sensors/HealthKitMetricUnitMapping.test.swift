import Foundation
import HealthKit
@testable import Shared
import Testing

/// Every catalog unit maps to an `HKUnit` where the running OS provides one; `effortScore` only exists
/// from iOS 18, and maps to `nil` before that so callers skip the metric.
struct HealthKitMetricUnitMappingTests {
    @Test func everyUnitHasAHealthKitUnit() {
        for unit in HealthKitMetricUnit.allCases where unit != .effortScore {
            #expect(unit.hkUnit != nil, "\(unit)")
        }
        if #available(iOS 18.0, *) {
            #expect(HealthKitMetricUnit.effortScore.hkUnit == HKUnit.appleEffortScore())
        } else {
            #expect(HealthKitMetricUnit.effortScore.hkUnit == nil)
        }
        #expect(HealthKitMetricUnit.kilometer.hkUnit == HKUnit.meterUnit(with: .kilo))
        #expect(HealthKitMetricUnit.countPerMinute.hkUnit == HKUnit.count().unitDivided(by: .minute()))
    }
}
