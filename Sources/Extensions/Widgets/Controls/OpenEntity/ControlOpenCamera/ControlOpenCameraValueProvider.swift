import AppIntents
import Foundation
import SFSafeSymbols
import Shared
import WidgetKit

@available(iOS 18, *)
struct ControlOpenCameraItem {
    let entity: HAAppEntityAppIntentEntity
    let icon: SFSymbolEntity
}

@available(iOS 18, *)
struct ControlOpenCameraValueProvider: AppIntentControlValueProvider {
    func currentValue(configuration: ControlOpenCameraConfiguration) async throws -> ControlOpenCameraItem {
        item(configuration: configuration)
    }

    func placeholder(for configuration: ControlOpenCameraConfiguration) -> ControlOpenCameraItem {
        item(configuration: configuration)
    }

    func previewValue(configuration: ControlOpenCameraConfiguration) -> ControlOpenCameraItem {
        item(configuration: configuration)
    }

    private func item(configuration: ControlOpenCameraConfiguration) -> ControlOpenCameraItem {
        .init(
            entity: configuration.entity ?? .init(
                id: "",
                entityId: "",
                serverId: "",
                serverName: "",
                displayString: "",
                iconName: ""
            ),
            icon: configuration.icon ?? placeholder().icon
        )
    }

    private func placeholder() -> ControlOpenCameraItem {
        .init(
            entity: .init(id: "", entityId: "", serverId: "", serverName: "", displayString: "", iconName: ""),
            icon: .init(id: SFSymbol.video.rawValue)
        )
    }
}

@available(iOS 18.0, *)
struct ControlOpenCameraConfiguration: ControlConfigurationIntent {
    static var title: LocalizedStringResource = .init(
        "widgets.controls.open_camera.configuration.title",
        defaultValue: "Open Camera"
    )

    @Parameter(
        title: .init("widgets.controls.open_camera.configuration.parameter.entity", defaultValue: "Camera"),
        optionsProvider: CameraEntityOptionsProvider()
    )
    var entity: HAAppEntityAppIntentEntity?

    @Parameter(
        title: .init("app_intents.scenes.icon.title", defaultValue: "Icon")
    )
    var icon: SFSymbolEntity?
}

@available(iOS 18.0, *)
struct CameraEntityOptionsProvider: DynamicOptionsProvider {
    func results() async throws -> IntentItemCollection<HAAppEntityAppIntentEntity> {
        let entities = ControlEntityProvider(domains: [.camera]).getEntities()

        return .init(sections: entities.map { (key: Server, value: [HAAppEntity]) in
            .init(
                .init(stringLiteral: key.info.name),
                items: value.map { entity in
                    HAAppEntityAppIntentEntity(
                        id: entity.id,
                        entityId: entity.entityId,
                        serverId: entity.serverId,
                        serverName: key.info.name,
                        displayString: entity.name,
                        iconName: entity.icon ?? SFSymbol.video.rawValue
                    )
                }
            )
        })
    }
}
