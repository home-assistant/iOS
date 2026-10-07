import SFSafeSymbols
import Shared
import SwiftUI
import UIKit
import UniformTypeIdentifiers

struct DebugDatabaseTransferSection: View {
    let part: DebugDatabaseTransfer.Part
    let onImportComplete: () -> Void

    @State private var shareWrapper: ShareWrapper?
    @State private var pendingImportURL: URL?
    @State private var isExporting = false
    @State private var isImporting = false
    @State private var hasExportableContent = false
    @State private var showImporter = false
    @State private var showImportAlert = false
    @State private var errorMessage: String?

    init(part: DebugDatabaseTransfer.Part, onImportComplete: @escaping () -> Void = {}) {
        self.part = part
        self.onImportComplete = onImportComplete
    }

    var body: some View {
        Section {
            HStack(spacing: DesignSystem.Spaces.two) {
                Button {
                    Current.impactFeedback.impactOccurred(style: .light)
                    Task {
                        await exportDatabasePart()
                    }
                } label: {
                    Label(
                        L10n.Settings.Debugging.DatabaseTransfer.Export.title,
                        systemSymbol: .squareAndArrowUp
                    )
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.outlinedButton)
                .disabled(isExporting || isImporting || !hasExportableContent)

                Button {
                    Current.impactFeedback.impactOccurred(style: .light)
                    showImporter = true
                } label: {
                    Label(
                        L10n.Settings.Debugging.DatabaseTransfer.Import.title,
                        systemSymbol: .squareAndArrowDown
                    )
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.outlinedButton)
                .disabled(isExporting || isImporting)
            }
            .listRowInsets(EdgeInsets())
            .listRowBackground(Color.clear)
        } footer: {
            Text(L10n.Settings.Debugging.DatabaseTransfer.footer(part.title))
        }
        .sheet(item: $shareWrapper) { wrapper in
            ActivityViewController(shareWrapper: wrapper)
        }
        .fileImporter(
            isPresented: $showImporter,
            allowedContentTypes: [.json],
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case let .success(urls):
                guard let url = urls.first else {
                    Current.Log.info("Debug database import file picker returned no file for \(part.rawValue)")
                    return
                }
                Current.Log.info("Selected debug database import file for \(part.rawValue): \(url.lastPathComponent)")
                do {
                    try DebugDatabaseTransfer.validateImportFile(from: url, part: part)
                    Current.Log.info("Presenting debug database import confirmation for \(part.rawValue)")
                    pendingImportURL = url
                    showImportAlert = true
                } catch {
                    Current.Log.error(
                        "Debug database import file validation failed for \(part.rawValue): \(error.localizedDescription)"
                    )
                    playImportFailureHaptic()
                    pendingImportURL = nil
                    showError(error)
                }
            case let .failure(error):
                Current.Log
                    .error(
                        "Debug database import file picker failed for \(part.rawValue): \(error.localizedDescription)"
                    )
                playImportFailureHaptic()
                showError(error)
            }
        }
        .alert(
            L10n.Settings.Debugging.DatabaseTransfer.Import.Confirmation.title(part.title),
            isPresented: $showImportAlert
        ) {
            Button(L10n.cancelLabel, role: .cancel) {
                Current.Log.info("Cancelled debug database import confirmation for \(part.rawValue)")
                pendingImportURL = nil
            }
            Button(L10n.Settings.Debugging.DatabaseTransfer.Import.Confirmation.button, role: .destructive) {
                Current.impactFeedback.impactOccurred(style: .light)
                Current.Log.info("Confirmed debug database import for \(part.rawValue)")
                Task {
                    await importDatabasePart()
                }
            }
        } message: {
            Text(L10n.Settings.Debugging.DatabaseTransfer.Import.Confirmation.message(part.title))
        }
        .alert(L10n.errorLabel, isPresented: Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )) {
            Button(L10n.okLabel, role: .cancel) {}
        } message: {
            Text(errorMessage.orEmpty)
        }
        .task {
            refreshExportAvailability()
        }
    }

    private func exportDatabasePart() async {
        isExporting = true
        do {
            let url = try DebugDatabaseTransfer.exportURL(part: part)
            shareWrapper = ShareWrapper(url: url)
        } catch {
            showError(error)
        }
        isExporting = false
    }

    private func importDatabasePart() async {
        guard let pendingImportURL else { return }
        isImporting = true
        showProgressToast(title: L10n.Settings.Debugging.DatabaseTransfer.Import.Progress.title(part.title))
        do {
            let summary = try await DebugDatabaseTransfer.importPayload(from: pendingImportURL, part: part)
            self.pendingImportURL = nil
            playImportSuccessHaptic()
            DispatchQueue.main.async {
                onImportComplete()
            }
            refreshExportAvailability()
            showSuccessToast(
                title: L10n.Settings.Debugging.DatabaseTransfer.Import.Success.title,
                message: L10n.Settings.Debugging.DatabaseTransfer.Import.Success.message(summary.totalRecords)
            )
        } catch {
            playImportFailureHaptic()
            showError(error)
        }
        isImporting = false
    }

    private func showError(_ error: Error) {
        Current.Log.error("Debug database transfer failed for \(part.rawValue): \(error.localizedDescription)")
        errorMessage = error.localizedDescription
        showFailureToast(
            title: L10n.Settings.Debugging.DatabaseTransfer.Error.title,
            message: error.localizedDescription
        )
    }

    private func refreshExportAvailability() {
        do {
            hasExportableContent = try DebugDatabaseTransfer.hasExportableContent(part: part)
            Current.Log.info("Export availability for \(part.rawValue): \(hasExportableContent)")
        } catch {
            Current.Log
                .error("Failed to refresh export availability for \(part.rawValue): \(error.localizedDescription)")
            hasExportableContent = false
        }
    }

    private func playImportSuccessHaptic() {
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }

    private func playImportFailureHaptic() {
        UINotificationFeedbackGenerator().notificationOccurred(.error)
    }

    private func showProgressToast(title: String) {
        if #available(iOS 18, *) {
            ToastPresenter.shared.show(
                id: "debug-database-transfer-\(part.rawValue)",
                symbol: .arrowClockwise,
                symbolForegroundStyle: (.white, .haPrimary),
                title: title
            )
        }
    }

    private func showSuccessToast(title: String, message: String) {
        if #available(iOS 18, *) {
            ToastPresenter.shared.show(
                id: "debug-database-transfer-\(part.rawValue)",
                symbol: .checkmarkSealFill,
                symbolForegroundStyle: (.white, .green),
                title: title,
                message: message,
                duration: 4
            )
        }
    }

    private func showFailureToast(title: String, message: String) {
        if #available(iOS 18, *) {
            ToastPresenter.shared.show(
                id: "debug-database-transfer-\(part.rawValue)",
                symbol: .exclamationmarkTriangleFill,
                symbolForegroundStyle: (.white, .red),
                title: title,
                message: message,
                duration: 5
            )
        }
    }
}

#Preview {
    List {
        DebugDatabaseTransferSection(part: .watchConfiguration)
    }
}
