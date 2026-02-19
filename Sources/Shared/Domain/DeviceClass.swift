import Foundation

public enum DeviceClass: String, CaseIterable {
    case battery
    case cold
    case connectivity
    case door
    case garage
    case garageDoor = "garage_door"
    case gas
    case heat
    case humidity
    case illuminance
    case light
    case lock
    case moisture
    case motion
    case moving
    case occupancy
    case opening
    case plug
    case power
    case presence
    case pressure
    case problem
    case safety
    case smoke
    case sound
    case temperature
    case timestamp
    case vibration
    case window
    case gate
    case damper
    case shutter
    case curtain
    case blind
    case shade
    case restart
    case update
    case outlet
    case `switch`
    case unknown
}
