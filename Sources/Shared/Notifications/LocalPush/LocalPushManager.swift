import UserNotifications
import HAKit
import PromiseKit

struct PushMessage: HADataDecodable {
    enum PushMessageError: Error {
        case invalidType
    }

    // todo: strongly type, keep sanitization in one place
    var data: [String: Any]

    init(data: HAData) throws {
        switch data {
        case let .dictionary(value): self.data = value
        default: throw PushMessageError.invalidType
        }
    }
}

public class LocalPushManager {
    struct SubscriptionInstance {
        let token: HACancellable
        let webhookID: String

        func cancel() {
            token.cancel()
        }
    }

    private var subscription: SubscriptionInstance?

    public init() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(updateSubscription),
            name: SettingsStore.connectionInfoDidChange,
            object: nil
        )

        updateSubscription()
    }

    deinit {
        subscription?.cancel()
    }

    @objc private func updateSubscription() {
        guard let webhookID = Current.settingsStore.connectionInfo?.webhookID else {
            // webhook is invalid, if there is a subscription we remove it
            subscription?.cancel()
            subscription = nil
            return
        }

        guard webhookID != subscription?.webhookID else {
            // webhookID hasn't changed, so we don't need to reset
            return
        }

        let request = HATypedSubscription<PushMessage>(request: .init(
            type: "mobile_app/push_notification_channel",
            data: ["webhook_id": webhookID]
        ))

        subscription = .init(
            token: Current.apiConnection.subscribe(to: request) { [weak self] _, value in
                self?.handle(event: value.data)
            },
            webhookID: webhookID
        )
    }

    private func handle(event serviceData: [String: Any]) {
        let content = Self.content(from: serviceData)
        let identifier = Self.identifier(from: serviceData)

        firstly {
            Current.api
        }.then { api in
            NotificationAttachmentManager().content(from: content, api: api)
        }.recover { error in
            Current.Log.error("failed to get content, giving default: \(error)")
            return .value(content)
        }.then { content -> Promise<Void> in
            let (promise, seal) = Promise<Void>.pending()
            let request = UNNotificationRequest(identifier: identifier, content: content, trigger: nil)
            UNUserNotificationCenter.current().add(request) { error in
                seal.resolve(error)
            }
            return promise
        }.done {
            Current.Log.info("added local notification")
        }.catch { error in
            Current.Log.error("failed to add local notification: \(error)")
        }
    }

    private static func identifier(from serviceData: [String: Any]) -> String {
        if let data = serviceData["data"] as? [String: Any],
           let headers = data["apns_headers"] as? [String: Any],
           let collapseId = headers["apns-collapse-id"] as? String {
            return collapseId
        } else {
            return UUID().uuidString
        }
    }

    private static func content(from serviceData: [String: Any]) -> UNNotificationContent {
        let content = UNMutableNotificationContent()
        content.title = serviceData["title"] as? String ?? ""
        content.body = serviceData["message"] as? String ?? ""

        if let data = serviceData["data"] as? [String: Any] {
            content.userInfo = data

            if let actionData = data["action_data"] as? [String: Any] {
                content.userInfo["homeassistant"] = actionData
            }

            update(content: content, for: data["push"] as? [String: Any] ?? [:])
        }

        return content
    }

    private static func update(content: UNMutableNotificationContent, for push: [String: Any]) {
        if let threadId = push["thread-id"] as? String {
            content.threadIdentifier = threadId
        }
        if let badge = push["badge"] as? Int {
            content.badge = NSNumber(value: badge)
        }
        if let category = push["category"] as? String {
            content.categoryIdentifier = category
        }
        if let subtitle = push["subtitle"] as? String {
            content.subtitle = subtitle
        }

        content.sound = Self.sound(for: push["sound"] as Any)
    }

    private static func sound(for sound: Any) -> UNNotificationSound? {
        let soundType: Sound

        if let sound = sound as? String {
            soundType = .init(name: sound)
        } else if let sound = sound as? [String: Any] {
            soundType = .init(dictionary: sound)
        } else {
            soundType = .init()
        }

        return soundType.asSound()
    }
}

private struct Sound {
    enum SoundType {
        case `default`
        case silent
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
        switch name.lowercased() {
        case "none":
            self.soundType = .silent
        case "default":
            self.soundType = .default
        default:
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
        switch soundType {
        case .silent: return nil
        case .default:
            if critical {
                if let level = level {
                    return .defaultCriticalSound(withAudioVolume: level)
                } else {
                    return .defaultCritical
                }
            } else {
                return .default
            }
        case let .named(name):
            if critical {
                if let level = level {
                    return .criticalSoundNamed(name, withAudioVolume: level)
                } else {
                    return .criticalSoundNamed(name)
                }
            } else {
                return .init(named: name)
            }
        }
    }
}
