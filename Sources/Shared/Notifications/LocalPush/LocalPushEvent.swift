import Foundation
import HAKit
import UserNotifications

struct LocalPushEvent: HADataDecodable {
    enum LocalPushEventError: Error, Equatable {
        case invalidType
    }

    var identifier: String
    var content: UNNotificationContent

    init(data: HAData) throws {
        guard case let .dictionary(value) = data else {
            throw LocalPushEventError.invalidType
        }

        let (headers, payload) = NotificationParserLegacy.result(from: value)
        self.init(headers: headers, payload: payload)
    }

    init(headers: [String: Any], payload: [String: Any]) {
        if let collapseId = headers["apns-collapse-id"] as? String {
            self.identifier = collapseId
        } else {
            self.identifier = UUID().uuidString
        }
        self.content = Self.content(from: payload)
    }

    private static func content(from payload: [String: Any]) -> UNNotificationContent {
        let content = UNMutableNotificationContent()
        if let aps = payload["aps"] as? [String: Any] {
            if let alert = aps["alert"] as? [String: Any] {
                if let title = alert["title"] as? String {
                    content.title = title
                }
                if let subtitle = alert["subtitle"] as? String {
                    content.subtitle = subtitle
                }
                if let body = alert["body"] as? String {
                    content.body = body
                }
            }
            if let threadIdentifier = aps["thread-id"] as? String {
                content.threadIdentifier = threadIdentifier
            }
            if let badge = aps["badge"] as? Int {
                content.badge = NSNumber(value: badge)
            }
            if let categoryIdentifier = aps["category"] as? String {
                content.categoryIdentifier = categoryIdentifier
            }
            if let sound = aps["sound"] as? String {
                content.sound = Sound(name: sound).asSound()
            }
            if let sound = aps["sound"] as? [String: Any] {
                content.sound = Sound(dictionary: sound).asSound()
            }
        }
        content.userInfo = payload
        // swiftlint:disable:next force_cast
        return content.copy() as! UNNotificationContent
    }
}

private struct Sound {
    enum SoundType {
        case `default`
        case named(UNNotificationSoundName)
    }

    var soundType: SoundType
    var critical: Bool
    var level: Float?

    init(soundType: SoundType = .default, critical: Bool = false, level: Float? = nil) {
        self.soundType = soundType
        self.critical = critical
        self.level = level
    }

    init(name: String) {
        if name.lowercased() == "default" {
            self.soundType = .default
        } else {
            self.soundType = .named(.init(rawValue: name))
        }

        self.level = nil
        self.critical = false
    }

    init(dictionary: [String: Any]) {
        if let name = dictionary["name"] as? String {
            self.init(name: name)
        } else {
            self.init(soundType: .default)
        }

        if let volume = dictionary["volume"] as? Double {
            self.level = Float(volume)
        }

        if let criticalInt = dictionary["critical"] as? Int {
            self.critical = criticalInt != 0
        } else if let criticalBool = dictionary["critical"] as? Bool {
            self.critical = criticalBool
        } else {
            self.critical = false
        }
    }

    func asSound() -> UNNotificationSound? {
        let defaultSound: UNNotificationSound = {
            if critical {
                if let level = level {
                    return .defaultCriticalSound(withAudioVolume: level)
                } else {
                    return .defaultCritical
                }
            } else {
                return .default
            }
        }()

        switch soundType {
        case .default: return defaultSound
        case let .named(name):
            #if os(watchOS)
            return defaultSound
            #else
            if critical {
                if let level = level {
                    return .criticalSoundNamed(name, withAudioVolume: level)
                } else {
                    return .criticalSoundNamed(name)
                }
            } else {
                return .init(named: name)
            }
            #endif
        }
    }
}
