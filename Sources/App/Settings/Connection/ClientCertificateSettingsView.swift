import Shared
import SwiftUI
import UniformTypeIdentifiers

struct ClientCertificateSettingsView: View {
    let server: Server
    @State private var certificates: [ClientCertificate] = []
    @State private var selectedCertificate: ClientCertificate?
    @State private var showingImport = false
    @State private var importData: Data?
    @State private var importName = ""
    @State private var importPassword = ""
    @State private var showingPasswordSheet = false
    @State private var importError: String?

    init(server: Server) {
        self.server = server
        self._selectedCertificate = State(initialValue: server.info.connection.clientCertificate)
    }

    var body: some View {
        List {
            certificateSection
            if selectedCertificate != nil {
                selectedCertificateSection
            }
        }
        .navigationTitle(L10n.Settings.ConnectionSection.ClientCertificate.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    showingImport = true
                } label: {
                    Image(systemSymbol: .plus)
                }
            }
        }
        .fileImporter(
            isPresented: $showingImport,
            allowedContentTypes: [UTType.pkcs12],
            allowsMultipleSelection: false
        ) { result in
            handleFileImport(result)
        }
        .sheet(isPresented: $showingPasswordSheet) {
            passwordSheet
        }
        .onAppear {
            loadCertificates()
        }
    }

    private var certificateSection: some View {
        Section {
            if certificates.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text(L10n.Settings.ConnectionSection.ClientCertificate.noCertificates)
                        .foregroundStyle(.secondary)
                    Text(L10n.Settings.ConnectionSection.ClientCertificate.importInstructions)
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
            } else {
                noneOption
                ForEach(certificates, id: \.name) { cert in
                    certificateRow(for: cert)
                }
                .onDelete { indexSet in
                    deleteCertificates(at: indexSet)
                }
            }
        } header: {
            Text(L10n.Settings.ConnectionSection.ClientCertificate.title)
        }
    }

    private var selectedCertificateSection: some View {
        Section {
            if let cert = selectedCertificate {
                HStack {
                    Text(L10n.Settings.ConnectionSection.ClientCertificate.Details.name)
                    Spacer()
                    Text(cert.name)
                        .foregroundStyle(.secondary)
                }
            }
        } header: {
            Text(L10n.Settings.ConnectionSection.ClientCertificate.Details.header)
        }
    }

    private var noneOption: some View {
        Button {
            selectCertificate(nil)
        } label: {
            HStack {
                Text(L10n.Settings.ConnectionSection.ClientCertificate.none)
                Spacer()
                if selectedCertificate == nil {
                    Image(systemSymbol: .checkmark)
                        .foregroundStyle(.tint)
                }
            }
        }
        .foregroundStyle(.primary)
    }

    private func certificateRow(for cert: ClientCertificate) -> some View {
        Button {
            selectCertificate(cert)
        } label: {
            HStack {
                Text(cert.name)
                Spacer()
                if selectedCertificate?.name == cert.name {
                    Image(systemSymbol: .checkmark)
                        .foregroundStyle(.tint)
                }
            }
        }
        .foregroundStyle(.primary)
    }

    private var passwordSheet: some View {
        NavigationView {
            Form {
                Section {
                    TextField(
                        L10n.Settings.ConnectionSection.ClientCertificate.Import.name,
                        text: $importName
                    )
                    SecureField(
                        L10n.Settings.ConnectionSection.ClientCertificate.Import.password,
                        text: $importPassword
                    )
                } footer: {
                    if let error = importError {
                        Text(error)
                            .foregroundStyle(.red)
                    }
                }

                Section {
                    Button(L10n.Settings.ConnectionSection.ClientCertificate.Import.importButton) {
                        performImport()
                    }
                    .disabled(importName.isEmpty)
                }
            }
            .navigationTitle(L10n.Settings.ConnectionSection.ClientCertificate.Import.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L10n.Settings.ConnectionSection.ClientCertificate.Import.cancel) {
                        resetImportState()
                    }
                }
            }
        }
    }

    private func handleFileImport(_ result: Result<[URL], Error>) {
        do {
            guard let selectedFile = try result.get().first else { return }
            guard selectedFile.startAccessingSecurityScopedResource() else {
                Current.Log.error("Cannot access security scoped resource")
                return
            }
            defer { selectedFile.stopAccessingSecurityScopedResource() }

            importData = try Data(contentsOf: selectedFile)
            importName = selectedFile.deletingPathExtension().lastPathComponent
            importPassword = ""
            importError = nil
            showingPasswordSheet = true
        } catch {
            Current.Log.error("Error importing file: \(error)")
        }
    }

    private func performImport() {
        guard let data = importData else { return }

        do {
            try ClientCertificateManager.shared.importP12(
                data: data,
                password: importPassword,
                name: importName
            )
            resetImportState()
            loadCertificates()
        } catch let error as ClientCertificateError {
            importError = error.localizedDescription
        } catch {
            importError = error.localizedDescription
        }
    }

    private func resetImportState() {
        showingPasswordSheet = false
        importData = nil
        importName = ""
        importPassword = ""
        importError = nil
    }

    private func loadCertificates() {
        certificates = ClientCertificateManager.shared.availableCertificates()
    }

    private func selectCertificate(_ certificate: ClientCertificate?) {
        selectedCertificate = certificate
        server.update { info in
            info.connection.clientCertificate = certificate
        }
    }

    private func deleteCertificates(at indexSet: IndexSet) {
        for index in indexSet {
            let cert = certificates[index]
            do {
                try ClientCertificateManager.shared.deleteIdentity(name: cert.name)
                if selectedCertificate?.name == cert.name {
                    selectCertificate(nil)
                }
            } catch {
                Current.Log.error("Error deleting certificate: \(error)")
            }
        }
        loadCertificates()
    }
}
