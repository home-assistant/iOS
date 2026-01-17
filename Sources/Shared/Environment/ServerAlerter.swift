import Foundation
import PromiseKit
import Version
import PMKFoundation
import HAKit

public struct ServerAlert: Codable, Equatable {
    public struct VersionRequirement: Codable, Equatable {
        var min: Version?
        var max: Version?

        private enum CodingKeys: CodingKey {
            case min, max
        }

        public init(min: Version?, max: Version?) {
            self.min = min
            self.max = max
        }

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)

            if let minString = try container.decodeIfPresent(String.self, forKey: .min) {
                self.min = try? Version(hassVersion: minString)
            } else {
                self.min = nil
            }

            if let maxString = try container.decodeIfPresent(String.self, forKey: .max) {
                self.max = try? Version(hassVersion: maxString)
            } else {
                self.max = nil
            }
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(min?.description, forKey: .min)
            try container.encode(max?.description, forKey: .max)
        }

        public func shouldTrigger(for compare: Version) -> Bool {
            if let min, let max {
                return compare >= min && compare <= max
            } else if let min {
                return compare >= min
            } else if let max {
                return compare <= max
            } else {
                // no provided min or max means it doesn't affect this version at all
                return false
            }
        }
    }

    public var id: String
    public var date: Date
    public var url: URL
    public var message: String
    public var adminOnly: Bool
    public var ios: VersionRequirement
    public var core: VersionRequirement

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decode(String.self, forKey: .id)
        self.date = try container.decode(Date.self, forKey: .date)
        self.url = try container.decode(URL.self, forKey: .url)
        self.message = try container.decode(String.self, forKey: .message)
        self.adminOnly = try container.decodeIfPresent(Bool.self, forKey: .adminOnly) ?? false
        self.ios = try container.decodeIfPresent(VersionRequirement.self, forKey: .ios) ?? .init(min: nil, max: nil)
        self.core = try container.decodeIfPresent(VersionRequirement.self, forKey: .core) ?? .init(min: nil, max: nil)
    }

    init(
        id: String,
        date: Date,
        url: URL,
        message: String,
        adminOnly: Bool,
        ios: VersionRequirement,
        core: VersionRequirement
    ) {
        self.id = id
        self.date = date
        self.url = url
        self.message = message
        self.adminOnly = adminOnly
        self.ios = ios
        self.core = core
    }

    public static func == (lhs: ServerAlert, rhs: ServerAlert) -> Bool {
        lhs.id == rhs.id
            && abs(lhs.date.timeIntervalSince(rhs.date)) < 1
            && lhs.url == rhs.url
            && lhs.message == rhs.message
            && lhs.adminOnly == rhs.adminOnly
            && lhs.ios == rhs.ios
            && lhs.core == rhs.core
    }
}

public class ServerAlerter {
    private var apiUrl: URL { URL(string: "https://alerts.home-assistant.io/mobile.json")! }

    enum AlerterError: LocalizedError {
        case privacyDisabled

        var errorDescription: String? {
            switch self {
            case .privacyDisabled:
                return "<privacy disabled>"
            }
        }
    }

    public func check(dueToUserInteraction: Bool) -> Promise<ServerAlert> {
        guard Current.settingsStore.privacy.alerts || dueToUserInteraction else {
            return .init(error: AlerterError.privacyDisabled)
        }

        return firstly {
            when(
                fulfilled:
                URLSession.shared.dataTask(.promise, with: apiUrl).map(\.data),
                when(fulfilled: Current.apis.compactMap(\.connection.caches.user).map { $0.once().promise })
            )
        }.map { [self] data, users -> [ServerAlert] in
            // allows individual alerts to fail to parse, in case e.g. somebody typos something
            struct FailableServerAlert: Decodable {
                var alert: ServerAlert?
                init(from decoder: Decoder) throws {
                    self.alert = try? ServerAlert(from: decoder)
                }
            }
            return try with(JSONDecoder()) {
                $0.dateDecodingStrategy = .iso8601
                $0.keyDecodingStrategy = .convertFromSnakeCase
            }
            .decode([FailableServerAlert].self, from: data)
            .compactMap(\.alert)
            .filter { alert in
                guard !isHandled(alert: alert) else {
                    return false
                }

                guard !alert.adminOnly || users.contains(where: \.isAdmin) else {
                    return false
                }

                if case let version = Current.clientVersion(), alert.ios.shouldTrigger(for: version) {
                    return true
                }

                for server in Current.servers.all where alert.core.shouldTrigger(for: server.info.version) {
                    return true
                }

                return false
            }
        }.firstValue
    }

    private var allHandledKeys: String { "ServerAlerterViewedAlerts" }

    public func markHandled(alert: ServerAlert) {
        var viewed = Current.settingsStore.prefs.stringArray(forKey: allHandledKeys) ?? []
        viewed.append(alert.id)
        Current.settingsStore.prefs.set(viewed, forKey: allHandledKeys)
    }

    private func isHandled(alert: ServerAlert) -> Bool {
        Current.settingsStore.prefs.stringArray(forKey: allHandledKeys)?.contains(alert.id) == true
    }
}

public extension HACache {
    /// Wrap a once subscription in a Guarantee
    ///
    /// - SeeAlso: `HACache.once(_:)`
    /// - Returns: The promies for the value, and a block to cancel
    func once() -> (promise: Guarantee<ValueType>, cancel: () -> Void) {
        let (guarantee, seal) = Guarantee<ValueType>.pending()
        let token = once(seal)
        return (promise: guarantee, cancel: token.cancel)
    }
}
