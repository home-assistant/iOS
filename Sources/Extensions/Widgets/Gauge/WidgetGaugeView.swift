import SwiftUI
import WidgetKit

@available(iOS 17.0, *)
struct WidgetGaugeView: View {
    var entry: WidgetGaugeEntry

    var body: some View {
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
