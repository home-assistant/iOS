import Foundation
import Eureka
import UIKit
import CoreLocation
import CoreMotion

public final class LocationPermissionRow: Row<LabelCellOf<CLAuthorizationStatus>>, RowType {
    required public init(tag: String?) {
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

public final class MotionPermissionRow: Row<LabelCellOf<CMAuthorizationStatus>>, RowType {
    required public init(tag: String?) {
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

public final class BackgroundRefreshStatusRow: Row<LabelCellOf<UIBackgroundRefreshStatus>>, RowType {
    required public init(tag: String?) {
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
    static var locationPermissionNotAlways: Condition {
        .function(["locationPermission"], { form in
            guard let row = form.rowBy(tag: "locationPermission") as? LocationPermissionRow else {
                return true
            }

            switch row.value {
            case .some(.authorizedAlways):
                return false
            default:
                return true
            }
        })
    }

    static var locationNotAlwaysOrBackgroundRefreshNotAvailable: Condition {
        return .function(["locationPermission", "backgroundRefresh"], { form in
            guard
                let locationPermissionRow = form.rowBy(tag: "locationPermission") as? LocationPermissionRow,
                let backgroundRefreshRow = form.rowBy(tag: "backgroundRefresh") as? BackgroundRefreshStatusRow
            else {
                return true
            }

            switch (locationPermissionRow.value, backgroundRefreshRow.value) {
            case (.some(.authorizedAlways), .some(.available)):
                return false
            default:
                return true
            }
        })
    }
}
