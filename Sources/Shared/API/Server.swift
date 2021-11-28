import Foundation
import HAKit
import Version

public struct ServerSettingKey<ValueType>: RawRepresentable, Hashable, ExpressibleByStringLiteral {
    public var rawValue: String
    public init(rawValue: String) {
        self.rawValue = rawValue
    }

    public init(stringLiteral value: StringLiteralType) {
        self.rawValue = value
    }
}

public extension ServerSettingKey {
    static var overrideDeviceName: ServerSettingKey<String> { "override_device_name" }
}

public struct ServerInfo: Codable, Equatable {
    public var name: String
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
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        self.name = try container.decode(String.self, forKey: .name)
        self.sortOrder = try container.decode(Int.self, forKey: .sortOrder)
        self.connection = try container.decode(ConnectionInfo.self, forKey: .connectionInfo)
        self.token = try container.decode(TokenInfo.self, forKey: .tokenInfo)
        self.version = try container.decode(Version.self, forKey: .version)
        self.settings = try container.decode([String: Any].self, forKey: .settings)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(name, forKey: .name)
        try container.encode(sortOrder, forKey: .sortOrder)
        try container.encode(version, forKey: .version)
        try container.encode(connection, forKey: .connectionInfo)
        try container.encode(token, forKey: .tokenInfo)
        try container.encode(settings, forKey: .settings)
    }

    public init(
        name: String,
        connection: ConnectionInfo,
        token: TokenInfo,
        version: Version
    ) {
        self.name = name
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

    public mutating func setSetting<T>(value: T?, for key: ServerSettingKey<T>) {
        settings[key.rawValue] = value
    }

    public func setting<T>(for key: ServerSettingKey<T>) -> T? {
        settings[key.rawValue] as? T
    }

    public static func == (lhs: ServerInfo, rhs: ServerInfo) -> Bool {
        func equatable(_ settings: [String: Any]) -> Data {
            do {
                return try JSONSerialization.data(withJSONObject: settings, options: [.sortedKeys])
            } catch {
                return Data()
            }
        }

        return lhs.name == rhs.name
            && lhs.connection == rhs.connection
            && lhs.token == rhs.token
            && equatable(lhs.settings) == equatable(rhs.settings)
    }
}

public final class Server: Hashable, Comparable, CustomStringConvertible {
    public static var historicId: Identifier<Server> = "historic"

    public let identifier: Identifier<Server>
    public var info: ServerInfo {
        get {
            getter()
        }
        set {
            let oldValue = getter()
            setter(newValue)
            if newValue != oldValue {
                observers.values.forEach { observer in
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
    public typealias Setter = (ServerInfo) -> Void
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
            return lhs.info.name.localizedCaseInsensitiveCompare(rhs.info.name) == .orderedAscending
        }
    }

    public var description: String {
        identifier.description
    }
}
