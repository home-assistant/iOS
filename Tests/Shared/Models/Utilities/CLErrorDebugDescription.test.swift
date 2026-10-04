import CoreLocation
import Foundation
@testable import Shared
import XCTest

final class CLErrorDebugDescriptionTests: XCTestCase {
    func testEveryKnownCodeHasItsOwnDescription() {
        let expected: [(CLError.Code, String)] = [
            (.locationUnknown, L10n.ClError.Description.locationUnknown),
            (.denied, L10n.ClError.Description.denied),
            (.network, L10n.ClError.Description.network),
            (.headingFailure, L10n.ClError.Description.headingFailure),
            (.regionMonitoringDenied, L10n.ClError.Description.regionMonitoringDenied),
            (.regionMonitoringFailure, L10n.ClError.Description.regionMonitoringFailure),
            (.regionMonitoringSetupDelayed, L10n.ClError.Description.regionMonitoringSetupDelayed),
            (.regionMonitoringResponseDelayed, L10n.ClError.Description.regionMonitoringResponseDelayed),
            (.geocodeFoundNoResult, L10n.ClError.Description.geocodeFoundNoResult),
            (.geocodeFoundPartialResult, L10n.ClError.Description.geocodeFoundPartialResult),
            (.geocodeCanceled, L10n.ClError.Description.geocodeCanceled),
            (.deferredFailed, L10n.ClError.Description.deferredFailed),
            (.deferredNotUpdatingLocation, L10n.ClError.Description.deferredNotUpdatingLocation),
            (.deferredAccuracyTooLow, L10n.ClError.Description.deferredAccuracyTooLow),
            (.deferredDistanceFiltered, L10n.ClError.Description.deferredDistanceFiltered),
            (.deferredCanceled, L10n.ClError.Description.deferredCanceled),
            (.rangingUnavailable, L10n.ClError.Description.rangingUnavailable),
            (.rangingFailure, L10n.ClError.Description.rangingFailure),
        ]

        for (code, description) in expected {
            XCTAssertEqual(CLError(code).debugDescription, description, "code \(code.rawValue)")
        }
        XCTAssertEqual(Set(expected.map(\.1)).count, expected.count)
    }

    func testUnhandledCodeFallsBackToUnknown() {
        XCTAssertEqual(CLError(.promptDeclined).debugDescription, L10n.ClError.Description.unknown)
    }
}
