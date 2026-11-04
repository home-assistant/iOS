import Shared
import SwiftUI
import UniformTypeIdentifiers

/// A server's client certificate for mutual TLS: what is installed and when it expires, with import
/// and removal.
struct ClientCertificateView: View {
    @ObservedObject var viewModel: ConnectionSettingsViewModel

    var body: some View {
        List {
            AppleLikeListTopRowHeader(
                image: .fileCertificateOutlineIcon,
                title: L10n.Settings.ConnectionSection.ClientCertificate.header,
                subtitle: L10n.Settings.ConnectionSection.ClientCertificate.footer
            )
            Section {
                if let certificate = viewModel.clientCertificate {
                    // Certificate is configured
                    HStack {
                        VStack(alignment: .leading, spacing: DesignSystem.Spaces.half) {
                            Text(certificate.displayName)
                                .font(.body)
                            if certificate.isExpired {
                                Text(L10n.Settings.ConnectionSection.ClientCertificate.expired)
                                    .font(.caption)
                                    .foregroundColor(.red)
                            } else if let expiresAt = certificate.expiresAt {
                                Text(L10n.Settings.ConnectionSection.ClientCertificate.expiresAt(expiresAt.formatted(
                                    date: .abbreviated,
                                    time: .omitted
                                )))
                                .font(.caption)
                                .foregroundColor(.secondary)
                            }
                        }
                        Spacer()
                        Button(role: .destructive) {
                            viewModel.isRemoveCertificateConfirmationPresented = true
                        } label: {
                            Image(systemSymbol: .trash)
                        }
                        .confirmationDialog(
                            L10n.Settings.ConnectionSection.ClientCertificate.RemoveConfirmation.title,
                            isPresented: $viewModel.isRemoveCertificateConfirmationPresented,
                            titleVisibility: .visible
                        ) {
                            Button(
                                L10n.Settings.ConnectionSection.ClientCertificate.RemoveConfirmation.remove,
                                role: .destructive,
                                action: viewModel.removeCertificate
                            )
                            Button(L10n.cancelLabel, role: .cancel) {}
                        } message: {
                            Text(L10n.Settings.ConnectionSection.ClientCertificate.RemoveConfirmation.message)
                        }
                    }
                } else {
                    // No certificate configured
                    Button {
                        viewModel.isCertificateImporterPresented = true
                    } label: {
                        if viewModel.isImportingCertificate {
                            HStack {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle())
                                Text(L10n.Settings.ConnectionSection.ClientCertificate.importing)
                            }
                        } else {
                            Label(L10n.Settings.ConnectionSection.ClientCertificate.import, systemSymbol: .plusCircle)
                        }
                    }
                    .disabled(viewModel.isImportingCertificate)
                }
            }
        }
        .fileImporter(
            isPresented: $viewModel.isCertificateImporterPresented,
            allowedContentTypes: ClientCertificateFile.allowedFormats,
            allowsMultipleSelection: false,
            onCompletion: viewModel.handleCertificatePick
        )
        .alert(
            L10n.Settings.ConnectionSection.ClientCertificate.PasswordPrompt.title,
            isPresented: $viewModel.isCertificatePasswordPromptPresented
        ) {
            SecureField(
                L10n.Settings.ConnectionSection.ClientCertificate.PasswordPrompt.placeholder,
                text: $viewModel.certificatePassword
            )
            Button(L10n.cancelLabel, role: .cancel, action: viewModel.cancelCertificateImport)
            Button(L10n.Settings.ConnectionSection.ClientCertificate.PasswordPrompt.importButton) {
                Task { await viewModel.confirmCertificateImport() }
            }
        } message: {
            Text(L10n.Settings.ConnectionSection.ClientCertificate.PasswordPrompt.message)
        }
        .alert(
            L10n.Settings.ConnectionSection.ClientCertificate.ImportError.title,
            isPresented: Binding(
                get: { viewModel.certificateError != nil },
                set: { if !$0 { viewModel.certificateError = nil } }
            ),
            presenting: viewModel.certificateError
        ) { _ in
            Button(L10n.okLabel, role: .cancel) {}
        } message: { error in
            Text(error.localizedDescription)
        }
    }
}

#Preview {
    NavigationView {
        ClientCertificateView(viewModel: ConnectionSettingsViewModel(server: ServerFixture.standard))
    }
    .navigationViewStyle(.stack)
}
