import Foundation
import GRDB
import Shared

public struct CarPlayConfig: Codable, FetchableRecord, PersistableRecord {
    public var id = UUID().uuidString
    public var tabs: [CarPlayTab] = [.quickAccess, .areas, .domains, .settings]
    public var quickActions: [MagicItem] = []

    public init(
        id: String = UUID().uuidString,
        tabs: [CarPlayTab] = [.quickAccess, .areas, .domains, .settings],
        quickActions: [MagicItem] = []
    ) {
        self.id = id
        self.tabs = tabs
        self.quickActions = quickActions
    }
}

public enum CarPlayTab: String, Codable, CaseIterable {
    case quickAccess
    case areas
    case domains
    case settings

    var name: String {
        switch self {
        case .quickAccess:
            return L10n.CarPlay.Navigation.Tab.quickAccess
        case .areas:
            return L10n.CarPlay.Navigation.Tab.areas
        case .domains:
            return L10n.CarPlay.Navigation.Tab.domains
        case .settings:
            return L10n.CarPlay.Navigation.Tab.settings
        }
    }
}
