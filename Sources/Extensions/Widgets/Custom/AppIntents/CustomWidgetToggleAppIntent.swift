import AppIntents
import Foundation
import Shared
import SwiftUI

@available(iOS 16.4, *)
struct CustomWidgetToggleAppIntent: AppIntent {
    static var title: LocalizedStringResource = "Toggle"
    static var isDiscoverable: Bool = false

    @Parameter(title: "Widget Id")
    var widgetId: String?
    @Parameter(title: "Magic Item Id")
    var magicItemServerUniqueId: String?
    @Parameter(title: "Server")
    var serverId: String?
    @Parameter(title: "Domain")
    var domain: String?
    @Parameter(title: "Entity ID")
    var entityId: String?

    func perform() async throws -> some IntentResult {
        guard let serverId,
              let domainString = domain,
              let domain = Domain(rawValue: domainString),
              let entityId,
              let server = Current.servers.all.first(where: { server in
                  server.identifier.rawValue == serverId
              }), let connection = Current.api(for: server)?.connection else {
            return .result()
        }

        await updateProgress(waitSeconds: 0, progress: 20)
        let success = await withCheckedContinuation { continuation in
            connection.send(.toggleDomain(domain: domain, entityId: entityId)).promise.pipe { result in
                switch result {
                case .fulfilled:
                    continuation.resume(returning: true)
                case let .rejected(error):
                    Current.Log
                        .error(
                            "Failed to execute ToggleAppIntent, serverId: \(serverId), domain: \(domain), entityId: \(entityId), error: \(error)"
                        )
                    continuation.resume(returning: false)
                }
            }
        }

        if success {
            await updateProgress(waitSeconds: 1, progress: 80)
            await updateProgress(waitSeconds: 2, progress: 100)
            await resetStates(waitSeconds: 3)
        } else {
            await updateProgress(waitSeconds: 1, progress: -1)
            await resetStates(waitSeconds: 2)
        }

        return .result()
    }

    private func resetStates(waitSeconds: UInt64) async {
        Task {
            do {
                // Allow visual feedback to display
                await wait(seconds: 3)
                _ = try await ResetAllCustomWidgetConfirmationAppIntent().perform()
            } catch {
                Current.Log.error("Failed to ResetAllCustomWidgetConfirmationAppIntent")
            }
        }
    }

    private func updateProgress(waitSeconds: UInt64, progress: Int) async {
        Task {
            do {
                // Update state to show progress
                let progressIntent = UpdateWidgetItemExecutionProgressStateAppIntent()
                progressIntent.widgetId = widgetId
                progressIntent.serverUniqueId = magicItemServerUniqueId
                progressIntent.progress = progress
                // Allow visual feedback to display
                await wait(seconds: waitSeconds)
                // Update state to show progress
                _ = try await progressIntent.perform()
            } catch {
                Current.Log.error("Failed to update custom widget item progress")
            }
        }
    }

    private func wait(seconds: UInt64) async {
        do {
            try await Task.sleep(nanoseconds: seconds * 1_000_000_000)
        } catch {
            Current.Log.error("Failed to wait in Custom CustomWidgetToggleAppIntent")
        }
    }
}
