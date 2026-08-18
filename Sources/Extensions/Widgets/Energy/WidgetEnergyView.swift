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
            // A configured entry always draws its layout, even with nothing to show yet: the figures
            // and the chart come back empty rather than being replaced by prose. Only an entry the
            // widget can't read at all — no server URL to reach, no dashboard, or a failed load —
            // falls back to the message.
            if !entry.isConfigured || entry.loadFailed {
                emptyView
            } else if family == .systemSmall {
                WidgetEnergySmallView(entry: entry)
            } else {
                WidgetEnergyMediumView(entry: entry)
            }
        }
    }

    private var emptyView: some View {
        VStack(spacing: DesignSystem.Spaces.one) {
            Text(WidgetEnergyStyle.emptyStateText(for: entry))
                .font(.footnote)
                .multilineTextAlignment(.center)
                .minimumScaleFactor(0.8)
                .foregroundStyle(WidgetEnergyStyle.secondaryText)
            // A missing energy dashboard is the one empty state a reload can't fix, so it's also the
            // one that doesn't offer the button. An unreachable server does get it: the URL
            // configuration, or the network, may have been sorted out since the entry was built.
            if entry.loadFailed || entry.noConnection {
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
    // No URL to reach the server with: the URL configuration message, with a retry.
    WidgetEnergyEntry(period: .today, isConfigured: false, noConnection: true)
    // Configured but the statistics request failed: the message, with a retry.
    WidgetEnergyEntry(period: .today, isConfigured: true, loadFailed: true)
    // Configured but nothing reported yet: empty figures, not prose.
    WidgetEnergyEntry(period: .today, isConfigured: true)
}

@available(iOS 17, *)
#Preview("Empty medium", as: .systemMedium) {
    WidgetEnergy()
} timeline: {
    WidgetEnergyEntry(period: .today, isConfigured: false)
    WidgetEnergyEntry(period: .today, isConfigured: false, loadFailed: true)
    WidgetEnergyEntry(period: .today, isConfigured: false, noConnection: true)
    WidgetEnergyEntry(period: .today, isConfigured: true)
}
