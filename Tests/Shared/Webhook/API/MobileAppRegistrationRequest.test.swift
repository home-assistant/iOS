import Foundation
import ObjectMapper
@testable import Shared
import Testing

struct MobileAppRegistrationRequestTests {
    @Test func mapsEveryFieldToJSON() {
        let request = MobileAppRegistrationRequest()
        request.AppData = ["push_token": "token"]
        request.AppIdentifier = "io.robbie.HomeAssistant"
        request.AppName = "Home Assistant"
        request.AppVersion = "2026.1 (1)"
        request.DeviceName = "Phone"
        request.DeviceID = "device-id"
        request.Manufacturer = "Apple"
        request.Model = "iPhone"
        request.OSName = "iOS"
        request.OSVersion = "26.0"
        request.SupportsEncryption = false

        let json = Mapper().toJSON(request)

        #expect((json["app_data"] as? [String: Any])?["push_token"] as? String == "token")
        #expect(json["app_id"] as? String == "io.robbie.HomeAssistant")
        #expect(json["app_name"] as? String == "Home Assistant")
        #expect(json["app_version"] as? String == "2026.1 (1)")
        #expect(json["device_name"] as? String == "Phone")
        #expect(json["device_id"] as? String == "device-id")
        #expect(json["manufacturer"] as? String == "Apple")
        #expect(json["model"] as? String == "iPhone")
        #expect(json["os_name"] as? String == "iOS")
        #expect(json["os_version"] as? String == "26.0")
        #expect(json["supports_encryption"] as? Bool == false)
    }

    @Test func supportsEncryptionByDefault() {
        let json = Mapper().toJSON(MobileAppRegistrationRequest())

        #expect(json["supports_encryption"] as? Bool == true)
        #expect(json["app_id"] == nil)
    }

    @Test func mapsFromJSON() throws {
        let request = try #require(Mapper<MobileAppRegistrationRequest>().map(JSON: [
            "app_id": "io.robbie.HomeAssistant",
            "device_name": "Phone",
            "os_version": "26.0",
            "supports_encryption": false,
        ]))

        #expect(request.AppIdentifier == "io.robbie.HomeAssistant")
        #expect(request.DeviceName == "Phone")
        #expect(request.OSVersion == "26.0")
        #expect(request.SupportsEncryption == false)
        #expect(request.Model == nil)
    }
}
