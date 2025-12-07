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
        content[WatchContext.servers.rawValue] = Current.servers.restorableState()

        // Get complications from GRDB
        do {
            let complications = try WatchComplicationGRDB.all()
            // Convert to JSON-compatible format
            content[WatchContext.complications.rawValue] = complications.map { complication in
                [
                    "identifier": complication.identifier,
                    "serverIdentifier": complication.serverIdentifier as Any,
                    "rawFamily": complication.rawFamily,
                    "rawTemplate": complication.rawTemplate,
                    "Data": complication.Data,
                    "CreatedAt": complication.createdAt,
                    "name": complication.name as Any,
                    "IsPublic": complication.isPublic,
                    "Template": complication.Template.rawValue,
                    "Family": complication.Family.rawValue,
                ]
            }
        } catch {
            Current.Log.error("Failed to fetch complications from GRDB: \(error)")
            content[WatchContext.complications.rawValue] = []
        }

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

    func updateComplications(passively: Bool) -> Promise<Void> {
        #if os(iOS)
        guard case .paired = Communicator.shared.currentWatchState else {
            Current.Log.verbose("skipping complication updates; no paired watch")
            return .value(())
        }
        #endif

        let complications: [WatchComplicationGRDB]
        do {
            complications = try WatchComplicationGRDB.forServer(identifier: server.identifier.rawValue)
        } catch {
            Current.Log.error("Failed to fetch complications from GRDB: \(error)")
            return Promise(error: error)
        }

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
