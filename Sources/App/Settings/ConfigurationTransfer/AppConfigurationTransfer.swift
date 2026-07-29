import Foundation
import GRDB
import Shared

/// Whole-app configuration export and import, used by Settings › Debugging › Import/Export configuration.
///
/// `DebugDatabaseTransfer` moves one feature at a time between two installs; this moves *everything*
/// the user configured — every feature it covers plus the ones it does not, plus the app's own
/// preferences — in a single file, and replaces all of it on import.
///
/// What is deliberately not in the file: servers and their tokens, anything in the keychain, cached
/// Home Assistant data (entities, areas, panels, registries) and diagnostics (logs, client events,
/// location history). An import therefore never brings credentials with it, and configuration
/// pointing at a server that is not signed in on this device is dropped rather than restored.
enum AppConfigurationTransfer {
    static let fileExtension = "json"
    /// Marks a file as a full-app export. A single-feature file written by `DebugDatabaseTransfer`
    /// has no `kind`, so it is rejected here instead of importing as an empty configuration.
    static let fileKind = "home-assistant-app-configuration"
    static let schemaVersion = 1

    enum TransferError: LocalizedError {
        case unsupportedFile
        case notAConfigurationFile
        case unsupportedSchema

        var errorDescription: String? {
            switch self {
            case .unsupportedFile:
                return L10n.Settings.Debugging.ConfigurationTransfer.Error.unsupportedFile
            case .notAConfigurationFile:
                return L10n.Settings.Debugging.ConfigurationTransfer.Error.notAConfigurationFile
            case .unsupportedSchema:
                return L10n.Settings.Debugging.ConfigurationTransfer.Error.unsupportedSchema
            }
        }
    }

    /// How many entries each category currently holds on this device, for the disclosure list.
    ///
    /// The app settings snapshot is passed in rather than captured here: capturing it has to happen
    /// on the main actor, while everything in this type is deliberately free of actor isolation so
    /// callers can run the encoding and file work off the main thread.
    static func entryCounts(appSettings: AppSettingsSnapshot) throws -> [AppConfigurationCategory: Int] {
        try makePayload(appSettings: appSettings).entryCounts
    }

    static func exportURL(appSettings: AppSettingsSnapshot) throws -> URL {
        let payload = try makePayload(appSettings: appSettings)
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]

        let data = try encoder.encode(payload)
        let exportDate = Self.filenameDateFormatter.string(from: Current.date())
        let filename = "home-assistant-configuration-\(exportDate).json"
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(filename)
        try data.write(to: url, options: .atomic)
        Current.Log.info("Wrote app configuration export \(filename): \(data.count) byte(s)")
        return url
    }

    /// Decodes a candidate file and reports what it holds, so the confirmation can spell out what the
    /// import is about to replace before anything is written.
    static func inspectImportFile(from url: URL) throws -> [AppConfigurationCategory: Int] {
        let payload = try decodePayload(from: url)
        Current.Log.info("Inspected app configuration import file: \(payload.summaryDescription)")
        return payload.entryCounts
    }

    /// Decoding and the database write run wherever this is called from — off the main actor when
    /// the caller is; only applying app settings hops back onto it.
    static func importPayload(from url: URL) async throws -> [AppConfigurationCategory: Int] {
        Current.Log.info("Starting app configuration import from \(url.lastPathComponent)")
        let payload = try decodePayload(from: url)

        let knownServerIds = Set(Current.servers.all.map(\.identifier.rawValue))
        Current.Log.info("Sanitizing app configuration import against \(knownServerIds.count) server(s)")
        let sanitized = payload.sanitized(knownServerIds: knownServerIds)
        Current.Log.info("Sanitized app configuration import: \(sanitized.summaryDescription)")

        try replaceDatabaseContent(with: sanitized)
        let appSettings = sanitized.appSettings
        await MainActor.run {
            appSettings?.apply()
        }
        try await runPostImportMigration()
        refreshImportedSurfaces()

        let counts = sanitized.entryCounts
        Current.Log.info("Finished app configuration import: \(counts.values.reduce(0, +)) entry(ies)")
        return counts
    }

    // MARK: - Payload

    private static func decodePayload(from url: URL) throws -> Payload {
        guard url.pathExtension.lowercased() == fileExtension else {
            Current.Log.error("Rejected app configuration import with unsupported extension: \(url.lastPathComponent)")
            throw TransferError.unsupportedFile
        }

        let didStartAccessing = url.startAccessingSecurityScopedResource()
        defer {
            if didStartAccessing {
                url.stopAccessingSecurityScopedResource()
            }
        }

        let data = try Data(contentsOf: url)
        Current.Log.info("Read app configuration import file \(url.lastPathComponent): \(data.count) byte(s)")
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let payload = try decoder.decode(Payload.self, from: data)

        guard payload.kind == fileKind else {
            Current.Log.error("Rejected app configuration import: kind is \(payload.kind ?? "missing")")
            throw TransferError.notAConfigurationFile
        }
        guard payload.schemaVersion <= schemaVersion else {
            Current.Log.error("Rejected app configuration import: schema version \(payload.schemaVersion)")
            throw TransferError.unsupportedSchema
        }
        return payload
    }

    private static func makePayload(appSettings: AppSettingsSnapshot) throws -> Payload {
        var payload = try Current.database().read { db in
            try Payload(
                exportedAt: Current.date(),
                watchConfigurations: WatchConfig.fetchAll(db),
                legacyComplications: WatchComplication.fetchAll(db),
                complicationConfigurations: WatchComplicationConfig.fetchAll(db),
                carPlayConfigurations: CarPlayConfig.fetchAll(db),
                customWidgets: CustomWidget.fetchAll(db),
                appIconShortcutConfigurations: AppIconShortcutConfig.fetchAll(db),
                macToolbarConfigurations: MacToolbarConfig.fetchAll(db),
                kioskSettings: KioskSettings.fetchAll(db),
                notificationCategories: NotificationCategory.fetchAll(db),
                notificationSnoozeActions: NotificationSnoozeAction.fetchAll(db),
                allowedTags: AllowedTag.fetchAll(db),
                remindersSyncConfigurations: RemindersSyncConfig.fetchAll(db)
            )
        }
        payload.appSettings = appSettings
        return payload
    }

    private static func replaceDatabaseContent(with payload: Payload) throws {
        Current.Log.info("Replacing app configuration database content")
        try Current.database().write { db in
            try WatchConfig.deleteAll(db)
            try WatchComplication.deleteAll(db)
            try WatchComplicationConfig.deleteAll(db)
            try CarPlayConfig.deleteAll(db)
            try CustomWidget.deleteAll(db)
            try AppIconShortcutConfig.deleteAll(db)
            try MacToolbarConfig.deleteAll(db)
            try KioskSettings.deleteAll(db)
            try NotificationCategory.deleteAll(db)
            try NotificationSnoozeAction.deleteAll(db)
            try AllowedTag.deleteAll(db)
            try RemindersSyncConfig.deleteAll(db)

            try insert(payload.watchConfigurations, in: db)
            try insert(payload.legacyComplications, in: db)
            try insert(payload.complicationConfigurations, in: db)
            try insert(payload.carPlayConfigurations, in: db)
            try insert(payload.customWidgets, in: db)
            try insert(payload.appIconShortcutConfigurations, in: db)
            try insert(payload.macToolbarConfigurations, in: db)
            try insert(payload.kioskSettings, in: db)
            try insert(payload.notificationCategories, in: db)
            try insert(payload.notificationSnoozeActions, in: db)
            try insert(payload.allowedTags, in: db)
            try insert(payload.remindersSyncConfigurations, in: db)
        }
    }

    private static func insert(_ records: [some PersistableRecord], in db: Database) throws {
        for record in records {
            try record.insert(db, onConflict: .replace)
        }
    }

    private static func runPostImportMigration() async throws {
        Current.Log.info("Running post-import model cleanup")
        try await withCheckedThrowingContinuation { continuation in
            Current.modelManager.cleanup().pipe { result in
                switch result {
                case .fulfilled:
                    continuation.resume()
                case let .rejected(error):
                    Current.Log.error("Post-import model cleanup failed: \(error.localizedDescription)")
                    continuation.resume(throwing: error)
                }
            }
        }

        for server in Current.servers.all {
            Current.appDatabaseUpdater.update(server: server, forceUpdate: true, showProgress: false)
        }
    }

    private static func refreshImportedSurfaces() {
        Current.Log.info("Refreshing surfaces after app configuration import")
        HomeAssistantAPI.syncWatchContext()
        WatchMirrorPushCoordinator.schedule(reason: .databaseUpdated)
        NotificationCenter.default.post(name: WatchComplication.didChangeNotification, object: nil)
        NotificationCenter.default.post(name: WatchComplicationConfig.didChangeNotification, object: nil)
        DataWidgetsUpdater.update()
        AppIconShortcutItemsUpdater.update()
    }

    private static let filenameDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = .current
        formatter.dateFormat = "yyyyMMdd-HHmmss"
        return formatter
    }()
}

extension AppConfigurationTransfer {
    /// The on-disk shape of a configuration export. Every collection decodes to an empty array when
    /// absent, so a file written by a build that did not know about a category still imports.
    struct Payload: Codable {
        let kind: String?
        let schemaVersion: Int
        let exportedAt: Date
        var appSettings: AppSettingsSnapshot?
        var watchConfigurations: [WatchConfig]
        var legacyComplications: [WatchComplication]
        var complicationConfigurations: [WatchComplicationConfig]
        var carPlayConfigurations: [CarPlayConfig]
        var customWidgets: [CustomWidget]
        var appIconShortcutConfigurations: [AppIconShortcutConfig]
        var macToolbarConfigurations: [MacToolbarConfig]
        var kioskSettings: [KioskSettings]
        var notificationCategories: [NotificationCategory]
        var notificationSnoozeActions: [NotificationSnoozeAction]
        var allowedTags: [AllowedTag]
        var remindersSyncConfigurations: [RemindersSyncConfig]

        init(
            kind: String? = AppConfigurationTransfer.fileKind,
            schemaVersion: Int = AppConfigurationTransfer.schemaVersion,
            exportedAt: Date,
            appSettings: AppSettingsSnapshot? = nil,
            watchConfigurations: [WatchConfig] = [],
            legacyComplications: [WatchComplication] = [],
            complicationConfigurations: [WatchComplicationConfig] = [],
            carPlayConfigurations: [CarPlayConfig] = [],
            customWidgets: [CustomWidget] = [],
            appIconShortcutConfigurations: [AppIconShortcutConfig] = [],
            macToolbarConfigurations: [MacToolbarConfig] = [],
            kioskSettings: [KioskSettings] = [],
            notificationCategories: [NotificationCategory] = [],
            notificationSnoozeActions: [NotificationSnoozeAction] = [],
            allowedTags: [AllowedTag] = [],
            remindersSyncConfigurations: [RemindersSyncConfig] = []
        ) {
            self.kind = kind
            self.schemaVersion = schemaVersion
            self.exportedAt = exportedAt
            self.appSettings = appSettings
            self.watchConfigurations = watchConfigurations
            self.legacyComplications = legacyComplications
            self.complicationConfigurations = complicationConfigurations
            self.carPlayConfigurations = carPlayConfigurations
            self.customWidgets = customWidgets
            self.appIconShortcutConfigurations = appIconShortcutConfigurations
            self.macToolbarConfigurations = macToolbarConfigurations
            self.kioskSettings = kioskSettings
            self.notificationCategories = notificationCategories
            self.notificationSnoozeActions = notificationSnoozeActions
            self.allowedTags = allowedTags
            self.remindersSyncConfigurations = remindersSyncConfigurations
        }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            self.kind = try container.decodeIfPresent(String.self, forKey: .kind)
            self.schemaVersion = try container.decodeIfPresent(Int.self, forKey: .schemaVersion) ?? 1
            self.exportedAt = try container.decodeIfPresent(Date.self, forKey: .exportedAt) ?? Current.date()
            self.appSettings = try container.decodeIfPresent(AppSettingsSnapshot.self, forKey: .appSettings)
            self.watchConfigurations = try container
                .decodeIfPresent([WatchConfig].self, forKey: .watchConfigurations) ?? []
            self.legacyComplications = try container
                .decodeIfPresent([WatchComplication].self, forKey: .legacyComplications) ?? []
            self.complicationConfigurations = try container
                .decodeIfPresent([WatchComplicationConfig].self, forKey: .complicationConfigurations) ?? []
            self.carPlayConfigurations = try container
                .decodeIfPresent([CarPlayConfig].self, forKey: .carPlayConfigurations) ?? []
            self.customWidgets = try container.decodeIfPresent([CustomWidget].self, forKey: .customWidgets) ?? []
            self.appIconShortcutConfigurations = try container
                .decodeIfPresent([AppIconShortcutConfig].self, forKey: .appIconShortcutConfigurations) ?? []
            self.macToolbarConfigurations = try container
                .decodeIfPresent([MacToolbarConfig].self, forKey: .macToolbarConfigurations) ?? []
            self.kioskSettings = try container.decodeIfPresent([KioskSettings].self, forKey: .kioskSettings) ?? []
            self.notificationCategories = try container
                .decodeIfPresent([NotificationCategory].self, forKey: .notificationCategories) ?? []
            self.notificationSnoozeActions = try container
                .decodeIfPresent([NotificationSnoozeAction].self, forKey: .notificationSnoozeActions) ?? []
            self.allowedTags = try container.decodeIfPresent([AllowedTag].self, forKey: .allowedTags) ?? []
            self.remindersSyncConfigurations = try container
                .decodeIfPresent([RemindersSyncConfig].self, forKey: .remindersSyncConfigurations) ?? []
        }

        /// User-visible entry counts: how many things the user would recognize as configured, which
        /// is not always the row count (a single `WatchConfig` row holds many watch items).
        var entryCounts: [AppConfigurationCategory: Int] {
            [
                .appSettings: appSettings == nil ? 0 : 1,
                .watchConfiguration: watchConfigurations.reduce(0) { $0 + $1.items.count },
                .watchComplications: legacyComplications.count + complicationConfigurations.count,
                .carPlayConfiguration: carPlayConfigurations.reduce(0) { $0 + $1.quickAccessItems.count },
                .customWidgets: customWidgets.count,
                .appQuickActions: appIconShortcutConfigurations.reduce(0) { $0 + $1.items.count },
                .macToolbar: macToolbarConfigurations.reduce(0) { $0 + $1.items.count },
                .kiosk: kioskSettings.isEmpty ? 0 : 1,
                .notificationCategories: notificationCategories.count,
                .notificationSnoozeActions: notificationSnoozeActions.count,
                .nfcTags: allowedTags.count,
                .remindersSync: remindersSyncConfigurations.count,
            ]
        }

        var summaryDescription: String {
            AppConfigurationCategory.allCases
                .map { "\($0.rawValue)=\(entryCounts[$0] ?? 0)" }
                .joined(separator: ", ")
        }

        /// Drops everything that points at a server this device is not signed in to, so an import
        /// never leaves behind items that can never resolve.
        func sanitized(knownServerIds: Set<String>) -> Self {
            var copy = self
            copy.watchConfigurations = copy.watchConfigurations.map { configuration in
                var configuration = configuration
                if let serverId = configuration.assist.serverId, !knownServerIds.contains(serverId) {
                    configuration.assist.serverId = nil
                    configuration.assist.pipelineId = nil
                }
                configuration.items = configuration.items.sanitized(knownServerIds: knownServerIds)
                return configuration
            }
            copy.legacyComplications = copy.legacyComplications.filter { complication in
                guard let serverIdentifier = complication.serverIdentifier else { return true }
                return knownServerIds.contains(serverIdentifier)
            }
            copy.complicationConfigurations = copy.complicationConfigurations
                .filter { knownServerIds.contains($0.serverId) }
            copy.carPlayConfigurations = copy.carPlayConfigurations.map { configuration in
                var configuration = configuration
                configuration.quickAccessItems = configuration.quickAccessItems
                    .sanitized(knownServerIds: knownServerIds)
                return configuration
            }
            copy.customWidgets = copy.customWidgets.compactMap { widget in
                var widget = widget
                widget.items = widget.items.sanitized(knownServerIds: knownServerIds)
                let remainingItemIds = Set(widget.items.map(\.serverUniqueId))
                widget.itemsStates = widget.itemsStates.filter { remainingItemIds.contains($0.key) }
                return widget.items.isEmpty ? nil : widget
            }
            copy.appIconShortcutConfigurations = copy.appIconShortcutConfigurations.map { configuration in
                var configuration = configuration
                configuration.items = configuration.items.sanitized(knownServerIds: knownServerIds)
                return configuration
            }
            copy.macToolbarConfigurations = copy.macToolbarConfigurations.map { configuration in
                var configuration = configuration
                configuration.items = configuration.items.sanitized(knownServerIds: knownServerIds)
                return configuration
            }
            copy.kioskSettings = copy.kioskSettings.map { settings in
                var settings = settings
                if let serverId = settings.serverId, !knownServerIds.contains(serverId) {
                    settings.serverId = nil
                    settings.dashboard = nil
                }
                return settings
            }
            copy.notificationCategories = copy.notificationCategories.filter { category in
                category.serverIdentifier.isEmpty || knownServerIds.contains(category.serverIdentifier)
            }
            copy.remindersSyncConfigurations = copy.remindersSyncConfigurations
                .filter { knownServerIds.contains($0.serverId) }
            return copy
        }
    }
}
