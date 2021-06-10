import CoreGraphics
import Foundation

public protocol ActiveStateObserver: AnyObject {
    func activeStateDidChange(for manager: ActiveStateManager)
}

public class ActiveStateManager {
    public var canTrackActiveStatus: Bool {
        Current.isCatalyst
    }

    public var isActive: Bool {
        isActiveExceptForIdle
            && !states.isIdle
    }

    private var isActiveExceptForIdle: Bool {
        !states.isScreensavering
            && !states.isLocked
            && !states.isSleeping
            && !states.isScreenOff
            && !states.isFastUserSwitched
            && !states.isTerminating
    }

    public struct States: Equatable {
        public var isScreensavering = false
        public var isLocked = false
        public var isSleeping = false
        public var isScreenOff = false
        public var isFastUserSwitched = false
        public var isIdle = false
        public var isTerminating = false

        public var attributes: [String: Any] { [
            "Idle": isIdle,
            "Screensaver": isScreensavering,
            "Locked": isLocked,
            "Screen Off": isScreenOff,
            "Fast User Switched": isFastUserSwitched,
            "Sleeping": isSleeping,
            "Terminating": isTerminating,
        ] }
    }

    public private(set) var states = States()

    public var minimumIdleTime: Measurement<UnitDuration> {
        get {
            if Current.settingsStore.prefs.object(forKey: UserDefaultsKeys.minimumIdleTime.rawValue) == nil {
                return .init(value: 5.0, unit: .minutes)
            } else {
                return .init(
                    value: Current.settingsStore.prefs.double(forKey: UserDefaultsKeys.minimumIdleTime.rawValue),
                    unit: .seconds
                )
            }
        }
        set {
            Current.settingsStore.prefs.set(
                newValue.converted(to: .seconds).value,
                forKey: UserDefaultsKeys.minimumIdleTime.rawValue
            )
        }
    }

    init() {
        setup()
    }

    internal var idleTimer: Timer? {
        willSet {
            Current.Log.info(newValue == nil ? "removing timer" : "starting timer")
            idleTimer?.invalidate()
        }
    }

    private var observers = NSHashTable<AnyObject>(options: .weakMemory)

    public func register(observer: ActiveStateObserver) {
        observers.add(observer)
    }

    public func unregister(observer: ActiveStateObserver) {
        observers.remove(observer)
    }

    private enum UserDefaultsKeys: String {
        case minimumIdleTime = "active_minimum_idle_time"
    }

    private static func distributedNotificationCenter() -> NotificationCenter? {
        if NSClassFromString("XCTest") != nil {
            return NotificationCenter.default
        }

        #if targetEnvironment(macCatalyst)
        return Current.macBridge.distributedNotificationCenter
        #else
        return NotificationCenter.default
        #endif
    }

    private static func workspaceNotificationCenter() -> NotificationCenter? {
        if NSClassFromString("XCTest") != nil {
            return NotificationCenter.default
        }

        #if targetEnvironment(macCatalyst)
        return Current.macBridge.workspaceNotificationCenter
        #else
        return NotificationCenter.default
        #endif
    }

    private func setup() {
        let distributedNotificationCenter = Self.distributedNotificationCenter()
        let workspaceNotificationCenter = Self.workspaceNotificationCenter()
        let defaultNotificationCenter = NotificationCenter.default

        for name in UpdateType.allCases {
            switch name.notification {
            case let .distributed(name):
                distributedNotificationCenter?.addObserver(
                    self,
                    selector: #selector(notificationDidPost(_:)),
                    name: name,
                    object: nil
                )
            case let .workspace(name):
                workspaceNotificationCenter?.addObserver(
                    self,
                    selector: #selector(notificationDidPost(_:)),
                    name: name,
                    object: nil
                )
            case let .default(name):
                defaultNotificationCenter.addObserver(
                    self,
                    selector: #selector(notificationDidPost(_:)),
                    name: name,
                    object: nil
                )
            case .none: break
            }
        }

        setupIdleTimer(isInitial: true)
    }

    private func setupIdleTimer(isInitial: Bool) {
        guard canTrackActiveStatus else {
            // Don't bother setting up idle timer if we aren't going to be used
            return
        }

        guard isActiveExceptForIdle else {
            // Inactive for a reason other than idle; we can turn off the timer until we're back to active
            idleTimer = nil
            return
        }

        guard idleTimer?.isValid != true else {
            // Timer is already set up, we don't need to do anything
            return
        }

        idleTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true, block: { [weak self] _ in
            self?.checkIdle()
        })

        if !isInitial {
            // If we're returning from another state, we may have had a cached idle value we want to fix
            idleTimer?.fire()
        }
    }

    private func activeDidChange() {
        Current.Log.info("notifying about change of active from \(!isActive) to \(isActive)")

        // in case we need to start/stop the idle timer
        setupIdleTimer(isInitial: false)

        observers
            .allObjects
            .compactMap { $0 as? ActiveStateObserver }
            .forEach { $0.activeStateDidChange(for: self) }
    }

    @objc private func notificationDidPost(_ note: Notification) {
        Current.Log.verbose(note)

        if let type = UpdateType(notificationName: note.name) {
            handle(updateType: type)
        } else {
            Current.Log.error("unknown notification: \(note)")
        }
    }

    private func checkIdle() {
        guard let currentTime = Current.device.idleTime() else {
            Current.Log.error("checking idle time on a platform which doesn't support it")
            return
        }

        let minimumTime = minimumIdleTime
        let shouldBeIdle = currentTime >= minimumTime

        if shouldBeIdle, !states.isIdle {
            Current.Log.info("idle time of \(currentTime) exceeds \(minimumTime)")
            handle(updateType: .idleStart)
        } else if !shouldBeIdle, states.isIdle {
            Current.Log.info("idle time of \(currentTime) is less than \(minimumTime)")
            handle(updateType: .idleEnd)
        }
    }

    private func handle(updateType: UpdateType) {
        let affectedKeyPath: WritableKeyPath<States, Bool> = {
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
            case .idleStart, .idleEnd:
                return \.isIdle
            case .terminateStart:
                return \.isTerminating
            }
        }()

        let currentValue = states[keyPath: affectedKeyPath]
        let newValue = updateType.isStart

        guard currentValue != newValue else {
            Current.Log.info("ignoring \(updateType) from \(currentValue) to \(newValue)")
            return
        }

        let oldStates = states

        Current.Log.info("from \(updateType) setting its state to \(newValue)")
        states[keyPath: affectedKeyPath] = newValue

        if oldStates != states {
            activeDidChange()
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
    case idleStart
    case idleEnd
    case terminateStart

    init?(notificationName name: Notification.Name) {
        let found = Self.allCases.first(where: {
            switch $0.notification {
            case let .distributed(caseName), let .workspace(caseName), let .default(caseName):
                return caseName == name
            case .none:
                return false
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
        case `default`(Notification.Name)
    }

    var notification: UpdateNotification? {
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
        // default notification center; likely some shim we post internally
        case .terminateStart:
            #if targetEnvironment(macCatalyst)
            return .default(Current.macBridge.terminationWillBeginNotification)
            #else
            return .default(.init("NonMac_terminationWillBeginNotification"))
            #endif
        // not notifications
        case .idleStart, .idleEnd: return nil
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
        case .idleStart: return true
        case .idleEnd: return false
        case .terminateStart: return true
        }
    }
}
