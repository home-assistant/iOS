import Foundation

/// Keys of the WatchConnectivity application context (`updateApplicationContext`, latest-wins)
/// exchanged between the iPhone and the watch. Raw values cross the wire — never repurpose them.
///
/// The iPhone sends `complications`/`complicationConfigs`; the watch sends `activeFamilies`,
/// `watchModel` and `watchVersion`.
///
/// `watchBattery` and `watchBatteryState` used to be watch-sent keys here; the watch now reports its
/// battery to Home Assistant directly, as a `mobile_app` device of its own. Their raw values are
/// retired, not free for reuse.
public enum WatchContext: String, CaseIterable {
    case servers
    case complications
    case complicationConfigs
    case activeFamilies
    case watchModel
    case watchVersion
}
