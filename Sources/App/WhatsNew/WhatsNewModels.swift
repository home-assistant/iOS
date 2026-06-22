import Foundation
import SFSafeSymbols
import Shared
import UIKit
import Version

typealias MaterialDesignIcon = MaterialDesignIcons

struct WhatsNewAppVersion: Hashable, Comparable, CustomStringConvertible {
    let major: Int
    let minor: Int
    let patch: Int

    var description: String {
        "\(major).\(minor).\(patch)"
    }

    init(major: Int, minor: Int, patch: Int) {
        self.major = major
        self.minor = minor
        self.patch = patch
    }

    init(_ version: Version) {
        self.major = version.major
        self.minor = version.minor ?? 0
        self.patch = version.patch ?? 0
    }

    static func < (lhs: Self, rhs: Self) -> Bool {
        (lhs.major, lhs.minor, lhs.patch) < (rhs.major, rhs.minor, rhs.patch)
    }
}

enum WhatsNewTargetPlatform: String, Hashable {
    case iPhone
    case iPad
    case mac

    static var current: WhatsNewTargetPlatform {
        #if targetEnvironment(macCatalyst)
        return .mac
        #else
        switch UIDevice.current.userInterfaceIdiom {
        case .pad:
            return .iPad
        default:
            return .iPhone
        }
        #endif
    }
}

/// A semantic operating-system version (e.g. iOS 26.1 or macOS 15.4), used to target a `WhatsNewRelease`
/// at the OS versions where its features are actually available.
struct WhatsNewOSVersion: Hashable, Comparable, CustomStringConvertible {
    let major: Int
    let minor: Int
    let patch: Int

    var description: String {
        "\(major).\(minor).\(patch)"
    }

    init(major: Int, minor: Int = 0, patch: Int = 0) {
        self.major = major
        self.minor = minor
        self.patch = patch
    }

    init(_ version: OperatingSystemVersion) {
        self.major = version.majorVersion
        self.minor = version.minorVersion
        self.patch = version.patchVersion
    }

    static var current: WhatsNewOSVersion {
        WhatsNewOSVersion(ProcessInfo.processInfo.operatingSystemVersion)
    }

    static func < (lhs: Self, rhs: Self) -> Bool {
        (lhs.major, lhs.minor, lhs.patch) < (rhs.major, rhs.minor, rhs.patch)
    }
}

/// An inclusive operating-system version range with optional bounds.
///
/// Pass only `minimum` for "this version or later" (e.g. iOS 26+), only `maximum` for "this version or
/// earlier", or both for a closed range. Passing equal bounds targets a single version.
struct WhatsNewOSVersionRange: Hashable, CustomStringConvertible {
    let minimum: WhatsNewOSVersion?
    let maximum: WhatsNewOSVersion?

    init(minimum: WhatsNewOSVersion? = nil, maximum: WhatsNewOSVersion? = nil) {
        precondition(minimum != nil || maximum != nil, "A version range must define at least one bound")
        if let minimum, let maximum {
            precondition(minimum <= maximum, "minimum must not be greater than maximum")
        }
        self.minimum = minimum
        self.maximum = maximum
    }

    func contains(_ version: WhatsNewOSVersion) -> Bool {
        if let minimum, version < minimum {
            return false
        }
        if let maximum, version > maximum {
            return false
        }
        return true
    }

    var description: String {
        switch (minimum, maximum) {
        case let (minimum?, maximum?):
            return minimum == maximum ? "\(minimum)" : "\(minimum)...\(maximum)"
        case let (minimum?, nil):
            return "\(minimum)+"
        case let (nil, maximum?):
            return "...\(maximum)"
        case (nil, nil):
            return ""
        }
    }
}

/// Per-platform operating-system constraints for a `WhatsNewRelease`.
///
/// `iOS` applies to the iPhone and iPad platforms; `macOS` applies to the Mac (Catalyst) platform. A platform
/// with no matching constraint is unrestricted, so a release can target, for example, iOS 26+ while remaining
/// available on every macOS version it ships to.
struct WhatsNewOSRequirements: Hashable, CustomStringConvertible {
    let iOS: WhatsNewOSVersionRange?
    let macOS: WhatsNewOSVersionRange?

    init(iOS: WhatsNewOSVersionRange? = nil, macOS: WhatsNewOSVersionRange? = nil) {
        precondition(iOS != nil || macOS != nil, "OS requirements must constrain at least one platform")
        self.iOS = iOS
        self.macOS = macOS
    }

    func allows(platform: WhatsNewTargetPlatform, osVersion: WhatsNewOSVersion) -> Bool {
        switch platform {
        case .iPhone, .iPad:
            guard let iOS else { return true }
            return iOS.contains(osVersion)
        case .mac:
            guard let macOS else { return true }
            return macOS.contains(osVersion)
        }
    }

    /// Stable, human-readable component appended to a release's identity so releases that differ only by OS
    /// targeting are tracked (and shown) independently.
    var description: String {
        var parts: [String] = []
        if let iOS {
            parts.append("iOS\(iOS)")
        }
        if let macOS {
            parts.append("macOS\(macOS)")
        }
        return parts.joined(separator: ",")
    }
}

enum WhatsNewIcon: Equatable {
    case sfSymbol(SFSymbol)
    case materialDesign(MaterialDesignIcon)
}

enum WhatsNewItemId: Hashable {
    case whatsNewValidationIntro
    case whatsNewValidationPlatforms
    case testFlightIncludeEmail
}

struct WhatsNewItem: Identifiable, Equatable {
    let id: WhatsNewItemId
    let title: String
    let body: String
    let icon: WhatsNewIcon
}

struct WhatsNewRelease: Identifiable, Equatable {
    let version: WhatsNewAppVersion
    let targetPlatforms: [WhatsNewTargetPlatform]
    /// Optional operating-system constraints. When `nil`, the release shows on every OS version of its
    /// target platforms.
    let osRequirements: WhatsNewOSRequirements?
    let items: [WhatsNewItem]

    var id: String {
        releaseID
    }

    var releaseID: String {
        let platforms = Set(targetPlatforms)
            .map(\.rawValue)
            .sorted()
            .joined(separator: ",")
        var releaseID = "\(version)-\(platforms)"
        if let osRequirements {
            releaseID += "-\(osRequirements)"
        }
        return releaseID
    }

    init(
        version: WhatsNewAppVersion,
        targetPlatforms: [WhatsNewTargetPlatform],
        osRequirements: WhatsNewOSRequirements? = nil,
        items: [WhatsNewItem]
    ) {
        precondition(!targetPlatforms.isEmpty)
        precondition(!items.isEmpty)
        self.version = version
        self.targetPlatforms = targetPlatforms
        self.osRequirements = osRequirements
        self.items = items
    }

    /// Whether this release may be shown on `platform` running `osVersion`. A release with no OS
    /// requirements matches every OS version of its target platforms.
    func matches(platform: WhatsNewTargetPlatform, osVersion: WhatsNewOSVersion) -> Bool {
        guard targetPlatforms.contains(platform) else {
            return false
        }
        guard let osRequirements else {
            return true
        }
        return osRequirements.allows(platform: platform, osVersion: osVersion)
    }
}
