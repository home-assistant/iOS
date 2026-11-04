import CoreLocation
import Foundation
@testable import Shared
import Testing

@Suite("LocationManager temporary full accuracy")
struct LocationManagerTemporaryFullAccuracyTests {
    /// Drives the real `LocationManager` rather than a stub, so the Core Location call behind
    /// `Current.locationManager` is exercised on the path `manuallyUpdate` takes.
    ///
    /// Deliberately asserts nothing about the completion handler. Core Location does not call it at
    /// all on a host that has no location authorization — which the test host does not — so waiting
    /// on it would fail here for a reason that says nothing about this code. What this does cover is
    /// that the main-queue hop and the request itself run without trapping.
    @Test("Dispatches the request to Core Location without trapping")
    func dispatchesRequestToCoreLocation() async {
        let manager = LocationManager()

        manager.requestTemporaryFullAccuracyAuthorization(
            purposeKey: "TemporaryFullAccuracyReasonManualUpdate"
        ) { _ in }

        // The request is hopped to the main queue; give it a turn to run before the test ends.
        try? await Task.sleep(for: .milliseconds(200))
        withExtendedLifetime(manager) {}
    }
}
