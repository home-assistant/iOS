#if !os(watchOS)
import SwiftUI

/// Marks a room's card as where its screen comes from, when there is a navigation stack to zoom
/// into. Outside one — a preview, a snapshot, the gallery — there is nothing to match against and
/// the card is left alone.
public struct HomeAreaZoomSource: ViewModifier {
    private let areaId: String
    private let namespace: Namespace.ID?

    public init(areaId: String, namespace: Namespace.ID?) {
        self.areaId = areaId
        self.namespace = namespace
    }

    public func body(content: Content) -> some View {
        if let namespace {
            content.modifier(HomeZoomSourceModifier(id: HomeDashboardPath.area(areaId), namespace: namespace))
        } else {
            content
        }
    }
}
#endif
