import Shared
import SwiftUI
import WidgetKit

/// Routes the Energy widget entry to the layout for the current widget family.
@available(iOS 17, *)
struct WidgetEnergyView: View {
    @Environment(\.widgetFamily) private var family

    let entry: WidgetEnergyEntry

    var body: some View {
        if !entry.isConfigured || !entry.hasData {
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

    /// Shared by every family so medium and large don't fall through to an empty card.
    private var emptyView: some View {
        // `isConfigured` is false only when the server has no energy dashboard. Every other way of
        // ending up without values — an unreachable server, or a period with no statistics — is a
        // "no data" state a reload can plausibly fix.
        let hasNoDashboard = !entry.isConfigured && !entry.loadFailed
        return VStack(spacing: DesignSystem.Spaces.one) {
            Text(hasNoDashboard ? L10n.Widgets.Energy.notConfigured : L10n.Widgets.Energy.noData)
                .font(.footnote)
                .multilineTextAlignment(.center)
                .foregroundStyle(WidgetEnergyStyle.secondaryText)
            if !hasNoDashboard {
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
