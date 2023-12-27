import UIKit

extension UITextView {
    func configureCodeFont() {
        // a little smaller than the body size
        let baseSize = UIFont.preferredFont(forTextStyle: .body).pointSize - 2.0
        font = UIFont.monospacedSystemFont(ofSize: baseSize, weight: .regular)
    }
}
