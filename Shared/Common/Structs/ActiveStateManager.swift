import Foundation

public protocol ActiveStateObserver: AnyObject {
    func activeStateDidChange(for manager: ActiveStateManager)
}

public class ActiveStateManager {
    public var canTrackActiveStatus: Bool {
        #if targetEnvironment(macCatalyst)
        return true
        #else
        return false
        #endif
    }

    public var isActive: Bool {
        precondition(canTrackActiveStatus)
        return !isScreensavering && !isLocked && !isSleeping && !isScreenOff && !isFastUserSwitched
    }

    public private(set) var isScreensavering = false
    public private(set) var isLocked = false
    public private(set) var isSleeping = false
    public private(set) var isScreenOff = false
    public private(set) var isFastUserSwitched = false

    init() {
        setup()
    }

    private var observers = NSHashTable<AnyObject>(options: .weakMemory)

    public func register(observer: ActiveStateObserver) {
        observers.add(observer)
    }

    public func unregister(observer: ActiveStateObserver) {
        observers.remove(observer)
    }

    private func setup() {
        let distributedNotificationCenter: NotificationCenter? = {
            #if targetEnvironment(macCatalyst)
            if let type = NSClassFromString("NSDistributedNotificationCenter") as? NotificationCenter.Type {
                return type.default
            } else {
                Current.Log.error("couldn't find distributed notification center")
                return nil
            }
            #else
            return nil
            #endif
        }()
        let workspaceNotificationCenter: NotificationCenter? = {
            #if targetEnvironment(macCatalyst)
            let center = NSClassFromString("NSWorkspace")?
                .value(forKeyPath: "sharedWorkspace.notificationCenter") as? NotificationCenter

            if let center = center {
                return center
            } else {
                Current.Log.error("couldn't find workspace notification center")
                return nil
            }
            #else
            return nil
            #endif
        }()

        for name in UpdateType.allCases {
            switch name.notification {
            case .distributed(let name):
                distributedNotificationCenter?.addObserver(
                    self,
                    selector: #selector(notificationDidPost(_:)),
                    name: name,
                    object: nil
                )
            case .workspace(let name):
                workspaceNotificationCenter?.addObserver(
                    self,
                    selector: #selector(notificationDidPost(_:)),
                    name: name,
                    object: nil
                )
            }
        }
    }

    @objc private func notificationDidPost(_ note: Notification) {
        Current.Log.verbose(note)

        if let type = UpdateType(notificationName: note.name) {
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
            case .screenOffStart, .screenOffEnd:
                return \.isScreenOff
            case .fastUserSwitchStart, .fastUserSwitchEnd:
                return \.isFastUserSwitched
            }
        }()

        let currentValue = self[keyPath: affectedKeyPath]
        let newValue = updateType.isStart

        guard currentValue != newValue else {
            Current.Log.info("ignoring \(updateType) from \(currentValue) to \(newValue)")
            return
        }

        let wasActive = isActive

        Current.Log.info("from \(updateType) setting its state to \(newValue)")
        self[keyPath: affectedKeyPath] = newValue

        if wasActive != isActive {
            Current.Log.info("notifying about change of active from \(wasActive) to \(isActive)")
            observers
                .allObjects
                .compactMap { $0 as? ActiveStateObserver }
                .forEach { $0.activeStateDidChange(for: self) }
        }
    }
}

private enum UpdateType: CaseIterable {
    case screensaverStart
    case screensaverEnd
    case lockStart
    case lockEnd
    case sleepStart
    case sleepEnd
    case screenOffStart
    case screenOffEnd
    case fastUserSwitchStart
    case fastUserSwitchEnd

    init?(notificationName name: Notification.Name) {
        let found = Self.allCases.first(where: {
            switch $0.notification {
            case .distributed(let caseName), .workspace(let caseName):
                return caseName == name
            }
        })

        if let found = found {
            self = found
        } else {
            return nil
        }
    }

    enum UpdateNotification {
        case distributed(Notification.Name)
        case workspace(Notification.Name)
    }

    var notification: UpdateNotification {
        switch self {
        // these distributed ones do not have constants we can access
        case .screensaverStart: return .distributed(.init(rawValue: "com.apple.screensaver.didstart"))
        case .screensaverEnd: return .distributed(.init(rawValue: "com.apple.screensaver.didstop"))
        case .lockStart: return .distributed(.init(rawValue: "com.apple.screenIsLocked"))
        case .lockEnd: return .distributed(.init(rawValue: "com.apple.screenIsUnlocked"))
        // these workspace ones do have constants, but they are in AppKit which we do not currently have access to
        case .sleepStart: return .workspace(.init("NSWorkspaceWillSleepNotification"))
        case .sleepEnd: return .workspace(.init("NSWorkspaceDidWakeNotification"))
        case .screenOffStart: return .workspace(.init("NSWorkspaceScreensDidSleepNotification"))
        case .screenOffEnd: return .workspace(.init("NSWorkspaceScreensDidWakeNotification"))
        case .fastUserSwitchStart: return .workspace(.init("NSWorkspaceSessionDidResignActiveNotification"))
        case .fastUserSwitchEnd: return .workspace(.init("NSWorkspaceSessionDidBecomeActiveNotification"))
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
        case .screenOffStart: return true
        case .screenOffEnd: return false
        case .fastUserSwitchStart: return true
        case .fastUserSwitchEnd: return false
        }
    }
}
