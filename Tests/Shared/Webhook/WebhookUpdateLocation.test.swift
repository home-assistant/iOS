import CoreLocation
import Foundation
@testable import Shared
import XCTest

class WebhookUpdateLocationTests: XCTestCase {
    func testMissingLocationAndZone() {
        for trigger: LocationUpdateTrigger in [
            .GPSRegionEnter,
            .GPSRegionExit,
            .BeaconRegionEnter,
            .BeaconRegionExit,
        ] {
            Current.device.batteries = { [DeviceBattery(level: 44, state: .charging, attributes: [:])] }

            let model = WebhookUpdateLocation(trigger: trigger, location: nil, zone: nil)
            let json = model.toJSON()
            XCTAssertEqual(json["battery"] as? Int, 44)
            XCTAssertNil(json["gps"])
            XCTAssertNil(json["gps_accuracy"])
            XCTAssertNil(json["location_name"])
            XCTAssertNil(json["speed"])
            XCTAssertNil(json["altitude"])
            XCTAssertNil(json["course"])
            XCTAssertNil(json["vertical_accuracy"])
        }
    }

    func testNameOfZoneWhenSet() {
        Current.device.batteries = { [DeviceBattery(level: 44, state: .charging, attributes: [:])] }

        let zone = with(RLMZone()) {
            $0.entityId = "zone.given_name"
            $0.serverIdentifier = "server1"
            $0.Latitude = -2.34
            $0.Longitude = -5.67
            $0.Radius = 88.8
        }

        let model = WebhookUpdateLocation(trigger: .BeaconRegionEnter, usingNameOf: zone)
        let json = model.toJSON()
        XCTAssertEqual(json["battery"] as? Int, 44)
        XCTAssertEqual(json["location_name"] as? String, "given_name")
        XCTAssertNil(json["gps"])
        XCTAssertNil(json["gps_accuracy"])
        XCTAssertNil(json["speed"])
        XCTAssertNil(json["altitude"])
        XCTAssertNil(json["course"])
        XCTAssertNil(json["vertical_accuracy"])
    }

    func testNameOfZoneWithNoZone() {
        Current.device.batteries = { [DeviceBattery(level: 44, state: .charging, attributes: [:])] }

        let model = WebhookUpdateLocation(trigger: .BeaconRegionEnter, usingNameOf: nil)
        let json = model.toJSON()
        XCTAssertEqual(json["battery"] as? Int, 44)
        XCTAssertEqual(json["location_name"] as? String, "not_home")
        XCTAssertNil(json["gps"])
        XCTAssertNil(json["gps_accuracy"])
        XCTAssertNil(json["speed"])
        XCTAssertNil(json["altitude"])
        XCTAssertNil(json["course"])
        XCTAssertNil(json["vertical_accuracy"])
    }

    func testBeaconEnterNotPassive() {
        Current.device.batteries = { [DeviceBattery(level: 44, state: .charging, attributes: [:])] }

        let model = WebhookUpdateLocation(
            trigger: .BeaconRegionEnter,
            location: CLLocation(latitude: 1.23, longitude: 4.56),
            zone: with(RLMZone()) {
                $0.entityId = "zone.given_name"
                $0.serverIdentifier = "server1"
                $0.Latitude = -2.34
                $0.Longitude = -5.67
                $0.Radius = 88.8
            }
        )

        let json = model.toJSON()

        XCTAssertEqual(json["battery"] as? Int, 44)
        XCTAssertEqual(json["gps"] as? [Double], [-2.34, -5.67])
        XCTAssertEqual(json["gps_accuracy"] as? Double, 88.8)
        XCTAssertEqual(json["location_name"] as? String, "Given Name")
        XCTAssertNil(json["speed"])
        XCTAssertNil(json["altitude"])
        XCTAssertNil(json["course"])
        XCTAssertNil(json["vertical_accuracy"])
    }

    func testBeaconEnterPassive() {
        let model = WebhookUpdateLocation(
            trigger: .BeaconRegionEnter,
            location: CLLocation(latitude: 1.23, longitude: 4.56),
            zone: with(RLMZone()) {
                $0.entityId = "zone.given_name"
                $0.serverIdentifier = "server1"
                $0.Latitude = -2.34
                $0.Longitude = -5.67
                $0.Radius = 88.8
                $0.isPassive = true
            }
        )

        let json = model.toJSON()

        XCTAssertEqual(json["battery"] as? Int, 44)
        XCTAssertEqual(json["gps"] as? [Double], [-2.34, -5.67])
        XCTAssertEqual(json["gps_accuracy"] as? Double, 88.8)
        XCTAssertNil(json["location_name"], "location is empty because it's passive")
        XCTAssertNil(json["speed"])
        XCTAssertNil(json["altitude"])
        XCTAssertNil(json["course"])
        XCTAssertNil(json["vertical_accuracy"])
    }

    func testBeaconExitNotPassive() {
        Current.device.batteries = { [DeviceBattery(level: 44, state: .charging, attributes: [:])] }

        let model = WebhookUpdateLocation(
            trigger: .BeaconRegionExit,
            location: CLLocation(latitude: 1.23, longitude: 4.56),
            zone: with(RLMZone()) {
                $0.entityId = "zone.given_name"
                $0.serverIdentifier = "server1"
                $0.Latitude = -2.34
                $0.Longitude = -5.67
                $0.Radius = 88.8
            }
        )

        let json = model.toJSON()

        // In case this model is accidentally sent to the server, it's without location info
        XCTAssertEqual(json["battery"] as? Int, 44)
        XCTAssertNil(json["gps"])
        XCTAssertNil(json["gps_accuracy"])
        XCTAssertNil(json["location_name"])
        XCTAssertNil(json["speed"])
        XCTAssertNil(json["altitude"])
        XCTAssertNil(json["course"])
        XCTAssertNil(json["vertical_accuracy"])
    }

    func testBeaconEnterHome() {
        Current.device.batteries = { [DeviceBattery(level: 44, state: .charging, attributes: [:])] }

        let model = WebhookUpdateLocation(
            trigger: .BeaconRegionEnter,
            location: CLLocation(latitude: 1.23, longitude: 4.56),
            zone: with(RLMZone()) {
                $0.entityId = "zone.home"
                $0.serverIdentifier = "server1"
                $0.Latitude = -2.34
                $0.Longitude = -5.67
                $0.Radius = 88.8
            }
        )

        let json = model.toJSON()

        XCTAssertEqual(json["battery"] as? Int, 44)
        XCTAssertEqual(json["gps"] as? [Double], [-2.34, -5.67])
        XCTAssertEqual(json["gps_accuracy"] as? Double, 88.8)
        XCTAssertEqual(json["location_name"] as? String, "home")
        XCTAssertNil(json["speed"])
        XCTAssertNil(json["altitude"])
        XCTAssertNil(json["course"])
        XCTAssertNil(json["vertical_accuracy"])
    }

    func testBeaconExitHome() {
        Current.device.batteries = { [DeviceBattery(level: 44, state: .charging, attributes: [:])] }

        let model = WebhookUpdateLocation(
            trigger: .BeaconRegionExit,
            location: CLLocation(latitude: 1.23, longitude: 4.56),
            zone: with(RLMZone()) {
                $0.entityId = "zone.given_name"
                $0.serverIdentifier = "server1"
                $0.Latitude = -2.34
                $0.Longitude = -5.67
                $0.Radius = 88.8
            }
        )

        let json = model.toJSON()

        // In case this model is accidentally sent to the server, it's without location info
        XCTAssertEqual(json["battery"] as? Int, 44)
        XCTAssertNil(json["gps"])
        XCTAssertNil(json["gps_accuracy"])
        XCTAssertNil(json["location_name"])
        XCTAssertNil(json["speed"])
        XCTAssertNil(json["altitude"])
        XCTAssertNil(json["course"])
        XCTAssertNil(json["vertical_accuracy"])
    }

    func testBeaconExitPassive() {
        Current.device.batteries = { [DeviceBattery(level: 44, state: .charging, attributes: [:])] }

        let model = WebhookUpdateLocation(
            trigger: .BeaconRegionExit,
            location: CLLocation(latitude: 1.23, longitude: 4.56),
            zone: with(RLMZone()) {
                $0.entityId = "zone.given_name"
                $0.serverIdentifier = "server1"
                $0.Latitude = -2.34
                $0.Longitude = -5.67
                $0.Radius = 88.8
                $0.isPassive = true
            }
        )

        let json = model.toJSON()

        // In case this model is accidentally sent to the server, it's without location info
        XCTAssertEqual(json["battery"] as? Int, 44)
        XCTAssertNil(json["gps"])
        XCTAssertNil(json["gps_accuracy"])
        XCTAssertNil(json["location_name"])
        XCTAssertNil(json["speed"])
        XCTAssertNil(json["altitude"])
        XCTAssertNil(json["course"])
        XCTAssertNil(json["vertical_accuracy"])
    }

    @available(iOS 13.4, *)
    func testGPSEnterNoBattery() {
        Current.device.batteries = { [] }

        let now = Date()

        let model = WebhookUpdateLocation(
            trigger: .GPSRegionEnter,
            location: CLLocation(
                coordinate: .init(latitude: 1.23, longitude: 4.56),
                altitude: 103,
                horizontalAccuracy: 104,
                verticalAccuracy: 105,
                course: 106,
                courseAccuracy: 107,
                speed: 108,
                speedAccuracy: 109,
                timestamp: now.addingTimeInterval(-110)
            ),
            zone: with(RLMZone()) {
                $0.entityId = "zone.given_name"
                $0.serverIdentifier = "server1"
                $0.Latitude = -2.34
                $0.Longitude = -5.67
                $0.Radius = 88.8
            }
        )

        let json = model.toJSON()

        XCTAssertNil(json["battery"])
        XCTAssertEqual(json["gps"] as? [Double], [1.23, 4.56])
        XCTAssertEqual(json["gps_accuracy"] as? Double, 104)
        XCTAssertNil(json["location_name"])
        XCTAssertEqual(json["speed"] as? Double, 108)
        XCTAssertEqual(json["altitude"] as? Double, 103)
        XCTAssertEqual(json["course"] as? Double, 106)
        XCTAssertEqual(json["vertical_accuracy"] as? Double, 105)
    }

    @available(iOS 13.4, *)
    func testGPSEnter() {
        Current.device.batteries = { [DeviceBattery(level: 44, state: .charging, attributes: [:])] }

        let now = Date()

        let model = WebhookUpdateLocation(
            trigger: .GPSRegionEnter,
            location: CLLocation(
                coordinate: .init(latitude: 1.23, longitude: 4.56),
                altitude: 103,
                horizontalAccuracy: 104,
                verticalAccuracy: 105,
                course: 106,
                courseAccuracy: 107,
                speed: 108,
                speedAccuracy: 109,
                timestamp: now.addingTimeInterval(-110)
            ),
            zone: with(RLMZone()) {
                $0.entityId = "zone.given_name"
                $0.serverIdentifier = "server1"
                $0.Latitude = -2.34
                $0.Longitude = -5.67
                $0.Radius = 88.8
            }
        )

        let json = model.toJSON()

        XCTAssertEqual(json["battery"] as? Int, 44)
        XCTAssertEqual(json["gps"] as? [Double], [1.23, 4.56])
        XCTAssertEqual(json["gps_accuracy"] as? Double, 104)
        XCTAssertNil(json["location_name"])
        XCTAssertEqual(json["speed"] as? Double, 108)
        XCTAssertEqual(json["altitude"] as? Double, 103)
        XCTAssertEqual(json["course"] as? Double, 106)
        XCTAssertEqual(json["vertical_accuracy"] as? Double, 105)
    }

    @available(iOS 13.4, *)
    func testGPSExit() {
        Current.device.batteries = { [DeviceBattery(level: 44, state: .charging, attributes: [:])] }

        let now = Date()

        let model = WebhookUpdateLocation(
            trigger: .GPSRegionExit,
            location: CLLocation(
                coordinate: .init(latitude: 1.23, longitude: 4.56),
                altitude: 103,
                horizontalAccuracy: 104,
                verticalAccuracy: 105,
                course: 106,
                courseAccuracy: 107,
                speed: 108,
                speedAccuracy: 109,
                timestamp: now.addingTimeInterval(-110)
            ),
            zone: with(RLMZone()) {
                $0.entityId = "zone.given_name"
                $0.serverIdentifier = "server1"
                $0.Latitude = -2.34
                $0.Longitude = -5.67
                $0.Radius = 88.8
            }
        )

        let json = model.toJSON()

        XCTAssertEqual(json["battery"] as? Int, 44)
        XCTAssertEqual(json["gps"] as? [Double], [1.23, 4.56])
        XCTAssertEqual(json["gps_accuracy"] as? Double, 104)
        XCTAssertNil(json["location_name"])
        XCTAssertEqual(json["speed"] as? Double, 108)
        XCTAssertEqual(json["altitude"] as? Double, 103)
        XCTAssertEqual(json["course"] as? Double, 106)
        XCTAssertEqual(json["vertical_accuracy"] as? Double, 105)
    }

    @available(iOS 13.4, *)
    func testGPSEnterHome() {
        Current.device.batteries = { [DeviceBattery(level: 44, state: .charging, attributes: [:])] }

        let now = Date()

        let model = WebhookUpdateLocation(
            trigger: .GPSRegionEnter,
            location: CLLocation(
                coordinate: .init(latitude: 1.23, longitude: 4.56),
                altitude: 103,
                horizontalAccuracy: 104,
                verticalAccuracy: 105,
                course: 106,
                courseAccuracy: 107,
                speed: 108,
                speedAccuracy: 109,
                timestamp: now.addingTimeInterval(-110)
            ),
            zone: with(RLMZone()) {
                $0.entityId = "zone.given_name"
                $0.serverIdentifier = "server1"
                $0.Latitude = -2.34
                $0.Longitude = -5.67
                $0.Radius = 88.8
            }
        )

        let json = model.toJSON()

        XCTAssertEqual(json["battery"] as? Int, 44)
        XCTAssertEqual(json["gps"] as? [Double], [1.23, 4.56])
        XCTAssertEqual(json["gps_accuracy"] as? Double, 104)
        XCTAssertNil(json["location_name"])
        XCTAssertEqual(json["speed"] as? Double, 108)
        XCTAssertEqual(json["altitude"] as? Double, 103)
        XCTAssertEqual(json["course"] as? Double, 106)
        XCTAssertEqual(json["vertical_accuracy"] as? Double, 105)
    }

    @available(iOS 13.4, *)
    func testGPSExitHome() {
        Current.device.batteries = { [DeviceBattery(level: 44, state: .charging, attributes: [:])] }

        let now = Date()

        let model = WebhookUpdateLocation(
            trigger: .GPSRegionExit,
            location: CLLocation(
                coordinate: .init(latitude: 1.23, longitude: 4.56),
                altitude: 103,
                horizontalAccuracy: 104,
                verticalAccuracy: 105,
                course: 106,
                courseAccuracy: 107,
                speed: 108,
                speedAccuracy: 109,
                timestamp: now.addingTimeInterval(-110)
            ),
            zone: with(RLMZone()) {
                $0.entityId = "zone.given_name"
                $0.serverIdentifier = "server1"
                $0.Latitude = -2.34
                $0.Longitude = -5.67
                $0.Radius = 88.8
            }
        )

        let json = model.toJSON()

        XCTAssertEqual(json["battery"] as? Int, 44)
        XCTAssertEqual(json["gps"] as? [Double], [1.23, 4.56])
        XCTAssertEqual(json["gps_accuracy"] as? Double, 104)
        XCTAssertNil(json["location_name"])
        XCTAssertEqual(json["speed"] as? Double, 108)
        XCTAssertEqual(json["altitude"] as? Double, 103)
        XCTAssertEqual(json["course"] as? Double, 106)
        XCTAssertEqual(json["vertical_accuracy"] as? Double, 105)
    }
}
