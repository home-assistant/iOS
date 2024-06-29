import SwiftUI
import WidgetKit

@available(iOS 17.0, *)
struct WidgetGaugeView: View {
    var entry: WidgetGaugeEntry
    
    var body: some View {
        switch (entry.gaugeType) {
        case .normal:
            Gauge(value: entry.value) {
                Text(entry.valueLabel)
            } currentValueLabel: {
                Text(entry.valueLabel)
            } minimumValueLabel: {
                Text(entry.min)
            } maximumValueLabel: {
                Text(entry.max)
            }
            .gaugeStyle(.accessoryCircular)
        case .capacity:
            Gauge(value: entry.value) {
                Text(entry.valueLabel)
            } currentValueLabel: {
                Text(entry.valueLabel)
            }
            .gaugeStyle(.accessoryCircularCapacity)
        }
    }
}
