import Foundation

public protocol ActiveStateObserver: AnyObject {
    func activeStateDidChange(for manager: ActiveStateManager)
}

public class ActiveStateManager {
    private var observers = NSHashTable<AnyObject>(options: .weakMemory)

    var canTrackActiveStatus: Bool {
        #if targetEnvironment(macCatalyst)
        return true
        #else
        return false
        #endif
    }

    var isActive: Bool {
        precondition(canTrackActiveStatus)
        return !isScreensavering && !isLocked && !isSleeping
    }

    private(set) var isScreensavering = false
    private(set) var isLocked = false
    private(set) var isSleeping = false

    init() {
        setup()
    }

    public func register(observer: ActiveStateObserver) {
        observers.add(observer)
    }

    public func unregister(observer: ActiveStateObserver) {
        observers.remove(observer)
    }

    private func setup() {
        #if targetEnvironment(macCatalyst)
        if let type = NSClassFromString("NSDistributedNotificationCenter") as? NotificationCenter.Type,
           case let notificationCenter = type.default {
            for name in UpdateType.allCases.compactMap(\.distributedNotificationName) {
                notificationCenter.addObserver(
                    self,
                    selector: #selector(distributedNotificationDidPost(_:)),
                    name: name,
                    object: nil
                )
            }
        }
        #endif
    }

    @objc private func distributedNotificationDidPost(_ note: Notification) {
        Current.Log.verbose(note)

        if let type = UpdateType(distributedNotificationName: note.name) {
            handle(updateType: type)
        } else {
            Current.Log.error("unknown notification: \(note)")
        }
    }

    private func handle(updateType: UpdateType) {
        let affectedKeyPath: ReferenceWritableKeyPath<ActiveStateManager, Bool> = {
            switch updateType {
            case .screensaverStart, .screensaverEnd:
                return \.isScreensavering
            case .lockStart, .lockEnd:
                return \.isLocked
            case .sleepStart, .sleepEnd:
                return \.isSleeping
            }
        }()

        let currentValue = self[keyPath: affectedKeyPath]
        let newValue = updateType.isStart

        guard currentValue != newValue else {
            Current.Log.info("ignoring \(updateType) from \(currentValue) to \(newValue)")
            return
        }

        Current.Log.info("from \(updateType) setting its state to \(newValue)")
        self[keyPath: affectedKeyPath] = newValue

        observers
            .allObjects
            .compactMap { $0 as? ActiveStateObserver }
            .forEach { $0.activeStateDidChange(for: self) }
    }
}

private enum UpdateType: CaseIterable {
    case screensaverStart
    case screensaverEnd
    case lockStart
    case lockEnd
    case sleepStart
    case sleepEnd

    init?(distributedNotificationName name: Notification.Name) {
        if let found = Self.allCases.first(where: { $0.distributedNotificationName == name }) {
            self = found
        } else {
            return nil
        }
    }

    var distributedNotificationName: Notification.Name? {
        switch self {
        case .screensaverStart: return .init(rawValue: "com.apple.screensaver.didstart")
        case .screensaverEnd: return .init(rawValue: "com.apple.screensaver.didstop")
        case .lockStart: return .init(rawValue: "com.apple.screenIsLocked")
        case .lockEnd: return .init(rawValue: "com.apple.screenIsUnlocked")
        case .sleepStart: return nil
        case .sleepEnd: return nil
        }
    }

    var isStart: Bool {
        switch self {
        case .screensaverStart: return true
        case .screensaverEnd: return false
        case .lockStart: return true
        case .lockEnd: return false
        case .sleepStart: return true
        case .sleepEnd: return false
        }
    }
}
