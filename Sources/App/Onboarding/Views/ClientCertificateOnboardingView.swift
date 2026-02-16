import Shared
import SwiftUI
import UniformTypeIdentifiers

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
        VStack(spacing: 24) {
            Spacer()
            
            Image(systemName: "lock.shield")
                .font(.system(size: 64))
                .foregroundColor(.accentColor)
            
            Text("Client Certificate Required")
                .font(.title)
                .fontWeight(.bold)
            
            Text("This server requires a client certificate (mTLS) for authentication. Please import your certificate file (.p12 or .pfx).")
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
            
            Spacer()
            
            VStack(spacing: 12) {
                Button {
                    showFilePicker = true
                } label: {
                    HStack {
                        Image(systemName: "doc.badge.plus")
                        Text("Select Certificate File")
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.primaryButton)
                .disabled(isImporting)
                
                Button("Cancel", role: .cancel) {
                    onCancel()
                }
                .buttonStyle(.secondaryButton)
            }
            .padding(.horizontal)
            .padding(.bottom, 32)
        }
        .fileImporter(
            isPresented: $showFilePicker,
            allowedContentTypes: [
                UTType(filenameExtension: "p12") ?? .data,
                UTType(filenameExtension: "pfx") ?? .data,
                .pkcs12
            ],
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case .success(let urls):
                if let url = urls.first {
                    pendingFileURL = url
                    showPasswordPrompt = true
                }
            case .failure(let error):
                errorMessage = error.localizedDescription
            }
        }
        .alert("Certificate Password", isPresented: $showPasswordPrompt) {
            SecureField("Password", text: $password)
            Button("Import") {
                importCertificate()
            }
            Button("Cancel", role: .cancel) {
                password = ""
                pendingFileURL = nil
            }
        } message: {
            Text("Enter the password for this certificate")
        }
    }
    
    private func importCertificate() {
        guard let fileURL = pendingFileURL else { return }
        
        isImporting = true
        errorMessage = nil
        
        // Access security-scoped resource
        guard fileURL.startAccessingSecurityScopedResource() else {
            errorMessage = "Unable to access the selected file"
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
