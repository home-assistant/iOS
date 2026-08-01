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
    case trigger = "trigger"
    case setTemperature = "set_temperature"
    case setHvacMode = "set_hvac_mode"
    case setFanMode = "set_fan_mode"
    case setSwingMode = "set_swing_mode"
    case setSwingHorizontalMode = "set_swing_horizontal_mode"
    case setPresetMode = "set_preset_mode"
    case setHumidity = "set_humidity"
}
