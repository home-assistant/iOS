import AppIntents
import Foundation
import Shared
import WidgetKit

@available(iOS 18, *)
struct ControlLightItem {
    let intentLightEntity: IntentLightEntity
    let icon: SFSymbolEntity
    let value: Bool
}

@available(iOS 18, *)
struct ControlLightsValueProvider: AppIntentControlValueProvider {
    func currentValue(configuration: ControlLightsConfiguration) async throws -> ControlLightItem {
        guard let serverId = configuration.light?.serverId,
              let server = Current.servers.all.first(where: { $0.identifier.rawValue == serverId }),
              let lightId = configuration.light?.entityId else {
            return .init(
                intentLightEntity: configuration.light ?? placeholder(),
                icon: configuration.icon ?? placeholderIcon(),
                value: false
            )
        }
        let api = Current.api(for: server)
        let isOn: Bool = await withCheckedContinuation { continuation in
            api.connection.send(.init(
                type: .rest(.get, "states/\(lightId)"),
                data: [:],
                shouldRetry: true
            )) { result in
                switch result {
                case let .success(data):
                    let isOn: String = data.decode("state", fallback: "off")
                    continuation.resume(returning: isOn == "on")
                case let .failure(error):
                    Current.Log.error("Failed to get light state for ControlLight widget: \(error)")
                    continuation.resume(returning: false)
                }
            }
        }

        return .init(
            intentLightEntity: configuration.light ?? placeholder(),
            icon: configuration.icon ?? placeholderIcon(),
            value: isOn
        )
    }

    func placeholder(for configuration: ControlLightsConfiguration) -> ControlLightItem {
        .init(
            intentLightEntity: configuration.light ?? placeholder(),
            icon: configuration.icon ?? placeholderIcon(),
            value: false
        )
    }

    func previewValue(configuration: ControlLightsConfiguration) -> ControlLightItem {
        .init(
            intentLightEntity: configuration.light ?? placeholder(),
            icon: configuration.icon ?? placeholderIcon(),
            value: false
        )
    }

    private func placeholder() -> IntentLightEntity {
        .init(
            id: UUID().uuidString,
            entityId: "",
            serverId: "",
            displayString: L10n.Widgets.Controls.Scripts.placeholderTitle,
            iconName: "lightbulb.fill"
        )
    }

    private func placeholderIcon() -> SFSymbolEntity {
        .init(id: "lightbulb.fill")
    }
}

@available(iOS 18.0, *)
struct ControlLightsConfiguration: ControlConfigurationIntent {
    static var title: LocalizedStringResource = .init("widgets.lights.description", defaultValue: "Turn on/off Light")

    @Parameter(
        title: .init("app_intents.lights.light.title", defaultValue: "Light")
    )
    var light: IntentLightEntity?
    @Parameter(
        title: .init("app_intents.scripts.icon.title", defaultValue: "Icon")
    )
    var icon: SFSymbolEntity?
}
