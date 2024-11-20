import Foundation
import SwiftUI

@available(iOS 16.0, *)
struct WidgetBasicViewTintedWrapper<T: WidgetBasicViewInterface>: View {
    @Environment(\.widgetRenderingMode) var widgetRenderingMode

    private let model: WidgetBasicViewModel
    private let sizeStyle: WidgetBasicSizeStyle
    let viewType: T.Type

    init(model: WidgetBasicViewModel, sizeStyle: WidgetBasicSizeStyle, viewType: T.Type) {
        self.model = model
        self.sizeStyle = sizeStyle
        self.viewType = viewType
    }

    var body: some View {
        viewType.init(model: model, sizeStyle: sizeStyle, tinted: widgetRenderingMode == .accented)
    }
}
