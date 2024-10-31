import Foundation
import GRDB
import Shared

public struct CarPlayConfig: Codable, FetchableRecord, PersistableRecord, Equatable {
    public var id = "carplay-config"
    public var tabs: [CarPlayTab] = [.quickAccess, .areas, .domains, .settings]
    public var quickAccessItems: [MagicItem] = []

    public init(
        id: String = UUID().uuidString,
        tabs: [CarPlayTab] = [.quickAccess, .areas, .domains, .settings],
        quickAccessItems: [MagicItem] = []
    ) {
        self.id = id
        self.tabs = tabs
        self.quickAccessItems = quickAccessItems
    }

    public static func getConfig() -> CarPlayConfig? {
        do {
            if let config: CarPlayConfig = try Current.database().read({ db in
                do {
                    return try CarPlayConfig.fetchOne(db)
                } catch {
                    Current.Log.error("Error fetching CarPlay config \(error)")
                }
                return nil
            }) {
                Current.Log.info("CarPlay configuration exists")
                return config
            } else {
                Current.Log.error("No CarPlay config found")
                return nil
            }
        } catch {
            Current.Log.error("Failed to access database (GRDB), error: \(error.localizedDescription)")
            return nil
        }
    }
}

public enum CarPlayTab: String, Codable, CaseIterable, DatabaseValueConvertible, Equatable {
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
