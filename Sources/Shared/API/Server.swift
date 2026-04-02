import Foundation
import HAKit
import Version

public protocol SettingValue {
    static var defaultSettingValue: Self { get }
}

extension Optional: SettingValue {
    public static var defaultSettingValue: Wrapped? { .none }
}

public struct ServerSettingKey<ValueType: SettingValue>: RawRepresentable, Hashable, ExpressibleByStringLiteral {
    public var rawValue: String
    public init(rawValue: String) {
        self.rawValue = rawValue
    }

    public init(stringLiteral value: StringLiteralType) {
        self.rawValue = value
    }
}

public enum ServerLocationPrivacy: String, CaseIterable, RawRepresentable, SettingValue {
    case exact
    case zoneOnly
    case never

    public static var defaultSettingValue: Self { .exact }
    public var localizedDescription: String {
        switch self {
        case .never: return L10n.Settings.ConnectionSection.LocationSendType.Setting.never
        case .exact: return L10n.Settings.ConnectionSection.LocationSendType.Setting.exact
        case .zoneOnly: return L10n.Settings.ConnectionSection.LocationSendType.Setting.zoneOnly
        }
    }
}

public enum ServerSensorPrivacy: String, CaseIterable, RawRepresentable, SettingValue {
    case all
    case none

    public static var defaultSettingValue: Self { .all }
    public var localizedDescription: String {
        switch self {
        case .all: return L10n.Settings.ConnectionSection.SensorSendType.Setting.all
        case .none: return L10n.Settings.ConnectionSection.SensorSendType.Setting.none
        }
    }
}

public extension ServerSettingKey {
    static var localName: ServerSettingKey<String?> { "local_name" }
    static var overrideDeviceName: ServerSettingKey<String?> { "override_device_name" }
    static var locationPrivacy: ServerSettingKey<ServerLocationPrivacy> { "privacy_location" }
    static var sensorPrivacy: ServerSettingKey<ServerSensorPrivacy> { "privacy_sensor" }
}

public struct ServerInfo: Codable, Equatable {
    public var name: String {
        if let local = setting(for: .localName), !local.isEmpty {
            return local
        } else {
            return remoteName
        }
    }

    public var remoteName: String
    public var hassDeviceId: String?
    public var sortOrder: Int
    public var version: Version
    public var connection: ConnectionInfo
    public var token: TokenInfo
    private var settings: [String: Any] {
        didSet {
            assert(JSONSerialization.isValidJSONObject(settings))
        }
    }

    enum CodingKeys: CodingKey {
        case id
        case sortOrder
        case name
        case version
        case connectionInfo
        case tokenInfo
        case settings
        case hassDeviceId
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        self.remoteName = try container.decode(String.self, forKey: .name)
        self.hassDeviceId = try container.decodeIfPresent(String.self, forKey: .hassDeviceId)
        self.sortOrder = try container.decode(Int.self, forKey: .sortOrder)
        self.connection = try container.decode(ConnectionInfo.self, forKey: .connectionInfo)
        self.token = try container.decode(TokenInfo.self, forKey: .tokenInfo)
        self.version = try container.decode(Version.self, forKey: .version)
        self.settings = try container.decode([String: Any].self, forKey: .settings)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(remoteName, forKey: .name)
        try container.encode(sortOrder, forKey: .sortOrder)
        try container.encode(version, forKey: .version)
        try container.encode(connection, forKey: .connectionInfo)
        try container.encode(token, forKey: .tokenInfo)
        try container.encode(settings, forKey: .settings)
        try container.encode(hassDeviceId, forKey: .hassDeviceId)
    }

    public init(
        name: String,
        connection: ConnectionInfo,
        token: TokenInfo,
        version: Version
    ) {
        self.remoteName = name
        self.sortOrder = Self.defaultSortOrder
        self.connection = connection
        self.token = token
        self.version = version
        self.settings = [:]
    }

    public static var defaultName: String {
        L10n.Settings.StatusSection.LocationNameRow.placeholder
    }

    public static var defaultSortOrder: Int { -1 }

    public mutating func setSetting<T: RawRepresentable>(value: T?, for key: ServerSettingKey<T>) {
        settings[key.rawValue] = value?.rawValue ?? T.defaultSettingValue
    }

    public mutating func setSetting(value: String?, for key: ServerSettingKey<String?>) {
        settings[key.rawValue] = value
    }

    public func setting<T: RawRepresentable>(for key: ServerSettingKey<T>) -> T {
        if let value = settings[key.rawValue] as? T.RawValue, let result = T(rawValue: value) {
            return result
        } else {
            return T.defaultSettingValue
        }
    }

    public func setting(for key: ServerSettingKey<String?>) -> String? {
        settings[key.rawValue] as? String
    }

    public static func == (lhs: ServerInfo, rhs: ServerInfo) -> Bool {
        func areEqual(_ lhsValue: Any, _ rhsValue: Any) -> Bool {
            switch (lhsValue, rhsValue) {
            case let (lhs as String, rhs as String):
                return lhs == rhs
            case let (lhs as Bool, rhs as Bool):
                return lhs == rhs
            case let (lhs as Int, rhs as Int):
                return lhs == rhs
            case let (lhs as Int8, rhs as Int8):
                return lhs == rhs
            case let (lhs as Int16, rhs as Int16):
                return lhs == rhs
            case let (lhs as Int32, rhs as Int32):
                return lhs == rhs
            case let (lhs as Int64, rhs as Int64):
                return lhs == rhs
            case let (lhs as UInt, rhs as UInt):
                return lhs == rhs
            case let (lhs as UInt8, rhs as UInt8):
                return lhs == rhs
            case let (lhs as UInt16, rhs as UInt16):
                return lhs == rhs
            case let (lhs as UInt32, rhs as UInt32):
                return lhs == rhs
            case let (lhs as UInt64, rhs as UInt64):
                return lhs == rhs
            case let (lhs as Float, rhs as Float):
                return lhs == rhs
            case let (lhs as Double, rhs as Double):
                return lhs == rhs
            case let (lhs as [Any], rhs as [Any]):
                guard lhs.count == rhs.count else { return false }
                for (lhsElement, rhsElement) in zip(lhs, rhs) where !areEqual(lhsElement, rhsElement) {
                    return false
                }
                return true
            case let (lhs as [String: Any], rhs as [String: Any]):
                return areEqualSettings(lhs, rhs)
            case let (lhs as AnyHashable, rhs as AnyHashable):
                return lhs == rhs
            case let (lhs as NSObject, rhs as NSObject):
                return lhs.isEqual(rhs)
            default:
                return false
            }
        }

        func areEqualSettings(_ lhsSettings: [String: Any], _ rhsSettings: [String: Any]) -> Bool {
            guard lhsSettings.count == rhsSettings.count else {
                return false
            }

            for (key, lhsValue) in lhsSettings {
                guard let rhsValue = rhsSettings[key], areEqual(lhsValue, rhsValue) else {
                    return false
                }
            }

            return true
        }

        return lhs.remoteName == rhs.remoteName
            && lhs.connection == rhs.connection
            && lhs.token == rhs.token
            && lhs.hassDeviceId == rhs.hassDeviceId
            && lhs.version == rhs.version
            && lhs.sortOrder == rhs.sortOrder
            && areEqualSettings(lhs.settings, rhs.settings)
    }
}

extension ServerInfo {
    // Used in the GRDB mirror so recovered servers have an explicit "no credentials"
    // state instead of accidentally persisting real auth tokens outside Keychain.
    static var mirrorPlaceholderToken: TokenInfo {
        .init(accessToken: "", refreshToken: "", expiration: .distantPast)
    }

    var mirroredForPersistence: ServerInfo {
        // Start from the full server info, then remove secrets before writing to GRDB.
        var info = self
        // The GRDB mirror is only for recovering non-secret server metadata if Keychain
        // entries disappear during the developer-account migration.
        info.token = Self.mirrorPlaceholderToken
        info.connection.cloudhookURL = nil
        info.connection.webhookSecret = nil
        info.connection.clientCertificate = nil
        return info
    }
}

public final class Server: Hashable, Comparable, CustomStringConvertible {
    public static let historicId: Identifier<Server> = "historic"

    public let identifier: Identifier<Server>
    public var info: ServerInfo {
        get {
            getter()
        }
        set {
            let oldValue = getter()
            let didUpdate = setter(newValue)
            if newValue != oldValue, didUpdate {
                for observer in observers.values {
                    DispatchQueue.main.async {
                        observer(newValue)
                    }
                }
            }
        }
    }

    public func update(_ block: (inout ServerInfo) -> Void) {
        var value = info
        block(&value)
        info = value
    }

    public func observe(_ block: @escaping Observer) -> HACancellable {
        let uuid = UUID()
        observers[uuid] = block
        return HABlockCancellable { [weak self] in
            self?.observers[uuid] = nil
        }
    }

    public typealias Getter = () -> ServerInfo
    public typealias Setter = (ServerInfo) -> Bool
    public typealias Observer = (ServerInfo) -> Void

    private let getter: Getter
    private let setter: Setter
    private var observers = [UUID: Observer]()

    public init(
        identifier: Identifier<Server>,
        getter: @escaping Getter,
        setter: @escaping Setter
    ) {
        self.identifier = identifier
        self.getter = getter
        self.setter = setter
    }

    public static func == (lhs: Server, rhs: Server) -> Bool {
        lhs.identifier == rhs.identifier
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(identifier)
    }

    public static func < (lhs: Server, rhs: Server) -> Bool {
        let lhsSO = lhs.info.sortOrder
        let rhsSO = rhs.info.sortOrder

        if lhsSO < rhsSO {
            return true
        } else if lhsSO > rhsSO {
            return false
        } else {
            return lhs.info.remoteName.localizedCaseInsensitiveCompare(rhs.info.remoteName) == .orderedAscending
        }
    }

    public var description: String {
        identifier.description
    }
}

#if !os(watchOS)
public extension Server {
    /// Triggers a refresh of this server's data from Home Assistant
    /// - Parameter forceUpdate: Whether to force the update regardless of cache state. Defaults to `false`.
    func refreshAppDatabase(forceUpdate: Bool = false) {
        Current.appDatabaseUpdater.update(server: self, forceUpdate: forceUpdate)
    }
}
#endif
