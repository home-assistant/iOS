import HAWatchComplications
import Shared
import SwiftUI

/// iPhone preview of the rectangular complication. Renders through the shared
/// `RectangularComplicationContentView` (the exact same view the watch uses), mapping the editor's
/// `ComplicationRenderContext` into the shared render model — so the preview can't drift from the
/// on-watch rendering.
struct RectangularComplicationPreview: View {
    let context: ComplicationRenderContext

    var body: some View {
        RectangularComplicationContentView(model: renderModel)
            .padding(12)
            .frame(width: 200)
    }

    private var renderModel: RectangularComplicationRenderModel {
        RectangularComplicationRenderModel(
            iconImage: context.iconImage,
            showsIcon: context.iconImage != nil,
            title: context.titleText,
            showsName: context.showsName,
            subtitle: context.subtitleText,
            showsSubtitle: context.showsSubtitle,
            fraction: context.showsGauge ? context.fraction : nil,
            minLabel: context.showsMin ? context.range.map { context.label($0.min) } : nil,
            maxLabel: context.showsMax ? context.range.map { context.label($0.max) } : nil,
            valueText: context.valueText,
            showsValue: context.showsValue,
            bottomText: context.bottomText,
            showsBottomText: context.showsBottomText,
            tint: context.tint,
            textColor: context.textColor,
            bottomTextColor: context.bottomTextColor
        )
    }
}

#if DEBUG
import SFSafeSymbols

private extension ComplicationRenderContext {
    /// Rectangular sample with independently toggleable text slots + gauge, so the previews can show
    /// off the full layout: title / subtitle / value (gauge or text) / bottom text. The subtitle and
    /// bottom-text slots the watch hides by default are made visible here with sample text.
    static func previewRectangular(
        name: String = "Battery",
        subtitle: String? = nil,
        bottomText: String? = nil,
        value: String = "68%",
        showValue: Bool = true,
        gauge: Bool = true,
        icon: Bool = true,
        textColor: String? = nil
    ) -> ComplicationRenderContext {
        var config = WatchComplicationConfig(
            serverId: "preview",
            widgetFamily: .rectangular,
            name: name,
            iconName: "battery-70",
            iconColor: "#34C759FF"
        )
        if gauge {
            config.gaugeMin = 0
            config.gaugeMax = 100
        }
        config.setOptions(
            WatchComplicationConfig.FamilyOptions(
                showValue: showValue,
                showIcon: icon,
                showGauge: gauge,
                tint: "#34C759FF",
                textColor: textColor
            ),
            for: .rectangular
        )
        for (slot, text) in [(ComplicationSlot.subtitle, subtitle), (.bottomText, bottomText)] {
            guard let text else { continue }
            config.setSlotConfig(
                ComplicationSlotConfig(isVisible: true, formula: ComplicationFormula(parts: [.text(text)])),
                slot: slot,
                for: .rectangular
            )
        }
        return ComplicationRenderContext(
            config: config,
            value: value,
            fraction: gauge ? 0.68 : nil,
            // Flatten the symbol into a white bitmap so the icon shows on the black face (mirrors the
            // colored MaterialDesignIcons bitmap the watch renders).
            iconImage: icon ? Image(uiImage: whiteSymbol(.battery75)) : nil
        )
    }
}

/// A symbol flattened into an opaque white bitmap. A tinted SF Symbol stays template-colored and would
/// draw black (invisible) on the preview's black face, so it's rendered to a non-template image.
private func whiteSymbol(_ symbol: SFSymbol, size: CGFloat = 22) -> UIImage {
    let configured = UIImage(systemSymbol: symbol)
        .applyingSymbolConfiguration(.init(pointSize: size)) ?? UIImage(systemSymbol: symbol)
    return UIGraphicsImageRenderer(size: configured.size).image { _ in
        configured.withTintColor(.white, renderingMode: .alwaysOriginal).draw(at: .zero)
    }.withRenderingMode(.alwaysOriginal)
}

/// Renders the preview on a dark rounded "watch face" so the complication's default white text is
/// legible — on the watch the face is black, so a light preview canvas would hide every text slot.
private func rectangularFace(_ context: ComplicationRenderContext) -> some View {
    RectangularComplicationPreview(context: context)
        .background(.black, in: .rect(cornerRadius: 14))
}

#Preview("Icon + name + gauge") {
    rectangularFace(.previewRectangular())
        .padding()
}

// Every text slot populated: title, subtitle, gauge (with value thumb), and bottom text.
#Preview("All slots") {
    rectangularFace(.previewRectangular(
        name: "Living Room",
        subtitle: "Temperature",
        bottomText: "Updated 2m ago"
    ))
    .padding()
}

// No gauge configured: the value renders as plain text instead of a progress bar.
#Preview("Value as text") {
    rectangularFace(.previewRectangular(
        name: "Front Door",
        subtitle: "Lock",
        value: "Locked",
        gauge: false
    ))
    .padding()
}

// Text-only: name + subtitle with neither a gauge nor a value.
#Preview("Text only") {
    rectangularFace(.previewRectangular(
        name: "Bedroom",
        subtitle: "All quiet",
        showValue: false,
        gauge: false
    ))
    .padding()
}

// Icon hidden: the text column takes the full width.
#Preview("No icon") {
    rectangularFace(.previewRectangular(
        name: "Humidity",
        subtitle: "Bathroom",
        value: "54%",
        icon: false
    ))
    .padding()
}

// Long strings in every slot: each is single-line and truncates with an ellipsis.
#Preview("Long text truncation") {
    rectangularFace(.previewRectangular(
        name: "Basement Dehumidifier Tank",
        subtitle: "Relative humidity, second floor",
        bottomText: "Last synchronized a few moments ago",
        value: "1234"
    ))
    .padding()
}

// Custom text color applied to the title / subtitle / bottom-text slots.
#Preview("Custom text color") {
    rectangularFace(.previewRectangular(
        name: "Solar",
        subtitle: "Production",
        bottomText: "Peak 4.2 kW",
        value: "82%",
        textColor: "#FFD60A"
    ))
    .padding()
}
#endif
