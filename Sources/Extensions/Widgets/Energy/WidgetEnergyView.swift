import Shared
import SwiftUI
import WidgetKit

/// Routes the Energy widget entry to the layout for the current widget family.
@available(iOS 17, *)
struct WidgetEnergyView: View {
    @Environment(\.widgetFamily) private var family

    let entry: WidgetEnergyEntry

    var body: some View {
        // The accessory families own their empty state: they render on the lock screen, where the
        // home screen card's background and prose don't fit.
        switch family {
        case .accessoryCircular:
            WidgetEnergyAccessoryCircularView(entry: entry)
        case .accessoryRectangular:
            WidgetEnergyAccessoryRectangularView(entry: entry)
        case .accessoryInline:
            WidgetEnergyAccessoryInlineView(entry: entry)
        default:
            if !entry.isConfigured {
                emptyView
            } else if family == .systemSmall {
                WidgetEnergySmallView(entry: entry)
            } else {
                WidgetEnergyMediumView(entry: entry)
            }
        }
    }

    private var emptyView: some View {
        Text(WidgetEnergyStyle.emptyStateText(isConfigured: entry.isConfigured, loadFailed: entry.loadFailed))
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
