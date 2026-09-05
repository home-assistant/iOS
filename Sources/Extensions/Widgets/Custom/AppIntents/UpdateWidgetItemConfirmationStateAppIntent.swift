import AppIntents
import Foundation
import Shared
import SwiftUI
import WidgetKit

struct UpdateWidgetItemConfirmationStateAppIntent: AppIntent {
    static var title: LocalizedStringResource = "Update custom widget confirmation"
    static var isDiscoverable: Bool = false

    // No translation needed below, this is not a discoverable intent
    @Parameter(title: "Widget Id")
    var widgetId: String?

    @Parameter(title: "item Id")
    var serverUniqueId: String?

    /// True when the rest of a split tile was tapped rather than its icon, so confirming runs the
    /// tile's tap behavior.
    @Parameter(title: "Confirms tap action")
    var confirmsTapAction: Bool?

    func perform() async throws -> some IntentResult {
        guard let serverUniqueId, let widgetId else {
            Current.Log
                .error(
                    "UpdateWidgetItemConfirmationStateAppIntent: missing parameters, serverUniqueId: \(String(describing: serverUniqueId)), widgetId: \(String(describing: widgetId))"
                )
            return .result()
        }

        _ = try await ResetAllCustomWidgetConfirmationAppIntent().perform()

        WidgetCenter.shared.reloadTimelines(ofKind: WidgetsKind.custom.rawValue)

        if var widget = try CustomWidget.widgets()?.first(where: { $0.id == widgetId }),
           let magicItem = widget.items.first(where: { $0.serverUniqueId == serverUniqueId }) {
            widget.itemsStates = [
                magicItem.serverUniqueId: confirmsTapAction == true ? .pendingTapConfirmation : .pendingConfirmation,
            ]
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
