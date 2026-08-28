#if !os(watchOS)
import Foundation
import HAIconic
import SwiftUI
import WidgetKit

/// One widget tile, drawn for the kind the widget asks for and dimmed while another tile is waiting
/// on a confirmation.
///
/// Resolves tinting from the widget's rendering mode by default, which is what a widget wants: the
/// system paints accented tiles itself, so the card's own background and border have to step aside.
public struct WidgetTileView: View {
    @Environment(\.widgetRenderingMode) private var widgetRenderingMode

    /// How much a tile fades while it is not the one being confirmed.
    private static let opacityWhenDisabled: CGFloat = 0.3

    public let model: WidgetTileModel
    public let sizeStyle: WidgetTileSizeStyle
    public let family: WidgetFamily
    public let kind: WidgetTileKind
    /// `nil` follows the widget's rendering mode. The layouts that predate accented rendering pin
    /// it to `false` instead.
    public let tinted: Bool?
    public let logo: Image?
    /// Splits an action tile into an icon control and a body control. Only ``WidgetTileKind/button``
    /// tiles can be split — a reading has nothing to control.
    public let regions: WidgetTileRegions?

    public init(
        model: WidgetTileModel,
        sizeStyle: WidgetTileSizeStyle,
        family: WidgetFamily,
        kind: WidgetTileKind,
        tinted: Bool? = nil,
        logo: Image? = nil,
        regions: WidgetTileRegions? = nil
    ) {
        self.model = model
        self.sizeStyle = sizeStyle
        self.family = family
        self.kind = kind
        self.tinted = tinted
        self.logo = logo
        self.regions = regions
    }

    public var body: some View {
        let isTinted = tinted ?? (widgetRenderingMode == .accented)
        Group {
            switch kind {
            case .button:
                WidgetTileButtonView(
                    model: model,
                    sizeStyle: sizeStyle,
                    family: family,
                    tinted: isTinted,
                    logo: logo,
                    regions: regions
                )
            case .sensor:
                WidgetTileSensorView(
                    model: model,
                    sizeStyle: sizeStyle,
                    family: family,
                    tinted: isTinted,
                    logo: logo
                )
            }
        }
        .opacity(model.disabled ? Self.opacityWhenDisabled : 1)
    }
}

#Preview {
    HStack {
        WidgetTileView(
            model: .init(id: "1", title: "Good morning", subtitle: "Scene", icon: .weatherSunsetUpIcon),
            sizeStyle: .single,
            family: .systemSmall,
            kind: .button,
            tinted: false
        )
        WidgetTileView(
            model: .init(id: "2", title: "21.4 °C", subtitle: "Living room", icon: .thermometerIcon),
            sizeStyle: .single,
            family: .systemSmall,
            kind: .sensor,
            tinted: false
        )
    }
    .frame(height: 160)
    .padding()
}
#endif
