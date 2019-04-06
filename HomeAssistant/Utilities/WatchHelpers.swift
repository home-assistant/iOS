//
//  WatchHelpers.swift
//  HomeAssistant
//
//  Created by Robert Trencheny on 2/27/19.
//  Copyright © 2019 Robbie Trencheny. All rights reserved.
//

import Foundation
import Communicator
import Shared
import DeviceKit
#if os(watchOS)
import ClockKit
#endif

extension HomeAssistantAPI {
    public static var watchContext: JSONDictionary {
        var content: JSONDictionary = Communicator.shared.mostRecentlyReceievedContext.content

        #if os(iOS)
        if let connInfo = try? JSONEncoder().encode(Current.settingsStore.connectionInfo) {
            content["connection_info"] = String(data: connInfo, encoding: .utf8)
        }

        if let tokenInfo = try? JSONEncoder().encode(Current.settingsStore.tokenInfo) {
            content["token_info"] = String(data: tokenInfo, encoding: .utf8)
        }

        content["apiPassword"] = keychain["apiPassword"]
        content["webhook_id"] = Current.settingsStore.webhookID
        content["webhook_secret"] = Current.settingsStore.webhookSecret
        content["cloudhook_url"] = Current.settingsStore.cloudhookURL
        content["iphone_device_id"] = Current.settingsStore.deviceID
        content["iphone_permanent_id"] = Constants.PermanentID
        content["iphone_device_name"] = UIDevice.current.name

        #elseif os(watchOS)

        let activeFamilies: [String]? = CLKComplicationServer.sharedInstance().activeComplications?.compactMap {
            ComplicationGroupMember(family: $0.family).rawValue
        }

        content["activeComplications"] = activeFamilies
        content["watchModel"] = Device.identifier

        #endif

        Current.Log.verbose("Context content \(content)")

        return content
    }

    public static func SyncWatchContext() -> NSError? {

        #if os(iOS)
        guard Communicator.shared.currentWatchState.isPaired &&
            Communicator.shared.currentWatchState.isWatchAppInstalled else {
                Current.Log.warning("Tried to sync HAAPI config to watch but watch not paired or app not installed")
                return nil
        }
        #endif

        let context = Context(content: HomeAssistantAPI.watchContext)

        do {
            try Communicator.shared.sync(context: context)
        } catch let error as NSError {
            Current.Log.error("Updating the context failed: \(error)")
            return error
        }

        Current.Log.verbose("Set the context to \(context)")
        return nil
    }

}
