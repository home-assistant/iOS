import Foundation
import GRDB
import PromiseKit

/// Central manager for configuration export/import operations
public final class ConfigurationManager {
    public static let shared = ConfigurationManager()

    private init() {}

    // MARK: - Export

    /// Export a configuration to a shareable file
    public func exportConfiguration(_ config: some ConfigurationExportable) throws -> URL {
        try config.exportToFile()
    }

    // MARK: - Import

    /// Import a configuration from a file URL with migration and confirmation
    @MainActor
    public func importConfiguration(
        from url: URL,
        completion: @escaping (Result<ConfigurationType, Error>) -> Void
    ) {
        do {
            // Read file to determine type
            let configType = try detectConfigurationType(from: url)

            switch configType {
            case .carPlay:
                try importCarPlayConfiguration(from: url, completion: completion)
            case .watch:
                try importWatchConfiguration(from: url, completion: completion)
            case .widgets:
                try importWidgetConfiguration(from: url, completion: completion)
            }
        } catch {
            Current.Log.error("Failed to import configuration: \(error.localizedDescription)")
            completion(.failure(error))
        }
    }

    // MARK: - Private Import Helpers

    @MainActor
    private func importCarPlayConfiguration(
        from url: URL,
        completion: @escaping (Result<ConfigurationType, Error>) -> Void
    ) throws {
        var config = try CarPlayConfig.importFromFile(url: url)

        // Migrate items to match current server IDs
        config.quickAccessItems = Current.magicItemProvider().migrateItemsIfNeeded(items: config.quickAccessItems)

        // Save to database
        try Current.database().write { db in
            try config.insert(db, onConflict: .replace)
        }

        Current.Log.info("CarPlay configuration imported successfully")
        completion(.success(.carPlay))
    }

    @MainActor
    private func importWatchConfiguration(
        from url: URL,
        completion: @escaping (Result<ConfigurationType, Error>) -> Void
    ) throws {
        var config = try WatchConfig.importFromFile(url: url)

        // Migrate items to match current server IDs
        config.items = Current.magicItemProvider().migrateItemsIfNeeded(items: config.items)

        // Save to database
        try Current.database().write { db in
            try config.insert(db, onConflict: .replace)
        }

        Current.Log.info("Watch configuration imported successfully")
        completion(.success(.watch))
    }

    @MainActor
    private func importWidgetConfiguration(
        from url: URL,
        completion: @escaping (Result<ConfigurationType, Error>) -> Void
    ) throws {
        var config = try CustomWidget.importFromFile(url: url)

        // Migrate items to match current server IDs
        config.items = Current.magicItemProvider().migrateItemsIfNeeded(items: config.items)

        // Save to database
        try Current.database().write { db in
            try config.insert(db, onConflict: .replace)
        }

        Current.Log.info("Widget configuration imported successfully")
        completion(.success(.widgets))
    }

    // MARK: - Type Detection

    private func detectConfigurationType(from url: URL) throws -> ConfigurationType {
        guard url.startAccessingSecurityScopedResource() else {
            throw ConfigurationImportError.securityScopedResourceAccessFailed
        }

        defer {
            url.stopAccessingSecurityScopedResource()
        }

        let data = try Data(contentsOf: url)
        let decoder = JSONDecoder()
        let container = try decoder.decode(ConfigurationExport.self, from: data)

        return container.type
    }
}
