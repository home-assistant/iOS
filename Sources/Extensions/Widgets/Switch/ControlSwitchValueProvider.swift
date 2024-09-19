// import AppIntents
// import Foundation
// import Shared
// import WidgetKit
// import SFSafeSymbols
//
// @available(iOS 18, *)
// struct ControlSwitchItem {
//    let intentLightEntity: IntentLightEntity
//    let icon: SFSymbolEntity
//    let value: Bool
// }
//
// @available(iOS 18, *)
// struct ControlSwitchValueProvider: AppIntentControlValueProvider {
//    func currentValue(configuration: ControlSwitchConfiguration) async throws -> ControlSwitchItem {
//        guard let serverId = configuration.light?.serverId,
//              let server = Current.servers.all.first(where: { $0.identifier.rawValue == serverId }),
//              let switchId = configuration.light?.entityId else {
//            return .init(
//                intentLightEntity: configuration.light ?? placeholder(),
//                icon: configuration.icon ?? placeholderIcon(),
//                value: false
//            )
//        }
//        let api = Current.api(for: server)
//        let isOn: Bool = await withCheckedContinuation { continuation in
//            api.connection.send(.init(
//                type: .rest(.get, "states/\(switchId)"),
//                data: [:],
//                shouldRetry: true
//            )) { result in
//                switch result {
//                case let .success(data):
//                    let isOn: String = data.decode("state", fallback: "off")
//                    continuation.resume(returning: isOn == "on")
//                case let .failure(error):
//                    Current.Log.error("Failed to get light state for ControlSwitch widget: \(error)")
//                    continuation.resume(returning: false)
//                }
//            }
//        }
//
//        return .init(
//            intentLightEntity: configuration.light ?? placeholder(),
//            icon: configuration.icon ?? placeholderIcon(),
//            value: isOn
//        )
//    }
//
//    func placeholder(for configuration: ControlSwitchConfiguration) -> ControlSwitchItem {
//        .init(
//            intentLightEntity: configuration.light ?? placeholder(),
//            icon: configuration.icon ?? placeholderIcon(),
//            value: false
//        )
//    }
//
//    func previewValue(configuration: ControlSwitchConfiguration) -> ControlSwitchItem {
//        .init(
//            intentLightEntity: configuration.light ?? placeholder(),
//            icon: configuration.icon ?? placeholderIcon(),
//            value: false
//        )
//    }
//
//    private func placeholder() -> IntentLightEntity {
//        .init(
//            id: UUID().uuidString,
//            entityId: "",
//            serverId: "",
//            displayString: L10n.Widgets.Controls.Scripts.placeholderTitle,
//            iconName: SFSymbol.lightswitchOnFill.rawValue
//        )
//    }
//
//    private func placeholderIcon() -> SFSymbolEntity {
//        .init(id: SFSymbol.lightswitchOnFill.rawValue)
//    }
// }
//
// @available(iOS 18.0, *)
// struct ControlSwitchConfiguration: ControlConfigurationIntent {
//    static var title: LocalizedStringResource = .init("widgets.lights.description", defaultValue: "Turn on/off Light")
//
//    @Parameter(
//        title: .init("app_intents.lights.light.title", defaultValue: "Light")
//    )
//    var light: IntentSwitchEntity?
//    @Parameter(
//        title: .init("app_intents.scripts.icon.title", defaultValue: "Icon")
//    )
//    var icon: SFSymbolEntity?
// }
