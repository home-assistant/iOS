import Communicator
import Foundation
import ObjectMapper
import PromiseKit
import RealmSwift
#if os(watchOS)
import ClockKit
import WatchKit
#endif

public enum WatchContext: String, CaseIterable {
    case servers
    case complications
    case ssid = "SSID"
    case activeFamilies
    case watchModel
    case watchVersion
    case watchBattery
    case watchBatteryState
}

public extension HomeAssistantAPI {
    // Be mindful of 262.1kb maximum size for context - https://stackoverflow.com/a/35076706/486182
    private static var watchContext: Content {
        var content: Content = Communicator.shared.mostRecentlyReceievedContext.content

        #if os(iOS)
        // Note: Servers are now synced via send/reply pattern, not context
        // See WatchHomeViewModel.requestServers() and WatchCommunicatorService.syncServers()

        #if targetEnvironment(simulator)
        content[WatchContext.ssid.rawValue] = "SimulatorWiFi"
        #else
        content[WatchContext.ssid.rawValue] = Current.connectivity.currentWiFiSSID()
        #endif

        #elseif os(watchOS)

        let activeFamilies: [String]? = CLKComplicationServer.sharedInstance().activeComplications?.compactMap {
            ComplicationGroupMember(family: $0.family).rawValue
        }

        content[WatchContext.activeFamilies.rawValue] = activeFamilies
        content[WatchContext.watchModel.rawValue] = Current.device.systemModel()
        content[WatchContext.watchVersion.rawValue] = Current.device.systemVersion()
        let currentWatchInterfaceDevice = WKInterfaceDevice.current()
        currentWatchInterfaceDevice.isBatteryMonitoringEnabled = true
        content[WatchContext.watchBattery.rawValue] = currentWatchInterfaceDevice.batteryLevel
        content[WatchContext.watchBatteryState.rawValue] = currentWatchInterfaceDevice.batteryState.rawValue

        #endif

        return content
    }

    static func SyncWatchContext() -> NSError? {
        #if os(iOS)
        guard case .paired(.installed) = Communicator.shared.currentWatchState else {
            Current.Log.warning("Tried to sync HAAPI config to watch but watch not paired or app not installed")
            return nil
        }
        #endif

        let context = Context(content: HomeAssistantAPI.watchContext)

        do {
            try Communicator.shared.sync(context)
            Current.Log.info("updated context")
        } catch let error as NSError {
            Current.Log.error("Updating the context failed: \(error)")
            return error
        }

        return nil
    }
}
