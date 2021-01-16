import Foundation
import PromiseKit
import Version

public struct ServerAlert: Codable, Equatable {
    public struct VersionRequirement: Codable, Equatable {
        var min: Version?
        var max: Version?

        // swiftlint:disable:next nesting
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
            if let min = min, let max = max {
                return compare >= min && compare <= max
            } else if let min = min {
                return compare >= min
            } else if let max = max {
                return compare <= max
            } else {
                // no provided min or max means it doesn't affect this version at all
                return false
            }
        }
    }

    public var url: URL
    public var message: String
    public var ios: VersionRequirement
    public var core: VersionRequirement
}

public class ServerAlerter {
    private var apiUrl: URL { URL(string: "https://companion.home-assistant.io/alerts.json")! }

    public func check() -> Promise<ServerAlert> {
        return firstly {
            URLSession.shared.dataTask(.promise, with: apiUrl)
        }.map { data, _ -> [ServerAlert] in
            // allows individual alerts to fail to parse, in case e.g. somebody typos something
            struct FailableServerAlert: Decodable {
                var alert: ServerAlert?
                init(from decoder: Decoder) throws {
                    alert = try? ServerAlert(from: decoder)
                }
            }
            return try JSONDecoder()
                .decode([FailableServerAlert].self, from: data)
                .compactMap(\.alert)
        }.get { updates in
            Current.Log.info("found alerts: \(updates)")
        }.filterValues {
            $0.ios.shouldTrigger(for: Current.clientVersion()) || $0.core.shouldTrigger(for: Current.serverVersion())
        }.filterValues { [self] alert in
            !isHandled(alert: alert)
        }.firstValue
    }

    private var allHandledKeys: String { "ServerAlerterViewedAlerts" }

    public func markHandled(alert: ServerAlert) {
        var viewed = Current.settingsStore.prefs.stringArray(forKey: allHandledKeys) ?? []
        viewed.append(alert.handledKey)
        Current.settingsStore.prefs.set(viewed, forKey: allHandledKeys)
    }

    private func isHandled(alert: ServerAlert) -> Bool {
        Current.settingsStore.prefs.stringArray(forKey: allHandledKeys)?.contains(alert.handledKey) == true
    }
}

private extension ServerAlert {
    var handledKey: String {
        "alert-viewed-\(url.absoluteString)"
    }
}
