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
    case actions
    case complications
    case ssid = "SSID"
    case activeFamilies
    case watchModel
    case watchVersion
    case watchBattery
}

public extension HomeAssistantAPI {
    // Be mindful of 262.1kb maximum size for context - https://stackoverflow.com/a/35076706/486182
    private static var watchContext: Content {
        var content: Content = Communicator.shared.mostRecentlyReceievedContext.content

        #if os(iOS)
        content[WatchContext.servers.rawValue] = Current.servers.restorableState()

        content[WatchContext.actions.rawValue] = Array(Current.realm().objects(Action.self)).toJSON()

        content[WatchContext.complications.rawValue] = Array(Current.realm().objects(WatchComplication.self)).toJSON()

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
        WKInterfaceDevice.current().isBatteryMonitoringEnabled = true
        content[WatchContext.watchBattery.rawValue] = WKInterfaceDevice.current().batteryLevel

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

    func updateComplications(passively: Bool) -> Promise<Void> {
        #if os(iOS)
        guard case .paired = Communicator.shared.currentWatchState else {
            Current.Log.verbose("skipping complication updates; no paired watch")
            return .value(())
        }
        #endif

        let complications = Set(
            Current.realm().objects(WatchComplication.self)
                .filter("serverIdentifier = %@", server.identifier.rawValue)
        )

        guard let request = WebhookResponseUpdateComplications.request(for: complications) else {
            Current.Log.verbose("no complications need templates rendered")

            #if os(iOS)
            // in case the user deleted the last complication, sync that fact up to the watch
            _ = HomeAssistantAPI.SyncWatchContext()
            #else
            // in case the user updated just the complication's metadata, force a refresh
            WebhookResponseUpdateComplications.updateComplications()
            #endif

            return .value(())
        }

        if passively {
            return Current.webhooks.sendPassive(identifier: .updateComplications, server: server, request: request)
        } else {
            return Current.webhooks.send(identifier: .updateComplications, server: server, request: request)
        }
    }
}
