import Foundation
import GRDB

public struct CarPlayConfig: Codable, FetchableRecord, PersistableRecord, Equatable {
    public static var carPlayConfigId = "carplay-config"
    public var id = CarPlayConfig.carPlayConfigId
    public var tabs: [CarPlayTab] = [.quickAccess, .areas, .settings]
    public var quickAccessItems: [MagicItem] = []
    public var quickAccessLayout: CarPlayQuickAccessLayout?
    public var showAddEditButtons: Bool?
    /// Folders created directly as tabs. They back a `.folder` tab like Quick Access folders do,
    /// but are not part of `quickAccessItems`, so the Quick Access tab never renders them.
    public var tabFolders: [MagicItem]?

    public init(
        id: String = CarPlayConfig.carPlayConfigId,
        tabs: [CarPlayTab] = [.quickAccess, .areas, .settings],
        quickAccessItems: [MagicItem] = [],
        quickAccessLayout: CarPlayQuickAccessLayout? = nil,
        showAddEditButtons: Bool? = nil,
        tabFolders: [MagicItem]? = nil
    ) {
        self.id = id
        self.tabs = tabs
        self.quickAccessItems = quickAccessItems
        self.quickAccessLayout = quickAccessLayout
        self.showAddEditButtons = showAddEditButtons
        self.tabFolders = tabFolders
    }

    public var resolvedQuickAccessLayout: CarPlayQuickAccessLayout {
        if let quickAccessLayout {
            return quickAccessLayout
        }

        return quickAccessItems.isEmpty ? .grid : .list
    }

    public var resolvedShowAddEditButtons: Bool {
        showAddEditButtons ?? true
    }

    public static func config() throws -> CarPlayConfig? {
        try Current.database().read({ db in
            try CarPlayConfig.fetchOne(db)
        })
    }

    /// Folders available in Quick Access; these can also be promoted to their own tab.
    public var folders: [MagicItem] {
        quickAccessItems.filter { $0.type == .folder }
    }

    /// Every folder a tab can reference: Quick Access folders plus tab-only folders.
    public var allFolders: [MagicItem] {
        folders + (tabFolders ?? [])
    }

    public func folder(withId folderId: String) -> MagicItem? {
        allFolders.first(where: { $0.type == .folder && $0.id == folderId })
    }

    /// Applies a mutation to the folder with the given id, wherever it lives — Quick Access items
    /// or tab-only folders. Returns true when the folder was found.
    @discardableResult
    public mutating func mutateFolder(withId folderId: String, _ mutation: (inout MagicItem) -> Void) -> Bool {
        if let index = quickAccessItems.firstIndex(where: { $0.type == .folder && $0.id == folderId }) {
            var folder = quickAccessItems[index]
            mutation(&folder)
            quickAccessItems[index] = folder
            return true
        }
        if let index = tabFolders?.firstIndex(where: { $0.type == .folder && $0.id == folderId }) {
            guard var folder = tabFolders?[index] else { return false }
            mutation(&folder)
            tabFolders?[index] = folder
            return true
        }
        return false
    }

    /// Display name for a tab, resolving folder tabs against this configuration's folders.
    public func name(for tab: CarPlayTab) -> String {
        tab.name(folders: allFolders)
    }
}

public enum CarPlayQuickAccessLayout: String, Codable, CaseIterable, DatabaseValueConvertible, Equatable {
    case grid
    case list

    public var name: String {
        switch self {
        case .grid:
            return L10n.HomeView.Customization.AreasLayout.Grid.title
        case .list:
            return L10n.HomeView.Customization.AreasLayout.List.title
        }
    }
}

public enum CarPlayTab: RawRepresentable, Codable, CaseIterable, DatabaseValueConvertible, Equatable, Hashable {
    /// Prefix used to persist folder tabs as plain strings, keeping the stored format compatible
    /// with the original String raw-value encoding used before folder tabs existed.
    private static let folderRawValuePrefix = "folder:"

    case quickAccess
    case areas
    case domains
    case settings
    /// A Quick Access folder promoted to its own tab; references the folder `MagicItem.id`.
    case folder(folderId: String)

    /// The fixed, built-in tabs. Folder tabs are user-created and are enumerated from the
    /// configuration's Quick Access folders instead.
    public static var allCases: [CarPlayTab] { [.quickAccess, .areas, .domains, .settings] }

    public init?(rawValue: String) {
        switch rawValue {
        case "quickAccess":
            self = .quickAccess
        case "areas":
            self = .areas
        case "domains":
            self = .domains
        case "settings":
            self = .settings
        default:
            guard rawValue.hasPrefix(Self.folderRawValuePrefix) else { return nil }
            self = .folder(folderId: String(rawValue.dropFirst(Self.folderRawValuePrefix.count)))
        }
    }

    public var rawValue: String {
        switch self {
        case .quickAccess:
            return "quickAccess"
        case .areas:
            return "areas"
        case .domains:
            return "domains"
        case .settings:
            return "settings"
        case let .folder(folderId):
            return Self.folderRawValuePrefix + folderId
        }
    }

    /// Explicit single-string Codable so the persisted format matches the original raw-value
    /// encoding (an associated-value enum would otherwise synthesize a keyed representation).
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let rawValue = try container.decode(String.self)
        guard let tab = Self(rawValue: rawValue) else {
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Unknown CarPlayTab raw value: \(rawValue)"
            )
        }
        self = tab
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }

    public var folderId: String? {
        guard case let .folder(folderId) = self else { return nil }
        return folderId
    }

    public var name: String {
        switch self {
        case .quickAccess:
            return L10n.CarPlay.Navigation.Tab.quickAccess
        case .areas:
            return L10n.CarPlay.Navigation.Tab.areas
        case .domains:
            return L10n.CarPlay.Navigation.Tab.domains
        case .settings:
            return L10n.CarPlay.Navigation.Tab.settings
        case .folder:
            return L10n.Watch.Configuration.Folder.defaultName
        }
    }

    /// Display name for the tab; folder tabs resolve their name from the folder item they reference.
    public func name(folders: [MagicItem]) -> String {
        guard let folderId,
              let folder = folders.first(where: { $0.type == .folder && $0.id == folderId }) else {
            return name
        }
        return folder.displayText ?? name
    }
}
