import AppIntents
import Foundation
import PromiseKit
import Shared
import SwiftUI

@available(iOS 16.4, *)
final class AutomationAppIntent: AppIntent {
    static let title: LocalizedStringResource = .init(
        "widgets.automation.trigger.title",
        defaultValue: "Trigger automation"
    )

    @Parameter(title: LocalizedStringResource(
        "app_intents.automations.parameter.automation.title",
        defaultValue: "Automation"
    ))
    var automation: IntentAutomationEntity

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
            "app_intents.haptic_confirmation.title",
            defaultValue: "Haptic confirmation"
        ),
        default: false
    )
    var hapticConfirmation: Bool

    func perform() async throws -> some IntentResult & ReturnsValue<Bool> {
        await Current.connectivity.syncNetworkInformation()
        if hapticConfirmation {
            AppIntentHaptics.notify()
        }

        let success: Bool = try await withCheckedThrowingContinuation { continuation in
            guard let server = Current.servers.all.first(where: { $0.identifier.rawValue == automation.serverId }),
                  let api = Current.api(for: server) else {
                continuation.resume(returning: false)
                return
            }
            api.CallService(
                domain: Domain.automation.rawValue,
                service: Service.trigger.rawValue,
                serviceData: ["entity_id": automation.entityId],
                triggerSource: .AppIntent
            )
            .pipe { [weak self] result in
                switch result {
                case .fulfilled:
                    continuation.resume(returning: true)
                case let .rejected(error):
                    Current.Log
                        .error(
                            "Failed to execute automation from AutomationAppIntent, name: \(String(describing: self?.automation.displayString)), error: \(error.localizedDescription)"
                        )
                    continuation.resume(returning: false)
                }
            }
        }
        if showConfirmationNotification {
            AppIntentNotificationHelper.showConfirmation(
                id: .automationAppIntentRun,
                title: success ? L10n.AppIntents.Automations.SuccessMessage.content(automation.displayString) : L10n
                    .AppIntents
                    .Automations.FailureMessage.content(automation.displayString),
                body: nil,
                isSuccess: success,
                duration: 3.0
            )
        }

        DataWidgetsUpdater.update()

        return .result(value: success)
    }
}
