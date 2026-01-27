import Foundation
import UIKit

public enum HAGestureActionCategory: String, CaseIterable {
    case homeAssistant
    case page
    case servers
    case app
    case other

    public var localizedString: String {
        switch self {
        case .homeAssistant:
            L10n.Gestures.Category.homeAssistant
        case .page:
            L10n.Gestures.Category.page
        case .servers:
            L10n.Gestures.Category.servers
        case .app:
            L10n.Gestures.Category.app
        case .other:
            L10n.Gestures.Category.other
        }
    }
}

public enum HAGestureAction: String, Codable, CaseIterable {
    // Home Assistant
    case showSidebar
    case quickSearch
    case searchEntities
    case searchDevices
    case searchCommands
    case assist
    // Page
    case backPage
    case nextPage
    // Servers
    case showServersList
    case nextServer
    case previousServer
    // App screens
    case showSettings
    case openDebug
    // Other
    case none

    public var category: HAGestureActionCategory {
        switch self {
        case .showSidebar, .quickSearch, .searchEntities, .searchDevices, .searchCommands, .assist:
            .homeAssistant
        case .backPage, .nextPage:
            .page
        case .showServersList, .nextServer, .previousServer:
            .servers
        case .showSettings, .openDebug:
            .app
        case .none:
            .other
        }
    }

    public var localizedString: String {
        switch self {
        case .showSidebar:
            L10n.Gestures.Value.Option.showSidebar
        case .backPage:
            L10n.Gestures.Value.Option.backPage
        case .nextPage:
            L10n.Gestures.Value.Option.nextPage
        case .quickSearch:
            L10n.Gestures.Value.Option.quickSearch
        case .searchEntities:
            L10n.Gestures.Value.Option.searchEntities
        case .showServersList:
            L10n.Gestures.Value.Option.serversList
        case .nextServer:
            L10n.Gestures.Value.Option.nextServer
        case .previousServer:
            L10n.Gestures.Value.Option.previousServer
        case .showSettings:
            L10n.Gestures.Value.Option.showSettings
        case .none:
            L10n.Gestures.Value.Option.none
        case .openDebug:
            L10n.Gestures.Value.Option.openDebug
        case .searchDevices:
            L10n.Gestures.Value.Option.searchDevices
        case .searchCommands:
            L10n.Gestures.Value.Option.searchCommands
        case .assist:
            L10n.Gestures.Value.Option.assist
        }
    }

    public var moreInfo: String? {
        switch self {
        case .showSidebar:
            nil
        case .backPage:
            nil
        case .nextPage:
            nil
        case .quickSearch:
            L10n.Gestures.Value.Option.MoreInfo.quickSearch
        case .searchEntities:
            L10n.Gestures.Value.Option.MoreInfo.searchEntities
        case .searchCommands:
            L10n.Gestures.Value.Option.MoreInfo.searchCommands
        case .searchDevices:
            L10n.Gestures.Value.Option.MoreInfo.searchDevices
        case .showServersList:
            nil
        case .nextServer:
            nil
        case .previousServer:
            nil
        case .showSettings:
            nil
        case .none:
            nil
        case .openDebug:
            nil
        case .assist:
            nil
        }
    }
}

public enum AppGesture: CaseIterable, Codable {
    case swipeRight
    case swipeLeft
    case _3FingersSwipeUp
    case _3FingersSwipeLeft
    case _3FingersSwipeRight
    case _2FingersSwipeLeft
    case _2FingersSwipeRight
    case shake

    public var localizedString: String {
        switch self {
        case .swipeRight, .swipeLeft:
            return L10n.Gestures._1Finger.title
        case ._2FingersSwipeLeft,
             ._2FingersSwipeRight:
            return L10n.Gestures._2Fingers.title
        case ._3FingersSwipeUp,
             ._3FingersSwipeLeft,
             ._3FingersSwipeRight:
            return L10n.Gestures._3Fingers.title
        case .shake:
            return L10n.Gestures.Shake.title
        }
    }

    public var setupScreenOrder: Int {
        switch self {
        case .swipeRight:
            0
        case .swipeLeft:
            1
        case ._2FingersSwipeRight:
            2
        case ._2FingersSwipeLeft:
            3
        case ._3FingersSwipeUp:
            4
        case ._3FingersSwipeRight:
            5
        case ._3FingersSwipeLeft:
            6
        case .shake:
            7
        }
    }

    public var direction: UISwipeGestureRecognizer.Direction? {
        switch self {
        case .swipeRight:
            .right
        case .swipeLeft:
            .left
        case ._2FingersSwipeRight:
            .right
        case ._2FingersSwipeLeft:
            .left
        case ._3FingersSwipeUp:
            .up
        case ._3FingersSwipeRight:
            .right
        case ._3FingersSwipeLeft:
            .left
        default:
            nil
        }
    }
}

public extension [AppGesture: HAGestureAction] {
    static var defaultGestures: [AppGesture: HAGestureAction] {
        [
            .swipeRight: .showSidebar,
            ._2FingersSwipeRight: .backPage,
            ._2FingersSwipeLeft: .nextPage,
            ._3FingersSwipeUp: .showServersList,
            ._3FingersSwipeRight: .nextServer,
            ._3FingersSwipeLeft: .previousServer,
            .shake: .openDebug,
        ]
    }

    func getAction(for gesture: UISwipeGestureRecognizer, numberOfTouches: Int) -> HAGestureAction {
        switch gesture.direction {
        case .down:
            switch numberOfTouches {
            case 1:
                return .none
            default:
                return .none
            }
        case .left:
            switch numberOfTouches {
            case 1:
                return Current.settingsStore.gestures[.swipeLeft] ?? .none
            case 2:
                return Current.settingsStore.gestures[._2FingersSwipeLeft] ?? .none
            case 3:
                return Current.settingsStore.gestures[._3FingersSwipeLeft] ?? .none
            default:
                return .none
            }
        case .right:
            switch numberOfTouches {
            case 1:
                return Current.settingsStore.gestures[.swipeRight] ?? .none
            case 2:
                return Current.settingsStore.gestures[._2FingersSwipeRight] ?? .none
            case 3:
                return Current.settingsStore.gestures[._3FingersSwipeRight] ?? .none
            default:
                return .none
            }

        case .up:
            switch numberOfTouches {
            case 1:
                return .none
            case 3:
                return Current.settingsStore.gestures[._3FingersSwipeUp] ?? .none
            default:
                return .none
            }
        default:
            return .none
        }
    }
}
