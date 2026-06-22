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

/// A native article presented when a What's New item is tapped: a header icon, title, rich (Markdown) body,
/// and an optional action button that opens a link in a Safari sheet.
struct ArticleMessage: Equatable {
    struct Action: Equatable {
        let title: String
        let url: URL

        init(title: String, url: URL) {
            self.title = title
            self.url = url
        }
    }

    let icon: WhatsNewIcon
    let title: String
    let body: String
    let action: Action?

    init(icon: WhatsNewIcon, title: String, body: String, action: Action? = nil) {
        self.icon = icon
        self.title = title
        self.body = body
        self.action = action
    }
}

/// What happens when a What's New item is tapped. Both destinations are pushed onto the navigation stack.
enum WhatsNewItemDestination: Equatable {
    /// Opens the URL directly in an in-app Safari view.
    case link(URL)
    /// Shows a native article screen.
    case article(ArticleMessage)
}

struct WhatsNewItem: Identifiable, Equatable {
    let id: String
    let title: String
    let body: String
    let icon: WhatsNewIcon
    /// Optional destination opened when the user taps the item. When `nil`, the item is not interactive.
    let destination: WhatsNewItemDestination?

    init(
        id: String,
        title: String,
        body: String,
        icon: WhatsNewIcon,
        destination: WhatsNewItemDestination? = nil
    ) {
        self.id = id
        self.title = title
        self.body = body
        self.icon = icon
        self.destination = destination
    }
}

/// Stable identifier for a What's New release, used to track whether it has already been shown.
/// Keep the raw value stable for a given release so it is presented only once — independent of any later
/// changes to its targeted platforms, app version, or OS requirements.
///
/// ```swift
/// extension WhatsNewReleaseId {
///     static let dropOldOSSupport = WhatsNewReleaseId("drop-old-os-support-2026-06")
/// }
/// ```
struct WhatsNewReleaseId: RawRepresentable, Hashable {
    let rawValue: String
    init(_ rawValue: String) { self.rawValue = rawValue }
    init(rawValue: String) { self.rawValue = rawValue }
}

struct WhatsNewRelease: Identifiable, Equatable {
    /// Stable identity used for seen-state tracking. A release is shown at most once per `id`.
    let id: WhatsNewReleaseId
    let version: WhatsNewAppVersion
    let targetPlatforms: [WhatsNewTargetPlatform]
    /// Optional operating-system constraints. When `nil`, the release shows on every OS version of its
    /// target platforms.
    let osRequirements: WhatsNewOSRequirements?
    /// Optional custom screen title. When `nil`, the view uses the default localized "What's New" title.
    let title: String?
    let items: [WhatsNewItem]

    init(
        id: WhatsNewReleaseId,
        version: WhatsNewAppVersion,
        targetPlatforms: [WhatsNewTargetPlatform],
        osRequirements: WhatsNewOSRequirements? = nil,
        title: String? = nil,
        items: [WhatsNewItem]
    ) {
        precondition(!targetPlatforms.isEmpty)
        precondition(!items.isEmpty)
        self.id = id
        self.version = version
        self.targetPlatforms = targetPlatforms
        self.osRequirements = osRequirements
        self.title = title
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
