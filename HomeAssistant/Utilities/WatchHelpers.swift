//
//  WatchHelpers.swift
//  HomeAssistant
//
//  Created by Robert Trencheny on 2/27/19.
//  Copyright © 2019 Robbie Trencheny. All rights reserved.
//

import Foundation
import Communicator
import DeviceKit
import ObjectMapper
import PromiseKit
import RealmSwift
#if os(watchOS)
import ClockKit
#endif

extension HomeAssistantAPI {
    // Be mindful of 262.1kb maximum size for context - https://stackoverflow.com/a/35076706/486182
    private static var watchContext: JSONDictionary {
        var content: JSONDictionary = Communicator.shared.mostRecentlyReceievedContext.content

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
        content["watchModel"] = Device.identifier

        #endif

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

    public static func BuildWatchRenderTemplatePayload() -> [String: Any] {
        var templates = [String: [String: String]]()

        let complications = Current.realm().objects(WatchComplication.self)

        Current.Log.verbose("complications \(complications)")

        var activeFamilies: [String] = []

        #if os(iOS)
        let context = Communicator.shared.mostRecentlyReceievedContext.content
        Current.Log.verbose("""
            mostRecentlyReceievedContext.content
            \(String(describing: context["activeFamilies"])) \(context.keys)
        """)
        guard let contextFamilies = context["activeFamilies"] as? [String] else { return [:] }
        Current.Log.verbose("contextFamilies \(contextFamilies)")
        activeFamilies = contextFamilies
        #elseif os(watchOS)
        guard let activeComplications = CLKComplicationServer.sharedInstance().activeComplications else { return [:] }
        activeFamilies = activeComplications.compactMap { ComplicationGroupMember(family: $0.family).rawValue }
        #endif

        for complication in complications {
            Current.Log.verbose("Check complication family \(complication.Family.rawValue)")
            if activeFamilies.contains(complication.Family.rawValue) {
                Current.Log.verbose("ACTIVE COMPLICATION! \(complication), \(complication.Data)")
                if let textAreas = complication.Data["textAreas"] as? [String: [String: Any]] {
                    for (textAreaKey, textArea) in textAreas {
                        let key = "\(complication.Template.rawValue)|\(textAreaKey)"
                        Current.Log.verbose("Got textArea \(key), \(textArea)")
                        if let needsRender = textArea["textNeedsRender"] as? Bool,
                            let text = textArea["text"] as? String, needsRender {
                            Current.Log.verbose("TEXT NEEDS RENDER! \(key)")
                            templates[key] = ["template": text]
                        }
                    }
                }
            }
        }

        Current.Log.verbose("JSON payload to send \(templates)")

        return templates
    }

    public func updateComplications() -> Promise<[WatchComplication]> {
        let payload = HomeAssistantAPI.BuildWatchRenderTemplatePayload()

        if payload.isEmpty {
            Current.Log.verbose("No complications have templates, not sending the request!")
            return Promise.value([WatchComplication]())
        }

        return firstly { () -> Promise<Any> in
            Current.webhooks.sendEphemeral(request: .init(type: "render_template", data: payload))
        }.then { (respJSON: Any) -> Promise<[WatchComplication]> in
            Current.Log.verbose("Got JSON \(respJSON)")
            guard let jsonDict = respJSON as? [String: String] else {
                Current.Log.error("Unable to cast JSON to [String: [String: String]]!")
                return Promise.value([WatchComplication]())
            }

            Current.Log.verbose("JSON Dict1 \(jsonDict)")

            var updatedComplications: [WatchComplication] = []

            for (templateKey, renderedText) in jsonDict {
                let components = templateKey.components(separatedBy: "|")
                let rawTemplate = components[0]
                let textAreaKey = components[1]
                let pred = NSPredicate(format: "rawTemplate == %@", rawTemplate)
                let realm = Realm.live()
                guard let complication = realm.objects(WatchComplication.self).filter(pred).first else {
                    Current.Log.error("Couldn't get complication from DB for \(rawTemplate)")
                    continue
                }

                guard var storedAreas = complication.Data["textAreas"] as? [String: [String: Any]] else {
                    Current.Log.error("Couldn't cast stored areas")
                    continue
                }

                storedAreas[textAreaKey]!["renderedText"] = renderedText

                // swiftlint:disable:next force_try
                try! realm.write {
                    complication.Data["textAreas"] = storedAreas
                }

                updatedComplications.append(complication)

                Current.Log.verbose("complication \(complication.Data)")
            }

            if let syncError = HomeAssistantAPI.SyncWatchContext() {
                return Promise(error: syncError)
            }

            return Promise.value(updatedComplications)
        }
    }
}
