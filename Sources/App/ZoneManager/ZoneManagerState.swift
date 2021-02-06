import CoreLocation
import Foundation
import Shared

enum ZoneManagerState {
    case initialize
    case didReceive(ZoneManagerEvent)
    case didIgnore(ZoneManagerEvent, Error)
    case didError(Error)
    case didFailMonitoring(CLRegion?, Error)
    case didStartMonitoring(CLRegion)
}
