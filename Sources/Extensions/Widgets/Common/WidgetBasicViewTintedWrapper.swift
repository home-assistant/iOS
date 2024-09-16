import Foundation
import SwiftUI

@available(iOS 16.0, *)
struct WidgetBasicViewTintedWrapper: View {
    @Environment(\.widgetRenderingMode) var widgetRenderingMode

    private let model: WidgetBasicViewModel
    private let sizeStyle: WidgetBasicSizeStyle

    init(model: WidgetBasicViewModel, sizeStyle: WidgetBasicSizeStyle) {
        self.model = model
        self.sizeStyle = sizeStyle
    }

    var body: some View {
        WidgetBasicView(model: model, sizeStyle: sizeStyle, tinted: widgetRenderingMode == .accented)
    }
}
