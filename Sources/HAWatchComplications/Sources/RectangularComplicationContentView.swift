import SwiftUI
import WidgetKit

/// The rectangular complication's on-face content: optional icon + name/subtitle, then either the
/// progress bar (when a gauge fraction exists) or the value as text, then optional bottom text.
///
/// This is the single source of truth shared by the real watch complication
/// (`RectangularComplicationView`) and the in-app editor preview (`RectangularComplicationPreview`).
/// Neither should re-implement this layout — they only build a `RectangularComplicationRenderModel`.
@available(iOS 16.0, watchOS 10.0, *)
public struct RectangularComplicationContentView: View {
    /// Layout metrics mirrored from the watch's `WatchWidgetConstants.Layout`.
    private enum Layout {
        static let spacing: CGFloat = 6
        static let logoSize: CGFloat = 18
        static let textSpacing: CGFloat = 1
        /// Opacity applied to secondary text (subtitle, bottom text).
        static let secondaryTextOpacity: CGFloat = 0.8
        /// Smallest fraction text is allowed to shrink to before truncating.
        static let minimumScaleFactor: CGFloat = 0.5
        static let titleLineLimit = 1
        static let valueLineLimit = 2
    }

    public let model: RectangularComplicationRenderModel

    public init(model: RectangularComplicationRenderModel) {
        self.model = model
    }

    public var body: some View {
        let textColor = model.textColor ?? .primary
        HStack(spacing: Layout.spacing) {
            if model.showsIcon, let iconImage = model.iconImage {
                iconImage
                    .resizable()
                    .scaledToFit()
                    .frame(width: Layout.logoSize, height: Layout.logoSize)
                    .widgetAccentable()
            }
            VStack(alignment: .leading, spacing: Layout.textSpacing) {
                if model.showsName, !model.title.isEmpty {
                    Text(model.title)
                        .font(.caption2.weight(.semibold))
                        .lineLimit(Layout.titleLineLimit)
                        .foregroundStyle(textColor)
                        .minimumScaleFactor(Layout.minimumScaleFactor)
                }
                if model.showsSubtitle, !model.subtitle.isEmpty {
                    Text(model.subtitle)
                        .font(.caption2)
                        .lineLimit(Layout.titleLineLimit)
                        .foregroundStyle(textColor.opacity(Layout.secondaryTextOpacity))
                        .minimumScaleFactor(Layout.minimumScaleFactor)
                }
                if let fraction = model.fraction {
                    RectangularProgressView(
                        fraction: fraction,
                        minLabel: model.minLabel,
                        maxLabel: model.maxLabel,
                        valueLabel: model.showsValue ? model.valueText : nil,
                        tint: model.tint
                    )
                } else if model.showsValue, !model.valueText.isEmpty {
                    Text(model.valueText)
                        .font(.caption2)
                        .lineLimit(Layout.valueLineLimit)
                        .foregroundStyle(textColor)
                }
                if model.showsBottomText, !model.bottomText.isEmpty {
                    Text(model.bottomText)
                        .font(.caption2)
                        .lineLimit(Layout.titleLineLimit)
                        .foregroundStyle(textColor.opacity(Layout.secondaryTextOpacity))
                        .minimumScaleFactor(Layout.minimumScaleFactor)
                }
            }
            Spacer(minLength: 0)
        }
    }
}

#if DEBUG
@available(iOS 16.0, watchOS 10.0, *)
public extension RectangularComplicationRenderModel {
    /// Sample model for previews and snapshot tests. Independently toggleable slots so callers can
    /// exercise the full layout (title / subtitle / gauge-or-value / bottom text).
    static func sample(
        icon: Bool = true,
        title: String = "Battery",
        subtitle: String? = nil,
        fraction: Double? = 0.68,
        value: String = "68%",
        showValue: Bool = true,
        showMinMax: Bool = true,
        bottomText: String? = nil,
        tint: Color = .green,
        textColor: Color? = nil
    ) -> RectangularComplicationRenderModel {
        RectangularComplicationRenderModel(
            iconImage: icon ? Image(systemName: "bolt.fill") : nil,
            showsIcon: icon,
            title: title,
            showsName: !title.isEmpty,
            subtitle: subtitle ?? "",
            showsSubtitle: subtitle != nil,
            fraction: fraction,
            minLabel: fraction != nil && showMinMax ? "0" : nil,
            maxLabel: fraction != nil && showMinMax ? "100" : nil,
            valueText: value,
            showsValue: showValue,
            bottomText: bottomText ?? "",
            showsBottomText: bottomText != nil,
            tint: tint,
            textColor: textColor
        )
    }
}

/// Renders on a dark rounded "watch face" so the default `.primary` text is legible, matching the
/// watch's black face.
@available(iOS 16.0, watchOS 10.0, *)
private func face(_ model: RectangularComplicationRenderModel) -> some View {
    RectangularComplicationContentView(model: model)
        .padding(12)
        .frame(width: 200)
        .background(.black, in: .rect(cornerRadius: 14))
        .environment(\.colorScheme, .dark)
}

@available(iOS 16.0, watchOS 10.0, *)
#Preview("Icon + name + gauge") {
    face(.sample()).padding()
}

@available(iOS 16.0, watchOS 10.0, *)
#Preview("All slots") {
    face(.sample(title: "Living Room", subtitle: "Temperature", bottomText: "Updated 2m ago")).padding()
}

// Every slot populated, but the gauge's min/max labels are hidden.
@available(iOS 16.0, watchOS 10.0, *)
#Preview("All slots, no min/max") {
    face(.sample(
        title: "Living Room",
        subtitle: "Temperature",
        showMinMax: false,
        bottomText: "Updated 2m ago"
    )).padding()
}

@available(iOS 16.0, watchOS 10.0, *)
#Preview("Value as text") {
    face(.sample(title: "Front Door", subtitle: "Lock", fraction: nil, value: "Locked")).padding()
}

@available(iOS 16.0, watchOS 10.0, *)
#Preview("Custom text color") {
    face(.sample(
        title: "Solar",
        subtitle: "Production",
        value: "82%",
        bottomText: "Peak 4.2 kW",
        textColor: .yellow
    )).padding()
}
#endif
