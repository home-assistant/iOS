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

enum WhatsNewIcon: Equatable {
    case sfSymbol(SFSymbol)
    case materialDesign(MaterialDesignIcon)
}

enum WhatsNewItemId: Hashable {
    case whatsNewValidationIntro
    case whatsNewValidationPlatforms
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
    let items: [WhatsNewItem]

    var id: String {
        releaseID
    }

    var releaseID: String {
        let platforms = Set(targetPlatforms)
            .map(\.rawValue)
            .sorted()
            .joined(separator: ",")
        return "\(version)-\(platforms)"
    }

    init(
        version: WhatsNewAppVersion,
        targetPlatforms: [WhatsNewTargetPlatform],
        items: [WhatsNewItem]
    ) {
        precondition(!targetPlatforms.isEmpty)
        precondition(!items.isEmpty)
        self.version = version
        self.targetPlatforms = targetPlatforms
        self.items = items
    }
}
