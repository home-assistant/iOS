// swiftformat:disable fileHeader

/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */

import Foundation
import UIKit

open class OpenInFirefoxControllerSwift {
    let firefoxScheme = "firefox:"
    let basicURL = URL(string: "firefox://")!

    // This would need to be changed if used from an extension… but you
    // can't open arbitrary URLs from an extension anyway.
    let app = UIApplication.shared

    private func encodeByAddingPercentEscapes(_ input: String) -> String {
        NSString(string: input).addingPercentEncoding(
            withAllowedCharacters: .urlQueryAllowed
        )!
    }

    open func isFirefoxInstalled() -> Bool {
        app.canOpenURL(basicURL)
    }

    open func openInFirefox(_ url: URL) {
        let scheme = url.scheme
        if scheme == "http" || scheme == "https" {
            let escaped = encodeByAddingPercentEscapes(url.absoluteString)
            if let firefoxURL = URL(string: "firefox://open-url?url=\(escaped)") {
                app.open(firefoxURL, options: [:], completionHandler: nil)
            }
        }
    }
}
