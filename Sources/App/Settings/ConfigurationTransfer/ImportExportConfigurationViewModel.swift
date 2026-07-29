import Foundation
import SFSafeSymbols
import Shared
import SwiftUI
import UIKit

@MainActor
final class ImportExportConfigurationViewModel: ObservableObject {
    @Published var entryCounts: [AppConfigurationCategory: Int] = [:]
    @Published var isExporting = false
    @Published var isImporting = false
    @Published var shareWrapper: ShareWrapper?
    @Published var showImporter = false
    @Published var showImportConfirmation = false
    @Published var errorMessage: String?
    /// Name of the file waiting for confirmation, plus what it was found to contain. Both are shown
    /// in the confirmation so the user knows exactly what is about to overwrite their configuration.
    @Published private(set) var pendingImportFilename = ""
    @Published private(set) var pendingImportSummary = ""

    private var pendingImportURL: URL?
    private static let toastID = "app-configuration-transfer"

    var isBusy: Bool { isExporting || isImporting }

    func refreshEntryCounts() {
        do {
            entryCounts = try AppConfigurationTransfer.entryCounts()
        } catch {
            Current.Log.error("Failed to read app configuration entry counts: \(error.localizedDescription)")
            entryCounts = [:]
        }
    }

    func entryCount(for category: AppConfigurationCategory) -> Int {
        entryCounts[category] ?? 0
    }

    func export() {
        Current.impactFeedback.impactOccurred(style: .light)
        isExporting = true
        do {
            let url = try AppConfigurationTransfer.exportURL()
            shareWrapper = ShareWrapper(url: url)
        } catch {
            show(error: error)
        }
        isExporting = false
    }

    func startImport() {
        Current.impactFeedback.impactOccurred(style: .light)
        showImporter = true
    }

    func handleFileSelection(_ result: Result<[URL], Error>) {
        switch result {
        case let .success(urls):
            guard let url = urls.first else {
                Current.Log.info("App configuration import file picker returned no file")
                return
            }
            do {
                let counts = try AppConfigurationTransfer.inspectImportFile(from: url)
                pendingImportURL = url
                pendingImportFilename = url.lastPathComponent
                pendingImportSummary = Self.summary(for: counts)
                showImportConfirmation = true
                Current.Log.info("Presenting app configuration import confirmation for \(url.lastPathComponent)")
            } catch {
                clearPendingImport()
                playFailureHaptic()
                show(error: error)
            }
        case let .failure(error):
            Current.Log.error("App configuration import file picker failed: \(error.localizedDescription)")
            playFailureHaptic()
            show(error: error)
        }
    }

    func cancelImport() {
        Current.Log.info("Cancelled app configuration import confirmation")
        clearPendingImport()
    }

    func confirmImport() async {
        guard let pendingImportURL else { return }
        Current.impactFeedback.impactOccurred(style: .light)
        isImporting = true
        showToast(
            symbol: .arrowClockwise,
            style: (.white, .haPrimary),
            title: L10n.Settings.Debugging.ConfigurationTransfer.Import.Progress.title
        )
        do {
            let counts = try await AppConfigurationTransfer.importPayload(from: pendingImportURL)
            clearPendingImport()
            refreshEntryCounts()
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            showToast(
                symbol: .checkmarkCircleFill,
                style: (.white, .green),
                title: L10n.Settings.Debugging.ConfigurationTransfer.Import.Success.title,
                message: L10n.Settings.Debugging.ConfigurationTransfer.Import.Success
                    .message(counts.values.reduce(0, +)),
                duration: 4
            )
        } catch {
            clearPendingImport()
            playFailureHaptic()
            show(error: error)
        }
        isImporting = false
    }

    /// One line per category that the selected file actually carries, e.g. "Custom widgets: 3".
    private static func summary(for counts: [AppConfigurationCategory: Int]) -> String {
        let lines = AppConfigurationCategory.allCases.compactMap { category -> String? in
            let count = counts[category] ?? 0
            guard count > 0 else { return nil }
            if category.isSingleValue {
                return category.title
            }
            return "\(category.title): \(count)"
        }
        guard !lines.isEmpty else {
            return L10n.Settings.Debugging.ConfigurationTransfer.Import.Confirmation.emptyFile
        }
        return lines.joined(separator: "\n")
    }

    private func clearPendingImport() {
        pendingImportURL = nil
        pendingImportFilename = ""
        pendingImportSummary = ""
    }

    private func playFailureHaptic() {
        UINotificationFeedbackGenerator().notificationOccurred(.error)
    }

    private func show(error: Error) {
        Current.Log.error("App configuration transfer failed: \(error.localizedDescription)")
        errorMessage = error.localizedDescription
        showToast(
            symbol: .exclamationmarkTriangleFill,
            style: (.white, .red),
            title: L10n.Settings.Debugging.ConfigurationTransfer.Error.title,
            message: error.localizedDescription,
            duration: 5
        )
    }

    private func showToast(
        symbol: SFSymbol,
        style: (Color, Color),
        title: String,
        message: String? = nil,
        duration: TimeInterval? = nil
    ) {
        guard #available(iOS 18, *) else { return }
        ToastPresenter.shared.show(
            id: Self.toastID,
            symbol: symbol,
            symbolForegroundStyle: style,
            title: title,
            message: message,
            duration: duration
        )
    }
}
