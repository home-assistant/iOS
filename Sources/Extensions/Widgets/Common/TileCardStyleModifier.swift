import Shared
import SwiftUI

extension View {
    func tileCardStyle(sizeStyle: WidgetBasicSizeStyle, model: WidgetBasicViewModel, tinted: Bool) -> some View {
        modifier(TileCardStyleModifier(sizeStyle: sizeStyle, tinted: tinted, model: model))
    }
}

struct TileCardStyleModifier: ViewModifier {
    let sizeStyle: WidgetBasicSizeStyle
    let tinted: Bool
    let model: WidgetBasicViewModel

    func body(content: Content) -> some View {
        content
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background({
                if tinted {
                    return Color.clear
                }
                if model.useCustomColors {
                    return model.backgroundColor
                } else {
                    return Color.asset(Asset.Colors.tileBackground)
                }
            }())
            .clipShape(RoundedRectangle(cornerRadius: sizeStyle == .compressed ? .zero : 14))
            .overlay {
                RoundedRectangle(cornerRadius: sizeStyle == .compressed ? .zero : 14)
                    .stroke(Color.asset(Asset.Colors.tileBorder), lineWidth: sizeStyle == .single ? 0 : 1)
                    .modify { view in
                        if #available(iOS 18, *) {
                            view.widgetAccentable()
                        } else {
                            view
                        }
                    }
            }
    }
}
