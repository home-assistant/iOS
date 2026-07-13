import Foundation
import SwiftUI
import WidgetKit

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
