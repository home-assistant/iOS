import Foundation
import UIKit

public extension UIImage {
    static func sharedAssetsImage(named: String) -> UIImage? {
        UIImage(named: named, in: Bundle(for: AppEnvironment.self), with: nil)
    }
}
