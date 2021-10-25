import UIKit

extension UIAlertAction {
    typealias Handler = @convention(block) (UIAlertAction) -> Void

    var ha_handler: Handler {
        // https://stackoverflow.com/questions/36173740/trigger-uialertaction-on-uialertcontroller-programmatically
        let block = value(forKey: "handler")
        return unsafeBitCast(block as AnyObject, to: Handler.self)
    }
}
