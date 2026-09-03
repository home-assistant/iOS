import Foundation
import ObjectMapper

/// Registers the watch with a server's `mobile_app` integration as a device of its own, over REST —
/// the one transport the watch reliably has (see `HomeAssistantRESTClient`).
public enum WatchDeviceRegistrar {
    public enum RegistrationError: LocalizedError, Equatable {
        /// The response carried no webhook ID, so there is nothing to report through.
        case unmappableResponse
        /// The server registered the watch but the registration couldn't be saved on the watch.
        /// Surfaced rather than retried: every registration request creates another device in
        /// Home Assistant, so a registration that can't be kept must not be repeated blindly.
        case persistenceFailed(String)

        public var errorDescription: String? {
            switch self {
            case .unmappableResponse:
                return "The registration response had no webhook ID"
            case let .persistenceFailed(reason):
                return "The registration could not be saved on the watch: \(reason)"
            }
        }
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

    /// The `update_registration` payload; Home Assistant requires every field on each update.
    public static func updateRegistrationBody(identity: WatchDeviceIdentity) -> [String: Any] {
        [
            "app_data": [String: Any](),
            "app_version": identity.appVersion,
            "device_name": identity.deviceName,
            "manufacturer": "Apple",
            "model": identity.model,
            "os_version": identity.osVersion,
        ]
    }

    /// What the watch keeps from a registration response, made under `identity`.
    public static func registration(
        from json: Any,
        identity: WatchDeviceIdentity,
        registeredAt: Date
    ) throws -> WatchDeviceRegistration {
        guard let dictionary = json as? [String: Any],
              dictionary["webhook_id"] is String,
              let response = Mapper<MobileAppRegistrationResponse>().map(JSON: dictionary) else {
            throw RegistrationError.unmappableResponse
        }

        return WatchDeviceRegistration(
            webhookID: response.WebhookID,
            webhookSecret: response.WebhookSecret,
            cloudhookURL: response.CloudhookURL,
            registeredAt: registeredAt,
            deviceName: identity.deviceName
        )
    }

    /// Posts a registration body to a server's `mobile_app/registrations` and returns the JSON reply.
    public typealias Send = (Server, [String: Any], TimeInterval) async throws -> Any

    /// The real transport: the server's REST API.
    public static func sendRegistration(
        server: Server,
        body: [String: Any],
        timeout: TimeInterval
    ) async throws -> Any {
        try await HomeAssistantRESTClient.sendForJSON(
            server: server,
            method: .post,
            path: ["mobile_app", "registrations"],
            body: body,
            timeout: timeout
        )
    }

    /// Registers with `server` and remembers the result in `Current.watchDeviceRegistrations`.
    ///
    /// - Parameter send: how the registration reaches the server; REST unless a test substitutes
    ///   a fake.
    public static func register(
        server: Server,
        identity: WatchDeviceIdentity? = nil,
        timeout: TimeInterval = HomeAssistantRESTClient.defaultTimeout,
        send: Send = WatchDeviceRegistrar.sendRegistration
    ) async throws -> WatchDeviceRegistration {
        let identity = identity ?? .current(for: server)
        Current.Log.info(
            "registering watch with \(server.info.name) as \"\(identity.appName)\" on \"\(identity.deviceName)\""
        )

        let json: Any
        do {
            json = try await send(
                server,
                registrationBody(identity: identity, serverVersion: server.info.version),
                timeout
            )
        } catch let HomeAssistantRESTError.unacceptableStatus(code, _) where code == 404 {
            throw HomeAssistantAPI.APIError.mobileAppComponentNotLoaded
        }

        let registration = try registration(from: json, identity: identity, registeredAt: Current.date())
        do {
            try Current.watchDeviceRegistrations.set(registration, for: server.identifier)
        } catch {
            Current.Log.error("failed saving watch registration for \(server.info.name): \(error)")
            throw RegistrationError.persistenceFailed(error.localizedDescription)
        }
        // Not the webhook ID: it is the credential for the webhook URL.
        Current.Log.info("registered watch with \(server.info.name)")
        return registration
    }
}
