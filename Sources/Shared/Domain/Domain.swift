import Foundation
import HAKit
import UIKit

public enum Domain: String, CaseIterable {
    case automation
    case button
    case climate
    case cover
    case fan
    case inputBoolean = "input_boolean"
    case inputButton = "input_button"
    case light
    case lock
    case scene
    case script
    case `switch`
    case sensor
    case binarySensor = "binary_sensor"
    case zone
    case person
    case camera
    case todo
    case airQuality = "air_quality"
    case alarmControlPanel = "alarm_control_panel"
    case alert
    case assistSatellite = "assist_satellite"
    case calendar
    case conversation
    case date
    case dateTime = "datetime"
    case deviceTracker = "device_tracker"
    case event
    case geoLocation = "geo_location"
    case group
    case humidifier
    case image
    case inputDatetime = "input_datetime"
    case inputNumber = "input_number"
    case inputSelect = "input_select"
    case inputText = "input_text"
    case lawnMower = "lawn_mower"
    case mediaPlayer = "media_player"
    case notify
    case number
    case remote
    case schedule
    case select
    case siren
    case stt
    case sun
    case text
    case time
    case tts
    case update
    case vacuum
    case valve
    case wakeWord = "wake_word"
    case waterHeater = "water_heater"
    case weather
    case counter
    case timer
    case aiTask = "ai_task"
    case configurator
    case imageProcessing = "image_processing"
    case infrared
    case plant
    case radioFrequency = "radio_frequency"
    case tag

    public init?(entityId: String) {
        let domainString = entityId.components(separatedBy: ".").first ?? ""
        self.init(rawValue: domainString)
    }

    public enum State: String, Codable {
        case locked
        case unlocked
        case jammed
        case locking
        case unlocking

        case on
        case off

        case opening
        case closing
        case closed
        case open

        case unknown
        case unavailable
    }

    public var states: [State] {
        var states: [State] = []
        switch self {
        case .cover:
            states = [.open, .closed, .opening, .closing]
        case .fan:
            states = [.on, .off]
        case .light:
            states = [.on, .off]
        case .lock:
            states = [.locked, .unlocked, .jammed, .locking, .unlocking]
        case .switch:
            states = [.on, .off]
        default:
            states = []
        }

        states.append(contentsOf: [.unavailable, .unknown])
        return states
    }

    /// - Parameter serverId: when provided, numeric states are formatted with the entity's display
    ///   precision from the local registry (same as widgets); non-numeric states and entities
    ///   without a registry row pass through unchanged.
    public func contextualStateDescription(for entity: HAEntity, serverId: String? = nil) -> String {
        // Climate reports its HVAC mode as state and its temperatures as attributes; combine them
        // the way the frontend does ("Heat · 21.5°").
        if self == .climate {
            return ClimateControlState(entity: entity).stateSummary
        }

        // Datetime-backed entities report a raw UTC ISO 8601 string as their state; render it the
        // way the frontend's automatic time format does rather than showing the machine format.
        if let timestampDescription = timestampStateDescription(for: entity) {
            return timestampDescription
        }

        let baseState = entity.localizedState.leadingCapitalized
        // The registry lookup is only worth its synchronous database read on the paths that render
        // the state value itself — enum states (on/off, locked, …) never need it.
        func adjustedBaseState() -> String {
            guard let serverId else { return baseState }
            return StatePrecision.adjustPrecision(
                serverId: serverId,
                entityId: entity.entityId,
                stateValue: baseState
            )
        }

        // Add unit of measurement if available
        if let unitOfMeasurement = entity.attributes.dictionary["unit_of_measurement"] {
            return "\(adjustedBaseState()) \(unitOfMeasurement)"
        }

        guard let state = Domain.State(rawValue: entity.state) else {
            return adjustedBaseState()
        }

        return stateForDeviceClass(entity.deviceClass, state: state)
    }

    /// Renders the datetime device classes the way the frontend's automatic format does: timestamps
    /// relative ("In 56 minutes"), dates absolute and localized. Nil for every other entity, and for
    /// a datetime entity whose state isn't currently a date (`unavailable`, `unknown`) so those keep
    /// their usual localized wording.
    private func timestampStateDescription(for entity: HAEntity) -> String? {
        switch entity.deviceClass {
        case .timestamp:
            return EntityTimestampFormatter.relativeDescription(for: entity.state)?.leadingCapitalized
        case .date:
            return EntityTimestampFormatter.dateDescription(for: entity.state)
        default:
            return nil
        }
    }

    public func stateForDeviceClass(_ deviceClass: DeviceClass, state: Domain.State) -> String {
        let baseState = localizedState(for: state.rawValue).leadingCapitalized
        // Provide context-aware descriptions for binary sensors with device classes
        if self == .binarySensor {
            switch deviceClass {
            case .door:
                return state == .on ?
                    CoreStrings.componentBinarySensorEntityComponentDoorStateOn :
                    CoreStrings.componentBinarySensorEntityComponentDoorStateOff
            case .window:
                return state == .on ?
                    CoreStrings.componentBinarySensorEntityComponentWindowStateOn :
                    CoreStrings.componentBinarySensorEntityComponentWindowStateOff
            case .garage, .garageDoor:
                return state == .on ?
                    CoreStrings.componentBinarySensorEntityComponentGarageDoorStateOn :
                    CoreStrings.componentBinarySensorEntityComponentGarageDoorStateOff
            case .lock:
                return state == .on ?
                    CoreStrings.componentBinarySensorEntityComponentLockStateOn :
                    CoreStrings.componentBinarySensorEntityComponentLockStateOff
            case .opening:
                return state == .on ?
                    CoreStrings.componentBinarySensorEntityComponentOpeningStateOn :
                    CoreStrings.componentBinarySensorEntityComponentOpeningStateOff
            case .presence:
                return state == .on ?
                    CoreStrings.componentBinarySensorEntityComponentPresenceStateOn :
                    CoreStrings.componentBinarySensorEntityComponentPresenceStateOff
            case .connectivity:
                return state == .on ?
                    CoreStrings.componentBinarySensorEntityComponentConnectivityStateOn :
                    CoreStrings.componentBinarySensorEntityComponentConnectivityStateOff
            case .gate:
                // Gate uses same open/closed as door
                return state == .on ?
                    CoreStrings.commonStateOpen :
                    CoreStrings.commonStateClosed
            case .shade:
                return state == .on ?
                    CoreStrings.componentCoverEntityComponentStateOpen :
                    CoreStrings.componentCoverEntityComponentStateClosed
            default:
                // For other device classes without specific strings, use generic on/off
                return state == .on ?
                    CoreStrings.componentBinarySensorEntityComponentStateOn :
                    CoreStrings.componentBinarySensorEntityComponentStateOff
            }
        }

        // Provide context-aware descriptions for covers with device classes
        if self == .cover {
            switch state {
            case .open:
                return CoreStrings.componentCoverEntityComponentStateOpen
            case .closed:
                return CoreStrings.componentCoverEntityComponentStateClosed
            case .opening, .closing:
                // For transitioning states, use localized state
                return baseState
            default:
                break
            }
        }

        // Provide context for locks
        if self == .lock {
            switch state {
            case .locked:
                return CoreStrings.componentLockEntityComponentStateLocked
            case .unlocked:
                return CoreStrings.componentLockEntityComponentStateUnlocked
            case .locking, .unlocking:
                // For transitioning states, add ellipsis to show in progress
                return baseState + "..."
            case .jammed:
                // For jammed state, add exclamation to show alert
                return baseState + "!"
            default:
                break
            }
        }
        return baseState
    }

    public func icon(deviceClass: String? = nil, state: State? = nil) -> MaterialDesignIcons {
        let deviceClass = DeviceClass(rawValue: deviceClass ?? "")
        var image: MaterialDesignIcons = .bookmarkIcon
        switch self {
        case .automation:
            image = .robotIcon
        case .button:
            image = MaterialDesignIcons.gestureTapButtonIcon
        case .climate:
            image = .thermostatIcon
        case .cover:
            image = imageForCover(deviceClass: deviceClass ?? .unknown, state: state ?? .unknown)
        case .fan:
            image = .fanIcon
        case .inputBoolean:
            image = .toggleSwitchOutlineIcon
        case .inputButton:
            image = .gestureTapButtonIcon
        case .light:
            image = .lightbulbIcon
        case .lock:
            image = .lockIcon
        case .scene:
            image = .paletteOutlineIcon
        case .script:
            image = .scriptTextOutlineIcon
        case .switch:
            image = .toggleSwitchVariantIcon
        case .sensor:
            image = .eyeIcon
        case .binarySensor:
            image = .radioboxBlankIcon
        case .zone:
            image = .mapIcon
        case .person:
            image = .accountIcon
        case .camera:
            image = .cameraIcon
        case .todo:
            image = .checkboxMarkedOutlineIcon
        case .airQuality:
            image = .airFilterIcon
        case .alarmControlPanel:
            image = .shieldHomeIcon
        case .alert:
            image = .alertIcon
        case .assistSatellite:
            image = .messageProcessingOutlineIcon
        case .calendar:
            image = .calendarIcon
        case .conversation:
            image = .forumOutlineIcon
        case .date:
            image = .calendarTodayIcon
        case .dateTime:
            image = .calendarClockIcon
        case .deviceTracker:
            image = .radarIcon
        case .event:
            image = .calendarStarIcon
        case .geoLocation:
            image = .mapMarkerRadiusIcon
        case .group:
            image = .googleCirclesCommunitiesIcon
        case .humidifier:
            image = .airHumidifierIcon
        case .image:
            image = .imageIcon
        case .inputDatetime:
            image = .calendarClockIcon
        case .inputNumber:
            image = .numericIcon
        case .inputSelect:
            image = .formatListBulletedIcon
        case .inputText:
            image = .formTextboxIcon
        case .lawnMower:
            image = .robotMowerIcon
        case .mediaPlayer:
            image = .castIcon
        case .notify:
            image = .messageIcon
        case .number:
            image = .numericIcon
        case .remote:
            image = .remoteIcon
        case .schedule:
            image = .calendarClockIcon
        case .select:
            image = .formatListBulletedIcon
        case .siren:
            image = .bullhornIcon
        case .stt:
            image = .microphoneMessageIcon
        case .sun:
            image = .whiteBalanceSunnyIcon
        case .text:
            image = .formTextboxIcon
        case .time:
            image = .clockOutlineIcon
        case .tts:
            image = .speakerMessageIcon
        case .update:
            image = .packageUpIcon
        case .vacuum:
            image = .robotVacuumIcon
        case .valve:
            image = .valveOpenIcon
        case .wakeWord:
            image = .microphoneIcon
        case .waterHeater:
            image = .waterBoilerIcon
        case .weather:
            image = .weatherPartlyCloudyIcon
        case .counter:
            image = .counterIcon
        case .timer:
            image = .timerOutlineIcon
        case .aiTask:
            image = .starFourPointsIcon
        case .configurator:
            image = .cogIcon
        case .imageProcessing:
            image = .imageFilterFramesIcon
        case .infrared:
            image = .ledOnIcon
        case .plant:
            image = .flowerIcon
        case .radioFrequency:
            image = .radioTowerIcon
        case .tag:
            image = .tagOutlineIcon
        }
        return image
    }

    /// Cover fallback icons, mirroring the frontend's `cover/icons.json` `entity_component` map
    /// (device class → open/closed default). The `_` (no/unknown device class) default is a window,
    /// matching the frontend, not curtains.
    private func imageForCover(deviceClass: DeviceClass, state: State) -> MaterialDesignIcons {
        if state == .closed {
            switch deviceClass {
            case .garage, .garageDoor:
                return MaterialDesignIcons.garageIcon
            case .gate:
                return MaterialDesignIcons.gateIcon
            case .shutter:
                return MaterialDesignIcons.windowShutterIcon
            case .blind:
                return MaterialDesignIcons.blindsHorizontalClosedIcon
            case .shade:
                return MaterialDesignIcons.rollerShadeClosedIcon
            case .curtain:
                return MaterialDesignIcons.curtainsClosedIcon
            case .door:
                return MaterialDesignIcons.doorClosedIcon
            case .damper:
                return MaterialDesignIcons.circleSlice8Icon
            case .window:
                return MaterialDesignIcons.windowClosedIcon
            default:
                return MaterialDesignIcons.windowClosedIcon
            }
        } else {
            switch deviceClass {
            case .garage, .garageDoor:
                return MaterialDesignIcons.garageOpenIcon
            case .gate:
                return MaterialDesignIcons.gateOpenIcon
            case .shutter:
                return MaterialDesignIcons.windowShutterOpenIcon
            case .blind:
                return MaterialDesignIcons.blindsHorizontalIcon
            case .shade:
                return MaterialDesignIcons.rollerShadeIcon
            case .curtain:
                return MaterialDesignIcons.curtainsIcon
            case .door:
                return MaterialDesignIcons.doorOpenIcon
            case .damper:
                return MaterialDesignIcons.circleIcon
            default:
                return MaterialDesignIcons.windowOpenIcon
            }
        }
    }

    /// Localized name of the domain, mapped to the correlated core string when available.
    public var name: String {
        switch self {
        case .automation:
            return CoreStrings.componentAutomationTitle
        case .button:
            return CoreStrings.componentButtonTitle
        case .climate:
            return CoreStrings.componentClimateTitle
        case .cover:
            return CoreStrings.componentCoverTitle
        case .fan:
            return CoreStrings.componentFanTitle
        case .inputBoolean:
            return CoreStrings.componentInputBooleanTitle
        case .inputButton:
            return CoreStrings.componentInputButtonTitle
        case .light:
            return CoreStrings.componentLightTitle
        case .lock:
            return CoreStrings.componentLockTitle
        case .scene:
            return CoreStrings.componentSceneTitle
        case .script:
            return CoreStrings.componentScriptTitle
        case .switch:
            return CoreStrings.componentSwitchTitle
        case .sensor:
            return CoreStrings.componentSensorTitle
        case .binarySensor:
            return CoreStrings.componentBinarySensorTitle
        case .person:
            return CoreStrings.componentPersonTitle
        case .camera:
            return CoreStrings.componentCameraTitle
        case .todo:
            return CoreStrings.componentTodoTitle
        case .alarmControlPanel:
            return CoreStrings.componentAlarmControlPanelTitle
        case .alert:
            return CoreStrings.componentAlertTitle
        case .assistSatellite:
            return CoreStrings.componentAssistSatelliteTitle
        case .calendar:
            return CoreStrings.componentCalendarTitle
        case .date:
            return CoreStrings.componentDateTitle
        case .dateTime:
            return CoreStrings.componentDatetimeTitle
        case .deviceTracker:
            return CoreStrings.componentDeviceTrackerTitle
        case .event:
            return CoreStrings.componentEventTitle
        case .geoLocation:
            return CoreStrings.componentGeoLocationTitle
        case .group:
            return CoreStrings.componentGroupTitle
        case .humidifier:
            return CoreStrings.componentHumidifierTitle
        case .image:
            return CoreStrings.componentImageTitle
        case .inputDatetime:
            return CoreStrings.componentInputDatetimeTitle
        case .inputNumber:
            return CoreStrings.componentInputNumberTitle
        case .inputSelect:
            return CoreStrings.componentInputSelectTitle
        case .inputText:
            return CoreStrings.componentInputTextTitle
        case .lawnMower:
            return CoreStrings.componentLawnMowerTitle
        case .mediaPlayer:
            return CoreStrings.componentMediaPlayerTitle
        case .notify:
            return CoreStrings.componentNotifyTitle
        case .number:
            return CoreStrings.componentNumberTitle
        case .remote:
            return CoreStrings.componentRemoteTitle
        case .schedule:
            return CoreStrings.componentScheduleTitle
        case .select:
            return CoreStrings.componentSelectTitle
        case .siren:
            return CoreStrings.componentSirenTitle
        case .sun:
            return CoreStrings.componentSunTitle
        case .text:
            return CoreStrings.componentTextTitle
        case .time:
            return CoreStrings.componentTimeTitle
        case .update:
            return CoreStrings.componentUpdateTitle
        case .vacuum:
            return CoreStrings.componentVacuumTitle
        case .valve:
            return CoreStrings.componentValveTitle
        case .waterHeater:
            return CoreStrings.componentWaterHeaterTitle
        case .weather:
            return CoreStrings.componentWeatherTitle
        case .timer:
            return CoreStrings.componentTimerTitle
        case .aiTask:
            return CoreStrings.componentAiTaskTitle
        case .configurator:
            return CoreStrings.componentConfiguratorTitle
        case .imageProcessing:
            return CoreStrings.componentImageProcessingTitle
        case .plant:
            return CoreStrings.componentPlantTitle
        case .tag:
            return CoreStrings.componentTagTitle
        case .zone, .airQuality, .conversation, .stt, .tts, .wakeWord, .counter, .infrared, .radioFrequency:
            return rawValue
        }
    }

    public var localizedDescription: String {
        name
    }

    public var isCarPlaySupported: Bool {
        Domain.carPlaySupported.contains(self)
    }

    public var isWatchSupported: Bool {
        Domain.watchSupported.contains(self)
    }

    /// Whether the watch shows this domain as a read-only item: tapping it runs nothing and opens
    /// the entity's details screen instead.
    public var isWatchDisplayOnly: Bool {
        Domain.watchDisplayOnly.contains(self)
    }

    /// Whether tapping an entity of this domain performs an action: its main action, or the
    /// state-aware lock handling (lock has no single main action).
    public var isActionable: Bool {
        mainAction != nil || self == .lock
    }

    /// Whether tapping this domain's entities opens a dedicated control screen (e.g. climate)
    /// rather than executing a single action.
    public var hasControlScreen: Bool {
        Domain.controlScreenDomains.contains(self)
    }

    /// Whether tapping this domain's entities always presents the domain's own confirmation
    /// (e.g. lock), so the per-item "require confirmation" setting has no effect.
    public var hasBuiltInConfirmation: Bool {
        Domain.builtInConfirmationDomains.contains(self)
    }

    /// Whether the entity icon changes with state/device class (e.g. cover open vs closed),
    /// so list UIs (CarPlay, watch) should render the live entity icon over a saved one.
    public var hasStateDependentIcon: Bool {
        [.cover, .inputBoolean, .light, .lock, .switch].contains(self)
    }

    /// Whether the domain's state adds no value in list UIs — scripts and scenes just report
    /// their last-triggered time.
    public var hasIrrelevantState: Bool {
        [.script, .scene].contains(self)
    }

    public func localizedState(for state: String) -> String {
        switch self {
        case .button, .inputButton, .scene:
            if let relativeDate = EntityTimestampFormatter.relativeDescription(for: state) {
                return relativeDate
            }
        default:
            break
        }
        return CoreStrings.getDomainStateLocalizedTitle(state: state) ?? FrontendStrings
            .getDefaultStateLocalizedTitle(state: state) ?? state
    }
}

// MARK: - Feature supported domains

public extension Domain {
    static let carPlaySupported: [Domain] = [
        .automation,
        .button,
        .climate,
        .cover,
        .fan,
        .humidifier,
        .inputBoolean,
        .inputButton,
        .light,
        .lock,
        .scene,
        .script,
        .switch,
        .vacuum,
        .valve,
    ]

    static let watchSupported: [Domain] = [
        .automation,
        .button,
        .cover,
        .fan,
        .humidifier,
        .inputBoolean,
        .inputButton,
        .light,
        .lock,
        .scene,
        .script,
        .switch,
        .valve,
    ]

    /// Sensor domains the watch can display but never run: tapping one opens its details screen
    /// (state, last update, attributes) instead of performing an action.
    static let watchDisplayOnly: [Domain] = [
        .sensor,
        .binarySensor,
    ]

    /// Domains whose entities are controlled through a dedicated control screen (pushed on CarPlay,
    /// presented as a sheet on the watch) instead of a single tap action — the same options the
    /// frontend's more-info dialog offers.
    static let controlScreenDomains: [Domain] = [
        .climate,
        .vacuum,
    ]

    /// Domains a spoken command can switch on and off. Narrowed to the domains whose on and off
    /// services differ, so "turn off" never re-activates a scene, and excluding locks, which carry
    /// their own confirmation rather than answering a phrase.
    static var voiceControllable: [Domain] {
        allCases.filter { $0.toggleIsStateAware && $0 != .lock }
    }

    /// Domains that always show their own confirmation when tapped (state-aware lock handling),
    /// making the per-item "require confirmation" customization irrelevant.
    static let builtInConfirmationDomains: [Domain] = [
        .lock,
    ]

    /// Everything the user can put on the watch home screen: the runnable domains, the display-only
    /// sensor ones, and the domains that open a control screen. This is the filter every watch
    /// picker and the watch database mirror use; `watchSupported` alone stays the list of domains
    /// the watch can execute with a single tap.
    static let watchAddable: [Domain] = watchSupported + watchDisplayOnly + controlScreenDomains

    /// Display order of the watch area screens' controllable entities, most commonly used domains
    /// first, covering every watch-runnable domain. Domains not listed sort last.
    static let watchAreaControlsOrder: [Domain] = [
        .light,
        .switch,
        .lock,
        .cover,
        .climate,
        .fan,
        .vacuum,
        .scene,
        .script,
        .humidifier,
        .valve,
        .inputBoolean,
        .button,
        .inputButton,
        .automation,
    ]

    /// Sort index into `watchAreaControlsOrder`; unknown or unlisted domains go last.
    static func watchAreaControlsSortIndex(for domain: Domain?) -> Int {
        guard let domain, let index = watchAreaControlsOrder.firstIndex(of: domain) else {
            return watchAreaControlsOrder.count
        }
        return index
    }

    static let sensorWidgetSupported: [Domain] = [
        .sensor,
        .binarySensor,
        .inputBoolean,
        .person,
        .lock,
        .number,
        .inputNumber,
        .inputText,
        .inputSelect,
        .select,
        .climate,
        .weather,
        .sun,
        .deviceTracker,
        .update,
    ]
}

// MARK: - Main Action

public extension Domain {
    /// The primary service to call when activating this domain.
    /// Returns nil for domains that don't have a single main action (e.g., sensors).
    /// A group has no services of its own, so its toggle is addressed to `serviceDomain`.
    var mainAction: Service? {
        switch self {
        case .automation:
            return .trigger
        case .button, .inputButton:
            return .press
        case .scene, .script:
            return .turnOn
        case .cover, .fan, .inputBoolean, .light, .switch, .humidifier, .valve, .group:
            return .toggle
        case .lock:
            return nil // Lock requires state-aware action (lock/unlock)
        case .sensor, .binarySensor, .zone, .person, .camera, .todo, .climate,
             .airQuality, .alarmControlPanel, .alert, .assistSatellite, .calendar, .conversation, .date,
             .dateTime, .deviceTracker, .event, .geoLocation, .image, .inputDatetime, .inputNumber,
             .inputSelect, .inputText, .lawnMower, .mediaPlayer, .notify, .number, .remote, .schedule,
             .select, .siren, .stt, .sun, .text, .time, .tts, .update, .vacuum, .wakeWord, .waterHeater,
             .weather, .counter, .timer, .aiTask, .configurator, .imageProcessing, .infrared, .plant,
             .radioFrequency, .tag:
            return nil // Read-only or complex domains
        }
    }
}
