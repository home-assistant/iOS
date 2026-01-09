import Shared
import SwiftUI
import UniformTypeIdentifiers

// MARK: - Settings Manager

/// Manages settings export and import for kiosk mode
@MainActor
public final class SettingsManager: ObservableObject {
    // MARK: - Singleton

    public static let shared = SettingsManager()

    // MARK: - Published Properties

    @Published public private(set) var lastExportDate: Date?
    @Published public private(set) var lastImportDate: Date?
    @Published public var exportError: String?
    @Published public var importError: String?

    // MARK: - Private Properties

    private let exportFileType = UTType(filenameExtension: "kioskconfig") ?? .json

    // MARK: - Initialization

    private init() {}

    // MARK: - Export

    /// Export current settings to JSON data
    public func exportSettings() -> Data? {
        let settings = KioskModeManager.shared.settings

        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            encoder.dateEncodingStrategy = .iso8601

            let exportData = SettingsExport(
                version: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0",
                exportDate: Date(),
                settings: settings
            )

            let data = try encoder.encode(exportData)
            lastExportDate = Date()

            Current.Log.info("Settings exported successfully")
            return data

        } catch {
            exportError = "Failed to export settings: \(error.localizedDescription)"
            Current.Log.error("Settings export failed: \(error)")
            return nil
        }
    }

    /// Get settings export as a shareable file URL
    public func exportSettingsFile() -> URL? {
        guard let data = exportSettings() else { return nil }

        let fileName = "Kiosk_Settings_\(dateFormatter.string(from: Date())).kioskconfig"
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)

        do {
            try data.write(to: tempURL)
            return tempURL
        } catch {
            exportError = "Failed to create export file: \(error.localizedDescription)"
            Current.Log.error("Failed to write export file: \(error)")
            return nil
        }
    }

    private lazy var dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd_HHmmss"
        return formatter
    }()

    // MARK: - Import

    /// Import settings from JSON data
    public func importSettings(from data: Data) -> Bool {
        do {
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601

            let importData = try decoder.decode(SettingsExport.self, from: data)

            // Validate version compatibility
            guard isVersionCompatible(importData.version) else {
                importError = "Settings file is from an incompatible version"
                return false
            }

            // Apply imported settings
            KioskModeManager.shared.updateSettings(importData.settings)

            lastImportDate = Date()
            Current.Log.info("Settings imported successfully from version \(importData.version)")

            return true

        } catch {
            importError = "Failed to import settings: \(error.localizedDescription)"
            Current.Log.error("Settings import failed: \(error)")
            return false
        }
    }

    /// Import settings from a file URL
    public func importSettings(from url: URL) -> Bool {
        do {
            let data = try Data(contentsOf: url)
            return importSettings(from: data)
        } catch {
            importError = "Failed to read settings file: \(error.localizedDescription)"
            Current.Log.error("Failed to read import file: \(error)")
            return false
        }
    }

    // MARK: - Version Compatibility

    private func isVersionCompatible(_ version: String) -> Bool {
        // Simple version check - could be more sophisticated
        let currentVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"

        // Extract major version
        let importMajor = version.components(separatedBy: ".").first ?? "1"
        let currentMajor = currentVersion.components(separatedBy: ".").first ?? "1"

        // Allow import from same major version
        return importMajor == currentMajor
    }

    // MARK: - Reset

    /// Reset all settings to defaults
    public func resetToDefaults() {
        KioskModeManager.shared.updateSettings(KioskSettings())

        Current.Log.info("Settings reset to defaults")
    }
}

// MARK: - Settings Export Container

/// Container for exported settings with metadata
public struct SettingsExport: Codable {
    let version: String
    let exportDate: Date
    let settings: KioskSettings
}

// MARK: - Settings Transfer View

public struct SettingsTransferView: View {
    @ObservedObject private var manager = SettingsManager.shared
    @ObservedObject private var kioskManager = KioskModeManager.shared

    @State private var showExportSheet = false
    @State private var showImportPicker = false
    @State private var showResetConfirmation = false
    @State private var showImportSuccess = false
    @State private var showExportSuccess = false

    public init() {}

    public var body: some View {
        Form {
            Section {
                Toggle("Allow Settings Export", isOn: Binding(
                    get: { kioskManager.settings.allowSettingsExport },
                    set: { newValue in
                        kioskManager.updateSettings { $0.allowSettingsExport = newValue }
                    }
                ))
            } header: {
                Text("Permissions")
            } footer: {
                Text("When enabled, settings can be exported to a file for backup or transfer to another device.")
            }

            if kioskManager.settings.allowSettingsExport {
                Section {
                    // Export button
                    Button {
                        exportSettings()
                    } label: {
                        Label("Export Settings", systemImage: "square.and.arrow.up")
                    }

                    // Last export date
                    if let lastExport = manager.lastExportDate {
                        HStack {
                            Text("Last Export")
                            Spacer()
                            Text(lastExport, style: .relative)
                                .foregroundColor(.secondary)
                        }
                        .font(.caption)
                    }

                } header: {
                    Text("Export")
                } footer: {
                    Text("Export your current settings to share with another device or for backup.")
                }

                Section {
                    // Import button
                    Button {
                        showImportPicker = true
                    } label: {
                        Label("Import Settings", systemImage: "square.and.arrow.down")
                    }

                    // Last import date
                    if let lastImport = manager.lastImportDate {
                        HStack {
                            Text("Last Import")
                            Spacer()
                            Text(lastImport, style: .relative)
                                .foregroundColor(.secondary)
                        }
                        .font(.caption)
                    }

                } header: {
                    Text("Import")
                } footer: {
                    Text("Import settings from a previously exported file. This will replace your current settings.")
                }
            }

            Section {
                Button(role: .destructive) {
                    showResetConfirmation = true
                } label: {
                    Label("Reset to Defaults", systemImage: "arrow.counterclockwise")
                }
            } header: {
                Text("Reset")
            } footer: {
                Text("Reset all kiosk settings to their default values. This cannot be undone.")
            }

            // Error display
            if let error = manager.exportError {
                Section {
                    Text(error)
                        .foregroundColor(.red)
                        .font(.caption)
                }
            }

            if let error = manager.importError {
                Section {
                    Text(error)
                        .foregroundColor(.red)
                        .font(.caption)
                }
            }
        }
        .navigationTitle("Settings Transfer")
        .sheet(isPresented: $showExportSheet) {
            if let url = manager.exportSettingsFile() {
                ShareSheet(items: [url])
            }
        }
        .fileImporter(
            isPresented: $showImportPicker,
            allowedContentTypes: [.json, UTType(filenameExtension: "kioskconfig") ?? .json],
            allowsMultipleSelection: false
        ) { result in
            handleImport(result)
        }
        .confirmationDialog(
            "Reset Settings?",
            isPresented: $showResetConfirmation,
            titleVisibility: .visible
        ) {
            Button("Reset to Defaults", role: .destructive) {
                manager.resetToDefaults()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will reset all kiosk settings to their default values. This action cannot be undone.")
        }
        .alert("Import Successful", isPresented: $showImportSuccess) {
            Button("OK") {}
        } message: {
            Text("Settings have been imported successfully.")
        }
        .alert("Export Successful", isPresented: $showExportSuccess) {
            Button("OK") {}
        } message: {
            Text("Settings have been exported successfully.")
        }
    }

    private func exportSettings() {
        manager.exportError = nil
        showExportSheet = true
    }

    private func handleImport(_ result: Result<[URL], Error>) {
        manager.importError = nil

        switch result {
        case .success(let urls):
            guard let url = urls.first else {
                manager.importError = "No file selected"
                return
            }

            // Start accessing security-scoped resource
            guard url.startAccessingSecurityScopedResource() else {
                manager.importError = "Unable to access file"
                return
            }

            defer { url.stopAccessingSecurityScopedResource() }

            if manager.importSettings(from: url) {
                showImportSuccess = true
            }

        case .failure(let error):
            manager.importError = "Failed to select file: \(error.localizedDescription)"
        }
    }
}

// MARK: - Share Sheet

struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
