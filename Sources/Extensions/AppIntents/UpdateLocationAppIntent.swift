import AppIntents
import CoreLocation
import Shared

@available(iOS 16.4, *)
struct UpdateLocationAppIntent: AppIntent {
    static var title: LocalizedStringResource = .init(
        "app_intents.update_location.title",
        defaultValue: "Update location"
    )

    static var description = IntentDescription(.init(
        "app_intents.update_location.description",
        defaultValue: "Send a location update to Home Assistant"
    ))

    @Parameter(title: .init("app_intents.update_location.location.title", defaultValue: "Location"))
    var location: CLPlacemark

    func perform() async throws -> some IntentResult & ReturnsValue<String> {
        await Current.connectivity.syncNetworkInformation()
        let failedServers = try await Current.apis.asyncCompactMap { api -> String? in
            do {
                try await api.SubmitLocation(
                    updateType: .AppShortcut,
                    location: location.location,
                    zone: nil
                ).async(timeout: 10)
                return nil
            } catch {
                return "\(api.server.info.name): \(error.localizedDescription)"
            }
        }

        guard failedServers.isEmpty == false else {
            return .result(value: "Updated location on all servers")
        }

        return .result(value: "Failed servers: \(failedServers.joined(separator: ", "))")
    }
}
