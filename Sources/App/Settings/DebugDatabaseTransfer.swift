import Foundation
import GRDB
import PromiseKit
import Shared

struct DebugDatabaseTransferSummary: Equatable {
    let watchConfigurations: Int
    let legacyComplications: Int
    let complicationConfigurations: Int
    let carPlayConfigurations: Int
    let customWidgets: Int
    let appIconShortcutConfigurations: Int

    var totalRecords: Int {
        watchConfigurations
            + legacyComplications
            + complicationConfigurations
            + carPlayConfigurations
            + customWidgets
            + appIconShortcutConfigurations
    }
}

enum DebugDatabaseTransfer {
    enum Part: String, CaseIterable, Codable {
        case watchConfiguration
        case complications
        case carPlayConfiguration
        case customWidgets
        case appIconShortcuts

        var filenameSlug: String { rawValue }

        var title: String {
            switch self {
            case .watchConfiguration:
                return L10n.Settings.Debugging.DatabaseTransfer.Part.watchConfiguration
            case .complications:
                return L10n.Settings.Debugging.DatabaseTransfer.Part.complications
            case .carPlayConfiguration:
                return L10n.Settings.Debugging.DatabaseTransfer.Part.carplayConfiguration
            case .customWidgets:
                return L10n.Settings.Debugging.DatabaseTransfer.Part.customWidgets
            case .appIconShortcuts:
                return L10n.Settings.Debugging.DatabaseTransfer.Part.appIconShortcuts
            }
        }
    }

    enum TransferError: LocalizedError {
        case unsupportedFile
        case unsupportedFeatureFile
        case wrongFeatureFile(actual: Part, expected: Part)

        var errorDescription: String? {
            switch self {
            case .unsupportedFile:
                return L10n.Settings.Debugging.DatabaseTransfer.Error.unsupportedFile
            case .unsupportedFeatureFile:
                return L10n.Settings.Debugging.DatabaseTransfer.Error.unsupportedFeatureFile
            case let .wrongFeatureFile(actual, expected):
                return L10n.Settings.Debugging.DatabaseTransfer.Error.wrongFeatureFile(actual.title, expected.title)
            }
        }
    }

    static let fileExtension = "json"

    static func hasExportableContent(part: Part) throws -> Bool {
        try Current.database().read { db in
            switch part {
            case .watchConfiguration:
                return try WatchConfig.fetchCount(db) > 0
            case .complications:
                return try WatchComplication.fetchCount(db) + WatchComplicationConfig.fetchCount(db) > 0
            case .carPlayConfiguration:
                return try CarPlayConfig.fetchCount(db) > 0
            case .customWidgets:
                return try CustomWidget.fetchCount(db) > 0
            case .appIconShortcuts:
                return try AppIconShortcutConfig.fetchCount(db) > 0
            }
        }
    }

    static func exportURL(part: Part) throws -> URL {
        let payload = try makePayload(part: part)
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]

        let data = try encoder.encode(payload)
        let exportDate = Self.filenameDateFormatter.string(from: Current.date())
        let filename = "home-assistant-\(part.filenameSlug)-\(exportDate).json"
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(filename)
        try data.write(to: url, options: .atomic)
        return url
    }

    static func validateImportFile(from url: URL, part: Part) throws {
        Current.Log.info("Validating debug database import file for \(part.rawValue): \(url.lastPathComponent)")
        let payload = try decodePayload(from: url)
        try validate(payload: payload, expectedPart: part)
        Current.Log
            .info(
                "Debug database import file validated for \(part.rawValue): \(payload.summary.totalRecords) record(s)"
            )
    }

    static func importPayload(from url: URL, part: Part) async throws -> DebugDatabaseTransferSummary {
        Current.Log.info("Starting debug database import for \(part.rawValue) from \(url.lastPathComponent)")
        let payload = try decodePayload(from: url)
        try validate(payload: payload, expectedPart: part)
        Current.Log.info("Debug database import payload accepted for \(part.rawValue): \(payload.summaryDescription)")

        let knownServerIds = Set(Current.servers.all.map(\.identifier.rawValue))
        Current.Log
            .info("Sanitizing debug database import for \(part.rawValue) against \(knownServerIds.count) server(s)")
        let sanitizedPayload = payload.sanitized(knownServerIds: knownServerIds)
        Current.Log.info("Sanitized debug database import for \(part.rawValue): \(sanitizedPayload.summaryDescription)")

        try replaceDatabaseContent(with: sanitizedPayload, part: part)
        try await runPostImportMigration()
        refreshImportedSurfaces(part: part)

        let summary = sanitizedPayload.summary(for: part)
        Current.Log.info("Finished debug database import for \(part.rawValue): \(summary.totalRecords) record(s)")
        return summary
    }

    private static func decodePayload(from url: URL) throws -> Payload {
        guard url.pathExtension.lowercased() == fileExtension else {
            Current.Log
                .error("Rejected debug database import file with unsupported extension: \(url.lastPathComponent)")
            throw TransferError.unsupportedFile
        }

        let didStartAccessing = url.startAccessingSecurityScopedResource()
        Current.Log.verbose(
            "Security-scoped access for debug database import file \(url.lastPathComponent): \(didStartAccessing)"
        )
        defer {
            if didStartAccessing {
                url.stopAccessingSecurityScopedResource()
                Current.Log
                    .verbose("Stopped security-scoped access for debug database import file \(url.lastPathComponent)")
            }
        }

        let data = try Data(contentsOf: url)
        Current.Log.info("Read debug database import file \(url.lastPathComponent): \(data.count) byte(s)")
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let payload = try decoder.decode(Payload.self, from: data)
        let exportedPart = payload.exportedPart ?? payload.inferredExportedPart
        Current.Log.info(
            "Decoded debug database import payload schema=\(payload.schemaVersion), " +
                "exportedPart=\(exportedPart?.rawValue ?? "unknown"), summary=\(payload.summaryDescription)"
        )
        return payload
    }

    private static func validate(payload: Payload, expectedPart: Part) throws {
        guard let exportedPart = payload.exportedPart ?? payload.inferredExportedPart else {
            Current.Log
                .error("Rejected debug database import for \(expectedPart.rawValue): missing feature discriminator")
            throw TransferError.unsupportedFeatureFile
        }
        guard exportedPart == expectedPart else {
            Current.Log.error(
                "Rejected debug database import for \(expectedPart.rawValue): file contains \(exportedPart.rawValue)"
            )
            throw TransferError.wrongFeatureFile(actual: exportedPart, expected: expectedPart)
        }
        Current.Log.info("Validated debug database import part \(exportedPart.rawValue)")
    }

    private static func makePayload(part: Part) throws -> Payload {
        try Current.database().read { db in
            switch part {
            case .watchConfiguration:
                return try Payload(
                    exportedPart: part,
                    exportedAt: Current.date(),
                    watchConfigurations: WatchConfig.fetchAll(db)
                )
            case .complications:
                return try Payload(
                    exportedPart: part,
                    exportedAt: Current.date(),
                    legacyComplications: WatchComplication.fetchAll(db),
                    complicationConfigurations: WatchComplicationConfig.fetchAll(db)
                )
            case .carPlayConfiguration:
                return try Payload(
                    exportedPart: part,
                    exportedAt: Current.date(),
                    carPlayConfigurations: CarPlayConfig.fetchAll(db)
                )
            case .customWidgets:
                return try Payload(
                    exportedPart: part,
                    exportedAt: Current.date(),
                    customWidgets: CustomWidget.fetchAll(db)
                )
            case .appIconShortcuts:
                return try Payload(
                    exportedPart: part,
                    exportedAt: Current.date(),
                    appIconShortcutConfigurations: AppIconShortcutConfig.fetchAll(db)
                )
            }
        }
    }

    private static func replaceDatabaseContent(with payload: Payload, part: Part) throws {
        Current.Log
            .info(
                "Replacing debug database content for \(part.rawValue): \(payload.summary(for: part).totalRecords) record(s)"
            )
        try Current.database().write { db in
            switch part {
            case .watchConfiguration:
                Current.Log.info("Deleting existing watch configuration rows")
                try WatchConfig.deleteAll(db)
                Current.Log.info("Inserting \(payload.watchConfigurations.count) watch configuration row(s)")
                for value in payload.watchConfigurations {
                    try value.insert(db, onConflict: .replace)
                }
            case .complications:
                Current.Log.info("Deleting existing complication rows")
                try WatchComplication.deleteAll(db)
                try WatchComplicationConfig.deleteAll(db)
                Current.Log.info(
                    "Inserting \(payload.legacyComplications.count) legacy complication row(s) and " +
                        "\(payload.complicationConfigurations.count) complication configuration row(s)"
                )
                for value in payload.legacyComplications {
                    try value.insert(db, onConflict: .replace)
                }
                for value in payload.complicationConfigurations {
                    try value.insert(db, onConflict: .replace)
                }
            case .carPlayConfiguration:
                Current.Log.info("Deleting existing CarPlay configuration rows")
                try CarPlayConfig.deleteAll(db)
                Current.Log.info("Inserting \(payload.carPlayConfigurations.count) CarPlay configuration row(s)")
                for value in payload.carPlayConfigurations {
                    try value.insert(db, onConflict: .replace)
                }
            case .customWidgets:
                Current.Log.info("Deleting existing custom widget rows")
                try CustomWidget.deleteAll(db)
                Current.Log.info("Inserting \(payload.customWidgets.count) custom widget row(s)")
                for value in payload.customWidgets {
                    try value.insert(db, onConflict: .replace)
                }
            case .appIconShortcuts:
                Current.Log.info("Deleting existing app quick action rows")
                try AppIconShortcutConfig.deleteAll(db)
                Current.Log.info(
                    "Inserting \(payload.appIconShortcutConfigurations.count) app quick action configuration row(s)"
                )
                for value in payload.appIconShortcutConfigurations {
                    try value.insert(db, onConflict: .replace)
                }
            }
        }
    }

    private static func runPostImportMigration() async throws {
        Current.Log.info("Running post-import model cleanup")
        try await withCheckedThrowingContinuation { continuation in
            Current.modelManager.cleanup().pipe { result in
                switch result {
                case .fulfilled:
                    Current.Log.info("Post-import model cleanup completed")
                    continuation.resume()
                case let .rejected(error):
                    Current.Log.error("Post-import model cleanup failed: \(error.localizedDescription)")
                    continuation.resume(throwing: error)
                }
            }
        }

        Current.Log.info("Refreshing app database for \(Current.servers.all.count) server(s) after import")
        for server in Current.servers.all {
            Current.Log.info("Requesting forced app database update for server \(server.identifier.rawValue)")
            Current.appDatabaseUpdater.update(server: server, forceUpdate: true)
        }
    }

    private static func refreshImportedSurfaces(part: Part) {
        Current.Log.info("Refreshing imported surfaces for \(part.rawValue)")
        switch part {
        case .watchConfiguration:
            Current.Log.info("Syncing watch context after watch configuration import")
            HomeAssistantAPI.syncWatchContext()
            WatchMirrorPushCoordinator.schedule(reason: .databaseUpdated)
        case .complications:
            Current.Log.info("Posting complication change notifications after import")
            NotificationCenter.default.post(name: WatchComplication.didChangeNotification, object: nil)
            NotificationCenter.default.post(name: WatchComplicationConfig.didChangeNotification, object: nil)
            HomeAssistantAPI.syncWatchContext()
            WatchMirrorPushCoordinator.schedule(reason: .complicationChanged)
        case .carPlayConfiguration:
            Current.Log.info("No additional CarPlay refresh action required after import")
        case .customWidgets:
            Current.Log.info("Refreshing data widgets after custom widgets import")
            DataWidgetsUpdater.update()
        case .appIconShortcuts:
            Current.Log.info("Refreshing app quick actions after import")
            AppIconShortcutItemsUpdater.update()
        }
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

private extension DebugDatabaseTransfer {
    struct Payload: Codable {
        let schemaVersion: Int
        let exportedPart: DebugDatabaseTransfer.Part?
        let exportedAt: Date
        var watchConfigurations: [WatchConfig]
        var legacyComplications: [WatchComplication]
        var complicationConfigurations: [WatchComplicationConfig]
        var carPlayConfigurations: [CarPlayConfig]
        var customWidgets: [CustomWidget]
        var appIconShortcutConfigurations: [AppIconShortcutConfig]

        init(
            schemaVersion: Int = 1,
            exportedPart: DebugDatabaseTransfer.Part,
            exportedAt: Date,
            watchConfigurations: [WatchConfig] = [],
            legacyComplications: [WatchComplication] = [],
            complicationConfigurations: [WatchComplicationConfig] = [],
            carPlayConfigurations: [CarPlayConfig] = [],
            customWidgets: [CustomWidget] = [],
            appIconShortcutConfigurations: [AppIconShortcutConfig] = []
        ) {
            self.schemaVersion = schemaVersion
            self.exportedPart = exportedPart
            self.exportedAt = exportedAt
            self.watchConfigurations = watchConfigurations
            self.legacyComplications = legacyComplications
            self.complicationConfigurations = complicationConfigurations
            self.carPlayConfigurations = carPlayConfigurations
            self.customWidgets = customWidgets
            self.appIconShortcutConfigurations = appIconShortcutConfigurations
        }

        var summary: DebugDatabaseTransferSummary {
            DebugDatabaseTransferSummary(
                watchConfigurations: watchConfigurations.count,
                legacyComplications: legacyComplications.count,
                complicationConfigurations: complicationConfigurations.count,
                carPlayConfigurations: carPlayConfigurations.count,
                customWidgets: customWidgets.count,
                appIconShortcutConfigurations: appIconShortcutConfigurations.count
            )
        }

        var summaryDescription: String {
            "watch=\(watchConfigurations.count), legacyComplications=\(legacyComplications.count), " +
                "complicationConfigurations=\(complicationConfigurations.count), " +
                "carPlay=\(carPlayConfigurations.count), customWidgets=\(customWidgets.count), " +
                "appQuickActions=\(appIconShortcutConfigurations.count)"
        }

        var inferredExportedPart: DebugDatabaseTransfer.Part? {
            var matchingParts: [DebugDatabaseTransfer.Part] = []
            if !watchConfigurations.isEmpty {
                matchingParts.append(.watchConfiguration)
            }
            if !legacyComplications.isEmpty || !complicationConfigurations.isEmpty {
                matchingParts.append(.complications)
            }
            if !carPlayConfigurations.isEmpty {
                matchingParts.append(.carPlayConfiguration)
            }
            if !customWidgets.isEmpty {
                matchingParts.append(.customWidgets)
            }
            if !appIconShortcutConfigurations.isEmpty {
                matchingParts.append(.appIconShortcuts)
            }
            return matchingParts.count == 1 ? matchingParts.first : nil
        }

        func summary(for part: DebugDatabaseTransfer.Part) -> DebugDatabaseTransferSummary {
            switch part {
            case .watchConfiguration:
                return DebugDatabaseTransferSummary(
                    watchConfigurations: watchConfigurations.count,
                    legacyComplications: 0,
                    complicationConfigurations: 0,
                    carPlayConfigurations: 0,
                    customWidgets: 0,
                    appIconShortcutConfigurations: 0
                )
            case .complications:
                return DebugDatabaseTransferSummary(
                    watchConfigurations: 0,
                    legacyComplications: legacyComplications.count,
                    complicationConfigurations: complicationConfigurations.count,
                    carPlayConfigurations: 0,
                    customWidgets: 0,
                    appIconShortcutConfigurations: 0
                )
            case .carPlayConfiguration:
                return DebugDatabaseTransferSummary(
                    watchConfigurations: 0,
                    legacyComplications: 0,
                    complicationConfigurations: 0,
                    carPlayConfigurations: carPlayConfigurations.count,
                    customWidgets: 0,
                    appIconShortcutConfigurations: 0
                )
            case .customWidgets:
                return DebugDatabaseTransferSummary(
                    watchConfigurations: 0,
                    legacyComplications: 0,
                    complicationConfigurations: 0,
                    carPlayConfigurations: 0,
                    customWidgets: customWidgets.count,
                    appIconShortcutConfigurations: 0
                )
            case .appIconShortcuts:
                return DebugDatabaseTransferSummary(
                    watchConfigurations: 0,
                    legacyComplications: 0,
                    complicationConfigurations: 0,
                    carPlayConfigurations: 0,
                    customWidgets: 0,
                    appIconShortcutConfigurations: appIconShortcutConfigurations.count
                )
            }
        }

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
            copy.complicationConfigurations = copy.complicationConfigurations.filter {
                knownServerIds.contains($0.serverId)
            }
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
            return copy
        }
    }
}

private extension [MagicItem] {
    func sanitized(knownServerIds: Set<String>) -> [MagicItem] {
        compactMap { item in
            var item = item
            if item.type == .folder {
                item.items = item.items?.sanitized(knownServerIds: knownServerIds)
                return item
            }
            guard item.serverId.isEmpty || knownServerIds.contains(item.serverId) else { return nil }
            return item
        }
    }
}
