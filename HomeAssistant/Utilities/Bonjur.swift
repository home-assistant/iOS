//
//  Bonjur.swift
//  HomeAssistant
//
//  Created by Stephan Vanterpool on 8/24/18.
//  Copyright © 2018 Robbie Trencheny. All rights reserved.
//

import DeviceKit
import Foundation
import Shared

class BonjourDelegate: NSObject, NetServiceBrowserDelegate, NetServiceDelegate {

    var resolving = [NetService]()
    var resolvingDict = [String: NetService]()

    // Browser methods

    func netServiceBrowser(_ netServiceBrowser: NetServiceBrowser,
                           didFind netService: NetService,
                           moreComing moreServicesComing: Bool) {
        NSLog("BonjourDelegate.Browser.didFindService")
        netService.delegate = self
        resolvingDict[netService.name] = netService
        netService.resolve(withTimeout: 0.0)
    }

    func netServiceDidResolveAddress(_ sender: NetService) {
        NSLog("BonjourDelegate.Browser.netServiceDidResolveAddress")
        if let txtRecord = sender.txtRecordData() {
            let serviceDict = NetService.dictionary(fromTXTRecord: txtRecord)
            let discoveryInfo = DiscoveryInfoFromDict(locationName: sender.name, netServiceDictionary: serviceDict)
            NotificationCenter.default.post(name: NSNotification.Name(rawValue: "homeassistant.discovered"),
                                            object: nil,
                                            userInfo: discoveryInfo.toJSON())
        }
    }

    func netServiceBrowser(_ netServiceBrowser: NetServiceBrowser,
                           didRemove netService: NetService,
                           moreComing moreServicesComing: Bool) {
        NSLog("BonjourDelegate.Browser.didRemoveService")
        let discoveryInfo: [NSObject: Any] = ["name" as NSObject: netService.name]
        NotificationCenter.default.post(name: NSNotification.Name(rawValue: "homeassistant.undiscovered"),
                                        object: nil,
                                        userInfo: discoveryInfo)
        resolvingDict.removeValue(forKey: netService.name)
    }

    private func DiscoveryInfoFromDict(locationName: String,
                                       netServiceDictionary: [String: Data]) -> DiscoveryInfoResponse {
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
        if let baseURL = outputDict["base_url"] as? String {
            if baseURL.hasSuffix("/") {
                outputDict["base_url"] = baseURL[..<baseURL.index(before: baseURL.endIndex)]
            }
        }
        return DiscoveryInfoResponse(JSON: outputDict)!
    }
}

class Bonjour {
    var nsb: NetServiceBrowser
    var nsp: NetService
    var nsdel: BonjourDelegate?

    init() {
        let device = Device()
        self.nsb = NetServiceBrowser()
        self.nsp = NetService(domain: "local", type: "_hass-ios._tcp.", name: device.name, port: 65535)
    }

    func buildPublishDict() -> [String: Data] {
        var publishDict: [String: Data] = [:]
        if let bundleVersion = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") {
            if let stringedBundleVersion = bundleVersion as? String {
                if let data = stringedBundleVersion.data(using: .utf8) {
                    publishDict["buildNumber"] = data
                }
            }
        }
        if let versionNumber = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") {
            if let stringedVersionNumber = versionNumber as? String {
                if let data = stringedVersionNumber.data(using: .utf8) {
                    publishDict["versionNumber"] = data
                }
            }
        }
        if let permanentID = DeviceUID.uid().data(using: .utf8) {
            publishDict["permanentID"] = permanentID
        }
        if let bundleIdentifier = Bundle.main.bundleIdentifier {
            if let data = bundleIdentifier.data(using: .utf8) {
                publishDict["bundleIdentifier"] = data
            }
        }
        return publishDict
    }

    func startDiscovery() {
        self.nsdel = BonjourDelegate()
        nsb.delegate = nsdel
        nsb.searchForServices(ofType: "_home-assistant._tcp.", inDomain: "local.")
    }

    func stopDiscovery() {
        nsb.stop()
    }

    func startPublish() {
        //        self.nsdel = BonjourDelegate()
        //        nsp.delegate = nsdel
        nsp.setTXTRecord(NetService.data(fromTXTRecord: buildPublishDict()))
        nsp.publish()
    }

    func stopPublish() {
        nsp.stop()
    }

}
