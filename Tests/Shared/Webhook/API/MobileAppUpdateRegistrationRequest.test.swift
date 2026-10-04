import Foundation
import ObjectMapper
@testable import Shared
import Testing

struct MobileAppUpdateRegistrationRequestTests {
    @Test func mapsEveryFieldToJSON() {
        let request = MobileAppUpdateRegistrationRequest()
        request.AppData = ["push_url": "https://example.com"]
        request.AppVersion = "2026.1 (1)"
        request.DeviceName = "Phone"
        request.Manufacturer = "Apple"
        request.Model = "iPhone"
        request.OSVersion = "26.0"

        let json = Mapper().toJSON(request)

        #expect((json["app_data"] as? [String: Any])?["push_url"] as? String == "https://example.com")
        #expect(json["app_version"] as? String == "2026.1 (1)")
        #expect(json["device_name"] as? String == "Phone")
        #expect(json["manufacturer"] as? String == "Apple")
        #expect(json["model"] as? String == "iPhone")
        #expect(json["os_version"] as? String == "26.0")
        #expect(json["app_id"] == nil)
    }

    @Test func mapsFromJSON() throws {
        let request = try #require(Mapper<MobileAppUpdateRegistrationRequest>().map(JSON: [
            "app_version": "2026.1 (1)",
            "device_name": "Phone",
            "manufacturer": "Apple",
        ]))

        #expect(request.AppVersion == "2026.1 (1)")
        #expect(request.DeviceName == "Phone")
        #expect(request.Manufacturer == "Apple")
        #expect(request.Model == nil)
        #expect(request.AppData == nil)
    }
}
