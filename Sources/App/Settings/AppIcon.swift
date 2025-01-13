import Foundation
import Shared

enum AppIcon: String, CaseIterable {
    case Release = "release"
    case Beta = "beta"
    case Dev = "dev"
    case Black = "black"
    case Blue = "blue"
    case CaribbeanGreen = "caribbean-green"
    case CornflowerBlue = "cornflower-blue"
    case Crimson = "crimson"
    case ElectricViolet = "electric-violet"
    case FireOrange = "fire-orange"
    case Green = "green"
    case Classic = "classic"
    case OldBeta = "old-beta"
    case OldDev = "old-dev"
    case OldRelease = "old-release"
    case Orange = "orange"
    case Pink = "pink"
    case Purple = "purple"
    case Red = "red"
    case White = "white"
    case BiPride = "bi_pride"
    case POCPride = "POC_pride"
    case NonBinary = "non-binary"
    case Rainbow = "rainbow"
    case Trans = "trans"

    var title: String {
        switch self {
        case .Release:
            return L10n.SettingsDetails.General.AppIcon.Enum.release
        case .Beta:
            return L10n.SettingsDetails.General.AppIcon.Enum.beta
        case .Dev:
            return L10n.SettingsDetails.General.AppIcon.Enum.dev
        case .Black:
            return L10n.SettingsDetails.General.AppIcon.Enum.black
        case .Blue:
            return L10n.SettingsDetails.General.AppIcon.Enum.blue
        case .CaribbeanGreen:
            return L10n.SettingsDetails.General.AppIcon.Enum.caribbeanGreen
        case .CornflowerBlue:
            return L10n.SettingsDetails.General.AppIcon.Enum.cornflowerBlue
        case .Crimson:
            return L10n.SettingsDetails.General.AppIcon.Enum.crimson
        case .ElectricViolet:
            return L10n.SettingsDetails.General.AppIcon.Enum.electricViolet
        case .FireOrange:
            return L10n.SettingsDetails.General.AppIcon.Enum.fireOrange
        case .Green:
            return L10n.SettingsDetails.General.AppIcon.Enum.green
        case .Classic:
            return L10n.SettingsDetails.General.AppIcon.Enum.classic
        case .OldBeta:
            return L10n.SettingsDetails.General.AppIcon.Enum.oldBeta
        case .OldDev:
            return L10n.SettingsDetails.General.AppIcon.Enum.oldDev
        case .OldRelease:
            return L10n.SettingsDetails.General.AppIcon.Enum.oldRelease
        case .Orange:
            return L10n.SettingsDetails.General.AppIcon.Enum.orange
        case .Pink:
            return L10n.SettingsDetails.General.AppIcon.Enum.pink
        case .Purple:
            return L10n.SettingsDetails.General.AppIcon.Enum.purple
        case .Red:
            return L10n.SettingsDetails.General.AppIcon.Enum.red
        case .White:
            return L10n.SettingsDetails.General.AppIcon.Enum.white
        case .BiPride:
            return L10n.SettingsDetails.General.AppIcon.Enum.prideBi
        case .POCPride:
            return L10n.SettingsDetails.General.AppIcon.Enum.pridePoc
        case .Rainbow:
            return L10n.SettingsDetails.General.AppIcon.Enum.prideRainbow
        case .Trans:
            return L10n.SettingsDetails.General.AppIcon.Enum.prideTrans
        case .NonBinary:
            return L10n.SettingsDetails.General.AppIcon.Enum.prideNonBinary
        }
    }

    var darkIcon: String {
        switch self {
        case .Release, .White, .Beta:
            return "icon-dark-mode"
        default:
            return "icon-\(rawValue)"
        }
    }

    var isDefault: Bool {
        switch Current.appConfiguration {
        case .debug where self == .Dev: return true
        case .beta where self == .Beta: return true
        case .release where self == .Release: return true
        default: return false
        }
    }

    var iconName: String? {
        if isDefault {
            return nil
        } else {
            return rawValue
        }
    }
}
