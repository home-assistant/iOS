import AppIntents
import Foundation
import Shared
import WidgetKit

/// Steps the Areas widget one page forward or back.
///
/// Not discoverable: it exists to be the intent behind the widget's own arrows, and carries the
/// widget's server, family and page count because the intent runs outside the view that knows them.
@available(iOS 17.0, *)
struct WidgetAreasPageAppIntent: AppIntent {
    static var title: LocalizedStringResource = .init(
        "widgets.areas.page.title",
        defaultValue: "Show other areas"
    )
    static var isDiscoverable: Bool = false

    // No translation needed below, this is not a discoverable intent
    @Parameter(title: "Server")
    var serverId: String?

    @Parameter(title: "Widget family")
    var familyRawValue: Int?

    /// `1` for the next page, `-1` for the previous one.
    @Parameter(title: "Step")
    var step: Int?

    @Parameter(title: "Pages")
    var pageCount: Int?

    func perform() async throws -> some IntentResult {
        AppIntentHaptics.notify()
        guard let serverId,
              let familyRawValue,
              let family = WidgetFamily(rawValue: familyRawValue),
              let step,
              let pageCount else {
            return .result()
        }
        let page = WidgetAreasPageStore.clamp(
            WidgetAreasPageStore.page(serverId: serverId, family: family) + step,
            pageCount: pageCount
        )
        WidgetAreasPageStore.setPage(page, serverId: serverId, family: family)
        WidgetCenter.shared.reloadTimelines(ofKind: WidgetsKind.areas.rawValue)
        return .result()
    }
}
