#if !os(watchOS)
import Foundation
import SwiftUI
import WidgetKit

public extension View {
    /// The widget's container background, falling back to a plain background before iOS 17 knew
    /// about one.
    func widgetBackground(_ backgroundView: some ShapeStyle) -> some View {
        if #available(iOS 17.0, *) {
            return containerBackground(backgroundView, for: .widget)
        } else {
            return background(backgroundView)
        }
    }
}
#endif
