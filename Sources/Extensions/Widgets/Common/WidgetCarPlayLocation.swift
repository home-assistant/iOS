import Foundation
import SwiftUI
import WidgetKit

extension WidgetConfiguration {
    /// Marks the widget as disfavored in CarPlay for the given families, so it appears in the
    /// "Other" section of the CarPlay widget gallery rather than alongside the suggested widgets.
    func disfavoredInCarPlayIfAvailable(for families: [WidgetFamily]) -> some WidgetConfiguration {
        // `disfavoredLocations(_:for:)` and `WidgetLocation.carPlay` are unavailable on macOS (CarPlay
        // does not exist there); they are available on iOS, iPadOS and Mac Catalyst 17+.
        #if !os(macOS)
        if #available(iOSApplicationExtension 17.0, *) {
            return self.disfavoredLocations([.carPlay], for: families)
        } else {
            return self
        }
        #else
        return self
        #endif
    }
}
