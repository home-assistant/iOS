import Shared
import SwiftUI
import WidgetKit

/// Routes the Energy widget entry to the layout for the current widget family.
@available(iOS 17, *)
struct WidgetEnergyView: View {
    @Environment(\.widgetFamily) private var family

    let entry: WidgetEnergyEntry

    var body: some View {
        if !entry.isConfigured {
            emptyView
        } else {
            switch family {
            case .systemSmall:
                WidgetEnergySmallView(entry: entry)
            default:
                WidgetEnergyMediumView(entry: entry)
            }
        }
    }

    private var emptyView: some View {
        Text(L10n.Widgets.Energy.notConfigured)
            .font(.footnote)
            .multilineTextAlignment(.center)
            .foregroundStyle(WidgetEnergyStyle.secondaryText)
            .padding()
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .widgetBackground(WidgetEnergyStyle.background)
    }
}

@available(iOS 17, *)
#Preview(as: .systemSmall) {
    WidgetEnergy()
} timeline: {
    WidgetEnergyEntry(period: .today, isConfigured: false)
}
