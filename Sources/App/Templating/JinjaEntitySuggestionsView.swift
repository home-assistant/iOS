import SFSafeSymbols
import Shared
import SwiftUI

/// The entity suggestion pills shown as the footer of the Jinja editor's template section: each
/// shows the entity's display name with its context line (Floor • Area • Device), plus a "More"
/// pill that opens the entity picker.
struct JinjaEntitySuggestionsView: View {
    /// One pill: the entity's display name and context, carrying the insertion it performs.
    struct Item: Identifiable {
        let suggestion: JinjaTemplateSuggestion
        let name: String
        let subtitle: String?
        var id: String { suggestion.id }
    }

    let items: [Item]
    let onSelect: (JinjaTemplateSuggestion) -> Void
    let onMore: () -> Void

    var body: some View {
        // Pills flow side by side and wrap to new lines instead of scrolling horizontally.
        FlowLayout(spacing: DesignSystem.Spaces.one) {
            ForEach(items) { item in
                Button {
                    onSelect(item.suggestion)
                } label: {
                    VStack(alignment: .leading, spacing: 0) {
                        Text(verbatim: item.name)
                            .font(.footnote.weight(.medium))
                            .foregroundStyle(Color.primary)
                            .lineLimit(1)
                            .truncationMode(.tail)
                        if let subtitle = item.subtitle, !subtitle.isEmpty {
                            Text(verbatim: subtitle)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                                .truncationMode(.tail)
                        }
                    }
                    .frame(maxWidth: 220, alignment: .leading)
                    .padding(.horizontal, DesignSystem.Spaces.oneAndHalf)
                    .padding(.vertical, DesignSystem.Spaces.half)
                    .background(Capsule().fill(Color(uiColor: .tertiarySystemFill)))
                }
                .buttonStyle(.plain)
            }

            Button {
                onMore()
            } label: {
                HStack(spacing: DesignSystem.Spaces.half) {
                    Text(L10n.Watch.Complications.Builder.templateSuggestionsMore)
                        .font(.footnote.weight(.semibold))
                    Image(systemSymbol: .chevronRight)
                        .font(.caption2.weight(.semibold))
                }
                .foregroundStyle(.white)
                .padding(.horizontal, DesignSystem.Spaces.oneAndHalf)
                .padding(.vertical, DesignSystem.Spaces.one)
                .background(Capsule().fill(Color.haPrimary))
            }
            .buttonStyle(.plain)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, DesignSystem.Spaces.half)
    }
}

#Preview {
    JinjaEntitySuggestionsView(
        items: [
            .init(
                suggestion: .init(label: "sensor.solar_power", insertion: "sensor.solar_power"),
                name: "Solar Power",
                subtitle: "Ground Floor • Garage"
            ),
            .init(
                suggestion: .init(label: "sensor.bruno_battery_level", insertion: "sensor.bruno_battery_level"),
                name: "Bruno Battery Level",
                subtitle: "iPhone"
            ),
            .init(
                suggestion: .init(label: "light.kitchen", insertion: "light.kitchen"),
                name: "Kitchen",
                subtitle: nil
            ),
        ],
        onSelect: { _ in },
        onMore: {}
    )
    .padding()
    .background(Color(uiColor: .systemGroupedBackground))
}
