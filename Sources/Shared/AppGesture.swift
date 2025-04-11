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
            L10n.Gestures.Category.homeAssistant
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
    case searchEntities
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
        case .showSidebar, .searchEntities:
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
        case .searchEntities:
            L10n.Gestures.Value.Option.MoreInfo.searchEntities
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
        }
    }
}

public enum AppGesture: CaseIterable, Codable {
    case swipeRight
    case swipeLeft
    case _3FingersSwipeUp
    //    case _3FingersSwipeDown
    case _3FingersSwipeLeft
    case _3FingersSwipeRight
    //    case _2FingersSwipeUp
    //    case _2FingersSwipeDown
    case _2FingersSwipeLeft
    case _2FingersSwipeRight
    case shake

    public var localizedString: String {
        switch self {
        case .swipeRight:
            return L10n.Gestures.SwipeRight.title
        case .swipeLeft:
            return L10n.Gestures.SwipeLeft.title
        case ._3FingersSwipeUp:
            return L10n.Gestures._3FingersSwipeUp.title
        //        case ._3FingersSwipeDown:
        //            return L10n.Gestures._3FingersSwipeDown.title
        case ._3FingersSwipeLeft:
            return L10n.Gestures._3FingersSwipeLeft.title
        case ._3FingersSwipeRight:
            return L10n.Gestures._3FingersSwipeRight.title
        //        case ._2FingersSwipeUp:
        //            return L10n.Gestures._2FingersSwipeUp.title
        //        case ._2FingersSwipeDown:
        //            return L10n.Gestures._2FingersSwipeDown.title
        case ._2FingersSwipeLeft:
            return L10n.Gestures._2FingersSwipeLeft.title
        case ._2FingersSwipeRight:
            return L10n.Gestures._2FingersSwipeRight.title
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
        //        case ._2FingersSwipeUp:
        //            2
        //        case ._2FingersSwipeDown:
        //            3
        case ._2FingersSwipeRight:
            4
        case ._2FingersSwipeLeft:
            5
        case ._3FingersSwipeUp:
            6
        //        case ._3FingersSwipeDown:
        //            7
        case ._3FingersSwipeRight:
            8
        case ._3FingersSwipeLeft:
            9
        case .shake:
            10
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
            //            case 2:
            //                return Current.settingsStore.gestures[._2FingersSwipeDown] ?? .none
            //            case 3:
            //                return Current.settingsStore.gestures[._3FingersSwipeDown] ?? .none
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
            //            case 2:
            //                return Current.settingsStore.gestures[._2FingersSwipeUp] ?? .none
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
