import Shared
import SwiftUI
import UniformTypeIdentifiers

enum ClientCertificateFile {
    static var allowedFormats: [UTType] = [
        UTType(filenameExtension: "p12") ?? .data,
        UTType(filenameExtension: "pfx") ?? .data,
        .pkcs12,
    ]
}

/// View for importing client certificate during onboarding
struct ClientCertificateOnboardingView: View {
    let onImport: (ClientCertificate) -> Void
    let onCancel: () -> Void

    @State private var showFilePicker = false
    @State private var showPasswordPrompt = false
    @State private var password = ""
    @State private var pendingFileURL: URL?
    @State private var isImporting = false
    @State private var errorMessage: String?

    var body: some View {
        VStack(spacing: DesignSystem.Spaces.two) {
            Spacer()
            headerView
            ExperimentalBadge()
            Spacer()
        }
        .safeAreaInset(edge: .bottom, content: {
            buttons
        })
        .fileImporter(
            isPresented: $showFilePicker,
            allowedContentTypes: ClientCertificateFile.allowedFormats,
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case let .success(urls):
                if let url = urls.first {
                    pendingFileURL = url
                    showPasswordPrompt = true
                }
            case let .failure(error):
                errorMessage = error.localizedDescription
            }
        }
        .alert(L10n.Onboarding.ClientCertificate.PasswordPrompt.title, isPresented: $showPasswordPrompt) {
            SecureField(L10n.Onboarding.ClientCertificate.PasswordPrompt.placeholder, text: $password)
            Button(L10n.Onboarding.ClientCertificate.PasswordPrompt.importButton) {
                importCertificate()
            }
            Button(L10n.cancelLabel, role: .cancel) {
                password = ""
                pendingFileURL = nil
            }
        } message: {
            Text(L10n.Onboarding.ClientCertificate.PasswordPrompt.message)
        }
    }

    private var buttons: some View {
        VStack(spacing: DesignSystem.Spaces.oneAndHalf) {
            Button {
                showFilePicker = true
            } label: {
                HStack {
                    Image(systemSymbol: .docBadgePlus)
                    Text(L10n.Onboarding.ClientCertificate.selectFileButton)
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.primaryButton)
            .disabled(isImporting)

            Button(L10n.cancelLabel, role: .cancel) {
                onCancel()
            }
            .buttonStyle(.secondaryButton)
        }
        .padding(.horizontal)
    }

    @ViewBuilder
    private var headerView: some View {
        Image(systemSymbol: .lockShield)
            .font(.system(size: 64))
            .foregroundColor(.accentColor)

        Text(L10n.Onboarding.ClientCertificate.title)
            .font(.title)
            .fontWeight(.bold)

        Text(L10n.Onboarding.ClientCertificate.description)
            .font(.body)
            .foregroundColor(.secondary)
            .multilineTextAlignment(.center)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.horizontal)

        if let error = errorMessage {
            Text(error)
                .font(.callout)
                .foregroundColor(.red)
                .padding()
                .background(Color.red.opacity(0.1))
                .cornerRadius(8)
        }
    }

    private func importCertificate() {
        guard let fileURL = pendingFileURL else { return }

        isImporting = true
        errorMessage = nil

        // Access security-scoped resource
        guard fileURL.startAccessingSecurityScopedResource() else {
            errorMessage = L10n.Onboarding.ClientCertificate.Error.fileAccess
            isImporting = false
            return
        }

        defer {
            fileURL.stopAccessingSecurityScopedResource()
        }

        do {
            let data = try Data(contentsOf: fileURL)
            let identifier = UUID().uuidString
            let certificate = try ClientCertificateManager.shared.importP12(
                data: data,
                password: password,
                identifier: identifier
            )

            password = ""
            pendingFileURL = nil
            isImporting = false

            onImport(certificate)
        } catch {
            password = ""
            isImporting = false

            if let certError = error as? ClientCertificateError {
                errorMessage = certError.localizedDescription
            } else {
                errorMessage = error.localizedDescription
            }
        }
    }
}

@available(iOS 16.0, *)
#Preview {
    VStack {}
        .sheet(isPresented: .constant(true)) {
            ClientCertificateOnboardingView(onImport: { cert in
                print("Imported certificate: \(cert)")
            }, onCancel: {
                print("Import cancelled")
            })
            .presentationDetents([.medium])
        }
}
