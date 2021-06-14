import CoreLocation
import CoreMotion
import Eureka
import Foundation
import Shared
import UIKit

public final class LocationPermissionRow: Row<LabelCellOf<CLAuthorizationStatus>>, RowType {
    public required init(tag: String?) {
        super.init(tag: tag)

        displayValueFor = { value in
            guard let value = value else { return nil }

            switch value {
            case .authorizedAlways:
                return L10n.SettingsDetails.Location.LocationPermission.always
            case .authorizedWhenInUse:
                return L10n.SettingsDetails.Location.LocationPermission.whileInUse
            case .denied, .restricted:
                return L10n.SettingsDetails.Location.LocationPermission.never
            case .notDetermined:
                return L10n.SettingsDetails.Location.LocationPermission.needsRequest
            @unknown default:
                return L10n.SettingsDetails.Location.LocationPermission.never
            }
        }
    }
}

@available(iOS 14, *)
public final class LocationAccuracyRow: Row<LabelCellOf<CLAccuracyAuthorization>>, RowType {
    public required init(tag: String?) {
        super.init(tag: tag)

        displayValueFor = { value in
            guard let value = value else { return nil }

            switch value {
            case .fullAccuracy: return L10n.SettingsDetails.Location.LocationAccuracy.full
            case .reducedAccuracy: return L10n.SettingsDetails.Location.LocationAccuracy.reduced
            @unknown default:
                return L10n.SettingsDetails.Location.LocationAccuracy.reduced
            }
        }
    }
}

public final class MotionPermissionRow: Row<LabelCellOf<CMAuthorizationStatus>>, RowType {
    public required init(tag: String?) {
        super.init(tag: tag)

        displayValueFor = { value in
            guard let value = value else { return nil }

            switch value {
            case .authorized:
                return L10n.SettingsDetails.Location.MotionPermission.enabled
            case .denied, .restricted:
                return L10n.SettingsDetails.Location.MotionPermission.denied
            case .notDetermined:
                return L10n.SettingsDetails.Location.MotionPermission.needsRequest
            @unknown default:
                return L10n.SettingsDetails.Location.MotionPermission.denied
            }
        }
    }
}

public final class FocusPermissionRow: Row<LabelCellOf<FocusStatusWrapper.AuthorizationStatus>>, RowType {
    public required init(tag: String?) {
        super.init(tag: tag)

        displayValueFor = { value in
            guard let value = value else { return nil }

            switch value {
            case .authorized:
                return L10n.SettingsDetails.Location.MotionPermission.enabled
            case .denied, .restricted:
                return L10n.SettingsDetails.Location.MotionPermission.denied
            case .notDetermined:
                return L10n.SettingsDetails.Location.MotionPermission.needsRequest
            }
        }
    }
}

public final class BackgroundRefreshStatusRow: Row<LabelCellOf<UIBackgroundRefreshStatus>>, RowType {
    public required init(tag: String?) {
        super.init(tag: tag)

        displayValueFor = { value in
            guard let value = value else { return nil }

            switch value {
            case .restricted, .denied:
                return L10n.SettingsDetails.Location.BackgroundRefresh.disabled
            case .available:
                return L10n.SettingsDetails.Location.BackgroundRefresh.enabled
            @unknown default:
                return L10n.SettingsDetails.Location.BackgroundRefresh.disabled
            }
        }
    }
}

extension Condition {
    private static func locationPermissionAlways(from form: Form) -> Bool? {
        guard let row = form.rowBy(tag: "locationPermission") as? LocationPermissionRow else {
            return nil
        }

        switch row.value {
        case .some(.authorizedAlways):
            return true
        default:
            return false
        }
    }

    private static func locationAccuracyFull(from form: Form) -> Bool? {
        guard #available(iOS 14, *), let row = form.rowBy(tag: "locationAccuracy") as? LocationAccuracyRow else {
            return nil
        }

        switch row.value {
        case .some(.fullAccuracy):
            return true
        default:
            return false
        }
    }

    private static func backgroundRefreshAvailable(from form: Form) -> Bool? {
        guard let backgroundRefreshRow = form.rowBy(tag: "backgroundRefresh") as? BackgroundRefreshStatusRow else {
            return nil
        }

        switch backgroundRefreshRow.value {
        case .some(.available):
            return true
        default:
            return false
        }
    }

    struct LocationCondition: OptionSet {
        let rawValue: Int
        init(rawValue: Int) { self.rawValue = rawValue }
        static let permissionNotAlways = LocationCondition(rawValue: 0b1)
        static let accuracyNotFull = LocationCondition(rawValue: 0b10)
        static let backgroundRefreshNotAvailable = LocationCondition(rawValue: 0b100)
    }

    static func location(
        conditions: LocationCondition
    ) -> Condition {
        .function(["locationPermission", "locationAccuracy", "backgroundRefresh"], { form in
            if conditions.contains(.permissionNotAlways), locationPermissionAlways(from: form) == false {
                return true
            }

            if conditions.contains(.accuracyNotFull), locationAccuracyFull(from: form) == false {
                return true
            }

            if conditions.contains(.backgroundRefreshNotAvailable), backgroundRefreshAvailable(from: form) == false {
                return true
            }

            return false
        })
    }
}
