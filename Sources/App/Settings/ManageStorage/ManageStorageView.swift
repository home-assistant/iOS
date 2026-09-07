import SFSafeSymbols
import Shared
import SwiftUI

struct ManageStorageView: View {
    @StateObject private var viewModel: ManageStorageViewModel

    /// The view model is handed in rather than defaulted: `ManageStorageViewModel` is `@MainActor`,
    /// and a default argument would be evaluated outside the main actor. Callers build it from the
    /// main actor, which every `View` body already is.
    init(viewModel: ManageStorageViewModel) {
        _viewModel = StateObject(wrappedValue: viewModel)
    }

    var body: some View {
        List {
            AppleLikeListTopRowHeader(
                image: nil,
                headerImageAlternativeView: AnyView(
                    Image(systemSymbol: .internaldrive)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 80, height: 80)
                        .foregroundStyle(Color.haPrimary)
                ),
                title: L10n.Settings.Debugging.ManageStorage.title,
                subtitle: L10n.Settings.Debugging.ManageStorage.subtitle
            )

            Section {
                HStack {
                    Text(L10n.Settings.Debugging.ManageStorage.Summary.total)
                    Spacer()
                    Text(ManageStorageItem.formatted(byteCount: viewModel.totalByteCount))
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                }
                HStack {
                    Text(L10n.Settings.Debugging.ManageStorage.Summary.reclaimable)
                    Spacer()
                    Text(ManageStorageItem.formatted(byteCount: viewModel.reclaimableByteCount))
                        .foregroundStyle(Color.haPrimary)
                        .monospacedDigit()
                }
                HStack {
                    Label {
                        Text(L10n.Settings.Debugging.ManageStorage.Summary.protected)
                    } icon: {
                        Image(systemSymbol: .lockFill)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Text(verbatim: "\(viewModel.protectedItemCount)")
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                }
            } footer: {
                Text(L10n.Settings.Debugging.ManageStorage.Summary.footer)
            }

            if viewModel.sections.isEmpty {
                Section {
                    Text(L10n.Settings.Debugging.ManageStorage.Empty.title)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .center)
                }
            }

            ForEach(viewModel.sections) { section in
                Section {
                    ForEach(section.items) { item in
                        HStack(alignment: .top, spacing: DesignSystem.Spaces.two) {
                            VStack(alignment: .leading, spacing: DesignSystem.Spaces.half) {
                                Text(item.title)
                                Text(item.explanation)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                if !item.countsTowardTotal {
                                    Text(L10n.Settings.Debugging.ManageStorage.insideAppDatabase)
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                }
                                if let reason = item.protection.reason {
                                    Label {
                                        Text(reason.explanation)
                                    } icon: {
                                        Image(systemSymbol: .lockFill)
                                    }
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                                }
                            }
                            Spacer(minLength: DesignSystem.Spaces.one)
                            VStack(alignment: .trailing, spacing: DesignSystem.Spaces.one) {
                                if viewModel.cleaningItemID == item.id {
                                    ProgressView()
                                        .progressViewStyle(.circular)
                                } else {
                                    Text(item.formattedSize)
                                        .foregroundStyle(.secondary)
                                        .monospacedDigit()
                                }
                                if item.isDeletable {
                                    Button {
                                        viewModel.confirmCleaning(of: item)
                                    } label: {
                                        Image(systemSymbol: .trash)
                                            .foregroundStyle(item.isCleanable ? Color.red : Color.secondary)
                                    }
                                    .buttonStyle(.borderless)
                                    .disabled(!item.isCleanable || viewModel.isBusy)
                                    .accessibilityLabel(
                                        L10n.Settings.Debugging.ManageStorage.deleteAccessibilityLabel(item.title)
                                    )
                                    .confirmationDialog(
                                        L10n.Settings.Debugging.ManageStorage.Confirm.title(item.title),
                                        isPresented: Binding(
                                            get: { viewModel.itemPendingCleaning?.id == item.id },
                                            set: { if !$0 { viewModel.itemPendingCleaning = nil } }
                                        ),
                                        titleVisibility: .visible
                                    ) {
                                        Button(
                                            L10n.Settings.Debugging.ManageStorage.Confirm.deleteButton,
                                            role: .destructive
                                        ) {
                                            Task { await viewModel.clean(item) }
                                        }
                                        Button(L10n.cancelLabel, role: .cancel) {}
                                    } message: {
                                        Text(item.explanation)
                                    }
                                }
                            }
                        }
                    }
                } header: {
                    HStack {
                        Label {
                            Text(section.category.title)
                        } icon: {
                            Image(systemSymbol: section.category.icon)
                        }
                        Spacer()
                        Text(section.formattedSize)
                            .monospacedDigit()
                    }
                } footer: {
                    Text(section.category.explanation)
                }
            }
        }
        .searchable(text: $viewModel.filter.searchTerm)
        .refreshable {
            await viewModel.load()
        }
        .task {
            await viewModel.load()
        }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Menu {
                    Picker(
                        L10n.Settings.Debugging.ManageStorage.Sort.title,
                        selection: $viewModel.sortOrder
                    ) {
                        ForEach(ManageStorageSortOrder.allCases) { order in
                            Text(order.title).tag(order)
                        }
                    }
                    Picker(
                        L10n.Settings.Debugging.ManageStorage.Filter.category,
                        selection: $viewModel.filter.category
                    ) {
                        Text(L10n.Settings.Debugging.ManageStorage.Filter.allCategories)
                            .tag(ManageStorageCategory?.none)
                        ForEach(viewModel.availableCategories) { category in
                            Text(category.title).tag(ManageStorageCategory?.some(category))
                        }
                    }
                    Toggle(isOn: $viewModel.filter.onlyDeletable) {
                        Text(L10n.Settings.Debugging.ManageStorage.Filter.onlyRemovable)
                    }
                } label: {
                    if viewModel.isLoading {
                        ProgressView()
                            .progressViewStyle(.circular)
                    } else {
                        Image(systemSymbol: .line3Horizontal)
                            .foregroundStyle(viewModel.filter.isActive ? Color.haPrimary : Color.accentColor)
                    }
                }
                .accessibilityLabel(L10n.Settings.Debugging.ManageStorage.Filter.title)
            }
        }
        .alert(
            L10n.errorLabel,
            isPresented: Binding(
                get: { viewModel.errorMessage != nil },
                set: { if !$0 { viewModel.errorMessage = nil } }
            )
        ) {
            Button(L10n.okLabel, role: .cancel) {}
        } message: {
            Text(viewModel.errorMessage ?? "")
        }
        .listTopContentMargin()
    }
}

#Preview {
    NavigationView {
        ManageStorageView(viewModel: ManageStorageViewModel(
            paths: .rooted(at: URL(fileURLWithPath: NSTemporaryDirectory())),
            isCatalyst: false,
            hasCompletedLegacyStoreMigration: true,
            measurer: ManageStorageSampleMeasurer(),
            cleaner: ManageStorageSampleCleaner()
        ))
    }
}
