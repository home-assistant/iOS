//
//  Reachability+NetworkType.swift
//  Shared
//
//  Created by Robert Trencheny on 2/20/19.
//  Copyright © 2019 Robbie Trencheny. All rights reserved.
//

// From https://gist.github.com/speedoholic/1746ac93be8e26723ce4023f0f4d211a

import Foundation
import Reachability
import CoreTelephony

enum NetworkType: Int, CaseIterable {
    case unknown
    case noConnection
    case wifi
    case cellular
    case wwan2g
    case wwan3g
    case wwan4g
    case unknownTechnology

    var description: String {
        return self.trackingId
    }

    var trackingId: String {
        switch self {
        case .unknown:
            return "Unknown"
        case .noConnection:
            return "No Connection"
        case .wifi:
            return "Wi-Fi"
        case .cellular:
            return "Cellular"
        case .wwan2g:
            return "2G"
        case .wwan3g:
            return "3G"
        case .wwan4g:
            return "4G"
        case .unknownTechnology:
            return "Unknown Technology"
        }
    }

    var networkTypeInt: Int {
        switch self {
        case .unknown:
            return 9
        case .noConnection:
            return 9
        case .wifi:
            return 1
        case .cellular:
            return 8
        case .wwan2g:
            return 2
        case .wwan3g:
            return 3
        case .wwan4g:
            return 4
        case .unknownTechnology:
            return 9
        }
    }

    var icon: String {
        switch self {
        case .unknown, .unknownTechnology:
            return "mdi:help-circle"
        case .noConnection:
            return "mdi:sim-off"
        case .wifi:
            return "mdi:wifi"
        case .cellular:
            return "mdi:signal"
        case .wwan2g:
            return "mdi:signal-2g"
        case .wwan3g:
            return "mdi:signal-3g"
        case .wwan4g:
            return "mdi:signal-4g"
        }
    }

    init(_ radioTech: String) {
        switch radioTech {
        case CTRadioAccessTechnologyGPRS,
             CTRadioAccessTechnologyEdge,
             CTRadioAccessTechnologyCDMA1x:
            self = .wwan2g
        case CTRadioAccessTechnologyWCDMA,
             CTRadioAccessTechnologyHSDPA,
             CTRadioAccessTechnologyHSUPA,
             CTRadioAccessTechnologyCDMAEVDORev0,
             CTRadioAccessTechnologyCDMAEVDORevA,
             CTRadioAccessTechnologyCDMAEVDORevB,
             CTRadioAccessTechnologyeHRPD:
            self = .wwan3g
        case CTRadioAccessTechnologyLTE:
            self = .wwan4g
        default:
            Current.Log.warning("Unknown connection technology: \(radioTech)")
            self = .unknownTechnology
        }
    }
}

extension Reachability {

    static func getSimpleNetworkType() -> NetworkType {
        guard let reachability: Reachability = Reachability() else { return .unknown }
        do {
            try reachability.startNotifier()

            switch reachability.connection {
            case .none:
                return .noConnection
            case .wifi:
                return .wifi
            case .cellular:
                return .cellular
            }
        } catch {
            return .unknown
        }
    }

    static func getNetworkType() -> NetworkType {
        guard let reachability: Reachability = Reachability() else { return .unknown }
        do {
            try reachability.startNotifier()

            switch reachability.connection {
            case .none:
                return .noConnection
            case .wifi:
                return .wifi
            case .cellular:
                return Reachability.getWWANNetworkType()
            }
        } catch {
            return .unknown
        }
    }

    static func getWWANNetworkType() -> NetworkType {
        let ctT = CTTelephonyNetworkInfo()
        if #available(iOS 13.0, *) {
            guard let serviceID = ctT.dataServiceIdentifier, let techDict = ctT.serviceCurrentRadioAccessTechnology, let currentType = techDict[serviceID] else {
                return .unknown
            }
            return NetworkType(currentType)
        }
        // No way in iOS 12 to get something like 13's dataServiceIdentifier so
        // we can't access the active radio tech type.
        guard let currentRadioAccessTechnology = ctT.currentRadioAccessTechnology else {
            return .unknown
        }
        return NetworkType(currentRadioAccessTechnology)
    }

}
