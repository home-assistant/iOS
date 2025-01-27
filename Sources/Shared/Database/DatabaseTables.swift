import Foundation

public enum GRDBDatabaseTable: String {
    case HAAppEntity = "hAAppEntity"
    case watchConfig
    case assistPipelines
    case carPlayConfig
    case clientEvent
    case appEntityRegistryListForDisplay
    case appPanel
    case customWidget
}

public enum DatabaseTables {
    public enum AppEntity: String {
        case id
        case entityId
        case serverId
        case domain
        case name
        case icon
    }

    public enum WatchConfig: String {
        case id
        case assist
        case items
    }

    // Assist pipelines
    public enum AssistPipelines: String {
        case serverId
        case preferredPipeline
        case pipelines
    }

    // CarPlay configuration
    public enum CarPlayConfig: String {
        case id
        case tabs
        case quickAccessItems
    }

    // Client events
    public enum ClientEvent: String {
        case id
        case text
        case type
        case jsonPayload
        case date
    }

    public enum AppEntityRegistryListForDisplay: String {
        case id
        case serverId
        case entityId
        case registry
    }

    public enum AppPanel: String {
        case id
        case serverId
        case icon
        case title
        case path
        case component
        case showInSidebar
    }

    public enum CustomWidget: String {
        case id
        case name
        case items
        case itemsStates
    }
}
