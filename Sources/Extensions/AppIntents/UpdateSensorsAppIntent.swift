import AppIntents
import Shared

@available(iOS 16.4, *)
struct UpdateSensorsAppIntent: AppIntent {
    static var title: LocalizedStringResource = .init(
        "app_intents.update_sensors.title",
        defaultValue: "Update sensors"
    )

    static var description = IntentDescription(.init(
        "app_intents.update_sensors.description",
        defaultValue: "Send a sensor update to Home Assistant"
    ))

    func perform() async throws -> some IntentResult & ReturnsValue<String> {
        await Current.connectivity.syncNetworkInformation()
        let failedServers = try await Current.apis.asyncCompactMap { api -> String? in
            do {
                try await api.UpdateSensors(trigger: .AppShortcut).async(timeout: 10)
                return nil
            } catch {
                return "\(api.server.info.name): \(error.localizedDescription)"
            }
        }

        guard failedServers.isEmpty == false else {
            return .result(value: L10n.AppIntents.UpdateSensors.success)
        }

        return .result(value: L10n.AppIntents.Error.failedServers(failedServers.joined(separator: ", ")))
    }
}
