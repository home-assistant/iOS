import Foundation

public enum Service: String, CaseIterable {
    case turnOn = "turn_on"
    case turnOff = "turn_off"
    case toggle = "toggle"
    case press = "press"
    case lock = "lock"
    case unlock = "unlock"
    case open = "open"
    case openCover = "open_cover"
    case closeCover = "close_cover"
    case stopCover = "stop_cover"
    case setCoverPosition = "set_cover_position"
    case setPercentage = "set_percentage"
    case trigger = "trigger"
}
