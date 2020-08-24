//
//  Bonjur.swift
//  HomeAssistant
//
//  Created by Stephan Vanterpool on 8/24/18.
//  Copyright © 2018 Robbie Trencheny. All rights reserved.
//

import Foundation
import Shared

public class BonjourDelegate: NSObject, NetServiceBrowserDelegate, NetServiceDelegate {

    var resolving = [NetService]()
    var resolvingDict = [String: NetService]()

    // Browser methods

    public func netServiceBrowser(_ netServiceBrowser: NetServiceBrowser, didFind netService: NetService,
                                  moreComing moreServicesComing: Bool) {
        Current.Log.verbose("BonjourDelegate.Browser.didFindService")
        netService.delegate = self
        resolvingDict[netService.name] = netService
        netService.resolve(withTimeout: 0.0)
    }

    public func netServiceDidResolveAddress(_ sender: NetService) {
        Current.Log.verbose("BonjourDelegate.Browser.netServiceDidResolveAddress")
        if let txtRecord = sender.txtRecordData() {
            let potentialServiceDict = NetService.dictionary(fromTXTRecord: txtRecord) as NSDictionary

            // This fixes a crash in 0.110, the root cause is the dictionary returned
            // above contains NSNull instead of NSData, which Swift will crash trying
            // to cast to the Swift dictionary. So we do it the hard way.
            let serviceDict = (potentialServiceDict as? [String: Any])?
                .compactMapValues { $0 as? Data } ?? [:]

            let discoveryInfo = DiscoveryInfoFromDict(locationName: sender.name, netServiceDictionary: serviceDict)
            discoveryInfo.AnnouncedFrom = sender.addresses?.compactMap { InternetAddress(data: $0)?.host } ?? []
            NotificationCenter.default.post(name: NSNotification.Name(rawValue: "homeassistant.discovered"),
                                            object: nil,
                                            userInfo: discoveryInfo.toJSON())
        }
    }

    public func netServiceBrowser(_ netServiceBrowser: NetServiceBrowser, didRemove netService: NetService,
                                  moreComing moreServicesComing: Bool) {
        Current.Log.verbose("BonjourDelegate.Browser.didRemoveService")
        let discoveryInfo: [NSObject: Any] = ["name" as NSObject: netService.name]
        NotificationCenter.default.post(name: NSNotification.Name(rawValue: "homeassistant.undiscovered"),
                                        object: nil,
                                        userInfo: discoveryInfo)
        resolvingDict.removeValue(forKey: netService.name)
    }

    private func DiscoveryInfoFromDict(locationName: String,
                                       netServiceDictionary: [String: Data]) -> DiscoveredHomeAssistant {
        var outputDict: [String: Any] = [:]
        for (key, value) in netServiceDictionary {
            outputDict[key] = String(data: value, encoding: .utf8)
            if outputDict[key] as? String == "true" || outputDict[key] as? String == "false" {
                if let stringedKey = outputDict[key] as? String {
                    outputDict[key] = Bool(stringedKey)
                }
            }
        }
        outputDict["location_name"] = locationName
        return DiscoveredHomeAssistant(JSON: outputDict)!
    }
}

public class Bonjour {
    private var nsb: NetServiceBrowser
    private var nsp: NetService
    private var nsdel: BonjourDelegate?

    public var browserIsRunning: Bool = false
    public var publishIsRunning: Bool = false

    public init() {
        self.nsb = NetServiceBrowser()
        self.nsp = NetService(
            domain: "local",
            type: "_hass-mobile-app._tcp.",
            name: Current.device.deviceName(),
            port: 65535
        )
    }

    private func buildPublishDict() -> [String: Data] {
        var publishDict: [String: Data] = [:]

        if let data = Constants.build.data(using: .utf8) {
            publishDict["buildNumber"] = data
        }

        if let data = Constants.version.data(using: .utf8) {
            publishDict["versionNumber"] = data
        }

        if let permanentID = Constants.PermanentID.data(using: .utf8) {
            publishDict["permanentID"] = permanentID
        }

        if let data = Constants.BundleID.data(using: .utf8) {
            publishDict["bundleIdentifier"] = data
        }

        return publishDict
    }

    public func startDiscovery() {
        self.browserIsRunning = true
        self.nsdel = BonjourDelegate()
        nsb.delegate = nsdel
        nsb.searchForServices(ofType: "_home-assistant._tcp.", inDomain: "local.")
    }

    public func stopDiscovery() {
        self.browserIsRunning = false
        nsb.stop()
    }

    public func startPublish() {
        //        self.nsdel = BonjourDelegate()
        //        nsp.delegate = nsdel
        self.publishIsRunning = true
        nsp.setTXTRecord(NetService.data(fromTXTRecord: buildPublishDict()))
        nsp.publish()
    }

    public func stopPublish() {
        self.publishIsRunning = false
        nsp.stop()
    }

}
