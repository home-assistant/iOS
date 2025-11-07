import Foundation

public enum GRDBDatabaseTable: String {
    case HAAppEntity = "hAAppEntity"
    case watchConfig
    case assistPipelines
    case carPlayConfig
    case appEntityRegistryListForDisplay
    case appPanel
    case customWidget
    case appArea

    // Dropped since 2025.2, now saved as json file
    // Context: https://github.com/groue/GRDB.swift/issues/1626#issuecomment-2623927815
    case clientEvent
}

public enum DatabaseTables {
    public enum AppEntity: String, CaseIterable {
        case id
        case entityId
        case serverId
        case domain
        case name
        case icon
        case rawDeviceClass
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

    // Table where it is store frontend related values such as
    // precision for sensors
    public enum AppEntityRegistryListForDisplay: String {
        case id
        case serverId
        case entityId
        case registry
    }

    // Sidebar dashboard panels
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

    // Areas from Home Assistant
    public enum AppArea: String {
        case id
        case serverId
        case areaId
        case name
        case aliases
        case picture
        case icon
        case entities
    }
}
