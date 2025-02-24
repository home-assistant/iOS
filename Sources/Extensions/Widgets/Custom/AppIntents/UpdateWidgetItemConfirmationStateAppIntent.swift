import AppIntents
import Foundation
import Shared
import SwiftUI
import WidgetKit

@available(iOS 16.4, *)
struct UpdateWidgetItemConfirmationStateAppIntent: AppIntent {
    static var title: LocalizedStringResource = "Update custom widget confirmation"
    static var isDiscoverable: Bool = false

    // No translation needed below, this is not a discoverable intent
    @Parameter(title: "Widget Id")
    var widgetId: String?

    @Parameter(title: "item Id")
    var serverUniqueId: String?

    func perform() async throws -> some IntentResult {
        guard let serverUniqueId, let widgetId else {
            return .result()
        }

        _ = try await ResetAllCustomWidgetConfirmationAppIntent().perform()

        WidgetCenter.shared.reloadTimelines(ofKind: WidgetsKind.custom.rawValue)

        if var widget = try CustomWidget.widgets()?.first(where: { $0.id == widgetId }),
           let magicItem = widget.items.first(where: { $0.serverUniqueId == serverUniqueId }) {
            widget.itemsStates = [magicItem.serverUniqueId: .pendingConfirmation]
            do {
                try await Current.database().write { [widget] db in
                    try widget.update(db)
                }
            } catch {
                Current.Log
                    .error(
                        "Failed to update custom widget to set pending confirmation item, error: \(error.localizedDescription)"
                    )
            }
        }
        return .result()
    }
}
