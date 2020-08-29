import Foundation
@testable import Shared
import XCTest
import PromiseKit

class LastUpdateSensorTests: XCTestCase {
    func testManualTrigger() throws {
        let request: SensorProviderRequest = .init(
            reason: .trigger("Manual"),
            dependencies: .init(),
            location: nil
        )
        let promise = LastUpdateSensor(request: request).sensors()
        let sensors = try hang(promise)
        XCTAssertEqual(sensors.count, 1)
        XCTAssertEqual(sensors[0].UniqueID, "last_update_trigger")
        XCTAssertEqual(sensors[0].Name, "Last Update Trigger")
        XCTAssertEqual(sensors[0].Icon, "mdi:cellphone-wireless")
        XCTAssertEqual(sensors[0].State as? String, "Manual")
    }
}
