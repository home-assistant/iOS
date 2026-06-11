import Foundation
import SwiftUI
import WidgetKit

extension WidgetConfiguration {
    /// Marks the widget as disfavored in CarPlay for the given families, so it appears in the
    /// "Other" section of the CarPlay widget gallery rather than alongside the suggested widgets.
    func disfavoredInCarPlayIfAvailable(for families: [WidgetFamily]) -> some WidgetConfiguration {
        // `WidgetLocation.carPlay` is available on iOS, iPadOS and Mac Catalyst 26+, and unavailable on
        // macOS (CarPlay does not exist there). The `disfavoredLocations(_:for:)` modifier itself is
        // iOS 17+, but the `.carPlay` location requires iOS 26, so guard on the stricter requirement.
        #if !os(macOS)
        if #available(iOSApplicationExtension 26.0, *) {
            return self.disfavoredLocations([.carPlay], for: families)
        } else {
            return self
        }
        #else
        return self
        #endif
    }
}
