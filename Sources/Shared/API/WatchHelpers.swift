import Communicator
import Foundation
import ObjectMapper
import PromiseKit
import RealmSwift
#if os(watchOS)
import ClockKit
#endif

public extension HomeAssistantAPI {
    // Be mindful of 262.1kb maximum size for context - https://stackoverflow.com/a/35076706/486182
    @available(*, deprecated)
    private static var watchContext: Content {
        var content: Content = Communicator.shared.mostRecentlyReceievedContext.content

        if content["iphone_permanent_id"] != nil {
            content = [:]
        }

        #if os(iOS)
        if let connInfo = try? JSONEncoder().encode(Current.settingsStore.connectionInfo) {
            content["connection_info"] = connInfo
        }

        if let tokenInfo = try? JSONEncoder().encode(Current.settingsStore.tokenInfo) {
            content["token_info"] = tokenInfo
        }

        content["actions"] = Array(Current.realm().objects(Action.self)).toJSON()

        content["complications"] = Array(Current.realm().objects(WatchComplication.self)).toJSON()

        content["isOnInternalNetwork"] = Current.settingsStore.connectionInfo?.isOnInternalNetwork

        #elseif os(watchOS)

        let activeFamilies: [String]? = CLKComplicationServer.sharedInstance().activeComplications?.compactMap {
            ComplicationGroupMember(family: $0.family).rawValue
        }

        content["activeFamilies"] = activeFamilies
        content["watchModel"] = Current.device.systemModel()
        content["watchVersion"] = Current.device.systemVersion()

        #endif

        return content
    }

    @available(*, deprecated)
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
        } catch let error as NSError {
            Current.Log.error("Updating the context failed: \(error)")
            return error
        }

        Current.Log.verbose("Set the context to \(context)")
        return nil
    }

    @available(*, deprecated)
    func updateComplications(passively: Bool) -> Promise<Void> {
        #if os(iOS)
        guard case .paired = Communicator.shared.currentWatchState else {
            Current.Log.verbose("skipping complication updates; no paired watch")
            return .value(())
        }
        #endif

        let complications = Set(Current.realm().objects(WatchComplication.self))

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

        guard let server = Current.servers.all.first else {
            return .value(())
        }

        if passively {
            return Current.webhooks.sendPassive(identifier: .updateComplications, server: server, request: request)
        } else {
            return Current.webhooks.send(identifier: .updateComplications, server: server, request: request)
        }
    }
}
