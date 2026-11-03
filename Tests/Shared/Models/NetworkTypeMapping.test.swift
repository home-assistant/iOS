import CoreTelephony
import Foundation
@testable import Shared
import Testing

/// `NetworkType` descriptions, icons and radio-technology mapping, and the path-based reachability
/// readings on whatever network the simulator has.
struct NetworkTypeMappingTests {
    @Test func everyTypeHasADescriptionAndIcon() {
        let descriptions = NetworkType.allCases.map(\.description)
        #expect(Set(descriptions).count == NetworkType.allCases.count)
        for type in NetworkType.allCases {
            #expect(type.icon.hasPrefix("mdi:"), "\(type)")
        }
    }

    @Test func radioTechnologiesMapToGenerations() {
        #expect(NetworkType(CTRadioAccessTechnologyNR) == .wwan5g)
        #expect(NetworkType(CTRadioAccessTechnologyNRNSA) == .wwan5g)
        for tech in [CTRadioAccessTechnologyGPRS, CTRadioAccessTechnologyEdge, CTRadioAccessTechnologyCDMA1x] {
            #expect(NetworkType(tech) == .wwan2g)
        }
        for tech in [
            CTRadioAccessTechnologyWCDMA, CTRadioAccessTechnologyHSDPA, CTRadioAccessTechnologyHSUPA,
            CTRadioAccessTechnologyCDMAEVDORev0, CTRadioAccessTechnologyCDMAEVDORevA,
            CTRadioAccessTechnologyCDMAEVDORevB, CTRadioAccessTechnologyeHRPD,
        ] {
            #expect(NetworkType(tech) == .wwan3g)
        }
        #expect(NetworkType(CTRadioAccessTechnologyLTE) == .wwan4g)
        #expect(NetworkType("CTRadioAccessTechnologyFuture") == .unknownTechnology)
    }

    /// Both mappings read the same connection, so they agree on it. Checked against fixed readings: two
    /// calls on a live `NetworkReachability` each read the monitor's path again, and the first can
    /// still see the unsatisfied path the monitor starts with while the second already sees Wi-Fi.
    @Test func bothMappingsAgreeOnOneReading() {
        #expect(NetworkReachability.simpleNetworkType(for: .unavailable) == .noConnection)
        #expect(NetworkReachability.networkType(for: .unavailable) == .noConnection)
        #expect(NetworkReachability.simpleNetworkType(for: .wifi) == .wifi)
        #expect(NetworkReachability.networkType(for: .wifi) == .wifi)
        #expect(NetworkReachability.simpleNetworkType(for: .cellular) == .cellular)
        // The detailed reading of a cellular path names the radio generation instead.
        #expect(Self.radioTypes.contains(NetworkReachability.networkType(for: .cellular)))
    }

    @Test func liveReachabilityReportsAConnectionType() {
        let reachability = NetworkReachability()
        #expect([.noConnection, .wifi, .cellular].contains(reachability.getSimpleNetworkType()))
        #expect(([.noConnection, .wifi] + Self.radioTypes).contains(reachability.getNetworkType()))
        #expect(Self.radioTypes.contains(NetworkReachability.getWWANNetworkType()))
    }

    /// What `getWWANNetworkType()` can return: a radio generation, or `.unknown` without a known radio.
    private static let radioTypes: [NetworkType] = [.unknown, .wwan2g, .wwan3g, .wwan4g, .wwan5g]
}
