import Shared
import SwiftUI

/// SwiftUI replacement for `ComplicationFamilySelectViewController`.
struct ComplicationFamilySelectView: View {
    let allowMultiple: Bool
    let currentFamilies: Set<ComplicationGroupMember>
    /// Called after a new complication is saved so the presenting flow can dismiss.
    let onSaved: () -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        List {
            if !allowMultiple, !currentFamilies.isEmpty {
                Section {
                    Text(L10n.Watch.Configurator.New.multipleComplicationInfo)
                        .foregroundColor(.secondary)
                }
            }

            ForEach(ComplicationGroup.allCases.sorted(), id: \.self) { group in
                Section {
                    ForEach(group.members.sorted(), id: \.self) { family in
                        familyRow(family: family)
                    }
                } header: {
                    Text(group.name)
                } footer: {
                    Text(group.description)
                }
            }
        }
        .navigationTitle(L10n.Watch.Configurator.New.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button(L10n.cancelLabel) { dismiss() }
            }
        }
    }

    @ViewBuilder
    private func familyRow(family: ComplicationGroupMember) -> some View {
        let disabled = !allowMultiple && currentFamilies.contains(family)

        NavigationLink {
            ComplicationEditView(
                config: makeNewComplication(for: family),
                isNew: true,
                onSaved: onSaved
            )
        } label: {
            VStack(alignment: .leading, spacing: DesignSystem.Spaces.half) {
                Text(family.shortName)
                    .foregroundColor(disabled ? .secondary : .primary)
                Text(family.description)
                    .font(.caption)
                    .foregroundColor(disabled ? Color(.tertiaryLabel) : .secondary)
            }
        }
        .disabled(disabled)
        .accessibilityAddTraits(disabled ? .isButton : [])
    }

    private func makeNewComplication(for family: ComplicationGroupMember) -> WatchComplication {
        let complication = WatchComplication()
        complication.Family = family

        if !allowMultiple {
            // Preserve migration behaviour: watchOS 6 complications used a
            // predictable, family-derived identifier.
            complication.identifier = family.rawValue
        }

        return complication
    }
}
