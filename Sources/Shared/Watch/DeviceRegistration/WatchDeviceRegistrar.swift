import Foundation
import ObjectMapper

/// Registers the watch with a server's `mobile_app` integration as a device of its own, over REST —
/// the one transport the watch reliably has (see `HomeAssistantRESTClient`).
public enum WatchDeviceRegistrar {
    public enum RegistrationError: Error, Equatable {
        /// The response carried no webhook ID, so there is nothing to report through.
        case unmappableResponse
    }

    /// The `POST /api/mobile_app/registrations` body. `device_id` is left out for servers that
    /// predate it, as the phone does; there is no `app_data` because the watch takes no push.
    public static func registrationBody(identity: WatchDeviceIdentity, serverVersion: Version) -> [String: Any] {
        var body: [String: Any] = [
            "app_id": identity.appID,
            "app_name": identity.appName,
            "app_version": identity.appVersion,
            "device_name": identity.deviceName,
            "manufacturer": "Apple",
            "model": identity.model,
            "os_name": identity.osName,
            "os_version": identity.osVersion,
            "supports_encryption": true,
            "app_data": [String: Any](),
        ]

        if serverVersion >= .canSendDeviceID {
            body["device_id"] = identity.deviceID
        }

        return body
    }

    /// What the watch keeps from a registration response.
    public static func registration(from json: Any, registeredAt: Date) throws -> WatchDeviceRegistration {
        guard let dictionary = json as? [String: Any],
              dictionary["webhook_id"] is String,
              let response = Mapper<MobileAppRegistrationResponse>().map(JSON: dictionary) else {
            throw RegistrationError.unmappableResponse
        }

        return WatchDeviceRegistration(
            webhookID: response.WebhookID,
            webhookSecret: response.WebhookSecret,
            cloudhookURL: response.CloudhookURL,
            registeredAt: registeredAt
        )
    }

    /// Registers with `server` and remembers the result in `Current.watchDeviceRegistrations`.
    public static func register(
        server: Server,
        identity: WatchDeviceIdentity = .current(),
        timeout: TimeInterval = HomeAssistantRESTClient.defaultTimeout
    ) async throws -> WatchDeviceRegistration {
        Current.Log.info(
            "registering watch with \(server.info.name) as \"\(identity.appName)\" on \"\(identity.deviceName)\""
        )

        let json: Any
        do {
            json = try await HomeAssistantRESTClient.sendForJSON(
                server: server,
                method: .post,
                path: ["mobile_app", "registrations"],
                body: registrationBody(identity: identity, serverVersion: server.info.version),
                timeout: timeout
            )
        } catch let HomeAssistantRESTError.unacceptableStatus(code, _) where code == 404 {
            throw HomeAssistantAPI.APIError.mobileAppComponentNotLoaded
        }

        let registration = try registration(from: json, registeredAt: Current.date())
        Current.watchDeviceRegistrations.set(registration, for: server.identifier)
        Current.Log.info("registered watch with \(server.info.name); webhook \(registration.webhookID)")
        return registration
    }
}
