import AppIntents
import Foundation
import Shared
import SwiftUI

@available(iOS 16.4, *)
struct ResetAllCustomWidgetConfirmationAppIntent: AppIntent {
    // No translation needed below, this is not a discoverable intent
    static var title: LocalizedStringResource = "Reset custom widget confirmation states"
    static var isDiscoverable: Bool = false

    func perform() async throws -> some IntentResult {
        do {
            guard var customWidgets = try CustomWidget.widgets(), !customWidgets.isEmpty else {
                return .result()
            }
            for index in customWidgets.indices {
                customWidgets[index].updateItemsStates([:])
            }

            do {
                try await Current.database().write { [customWidgets] db in
                    for widget in customWidgets {
                        do {
                            try widget.update(db)
                        } catch {
                            Current.Log
                                .error(
                                    "Failed to update custom widget to reset items states, error: \(error.localizedDescription)"
                                )
                        }
                    }
                }
            } catch {
                Current.Log
                    .error("Failed to write custom widget to reset items states, error: \(error.localizedDescription)")
            }
        } catch {
            Current.Log.error("Failed to load custom widgets to reset items states: \(error)")
        }

        return .result()
    }
}
