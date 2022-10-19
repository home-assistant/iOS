// swiftformat:disable fileHeader

/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */

import Foundation
import UIKit

open class OpenInFirefoxControllerSwift {
    enum FirefoxType {
        case regular
        case focus
        case klar

        var urlScheme: String {
            switch self {
            case .regular:
                return "firefox"
            case .focus:
                return "firefox-focus"
            case .klar:
                return "firefox-klar"
            }
        }
    }

    let type: FirefoxType

    // This would need to be changed if used from an extension… but you
    // can't open arbitrary URLs from an extension anyway.
    let app = UIApplication.shared

    init(type: FirefoxType = .regular) {
        self.type = type
    }

    private func encodeByAddingPercentEscapes(_ input: String) -> String {
        NSString(string: input).addingPercentEncoding(
            withAllowedCharacters: .urlQueryAllowed
        )!
    }

    open func isFirefoxInstalled() -> Bool {
        app.canOpenURL(URL(string: "\(type.urlScheme)://")!)
    }

    open func openInFirefox(_ url: URL, privateTab: Bool = false) {
        let scheme = url.scheme
        if scheme == "http" || scheme == "https" {
            let escaped = encodeByAddingPercentEscapes(url.absoluteString)
            if let firefoxURL =
                URL(string: "\(type.urlScheme)://open-url?\(privateTab ? "private=true&" : "")url=\(escaped)") {
                app.open(firefoxURL, options: [:], completionHandler: nil)
            }
        }
    }
}
