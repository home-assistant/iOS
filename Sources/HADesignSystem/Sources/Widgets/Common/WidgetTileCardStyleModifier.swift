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
    /// Which corners this tile shares with the widget, set by ``WidgetTileGridView``.
    @Environment(\.widgetTileCorners) private var widgetTileCorners

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
            .clipShape(shape)
            .overlay {
                shape
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

    /// The radius a corner has when it sits inside the widget rather than in one of its corners.
    private var cornerRadius: CGFloat {
        sizeStyle == .compressed ? .zero : 14
    }

    /// The radius a corner has when it is the one sitting in a corner of the widget.
    ///
    /// A tile in the widget's corner reads as pinched when it rounds tighter than the widget does,
    /// so it gets the widget's own radius less the padding holding it off the edge. That is a fixed
    /// number rather than a measured one: the widget is never asked how round it is, and the answer
    /// varies by platform anyway. This is the one value to tune if the two stop agreeing.
    private static let edgeCornerRadius: CGFloat = 20

    /// The card's outline: ``edgeCornerRadius`` on the corners the tile shares with the widget,
    /// ``cornerRadius`` on the rest.
    private var shape: AnyShape {
        guard !widgetTileCorners.isEmpty else {
            return AnyShape(RoundedRectangle(cornerRadius: cornerRadius))
        }
        return AnyShape(UnevenRoundedRectangle(
            topLeadingRadius: radius(for: .topLeading),
            bottomLeadingRadius: radius(for: .bottomLeading),
            bottomTrailingRadius: radius(for: .bottomTrailing),
            topTrailingRadius: radius(for: .topTrailing)
        ))
    }

    private func radius(for corner: WidgetTileCorners) -> CGFloat {
        widgetTileCorners.contains(corner) ? Self.edgeCornerRadius : cornerRadius
    }
}
#endif
