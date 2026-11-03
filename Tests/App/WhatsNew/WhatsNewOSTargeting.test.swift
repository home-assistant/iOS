import Foundation
@testable import HomeAssistant
import Testing
import UIKit

/// The OS targeting of What's New releases: version ranges with either or both bounds, per-platform
/// requirements and their descriptions, and the current platform and OS version.
struct WhatsNewOSTargetingTests {
    private let v17 = WhatsNewOSVersion(major: 17)
    private let v18 = WhatsNewOSVersion(major: 18, minor: 2, patch: 1)
    private let v26 = WhatsNewOSVersion(major: 26)

    @Test func rangesDescribeAndContainTheirBounds() {
        let single = WhatsNewOSVersionRange(minimum: v18, maximum: v18)
        #expect(single.description == "18.2.1")
        #expect(single.contains(v18))
        #expect(!single.contains(v17))
        #expect(!single.contains(v26))

        let closed = WhatsNewOSVersionRange(minimum: v17, maximum: v26)
        #expect(closed.description == "17.0.0...26.0.0")
        #expect(closed.contains(v18))

        let upTo = WhatsNewOSVersionRange(maximum: v18)
        #expect(upTo.description == "...18.2.1")
        #expect(upTo.contains(v17))
        #expect(!upTo.contains(v26))

        let from = WhatsNewOSVersionRange(minimum: v18)
        #expect(from.description == "18.2.1+")
        #expect(from.contains(v26))
    }

    @Test func requirementsApplyPerPlatform() {
        let iOSOnly = WhatsNewOSRequirements(iOS: WhatsNewOSVersionRange(minimum: v26))
        #expect(!iOSOnly.allows(platform: .iPhone, osVersion: v18))
        #expect(iOSOnly.allows(platform: .iPad, osVersion: v26))
        // No macOS constraint: every Mac qualifies.
        #expect(iOSOnly.allows(platform: .mac, osVersion: v17))
        #expect(iOSOnly.description == "iOS26.0.0+")

        let macOnly = WhatsNewOSRequirements(macOS: WhatsNewOSVersionRange(maximum: v17))
        #expect(macOnly.allows(platform: .iPhone, osVersion: v26))
        #expect(!macOnly.allows(platform: .mac, osVersion: v26))
        #expect(macOnly.description == "macOS...17.0.0")

        let both = WhatsNewOSRequirements(
            iOS: WhatsNewOSVersionRange(minimum: v17),
            macOS: WhatsNewOSVersionRange(minimum: v26)
        )
        #expect(both.description == "iOS17.0.0+,macOS26.0.0+")
    }

    @Test func currentPlatformAndVersionMatchTheDevice() {
        let current = WhatsNewOSVersion.current
        #expect(current.major == ProcessInfo.processInfo.operatingSystemVersion.majorVersion)
        let expected: WhatsNewTargetPlatform = UIDevice.current.userInterfaceIdiom == .pad ? .iPad : .iPhone
        #expect(WhatsNewTargetPlatform.current == expected)

        #expect(WhatsNewReleaseId("release").rawValue == "release")
    }
}
