#if !os(watchOS)
import SwiftUI
import WidgetKit

public extension View {
    /// The card every widget tile sits on: background, rounded corners and a hairline border, all
    /// dropped when the widget renders accented and the system paints the tile itself.
    func widgetTileCardStyle(sizeStyle: WidgetTileSizeStyle, model: WidgetTileModel, tinted: Bool) -> some View {
        modifier(WidgetTileCardStyleModifier(sizeStyle: sizeStyle, tinted: tinted, model: model))
    }
}

public struct WidgetTileCardStyleModifier: ViewModifier {
    public let sizeStyle: WidgetTileSizeStyle
    public let tinted: Bool
    public let model: WidgetTileModel

    public init(sizeStyle: WidgetTileSizeStyle, tinted: Bool, model: WidgetTileModel) {
        self.sizeStyle = sizeStyle
        self.tinted = tinted
        self.model = model
    }

    public func body(content: Content) -> some View {
        content
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background({
                if tinted {
                    return Color.clear
                }
                if model.useCustomColors {
                    return model.backgroundColor
                } else {
                    return .widgetTileBackground
                }
            }())
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius)
                    .stroke(Color.tileBorder, lineWidth: sizeStyle == .single ? 0 : 1)
                    .modify { view in
                        if #available(iOS 18, *) {
                            view.widgetAccentable()
                        } else {
                            view
                        }
                    }
            }
    }

    private var cornerRadius: CGFloat {
        sizeStyle == .compressed ? .zero : 14
    }
}
#endif
