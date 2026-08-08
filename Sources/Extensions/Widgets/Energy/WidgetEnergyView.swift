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
            if !entry.isConfigured || !hasData {
                emptyView
            } else if family == .systemSmall {
                WidgetEnergySmallView(entry: entry)
            } else {
                WidgetEnergyMediumView(entry: entry)
            }
        }
    }

    /// Whether any home screen layout has something to draw. Without this the medium and large
    /// families fall through to a card holding nothing but the logo, where the small family at
    /// least says "no data".
    private var hasData: Bool {
        !WidgetEnergyMetric.metrics(for: entry).isEmpty || !entry.chartPoints.isEmpty
    }

    private var emptyView: some View {
        // Mirrors `emptyStateText`: a missing energy dashboard is the one empty state a reload
        // can't fix, so it's also the one that doesn't offer the button.
        let canRetry = entry.isConfigured || entry.loadFailed
        return VStack(spacing: DesignSystem.Spaces.one) {
            Text(WidgetEnergyStyle.emptyStateText(isConfigured: entry.isConfigured, loadFailed: entry.loadFailed))
                .font(.footnote)
                .multilineTextAlignment(.center)
                .foregroundStyle(WidgetEnergyStyle.secondaryText)
            if canRetry {
                Button(intent: WidgetEnergyRefreshAppIntent()) {
                    Image(systemSymbol: .arrowClockwiseCircle)
                        .foregroundStyle(.secondary)
                        .font(DesignSystem.Font.title)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(L10n.Widgets.Energy.refreshTitle)
            }
        }
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
    WidgetEnergyEntry(period: .today, isConfigured: false, loadFailed: true)
    WidgetEnergyEntry(period: .today, isConfigured: true)
}

@available(iOS 17, *)
#Preview("Empty medium", as: .systemMedium) {
    WidgetEnergy()
} timeline: {
    WidgetEnergyEntry(period: .today, isConfigured: false, loadFailed: true)
    WidgetEnergyEntry(period: .today, isConfigured: true)
}
