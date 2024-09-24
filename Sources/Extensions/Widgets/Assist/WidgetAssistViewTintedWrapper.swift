import Foundation
import SwiftUI

@available(iOS 16.0, *)
struct WidgetAssistViewTintedWrapper: View {
    @Environment(\.widgetRenderingMode) var widgetRenderingMode

    private let entry: WidgetAssistEntry

    init(entry: WidgetAssistEntry) {
        self.entry = entry
    }

    var body: some View {
        WidgetAssistView(
            entry: entry,
            tinted: widgetRenderingMode == .accented
        )
    }
}
