import SFSafeSymbols
import Shared
import SwiftUI

/// A bottom sheet view that allows users to select an existing widget to add an entity to,
/// or create a new widget.
struct WidgetSelectionView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel: WidgetSelectionViewModel

    /// Called when a widget is selected or a new one should be created
    /// - Parameter widget: The selected widget, or nil if creating a new one
    private let onSelection: (CustomWidget?) -> Void

    init(
        entityId: String,
        serverId: String,
        onSelection: @escaping (CustomWidget?) -> Void
    ) {
        self._viewModel = .init(wrappedValue: WidgetSelectionViewModel(
            entityId: entityId,
            serverId: serverId
        ))
        self.onSelection = onSelection
    }

    var body: some View {
        NavigationView {
            List {
                if viewModel.widgets.isEmpty {
                    emptyStateView
                } else {
                    widgetsSection
                    createNewSection
                }
            }
            .navigationTitle(L10n.Settings.Widgets.Select.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    if #unavailable(iOS 16.0) {
                        Button(L10n.cancelLabel) {
                            dismiss()
                        }
                    }
                }
            }
            .onAppear {
                viewModel.loadWidgets()
            }
        }
        .navigationViewStyle(.stack)
    }

    private var emptyStateView: some View {
        Section {
            VStack(spacing: DesignSystem.Spaces.two) {
                Image(systemSymbol: {
                    if #available(iOS 17.0, *) {
                        return .squareBadgePlusFill
                    } else {
                        return .squareshapeDashedSquareshape
                    }
                }())
                    .font(.system(size: 50))
                    .foregroundStyle(Color.haPrimary)

                Text(L10n.Settings.Widgets.Select.Empty.title)
                    .font(.headline)

                Text(L10n.Settings.Widgets.Select.Empty.subtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)

                Button {
                    dismiss()
                    onSelection(nil)
                } label: {
                    Label(L10n.Settings.Widgets.Create.title, systemSymbol: .plus)
                }
                .buttonStyle(.borderedProminent)
                .padding(.top, DesignSystem.Spaces.one)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, DesignSystem.Spaces.four)
        }
        .listRowBackground(Color.clear)
    }

    private var widgetsSection: some View {
        Section {
            ForEach(viewModel.widgets, id: \.id) { widget in
                Button {
                    dismiss()
                    onSelection(widget)
                } label: {
                    HStack {
                        VStack(alignment: .leading, spacing: DesignSystem.Spaces.half) {
                            Text(widget.name)
                                .font(.body)
                                .foregroundStyle(Color.primary)

                            Text(L10n.Settings.Widgets.Select.ItemCount.title(widget.items.count))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        Spacer()

                        Image(systemSymbol: .chevronRight)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        } header: {
            Text(L10n.Settings.Widgets.YourWidgets.title)
        } footer: {
            Text(L10n.Settings.Widgets.Select.Footer.title)
        }
    }

    private var createNewSection: some View {
        Section {
            Button {
                dismiss()
                onSelection(nil)
            } label: {
                Label(L10n.Settings.Widgets.Create.title, systemSymbol: .plus)
            }
        }
    }
}

// MARK: - ViewModel

final class WidgetSelectionViewModel: ObservableObject {
    @Published var widgets: [CustomWidget] = []

    let entityId: String
    let serverId: String

    init(entityId: String, serverId: String) {
        self.entityId = entityId
        self.serverId = serverId
    }

    func loadWidgets() {
        do {
            widgets = try CustomWidget.widgets()?.sorted(by: { $0.name < $1.name }) ?? []
        } catch {
            Current.Log.error("Failed to load widgets: \(error)")
        }
    }
}

#Preview {
    WidgetSelectionView(entityId: "light.living_room", serverId: "server-1") { widget in
        print("Selected: \(widget?.name ?? "Create new")")
    }
}
