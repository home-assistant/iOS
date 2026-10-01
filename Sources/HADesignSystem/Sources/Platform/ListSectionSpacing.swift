#if os(macOS)
import SwiftUI

/// Stands in for `ListSectionSpacing`. A Mac list spaces its sections itself.
public enum ListSectionSpacing {
    case `default`
    case compact

    public static func custom(_ spacing: CGFloat) -> ListSectionSpacing { .default }
}
#endif
