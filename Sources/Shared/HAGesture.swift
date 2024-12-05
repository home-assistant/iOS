import Foundation
import UIKit

public enum HAGestureAction: String, Codable, CaseIterable {
    case showSidebar
    case backPage
    case nextPage
    case showServersList
    case nextServer
    case previousServer
    case showSettings
    case none

    public var localizedString: String {
        switch self {
        case .showSidebar:
            return L10n.Gestures.Value.Option.showSidebar
        case .backPage:
            return L10n.Gestures.Value.Option.backPage
        case .nextPage:
            return L10n.Gestures.Value.Option.nextPage
        case .showServersList:
            return L10n.Gestures.Value.Option.serversList
        case .nextServer:
            return L10n.Gestures.Value.Option.nextServer
        case .previousServer:
            return L10n.Gestures.Value.Option.previousServer
        case .showSettings:
            return L10n.Gestures.Value.Option.showSettings
        case .none:
            return L10n.Gestures.Value.Option.none
        }
    }
}

public enum HAGesture: CaseIterable, Codable {
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
        }
    }
}

public extension [HAGesture: HAGestureAction] {
    static var defaultGestures: [HAGesture: HAGestureAction] {
        [
            .swipeRight: .showSidebar,
            ._2FingersSwipeRight: .nextPage,
            ._2FingersSwipeLeft: .backPage,
            ._3FingersSwipeUp: .showServersList,
            ._3FingersSwipeRight: .nextServer,
            ._3FingersSwipeLeft: .previousServer,
            //            ._3FingersSwipeDown: .showSettings,
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
