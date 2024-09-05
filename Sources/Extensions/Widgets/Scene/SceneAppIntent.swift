import AppIntents
import AudioToolbox
import Foundation
import PromiseKit
import Shared
import SwiftUI

@available(iOS 16.4, *)
final class SceneAppIntent: AppIntent {
    static let title: LocalizedStringResource = .init("widgets.scene.activate.title", defaultValue: "Activate scene")

    @Parameter(title: LocalizedStringResource("app_intents.scenes.parameter.scene.title", defaultValue: "Scene"))
    var scene: IntentSceneEntity

    @Parameter(
        title: LocalizedStringResource(
            "app_intents.scenes.requires_confirmation_before_run.title",
            defaultValue: "Confirm before run"
        ),
        description: LocalizedStringResource(
            "app_intents.scenes.requires_confirmation_before_run.description",
            defaultValue: "Requires manual confirmation before running the scene."
        ),
        default: true
    )
    var requiresConfirmationBeforeRun: Bool

    @Parameter(
        title: LocalizedStringResource(
            "app_intents.show_confirmation_dialog.title",
            defaultValue: "Confirmation notification"
        ),
        description: LocalizedStringResource(
            "app_intents.show_confirmation_dialog.description",
            defaultValue: "Shows confirmation notification after executed"
        ),
        default: true
    )
    var showConfirmationNotification: Bool

    @Parameter(
        title: LocalizedStringResource(
            "app_intents.haptic_confirmation.title",
            defaultValue: "Haptic confirmation"
        ),
        default: false
    )
    var hapticConfirmation: Bool

    func perform() async throws -> some IntentResult & ReturnsValue<Bool> {
        if requiresConfirmationBeforeRun {
            try await requestConfirmation()
        }

        if hapticConfirmation {
            // Unfortunately this is the only 'haptics' that work with widgets
            // ideally in the future this should use CoreHaptics for a better experience
            AudioServicesPlayAlertSound(SystemSoundID(kSystemSoundID_Vibrate))
        }

        let success: Bool = try await withCheckedThrowingContinuation { continuation in
            guard let server = Current.servers.all.first(where: { $0.identifier.rawValue == scene.serverId }) else {
                continuation.resume(returning: false)
                return
            }
            Current.api(for: server).CallService(
                domain: Domain.scene.rawValue,
                service: "turn_on",
                serviceData: ["entity_id": scene.id]
            )
            .pipe { [weak self] result in
                switch result {
                case .fulfilled:
                    continuation.resume(returning: true)
                case let .rejected(error):
                    Current.Log
                        .error(
                            "Failed to execute scene from SceneAppIntent, name: \(String(describing: self?.scene.displayString)), error: \(error.localizedDescription)"
                        )
                    continuation.resume(returning: false)
                }
            }
        }
        if showConfirmationNotification {
            LocalNotificationDispatcher().send(.init(
                id: .sceneAppIntentRun,
                title: success ? L10n.AppIntents.Scenes.SuccessMessage.content(scene.displayString) : L10n.AppIntents
                    .Scenes.FailureMessage.content(scene.displayString)
            ))
        }
        return .result(value: success)
    }
}
