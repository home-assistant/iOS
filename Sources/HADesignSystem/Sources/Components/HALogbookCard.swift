#if !os(watchOS)
import SwiftUI

/// What happened recently, newest first, down a timeline. The SwiftUI counterpart of the frontend's
/// `hui-logbook-card` and the `ha-logbook-entry` rows inside it.
///
/// Draws the frontend's `timeline` layout: the time in a column of its own, an icon node on a rule
/// running down the card, and the name and message beside it. The rule is what makes a run of
/// entries read as one sequence rather than as separate rows.
public struct HALogbookCard: View {
    private static let nodeSize: CGFloat = 24
    private static let timeColumnWidth: CGFloat = 62

    @Environment(\.locale) private var locale
    @Environment(\.timeZone) private var timeZone

    private let title: String?
    private let entries: [HALogbookEntry]
    private let emptyMessage: String?
    private let onSelect: ((HALogbookEntry) -> Void)?

    /// - Parameter emptyMessage: Shown in place of the list when there is nothing to report, the
    ///   frontend's `no_logbook_entries_found`. A card with an empty body reads as broken.
    public init(
        title: String? = nil,
        entries: [HALogbookEntry],
        emptyMessage: String? = nil,
        onSelect: ((HALogbookEntry) -> Void)? = nil
    ) {
        self.title = title
        self.entries = entries
        self.emptyMessage = emptyMessage
        self.onSelect = onSelect
    }

    public var body: some View {
        HACard(header: title) {
            if entries.isEmpty {
                Text(emptyMessage ?? "")
                    .font(DesignSystem.Font.body)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(DesignSystem.Spaces.two)
            } else {
                VStack(spacing: .zero) {
                    ForEach(Array(entries.enumerated()), id: \.element.id) { index, entry in
                        row(entry, isLast: index == entries.count - 1)
                    }
                }
                .padding(.vertical, DesignSystem.Spaces.one)
            }
        }
    }

    private func row(_ entry: HALogbookEntry, isLast: Bool) -> some View {
        HStack(alignment: .top, spacing: DesignSystem.Spaces.one) {
            Text(time(for: entry))
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
                .frame(width: Self.timeColumnWidth, alignment: .trailing)
                // The time sits on the first line of the message rather than at the top of the
                // block, so a two-line message keeps its timestamp beside its first words.
                .padding(.top, DesignSystem.Spaces.micro)
            node(entry, isLast: isLast)
            VStack(alignment: .leading, spacing: DesignSystem.Spaces.micro) {
                Text(entry.name)
                    .font(DesignSystem.Font.body)
                    .fixedSize(horizontal: false, vertical: true)
                Text(entry.message)
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: .zero)
        }
        .padding(.horizontal, DesignSystem.Spaces.two)
        .padding(.bottom, isLast ? .zero : DesignSystem.Spaces.two)
        .contentShape(Rectangle())
        .modify { view in
            if let onSelect {
                Button { onSelect(entry) } label: { view }.buttonStyle(.plain)
            }
        }
        .accessibilityElement(children: .combine)
    }

    /// The icon, with the rule to the next entry continuing below it.
    private func node(_ entry: HALogbookEntry, isLast: Bool) -> some View {
        VStack(spacing: .zero) {
            ZStack {
                Circle()
                    .fill(entry.color.opacity(0.2))
                if let icon = entry.icon {
                    MaterialDesignIconsImage(icon: icon, size: 14)
                        .foregroundStyle(entry.color)
                } else {
                    Circle()
                        .fill(entry.color)
                        .frame(width: 8, height: 8)
                }
            }
            .frame(width: Self.nodeSize, height: Self.nodeSize)
            if !isLast {
                Rectangle()
                    .fill(Color.haDivider)
                    .frame(width: DesignSystem.Border.Width.default)
                    .frame(maxHeight: .infinity)
            }
        }
        .fixedSize(horizontal: true, vertical: false)
    }

    private func time(for entry: HALogbookEntry) -> String {
        entry.when.formatted(
            Date.FormatStyle(date: .omitted, time: .shortened, locale: locale, timeZone: timeZone)
        )
    }
}

/// 2026-08-29 09:41:07 UTC, the instant the rest of the gallery pins.
private let sampleNow = Date(timeIntervalSince1970: 1_787_996_467)

#Preview {
    VStack(spacing: DesignSystem.Spaces.two) {
        HALogbookCard(
            title: "Logbook",
            entries: [
                HALogbookEntry(
                    id: "1",
                    when: sampleNow,
                    name: "Front door",
                    message: "was opened",
                    icon: .doorOpenIcon
                ),
                HALogbookEntry(
                    id: "2",
                    when: sampleNow.addingTimeInterval(-600),
                    name: "Kitchen light",
                    message: "was turned on by Bruno",
                    icon: .lightbulbOnIcon,
                    color: .haWarningColor
                ),
                HALogbookEntry(
                    id: "3",
                    when: sampleNow.addingTimeInterval(-3600),
                    name: "Alarm",
                    message: "changed to disarmed",
                    icon: .shieldOffOutlineIcon,
                    color: .haSuccessColor
                ),
            ]
        )
        HALogbookCard(title: "Logbook", entries: [], emptyMessage: "No logbook entries found.")
    }
    .padding()
    .background(Color.haNeutralQuietFill)
}

extension HALogbookCard: FrontendComponent {
    public static var frontendComponentName: String { "hui-logbook-card" }
    public static var frontendComponentVersion: String { "2026-08-28" }
}

#endif
