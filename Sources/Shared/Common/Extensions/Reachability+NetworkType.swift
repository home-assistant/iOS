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

public enum NetworkType: Int, CaseIterable {
    case unknown
    case noConnection
    case wifi
    case cellular
    case wwan2g
    case wwan3g
    case wwan4g
    case wwan5g
    case unknownTechnology

    var description: String {
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
        case .wwan5g:
            return "5G"
        case .unknownTechnology:
            return "Unknown Technology"
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
        case .wwan5g:
            return "mdi:signal-5g"
        }
    }

    #if !targetEnvironment(macCatalyst)
    init(_ radioTech: String) {
        if #available(iOS 14.1, *), [CTRadioAccessTechnologyNR, CTRadioAccessTechnologyNRNSA].contains(radioTech) {
            // although these are declared available in 14.0, they will crash on use before 14.1
            self = .wwan5g
            return
        }

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
    #endif
}

public extension Reachability {

    static func getSimpleNetworkType() -> NetworkType {
        guard let reachability: Reachability = try? Reachability() else { return .unknown }
        do {
            try reachability.startNotifier()

            switch reachability.connection {
            case .none:
                return .noConnection
            case .wifi:
                return .wifi
            case .cellular:
                return .cellular
            case .unavailable:
                return .noConnection
            }
        } catch {
            return .unknown
        }
    }

    static func getNetworkType() -> NetworkType {
        guard let reachability: Reachability = try? Reachability() else { return .unknown }
        do {
            try reachability.startNotifier()

            switch reachability.connection {
            case .none:
                return .noConnection
            case .wifi:
                return .wifi
            case .cellular:
                #if !targetEnvironment(macCatalyst)
                    return Reachability.getWWANNetworkType()
                #else
                    return .cellular
                #endif
            case .unavailable:
                return .noConnection
            }
        } catch {
            return .unknown
        }
    }

    #if !targetEnvironment(macCatalyst)
    static func getWWANNetworkType() -> NetworkType {
        guard let currentRadioAccessTechnology = CTTelephonyNetworkInfo().currentRadioAccessTechnology else {
            return .unknown
        }
        return NetworkType(currentRadioAccessTechnology)
    }
    #endif
}
