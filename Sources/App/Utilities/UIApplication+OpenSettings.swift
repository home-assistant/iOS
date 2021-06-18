import Shared
import UIKit

extension UIApplication {
    enum OpenSettingsDestination {
        case location
        case motion
        case notification
        case focus
        case backgroundRefresh

        var url: URL? {
            if Current.isCatalyst {
                let query: String?
                let bundleIdentifier: String?

                switch self {
                case .location:
                    bundleIdentifier = "com.apple.preference.security"
                    query = "Privacy_LocationServices"
                case .motion:
                    bundleIdentifier = nil
                    query = nil
                case .notification, .focus:
                    bundleIdentifier = "com.apple.preference.notifications"
                    query = nil
                case .backgroundRefresh:
                    bundleIdentifier = nil
                    query = nil
                }

                if let bundleIdentifier = bundleIdentifier {
                    return URL(string: "x-apple.systempreferences:\(bundleIdentifier)?\(query ?? "")")!
                } else {
                    return nil
                }
            } else {
                return URL(string: UIApplication.openSettingsURLString)!
            }
        }
    }

    func openSettings(destination: OpenSettingsDestination, completionHandler: ((Bool) -> Void)? = nil) {
        if let url = destination.url {
            UIApplication.shared.open(url, options: [:], completionHandler: completionHandler)
        } else {
            completionHandler?(false)
        }
    }
}
