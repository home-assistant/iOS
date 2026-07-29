import SFSafeSymbols
import Shared
import SwiftUI
import UniformTypeIdentifiers

/// Settings › Debugging › Import/Export configuration.
///
/// The list doubles as the disclosure of the export's contents: every category that travels in the
/// file is spelled out with what it holds and how much of it exists on this device, followed by an
/// explicit list of what is never exported (credentials, cached server data, diagnostics).
struct ImportExportConfigurationView: View {
    /// One line of the "never included" disclosure.
    private struct ExcludedItem: Identifiable {
        let id: String
        let symbol: SFSymbol
        let title: String
    }

    @StateObject private var viewModel = ImportExportConfigurationViewModel()

    var body: some View {
        List {
            AppleLikeListTopRowHeader(
                image: .swapHorizontalIcon,
                title: L10n.Settings.Debugging.ConfigurationTransfer.Header.title,
                subtitle: L10n.Settings.Debugging.ConfigurationTransfer.Header.subtitle
            )

            Section {
                ForEach(AppConfigurationCategory.allCases) { category in
                    HStack(alignment: .top, spacing: DesignSystem.Spaces.two) {
                        Image(systemSymbol: category.icon)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 18, height: 18, alignment: .center)
                            .foregroundStyle(Color.haPrimary)
                            .padding(.top, DesignSystem.Spaces.half)
                        VStack(alignment: .leading, spacing: DesignSystem.Spaces.half) {
                            Text(category.title)
                            Text(category.explanation)
                                .font(.footnote)
                                .foregroundStyle(Color(uiColor: .secondaryLabel))
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        Text(stateLabel(for: category))
                            .font(.footnote)
                            .foregroundStyle(Color(uiColor: .secondaryLabel))
                            .padding(.top, DesignSystem.Spaces.half)
                    }
                }
            } header: {
                Text(L10n.Settings.Debugging.ConfigurationTransfer.Contents.header)
            } footer: {
                Text(L10n.Settings.Debugging.ConfigurationTransfer.Contents.footer)
            }

            Section {
                ForEach(Self.excludedItems) { item in
                    HStack(spacing: DesignSystem.Spaces.two) {
                        Image(systemSymbol: item.symbol)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 18, height: 18, alignment: .center)
                            .foregroundStyle(Color(uiColor: .secondaryLabel))
                        Text(item.title)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            } header: {
                Text(L10n.Settings.Debugging.ConfigurationTransfer.Excluded.header)
            } footer: {
                Text(L10n.Settings.Debugging.ConfigurationTransfer.Excluded.footer)
            }

            Section {
                HStack(spacing: DesignSystem.Spaces.two) {
                    Button {
                        viewModel.export()
                    } label: {
                        Label(
                            L10n.Settings.Debugging.ConfigurationTransfer.Export.button,
                            systemSymbol: .squareAndArrowUp
                        )
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.outlinedButton)
                    .disabled(viewModel.isBusy)

                    Button {
                        viewModel.startImport()
                    } label: {
                        Label(
                            L10n.Settings.Debugging.ConfigurationTransfer.Import.button,
                            systemSymbol: .squareAndArrowDown
                        )
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.outlinedButton)
                    .disabled(viewModel.isBusy)
                    .fileImporter(
                        isPresented: $viewModel.showImporter,
                        allowedContentTypes: [.json],
                        allowsMultipleSelection: false
                    ) { result in
                        viewModel.handleFileSelection(result)
                    }
                    .alert(
                        L10n.Settings.Debugging.ConfigurationTransfer.Import.Confirmation.title,
                        isPresented: $viewModel.showImportConfirmation
                    ) {
                        Button(L10n.cancelLabel, role: .cancel) {
                            viewModel.cancelImport()
                        }
                        Button(
                            L10n.Settings.Debugging.ConfigurationTransfer.Import.Confirmation.button,
                            role: .destructive
                        ) {
                            Task { await viewModel.confirmImport() }
                        }
                    } message: {
                        Text(
                            L10n.Settings.Debugging.ConfigurationTransfer.Import.Confirmation
                                .message(viewModel.pendingImportFilename, viewModel.pendingImportSummary)
                        )
                    }
                }
                .listRowInsets(EdgeInsets())
                .listRowBackground(Color.clear)
            } footer: {
                Text(L10n.Settings.Debugging.ConfigurationTransfer.Actions.footer)
            }
        }
        .navigationTitle(L10n.Settings.Debugging.ConfigurationTransfer.title)
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $viewModel.shareWrapper) { wrapper in
            ActivityViewController(shareWrapper: wrapper)
        }
        .alert(L10n.errorLabel, isPresented: Binding(
            get: { viewModel.errorMessage != nil },
            set: { if !$0 { viewModel.errorMessage = nil } }
        )) {
            Button(L10n.okLabel, role: .cancel) {}
        } message: {
            Text(viewModel.errorMessage.orEmpty)
        }
        .onAppear {
            viewModel.refreshEntryCounts()
        }
    }

    /// Data the app never writes into an export file, listed so the user can share the file knowing
    /// no credentials or personal history travel with it.
    private static var excludedItems: [ExcludedItem] {
        [
            ExcludedItem(
                id: "credentials",
                symbol: .key,
                title: L10n.Settings.Debugging.ConfigurationTransfer.Excluded.credentials
            ),
            ExcludedItem(
                id: "cachedData",
                symbol: .tablecells,
                title: L10n.Settings.Debugging.ConfigurationTransfer.Excluded.cachedData
            ),
            ExcludedItem(
                id: "diagnostics",
                symbol: .docTextFill,
                title: L10n.Settings.Debugging.ConfigurationTransfer.Excluded.diagnostics
            ),
        ]
    }

    private func stateLabel(for category: AppConfigurationCategory) -> String {
        let count = viewModel.entryCount(for: category)
        guard count > 0 else {
            return L10n.Settings.Debugging.ConfigurationTransfer.State.notConfigured
        }
        if category.isSingleValue {
            return L10n.Settings.Debugging.ConfigurationTransfer.State.included
        }
        return L10n.Settings.Debugging.ConfigurationTransfer.State.itemCount(count)
    }
}

#Preview {
    NavigationView {
        ImportExportConfigurationView()
    }
}
