import UserNotifications
import HAKit
import PromiseKit

struct LocalPushMessage: HADataDecodable {
    enum PushMessageError: Error {
        case invalidType
    }

    var headers: [String: Any]
    var payload: [String: Any]

    init(data: HAData) throws {
        switch data {
        case let .dictionary(value):
            (self.headers, self.payload) = NotificationParserLegacy.result(from: value)
        default:
            throw PushMessageError.invalidType
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

        let request = HATypedSubscription<LocalPushMessage>(request: .init(
            type: "mobile_app/push_notification_channel",
            data: ["webhook_id": webhookID]
        ))

        subscription?.cancel()
        subscription = .init(
            token: Current.apiConnection.subscribe(
                to: request,
                initiated: { [weak self] result in
                    self?.handle(initiated: result.map { _ in () })
                }, handler: { [weak self] _, value in
                    self?.handle(event: value)
                }
            ),
            webhookID: webhookID
        )
    }

    private func handle(initiated result: Swift.Result<Void, HAError>) {
        switch result {
        case let .failure(error):
            Current.Log.error("failed to subscribe to notifications: \(error)")
            subscription = nil
        case .success:
            Current.Log.info("started")
        }
    }

    private func handle(event pushMessage: LocalPushMessage) {
        Current.Log.debug("handling \(pushMessage)")

        let content = UNNotificationContent.content(from: pushMessage)
        let identifier = Self.identifier(from: pushMessage)
        let attachmentManager = NotificationAttachmentManager()

        firstly {
            Current.api
        }.then { api in
            attachmentManager.content(from: content, api: api)
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

    private static func identifier(from pushMessage: LocalPushMessage) -> String {
        if let collapseId = pushMessage.headers["apns-collapse-id"] as? String {
            return collapseId
        } else {
            return UUID().uuidString
        }
    }
}

extension UNNotificationContent {
    static func content(from pushMessage: LocalPushMessage) -> UNNotificationContent {
        let content = UNMutableNotificationContent()
        if let aps = pushMessage.payload["aps"] as? [String: Any] {
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
        content.userInfo = pushMessage.payload
        return content
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
