import SFSafeSymbols
import Shared
import SwiftUI

/// Confirmation screen shown when the user opens a server-configuration file. It never imports
/// silently: it lists every server the file describes, says which will be added automatically (the
/// file carried a working token) versus which need a sign-in, flags duplicates, and waits for an
/// explicit confirm. This is the security boundary for "a file just told the app to add servers."
///
/// While the import runs the screen can't be closed, by its button or by a swipe. Guided sign-in only
/// starts from the results screen's Continue button, so the results stay readable first.
struct ServerConfigurationImportView: View {
    @StateObject var viewModel: ServerConfigurationImportViewModel

    var body: some View {
        NavigationView {
            content
                .navigationBarTitleDisplayMode(.inline)
                .navigationTitle(Text(L10n.ImportServers.title))
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        CloseButton {
                            viewModel.close()
                        }
                        .disabled(viewModel.isImporting)
                    }
                }
        }
        .navigationViewStyle(.stack)
        .interactiveDismissDisabled(viewModel.isImporting)
    }

    @ViewBuilder
    private var content: some View {
        switch viewModel.phase {
        case .confirming:
            confirmingList
        case .importing:
            importingProgress
        case let .finished(summary):
            finishedList(summary: summary)
        }
    }

    // MARK: - Confirming

    private var confirmingList: some View {
        List {
            Section {
                Text(L10n.ImportServers.Confirm.intro(viewModel.document.servers.count))
                    .font(.footnote)
                    .foregroundStyle(Color(uiColor: .secondaryLabel))
            }

            Section {
                ForEach(Array(viewModel.outcomes.enumerated()), id: \.offset) { _, outcome in
                    row(for: outcome)
                }
            } header: {
                Text(L10n.ImportServers.Confirm.sectionHeader)
            } footer: {
                Text(L10n.ImportServers.Confirm.sectionFooter)
            }

            Section {
                Button {
                    viewModel.confirm()
                } label: {
                    Text(confirmButtonTitle)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.outlinedButton)
                .disabled(!viewModel.hasActionableServers)

                Button(role: .cancel) {
                    viewModel.close()
                } label: {
                    Text(L10n.ImportServers.Confirm.cancel)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.outlinedButton)
            } footer: {
                if !viewModel.hasActionableServers {
                    Text(L10n.ImportServers.Confirm.allDuplicates)
                        .font(.footnote)
                        .foregroundStyle(Color(uiColor: .secondaryLabel))
                }
            }
        }
    }

    /// The confirm button's label reflects what the run will do: add (token servers only), sign in
    /// (token-less only), or both.
    private var confirmButtonTitle: String {
        if viewModel.automaticCount > 0, viewModel.guidedCount > 0 {
            return L10n.ImportServers.Confirm.addAndSignIn
        }
        if viewModel.guidedCount > 0 {
            return L10n.ImportServers.Confirm.signInServers
        }
        return L10n.ImportServers.Confirm.addServers
    }

    private func row(for outcome: ServerConfigurationImport.ServerOutcome) -> some View {
        HStack(alignment: .top, spacing: DesignSystem.Spaces.two) {
            Image(systemSymbol: symbol(for: outcome.classification))
                .foregroundStyle(tint(for: outcome.classification))
                .frame(width: 22)
                .padding(.top, 2)
            VStack(alignment: .leading, spacing: 2) {
                Text(verbatim: outcome.entry.name)
                Text(verbatim: outcome.entry.externalURL.absoluteString)
                    .font(.footnote)
                    .foregroundStyle(Color(uiColor: .secondaryLabel))
                Text(label(for: outcome.classification))
                    .font(.caption)
                    .foregroundStyle(tint(for: outcome.classification))
            }
            Spacer(minLength: 0)
        }
    }

    // MARK: - Importing

    private var importingProgress: some View {
        VStack(spacing: DesignSystem.Spaces.two) {
            ProgressView()
            Text(L10n.ImportServers.importing)
                .foregroundStyle(Color(uiColor: .secondaryLabel))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Finished

    private func finishedList(summary: ServerConfigurationImportViewModel.Summary) -> some View {
        List {
            Section {
                Text(verbatim: summaryHeadline(summary))
            }
            Section {
                ForEach(Array(viewModel.outcomes.enumerated()), id: \.offset) { _, outcome in
                    resultRow(for: outcome)
                }
            } header: {
                Text(L10n.ImportServers.Results.header)
            } footer: {
                if summary.guidedRemaining > 0 {
                    Text(L10n.ImportServers.Results.footer)
                        .font(.footnote)
                        .foregroundStyle(Color(uiColor: .secondaryLabel))
                }
            }
            Section {
                if summary.guidedRemaining > 0 {
                    Button {
                        viewModel.continueToGuidedSignIn()
                    } label: {
                        Text(L10n.ImportServers.Results.continueToSignIn(summary.guidedRemaining))
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.outlinedButton)
                }
                Button {
                    viewModel.close()
                } label: {
                    Text(summary.guidedRemaining > 0 ? L10n.ImportServers.Results.skipSignIn : L10n.ImportServers.done)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.outlinedButton)
            }
        }
    }

    private func summaryHeadline(_ summary: ServerConfigurationImportViewModel.Summary) -> String {
        var parts: [String] = []
        if summary.added > 0 { parts.append(L10n.ImportServers.Summary.added(summary.added)) }
        if summary.guidedRemaining > 0 { parts.append(L10n.ImportServers.Summary.needsSignIn(summary.guidedRemaining)) }
        if summary.skipped > 0 { parts.append(L10n.ImportServers.Summary.skipped(summary.skipped)) }
        if summary.failed > 0 { parts.append(L10n.ImportServers.Summary.failed(summary.failed)) }
        return parts.isEmpty ? L10n.ImportServers.Summary.empty : parts.joined(separator: ", ") + "."
    }

    private func resultRow(for outcome: ServerConfigurationImport.ServerOutcome) -> some View {
        HStack(alignment: .top, spacing: DesignSystem.Spaces.two) {
            Image(systemSymbol: resultSymbol(outcome.result))
                .foregroundStyle(resultTint(outcome.result))
                .frame(width: 22)
                .padding(.top, 2)
            VStack(alignment: .leading, spacing: 2) {
                Text(verbatim: outcome.entry.name)
                Text(verbatim: resultLabel(outcome.result))
                    .font(.caption)
                    .foregroundStyle(resultTint(outcome.result))
            }
            Spacer(minLength: 0)
        }
    }

    private func resultSymbol(_ result: ServerConfigurationImport.ServerOutcome.Result) -> SFSymbol {
        switch result {
        case .added: return .checkmarkCircleFill
        case .awaitingGuidedSignIn: return .lockShield
        case .skipped: return .minusCircle
        case .failed: return .exclamationmarkTriangleFill
        case .pending: return .clock
        }
    }

    private func resultTint(_ result: ServerConfigurationImport.ServerOutcome.Result) -> Color {
        switch result {
        case .added: return .green
        case .awaitingGuidedSignIn: return Color(uiColor: .label)
        case .skipped: return Color(uiColor: .secondaryLabel)
        case .failed: return .red
        case .pending: return Color(uiColor: .secondaryLabel)
        }
    }

    private func resultLabel(_ result: ServerConfigurationImport.ServerOutcome.Result) -> String {
        switch result {
        case .added: return L10n.ImportServers.Result.added
        case .awaitingGuidedSignIn: return L10n.ImportServers.Result.guided
        case let .skipped(reason): return L10n.ImportServers.Result.skipped(reason)
        case let .failed(reason): return L10n.ImportServers.Result.failed(reason)
        case .pending: return L10n.ImportServers.Result.pending
        }
    }

    // MARK: - Classification presentation

    private func symbol(for classification: ServerConfigurationImport.ServerOutcome.Classification) -> SFSymbol {
        switch classification {
        case .automatic: return .boltFill
        case .guided: return .lockShield
        case .duplicate: return .checkmarkCircleFill
        case .repeatedInFile: return .docOnDoc
        }
    }

    private func tint(for classification: ServerConfigurationImport.ServerOutcome.Classification) -> Color {
        switch classification {
        case .automatic: return .haPrimary
        case .guided: return Color(uiColor: .label)
        case .duplicate, .repeatedInFile: return Color(uiColor: .secondaryLabel)
        }
    }

    private func label(for classification: ServerConfigurationImport.ServerOutcome.Classification) -> String {
        switch classification {
        case .automatic: return L10n.ImportServers.Classification.automatic
        case .guided: return L10n.ImportServers.Classification.guided
        case let .duplicate(existingName): return L10n.ImportServers.Classification.duplicate(existingName)
        case let .repeatedInFile(firstName): return L10n.ImportServers.Classification.repeatedInFile(firstName)
        }
    }
}

#Preview {
    if let document = try? ServerConfigurationImport.decode(data: Data("""
    {
      "kind": "home-assistant-servers",
      "schemaVersion": 1,
      "servers": [
        { "name": "Home", "externalURL": "https://home.example.com", "longLivedAccessToken": "token" },
        { "name": "Cabin", "externalURL": "https://cabin.example.com" },
        { "name": "Cabin again", "externalURL": "https://cabin.example.com" }
      ]
    }
    """.utf8)) {
        ServerConfigurationImportView(viewModel: ServerConfigurationImportViewModel(document: document))
    }
}
