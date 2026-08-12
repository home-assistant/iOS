import AppIntents
import Foundation
import PromiseKit
import Shared

final class ScriptAppIntent: AppIntent, @unchecked Sendable {
    static let title: LocalizedStringResource = .init("widgets.script.description.title", defaultValue: "Run Script")

    @Parameter(title: LocalizedStringResource("app_intents.scripts.script.title", defaultValue: "Run Script"))
    var script: IntentScriptEntity

    @Parameter(
        title: LocalizedStringResource(
            "app_intents.notify_when_run.title",
            defaultValue: "Notify when run"
        ),
        description: LocalizedStringResource(
            "app_intents.notify_when_run.description",
            defaultValue: "Shows notification after executed"
        ),
        default: true
    )
    var showConfirmationNotification: Bool

    @Parameter(
        title: LocalizedStringResource(
            "app_intents.scripts.haptic_confirmation.title",
            defaultValue: "Haptic confirmation"
        ),
        default: false
    )
    var hapticConfirmation: Bool

    func perform() async throws -> some IntentResult & ReturnsValue<Bool> {
        await Current.connectivity.refreshNetworkInformation()
        if hapticConfirmation {
            AppIntentHaptics.notify()
        }

        // `script.turn_on` travels over the webhook API on every platform, so this needs no
        // WebSocket and works as-is on the watch.
        let success: Bool = try await withCheckedThrowingContinuation { continuation in
            guard let server = Current.servers.all.first(where: { $0.identifier.rawValue == script.serverId }),
                  let api = Current.api(for: server) else {
                continuation.resume(returning: false)
                return
            }
            api.turnOnScript(scriptEntityId: script.entityId, triggerSource: .AppIntent)
                .pipe { [weak self] result in
                    switch result {
                    case .fulfilled:
                        continuation.resume(returning: true)
                    case let .rejected(error):
                        Current.Log
                            .error(
                                "Failed to execute script from ScriptAppIntent, name: \(String(describing: self?.script.displayString)), error: \(error.localizedDescription)"
                            )
                        continuation.resume(returning: false)
                    }
                }
        }
        if showConfirmationNotification {
            Current.notificationDispatcher.send(.init(
                id: .scriptAppIntentRun,
                title: success ? L10n.AppIntents.Scripts.SuccessMessage.content(script.displayString) : L10n.AppIntents
                    .Scripts.FailureMessage.content(script.displayString)
            ))
        }

        #if os(iOS) || os(macOS)
        // Home screen widgets and Control Center controls are iOS/macOS-only; the watch renders its
        // complications from its own snapshot store, which the next refresh picks up.
        DataWidgetsUpdater.update()
        #endif

        return .result(value: success)
    }
}
