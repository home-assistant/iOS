import Foundation
import GRDB
import UserNotifications

/// An actionable notification category persisted in GRDB. Replaces the legacy
/// Realm-backed model; actions are embedded in the row as JSON.
public struct NotificationCategory: Codable, FetchableRecord, PersistableRecord, Equatable, Identifiable {
    public static let databaseTableName = GRDBDatabaseTable.notificationCategory.rawValue

    public static let FallbackActionIdentifier = "_"

    public var identifier: String
    public var serverIdentifier: String
    public var name: String
    public var isServerControlled: Bool
    public var hiddenPreviewsBodyPlaceholder: String?
    public var categorySummaryFormat: String?

    // Options
    public var sendDismissActions: Bool
    public var hiddenPreviewsShowTitle: Bool
    public var hiddenPreviewsShowSubtitle: Bool

    // Maybe someday, HA will be on CarPlay (hey that rhymes!)...
    // public var allowInCarPlay: Bool = false

    public var actions: [NotificationAction]

    public var id: String { identifier }

    public init(
        identifier: String = "",
        serverIdentifier: String = "",
        name: String = "",
        isServerControlled: Bool = false,
        hiddenPreviewsBodyPlaceholder: String? = nil,
        categorySummaryFormat: String? = nil,
        sendDismissActions: Bool = true,
        hiddenPreviewsShowTitle: Bool = false,
        hiddenPreviewsShowSubtitle: Bool = false,
        actions: [NotificationAction] = []
    ) {
        self.identifier = identifier
        self.serverIdentifier = serverIdentifier
        self.name = name
        self.isServerControlled = isServerControlled
        self.hiddenPreviewsBodyPlaceholder = hiddenPreviewsBodyPlaceholder
        self.categorySummaryFormat = categorySummaryFormat
        self.sendDismissActions = sendDismissActions
        self.hiddenPreviewsShowTitle = hiddenPreviewsShowTitle
        self.hiddenPreviewsShowSubtitle = hiddenPreviewsShowSubtitle
        self.actions = actions
    }

    public var options: UNNotificationCategoryOptions {
        var categoryOptions = UNNotificationCategoryOptions([])

        if sendDismissActions { categoryOptions.insert(.customDismissAction) }

        #if os(iOS)
        if hiddenPreviewsShowTitle { categoryOptions.insert(.hiddenPreviewsShowTitle) }
        if hiddenPreviewsShowSubtitle { categoryOptions.insert(.hiddenPreviewsShowSubtitle) }
        #endif

        return categoryOptions
    }

    #if os(iOS)
    public var categories: [UNNotificationCategory] {
        [
            UNNotificationCategory(
                identifier: identifier.uppercased(),
                actions: actions.map(\.action),
                intentIdentifiers: [],
                hiddenPreviewsBodyPlaceholder: hiddenPreviewsBodyPlaceholder,
                categorySummaryFormat: categorySummaryFormat,
                options: options
            ),
        ]
    }
    #endif

    public var exampleServiceCall: String {
        let urlStrings = actions.map { "\"\($0.identifier)\": \"http://example.com/url\"" }

        let indentation = "\n    "

        return """
        service: notify.mobile_app_#name_here
        data:
          push:
            category: \(identifier.uppercased())
          action_data:
            # see example trigger in action
            # value will be in fired event

          # url can be absolute path like:
          # "http://example.com/url"
          # or relative like:
          # "/lovelace/dashboard"

          # pick one of the following styles:

          # always open when opening notification
          url: "/lovelace/dashboard"

          # open a different url per action
          # use "\(Self.FallbackActionIdentifier)" as key for no action chosen
          url:
            "\(Self.FallbackActionIdentifier)": "http://example.com/fallback"
            \(urlStrings.joined(separator: indentation))
        """
    }
}

// MARK: - Queries

public extension NotificationCategory {
    /// All persisted categories, across all servers.
    static func all() -> [NotificationCategory] {
        do {
            return try Current.database().read { db in
                try NotificationCategory.fetchAll(db)
            }
        } catch {
            Current.Log.error("Failed to fetch notification categories: \(error.localizedDescription)")
            return []
        }
    }

    static func fetch(identifier: String) -> NotificationCategory? {
        do {
            return try Current.database().read { db in
                try NotificationCategory
                    .filter(Column(DatabaseTables.NotificationCategory.identifier.rawValue) == identifier)
                    .fetchOne(db)
            }
        } catch {
            Current.Log.error("Failed to fetch notification category: \(error.localizedDescription)")
            return nil
        }
    }

    func save() {
        do {
            try Current.database().write { db in
                try self.save(db)
            }
        } catch {
            Current.Log.error("Failed to save notification category \(identifier): \(error.localizedDescription)")
        }
    }

    static func delete(identifiers: [String]) {
        guard !identifiers.isEmpty else { return }
        do {
            try Current.database().write { db in
                try NotificationCategory
                    .filter(identifiers.contains(Column(DatabaseTables.NotificationCategory.identifier.rawValue)))
                    .deleteAll(db)
            }
        } catch {
            Current.Log.error("Failed to delete notification categories: \(error.localizedDescription)")
        }
    }
}

// MARK: - UpdatableModel

extension NotificationCategory: UpdatableModel {
    static var serverIdentifierColumnName: String { DatabaseTables.NotificationCategory.serverIdentifier.rawValue }
    static var primaryKeyColumnName: String { DatabaseTables.NotificationCategory.identifier.rawValue }
    static var updateEligibleCondition: SQLExpression? {
        (Column(DatabaseTables.NotificationCategory.isServerControlled.rawValue) == true).sqlExpression
    }

    var primaryKeyValue: String { identifier }

    static func primaryKey(sourceIdentifier: String, serverIdentifier: String) -> String {
        #warning("multiserver - primary key duplication")
        return sourceIdentifier.uppercased()
    }

    init(primaryKey: String, serverIdentifier: String) {
        self.init(identifier: primaryKey, serverIdentifier: serverIdentifier)
    }

    mutating func update(with object: MobileAppConfigPushCategory, server: Server) -> Bool {
        precondition(identifier == object.identifier.uppercased())

        isServerControlled = true
        serverIdentifier = server.identifier.rawValue
        name = object.name
        actions = object.actions.map(NotificationAction.init(action:))

        return true
    }
}

// MARK: - Table

final class NotificationCategoryTable: DatabaseTableProtocol {
    var tableName: String { GRDBDatabaseTable.notificationCategory.rawValue }

    var definedColumns: [String] { DatabaseTables.NotificationCategory.allCases.map(\.rawValue) }

    func createIfNeeded(database: DatabaseQueue) throws {
        let shouldCreateTable = try database.read { db in
            try !db.tableExists(tableName)
        }
        if shouldCreateTable {
            try database.write { db in
                try db.create(table: tableName) { t in
                    t.primaryKey(DatabaseTables.NotificationCategory.identifier.rawValue, .text).notNull()
                    t.column(DatabaseTables.NotificationCategory.serverIdentifier.rawValue, .text).notNull()
                    t.column(DatabaseTables.NotificationCategory.name.rawValue, .text).notNull()
                    t.column(DatabaseTables.NotificationCategory.isServerControlled.rawValue, .boolean).notNull()
                    t.column(DatabaseTables.NotificationCategory.hiddenPreviewsBodyPlaceholder.rawValue, .text)
                    t.column(DatabaseTables.NotificationCategory.categorySummaryFormat.rawValue, .text)
                    t.column(DatabaseTables.NotificationCategory.sendDismissActions.rawValue, .boolean).notNull()
                    t.column(DatabaseTables.NotificationCategory.hiddenPreviewsShowTitle.rawValue, .boolean).notNull()
                    t.column(DatabaseTables.NotificationCategory.hiddenPreviewsShowSubtitle.rawValue, .boolean)
                        .notNull()
                    t.column(DatabaseTables.NotificationCategory.actions.rawValue, .jsonText).notNull()
                }
            }
        } else {
            try migrateColumns(database: database)
        }
    }
}
