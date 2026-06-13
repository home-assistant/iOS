import Shared
import SwiftUI
import WidgetKit

@available(iOS 17.0, *)
struct WidgetGaugeView: View {
    @Environment(\.widgetFamily) private var family
    var entry: WidgetGaugeEntry

    /// Intrinsic size (points) of the `.accessoryCircular` gauge, including its min/max
    /// labels. That style is Lock-Screen-sized and ignores its frame, so on the Home
    /// Screen (`.systemSmall`) we scale it up by `tileSize / this` to fill the tile.
    private static let accessoryCircularIntrinsicSize: CGFloat = 74
    /// Inset around the scaled gauge within the `.systemSmall` tile.
    private static let systemSmallPadding: CGFloat = 12

    var body: some View {
        switch family {
        case .systemSmall:
            // The accessory gauge has a fixed Lock-Screen intrinsic size and won't grow on
            // its own, so scale it up to fill the Home Screen square. Widgets render to a
            // static image, so the scaled strokes/text stay crisp. `scaleEffect` is a
            // transform that ignores layout bounds, hence `.clipped()` to guard against bleed.
            // The Lock Screen is tinted by the system, but the Home Screen renders full-color,
            // so tint the gauge with the brand color — otherwise the fill renders black.
            GeometryReader { proxy in
                gauge
                    .scaleEffect(min(proxy.size.width, proxy.size.height) / Self.accessoryCircularIntrinsicSize)
                    .frame(width: proxy.size.width, height: proxy.size.height)
            }
            .clipped()
            .padding(Self.systemSmallPadding)
            .tint(Color.haPrimary)
        default:
            gauge
        }
    }

    @ViewBuilder private var gauge: some View {
        switch entry.gaugeType {
        case .normal:
            Gauge(value: entry.value) {
                if entry.valueLabel != nil {
                    Text(entry.valueLabel!)
                } else {
                    Text("00")
                        .redacted(reason: .placeholder)
                }
            } currentValueLabel: {
                if entry.valueLabel != nil {
                    Text(entry.valueLabel!)
                } else {
                    Text("00")
                        .redacted(reason: .placeholder)
                }
            } minimumValueLabel: {
                if entry.min != nil {
                    Text(entry.min!)
                } else {
                    Text("00")
                        .redacted(reason: .placeholder)
                }
            } maximumValueLabel: {
                if entry.max != nil {
                    Text(entry.max!)
                } else {
                    Text("00")
                        .redacted(reason: .placeholder)
                }
            }
            .gaugeStyle(.accessoryCircular)
        case .singleLabel:
            Gauge(value: entry.value) {
                if entry.label != nil {
                    Text(entry.label!)
                } else {
                    Text("00")
                        .redacted(reason: .placeholder)
                }
            } currentValueLabel: {
                if entry.valueLabel != nil {
                    Text(entry.valueLabel!)
                } else {
                    Text("00")
                        .redacted(reason: .placeholder)
                }
            }
            .gaugeStyle(.accessoryCircular)
        case .capacity:
            Gauge(value: entry.value) {
                if entry.valueLabel != nil {
                    Text(entry.valueLabel!)
                } else {
                    Text("00")
                        .redacted(reason: .placeholder)
                }
            } currentValueLabel: {
                if entry.valueLabel != nil {
                    Text(entry.valueLabel!)
                } else {
                    Text("00")
                        .redacted(reason: .placeholder)
                }
            }
            .gaugeStyle(.accessoryCircularCapacity)
        }
    }
}
