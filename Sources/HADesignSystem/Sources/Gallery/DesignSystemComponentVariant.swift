#if !os(watchOS)
import SwiftUI

/// One capability of a component, as shown in `ComponentsLibraryView` and captured by the gallery
/// snapshot test.
///
/// A component lists a variant per thing it can do — every alert type, a label with and without an
/// icon, a bar at each threshold — so the library doubles as the specification of what the component
/// supports, and adding a capability without demonstrating it is visible in review.
///
/// Frontend counterpart: one demo on a `gallery/` page. Gallery scaffolding, not a component.
public struct DesignSystemComponentVariant: Identifiable {
    /// Describes what this variant demonstrates, e.g. "Warning" or "Without title". Also used to
    /// name the recorded snapshot, so it has to stay stable once a reference image exists.
    public let name: String
    public let content: AnyView

    public var id: String { name }

    public init(_ name: String, @ViewBuilder content: () -> some View) {
        self.name = name
        self.content = AnyView(content())
    }
}
#endif
