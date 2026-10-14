import Shared
import SwiftUI
import UniformTypeIdentifiers

/// A server's client certificate for mutual TLS: what is installed and when it expires, with import
/// and removal.
struct ClientCertificateView: View {
    @ObservedObject var viewModel: ConnectionSettingsViewModel
    @State private var showCertificateImporter = false
    @State private var showCertificatePasswordPrompt = false
    @State private var certificatePassword = ""
    @State private var pendingCertificateURL: URL?
    @State private var showRemoveCertificateConfirmation = false

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
                            showRemoveCertificateConfirmation = true
                        } label: {
                            Image(systemSymbol: .trash)
                        }
                        .confirmationDialog(
                            L10n.Settings.ConnectionSection.ClientCertificate.RemoveConfirmation.title,
                            isPresented: $showRemoveCertificateConfirmation,
                            titleVisibility: .visible
                        ) {
                            Button(
                                L10n.Settings.ConnectionSection.ClientCertificate.RemoveConfirmation.remove,
                                role: .destructive
                            ) {
                                viewModel.removeCertificate()
                            }
                            Button(L10n.cancelLabel, role: .cancel) {}
                        } message: {
                            Text(L10n.Settings.ConnectionSection.ClientCertificate.RemoveConfirmation.message)
                        }
                    }
                } else {
                    // No certificate configured
                    Button {
                        showCertificateImporter = true
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
            isPresented: $showCertificateImporter,
            allowedContentTypes: ClientCertificateFile.allowedFormats,
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case let .success(urls):
                if let url = urls.first {
                    pendingCertificateURL = url
                    showCertificatePasswordPrompt = true
                }
            case let .failure(error):
                Current.Log.error("Failed to select certificate file: \(error)")
            }
        }
        .alert(
            L10n.Settings.ConnectionSection.ClientCertificate.PasswordPrompt.title,
            isPresented: $showCertificatePasswordPrompt
        ) {
            SecureField(
                L10n.Settings.ConnectionSection.ClientCertificate.PasswordPrompt.placeholder,
                text: $certificatePassword
            )
            Button(L10n.cancelLabel, role: .cancel) {
                certificatePassword = ""
                pendingCertificateURL = nil
            }
            Button(L10n.Settings.ConnectionSection.ClientCertificate.PasswordPrompt.importButton) {
                if let url = pendingCertificateURL {
                    Task {
                        await viewModel.importCertificate(from: url, password: certificatePassword)
                        certificatePassword = ""
                        pendingCertificateURL = nil
                    }
                }
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
