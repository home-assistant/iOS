import HAWatchComplications
import Shared
import SwiftUI
import WidgetKit

@available(iOS 17.0, *)
struct WidgetGaugeView: View {
    @Environment(\.widgetFamily) private var family
    var entry: WidgetGaugeEntry

    /// Inset around the gauge within the `.systemSmall` tile.
    private static let systemSmallPadding: CGFloat = 10

    var body: some View {
        // A mirrored complication renders through the very same content view the watch and the
        // complication editor use, so it carries its own gauge style, colors and slots.
        if let model = entry.complicationModel {
            complication(model)
        } else {
            WidgetGaugeContentView(
                gaugeType: entry.gaugeType.designSystemType,
                value: entry.value,
                valueLabel: entry.valueLabel,
                label: entry.label,
                min: entry.min,
                max: entry.max,
                family: family,
                logo: Image(.logo)
            )
        }
    }

    /// The complication content view. The lock screen renders it bare, the way the watch face does.
    /// The Home Screen is full-color, so the complication gets the black face it was designed for —
    /// its white text and icon would otherwise be invisible on a light tile.
    @ViewBuilder private func complication(_ model: CircularComplicationRenderModel) -> some View {
        if family == .systemSmall {
            CircularComplicationContentView(model: model)
                .padding(Self.systemSmallPadding)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(.black, in: .circle)
                .environment(\.colorScheme, .dark)
                .padding(Self.systemSmallPadding)
        } else {
            CircularComplicationContentView(model: model)
        }
    }
}

@available(iOS 17, *)
#Preview(as: .systemSmall, widget: {
    WidgetGauge()
}, timeline: {
    WidgetGaugeEntry(
        gaugeType: .normal,
        value: 0.67,
        valueLabel: "67%",
        label: nil,
        min: "0",
        max: "100",
        runScript: false,
        script: nil,
        showConfirmationNotification: true
    )
})

@available(iOS 17, *)
#Preview(as: .systemSmall, widget: {
    WidgetGauge()
}, timeline: {
    WidgetGaugeEntry(
        gaugeType: .singleLabel,
        value: 0.67,
        valueLabel: "67%",
        label: "Battery",
        min: nil,
        max: nil,
        runScript: false,
        script: nil,
        showConfirmationNotification: true
    )
})

@available(iOS 17, *)
#Preview(as: .systemSmall, widget: {
    WidgetGauge()
}, timeline: {
    WidgetGaugeEntry(
        gaugeType: .capacity,
        value: 0.67,
        valueLabel: "100%",
        label: nil,
        min: "0",
        max: "100",
        runScript: false,
        script: nil,
        showConfirmationNotification: true
    )
})

@available(iOS 17, *)
#Preview(as: .accessoryCircular, widget: {
    WidgetGauge()
}, timeline: {
    WidgetGaugeEntry(
        gaugeType: .normal,
        value: 0.67,
        valueLabel: "67%",
        label: nil,
        min: "0",
        max: "100",
        runScript: false,
        script: nil,
        showConfirmationNotification: true
    )
})
