import Foundation

/// Keys of the WatchConnectivity application context (`updateApplicationContext`, latest-wins)
/// exchanged between the iPhone and the watch. Raw values cross the wire — never repurpose them.
///
/// The iPhone sends `complications`/`complicationConfigs`; the watch sends `activeFamilies`,
/// `watchModel`, `watchVersion`, `watchBattery` and `watchBatteryState`.
public enum WatchContext: String, CaseIterable {
    case servers
    case complications
    case complicationConfigs
    case activeFamilies
    case watchModel
    case watchVersion
    case watchBattery
    case watchBatteryState
}
