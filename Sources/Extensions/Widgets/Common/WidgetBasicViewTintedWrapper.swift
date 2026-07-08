import Foundation
import SwiftUI
import WidgetKit

struct WidgetBasicViewTintedWrapper<T: WidgetBasicViewProtocol>: View {
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
