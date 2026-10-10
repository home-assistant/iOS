#if os(macOS)
import SwiftUI

/// Stands in for `NavigationBarItem.TitleDisplayMode`. A Mac window has a single title style.
public enum NavigationBarTitleDisplayMode {
    case automatic
    case inline
    case large
}
#endif
